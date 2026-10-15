extends Control
## Shell aplikasi: top bar, area konten (5 tab), tombol Lanjut, navigasi bawah, popup.
## Analogi web: ini "layout" + router sederhana. Tiap tab adalah scene terpisah.
##
## Antrean popup: beberapa popup bisa muncul berurutan dalam satu giliran
## (laporan bulan -> instrumen baru terbuka -> event hidup). Popup berikutnya
## baru tampil setelah popup sebelumnya ditutup (signal `closed` dari ModalPopup).

const END_SCENE := "res://scenes/end_screen.tscn"

## Petunjuk kontekstual saat tab dibuka pertama kali (index tab -> key teks).
const TAB_HINTS := {1: "HINT_MARKET", 2: "HINT_PORTFOLIO", 3: "HINT_ACTIVITY", 4: "HINT_PROFILE"}
const BOLT_ICON := preload("res://assets/icons/bolt.svg")
const BOLT_FULL := Color("#ffc95c")
const BOLT_EMPTY := Color("#5a4e78")
const NAV_MUTED := Color("#7a6650")

@onready var _screens: Array[Control] = [
	%HomeScreen, %MarketScreen, %PortfolioScreen, %ActivityScreen, %ProfileScreen]
@onready var _nav_buttons: Array[Button] = [
	%NavHome, %NavMarket, %NavPortfolio, %NavActivity, %NavProfile]

var _popup_queue: Array[Callable] = []
var _popup_open := false
var _last_level := 0
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween


func _ready() -> void:
	# Saat scene ini dijalankan langsung dari editor (F6) tanpa lewat layar judul.
	if not GameState.is_active:
		GameState.new_game()

	var group := ButtonGroup.new()
	for i in _nav_buttons.size():
		_nav_buttons[i].button_group = group
		_nav_buttons[i].pressed.connect(_show_screen.bind(i))
		_nav_buttons[i].toggled.connect(_style_nav.bind(_nav_buttons[i]))
		_style_nav(false, _nav_buttons[i])
	%PlayerAvatar.avatar_index = GameState.avatar
	%PlayerName.text = GameState.player_name

	%NextButton.pressed.connect(func() -> void:
		Sfx.play("coin")
		GameState.advance_month())
	%GlossaryButton.pressed.connect(func() -> void: _enqueue(%GlossaryPopup.open))
	%ProfileScreen.glossary_requested.connect(func() -> void: _enqueue(%GlossaryPopup.open))
	GameState.changed.connect(_refresh_top_bar)
	GameState.month_advanced.connect(func(report: Dictionary) -> void:
		_enqueue(%SummaryPopup.show_report.bind(report))
		if GameState.research.has_rumor():  # rumor pertama (v1.5d): jelaskan riset di tab Pasar
			_hint("HINT_RUMOR")
		_enqueue_plan_review())
	%HomeScreen.plan_requested.connect(func() -> void: _enqueue(%PlanPopup.open))
	GameState.job_offers_received.connect(func(_offers: Array) -> void:
		_enqueue(_celebrating(%OfferPopup.open)))
	%OfferPopup.offer_accepted.connect(func(title: String, first_salary: int) -> void:
		var text := tr("TOAST_JOB") % tr(title)
		if first_salary > 0:
			text += " " + tr("TOAST_FIRST_SALARY") % Fmt.rupiah(first_salary)
		_show_toast(text)
		_enqueue_plan_review())  # gaji pertama/baru: susun atau tinjau rencana gaji
	GameState.career_changed.connect(func(kind: String, title: String) -> void:
		if kind == "promoted":
			_show_toast(tr("TOAST_PROMOTED") % tr(title))
			_enqueue_plan_review())  # gaji baru: tinjau rencana gaji
	%ActivityScreen.resign_requested.connect(func() -> void:
		_enqueue(%InfoPopup.open.bind(tr("RESIGN_TITLE"), tr("RESIGN_BODY"), tr("RESIGN_CONFIRM"), func() -> void:
			GameState.career.resign()
			_show_toast(tr("TOAST_RESIGNED")), tr("BTN_CANCEL"))))
	%ActivityScreen.enroll_requested.connect(_confirm_enroll)
	%ActivityScreen.quit_study_requested.connect(func() -> void:
		_enqueue(%InfoPopup.open.bind(tr("EDU_QUIT_TITLE"), tr("EDU_QUIT_BODY"), tr("EDU_QUIT_CONFIRM"),
			GameState.education.quit_study, tr("BTN_CANCEL"))))
	GameState.graduated.connect(func(program: String, result: String, skill_gain: int) -> void:
		_enqueue(_celebrating(%InfoPopup.open.bind(tr("EDU_GRADUATED_TITLE"),
			tr("EDU_GRADUATED_BODY") % [tr(program), result, result, skill_gain]))))
	%HomeScreen.career_requested.connect(_show_screen.bind(3))
	%HomeScreen.insurance_requested.connect(func() -> void: _enqueue(%InsurancePopup.open))
	%HomeScreen.loan_requested.connect(func(product_id: String) -> void:
		_hint("HINT_LOAN")
		_enqueue(%LoanPopup.open_apply.bind(product_id)))
	%HomeScreen.loan_detail_requested.connect(func(loan_id: int) -> void:
		_enqueue(%LoanPopup.open_detail.bind(loan_id)))
	%LoanPopup.loan_taken.connect(func(loan_name: String, amount: int) -> void:
		_show_toast(tr("TOAST_LOAN") % [tr(loan_name), Fmt.rupiah(amount)]))
	%LoanPopup.loan_paid_off.connect(func(loan_name: String) -> void:
		_show_toast(tr("TOAST_LOAN_PAID") % tr(loan_name)))
	%HomeScreen.vehicle_buy_requested.connect(func(vehicle_id: String) -> void:
		_hint("HINT_VEHICLE")
		_enqueue(%VehiclePopup.open_buy.bind(vehicle_id)))
	%HomeScreen.vehicle_detail_requested.connect(func(vehicle_id: String) -> void:
		_enqueue(%VehiclePopup.open_detail.bind(vehicle_id)))
	%VehiclePopup.vehicle_bought.connect(func(vehicle_name: String) -> void:
		_show_toast(tr("TOAST_VEHICLE_BOUGHT") % tr(vehicle_name))
		_enqueue_plan_review())
	%VehiclePopup.vehicle_sold.connect(func(vehicle_name: String, net: int) -> void:
		_show_toast(tr("TOAST_VEHICLE_SOLD") % [tr(vehicle_name), Fmt.rupiah(net)]))
	%HomeScreen.property_market_requested.connect(func() -> void:
		_hint("HINT_PROPERTY")
		_enqueue(%PropertyPopup.open_market))
	%HomeScreen.property_detail_requested.connect(func(uid: int) -> void:
		_enqueue(%PropertyPopup.open_detail.bind(uid)))
	%PropertyPopup.property_bought.connect(func(property_name: String) -> void:
		_show_toast(tr("TOAST_PROPERTY_BOUGHT") % tr(property_name))
		_check_first_home()
		_enqueue_plan_review())
	%PropertyPopup.moved_in.connect(_check_first_home)
	%PropertyPopup.property_listed.connect(func(property_name: String) -> void:
		_show_toast(tr("TOAST_PROPERTY_LISTED") % tr(property_name)))
	%MarketScreen.trade_requested.connect(func(asset_id: String, is_buy: bool, amount: int) -> void:
		_enqueue(%TradeConfirmPopup.open.bind(asset_id, is_buy, amount)))
	%TradeConfirmPopup.trade_done.connect(%MarketScreen.show_trade_result)
	%MarketScreen.order_requested.connect(func(asset_id: String) -> void:
		_enqueue(%OrderPopup.open.bind(asset_id)))
	GameState.stage_unlocked.connect(func(stage: Dictionary) -> void:
		_enqueue(_celebrating(%InfoPopup.open.bind(tr("UNLOCK_POPUP_TITLE"),
			tr("UNLOCK_POPUP_BODY") % [tr(stage["name_key"]), UiText.stage_assets_text(int(stage["stage"]))]))))
	GameState.event_triggered.connect(func(event: Dictionary) -> void:
		_enqueue(%EventPopup.open.bind(event)))
	GameState.goal_reached.connect(func(goal: String) -> void:
		_enqueue(_celebrating(%InfoPopup.open.bind(tr("GOAL_TITLE_" + goal.to_upper()), tr("GOAL_BODY_" + goal.to_upper()),
			tr("GOAL_FINISH_NOW"), GameState.finish_game.bind("win", goal)))))
	GameState.dream_achieved.connect(func(dream: Dictionary) -> void:
		var def: Dictionary = dream["def"]
		var body := tr("DREAM_ACHIEVED_BODY") % [tr(def["name"]), int(def["happiness"]), int(def["xp"])]
		if def.get("keep_funds", false):  # DP Rumah: dananya masuk kas untuk membeli properti
			body += "\n\n" + tr("DREAM_ACHIEVED_FUNDS") % Fmt.rupiah(dream["cost"])
		_enqueue(_celebrating(%InfoPopup.open.bind(tr("DREAM_ACHIEVED_TITLE"), body))))
	GameState.dream_overdue.connect(func(dream: Dictionary) -> void:
		_enqueue(%DreamPopup.open_overdue.bind(dream)))
	GameState.target_completed.connect(func(target: Dictionary) -> void:
		_show_toast(tr("TOAST_TARGET") % UiText.target_text(target)))
	%HomeScreen.dream_requested.connect(func(dream_id: String) -> void:
		_enqueue(%DreamPopup.open_detail.bind(dream_id)))
	%HomeScreen.add_dream_requested.connect(func() -> void: _enqueue(%DreamPickerPopup.open))
	# Impian baru di tengah permainan: buka Rencana Gaji agar porsi pos impiannya bisa dicek.
	%DreamPickerPopup.dreams_picked.connect(func() -> void:
		if GameState.budget.plan.get("confirmed", false):
			_enqueue(%PlanPopup.open))
	# Game berakhir: popup yang masih mengantre (event, unlock) dibuang karena tidak relevan lagi.
	# Popup yang sedang tampil (mis. laporan bulan terakhir) tetap dibaca dulu, lalu pindah ke layar akhir.
	GameState.game_ended.connect(func(_result: Dictionary) -> void:
		_popup_queue.clear()
		_enqueue(func() -> void: get_tree().change_scene_to_file(END_SCENE)))
	%ProfileScreen.text_requested.connect(func(title: String, body: String) -> void:
		_enqueue(%TextPopup.open.bind(title, body)))
	%ActivityScreen.quiz_requested.connect(func(question: Dictionary) -> void:
		_enqueue(%QuizPopup.open.bind(question)))
	for popup: ModalPopup in [%SummaryPopup, %InfoPopup, %EventPopup, %QuizPopup, %GlossaryPopup, %TextPopup,
			%PlanPopup, %DreamPickerPopup, %DreamPopup, %TradeConfirmPopup, %InsurancePopup, %OrderPopup, %OfferPopup,
			%LoanPopup, %VehiclePopup, %PropertyPopup]:
		popup.closed.connect(_show_next_popup)

	_build_toast()
	_last_level = GameState.progress.level()
	_show_screen(0)
	_refresh_top_bar()
	# Cerita hari pertama (v1.5b langkah 4): belum bekerja, modal kecil, ajak ke Lowongan.
	if GameState.month == 0 and not GameState.career.is_employed() and GameState.mark_story("start"):
		var story := tr("STORY_START_" + str(GameState.background["id"]).to_upper()) \
			% Fmt.rupiah_words(GameState.nominal(GameState.difficulty["start_cash"]))
		_enqueue(%InfoPopup.open.bind(tr("STORY_START_TITLE"), story, tr("HOME_SEE_OPENINGS"), _show_screen.bind(3)))
	# Event yang belum diputuskan saat game disimpan muncul lagi setelah dimuat.
	if GameState.events.has_pending():
		_enqueue(%EventPopup.open.bind(GameState.events.pending))
	if not GameState.career.job_offers.is_empty():  # tawaran kerja yang belum diputuskan
		_enqueue(%OfferPopup.open)
	# Permainan baru: pilih impian dulu, lalu susun rencana gaji pertama.
	if not GameState.dreams.asked:
		_enqueue(%DreamPickerPopup.open)
	_enqueue_plan_review()
	for dream: Dictionary in GameState.dreams.overdue():  # tenggat terlewat sebelum game ditutup
		_enqueue(%DreamPopup.open_overdue.bind(GameState.dreams.view_of(dream)))


func _show_screen(index: int) -> void:
	_nav_buttons[index].button_pressed = true  # lewat ButtonGroup: tombol lain otomatis lepas
	for i in _screens.size():
		_screens[i].visible = i == index
	if TAB_HINTS.has(index) and GameState.consume_hint(TAB_HINTS[index]):
		_enqueue(%InfoPopup.open.bind(tr("HINT_TITLE"), tr(TAB_HINTS[index])))


func _refresh_top_bar() -> void:
	%CashValue.text = Fmt.rupiah(GameState.cash)
	%CashValue.add_theme_color_override("font_color", Palette.LOSS if GameState.cash < 0 else Palette.INK)
	%NetWorthValue.text = Fmt.rupiah(GameState.net_worth())
	%DateLabel.text = Fmt.game_date(GameState.month)
	%AgeLabel.text = tr("TOPBAR_AGE") % GameState.age()
	%LevelLabel.text = tr("TOPBAR_LEVEL") % GameState.progress.level()
	if GameState.progress.level() > _last_level:
		_show_toast(tr("TOAST_LEVEL") % GameState.progress.level())
	_last_level = GameState.progress.level()
	_refresh_energy()
	var busy := GameState.events.has_pending() or GameState.is_over
	%NextButton.disabled = busy
	%NextButton.get_child(0).modulate.a = 0.45 if busy else 1.0


## Satu ikon petir per poin energi bulan ini: kuning = tersisa, ungu redup = terpakai.
func _refresh_energy() -> void:
	var icons: Control = %EnergyIcons
	while icons.get_child_count() < GameState.activities.energy_capacity:
		var bolt := TextureRect.new()
		bolt.texture = BOLT_ICON
		bolt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bolt.custom_minimum_size = Vector2(18, 22)
		bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icons.add_child(bolt)
	for i in icons.get_child_count():
		var bolt: TextureRect = icons.get_child(i)
		bolt.visible = i < GameState.activities.energy_capacity
		bolt.self_modulate = BOLT_FULL if i < GameState.activities.energy else BOLT_EMPTY
	%EnergyPill.tooltip_text = tr("TOPBAR_ENERGY") % [GameState.activities.energy, GameState.activities.energy_capacity]


## Tab aktif: ikon & label tinta di atas pil emas; tab lain: cokelat redup.
func _style_nav(active: bool, button: Button) -> void:
	var color := Palette.INK if active else NAV_MUTED
	button.get_node("Content/Icon").self_modulate = color
	button.get_node("Content/Label").add_theme_color_override("font_color", color)


## Membungkus pembuka popup agar confetti ikut tampil (impian, tahap baru, target kemenangan).
## Petunjuk sekali seumur pemain sebelum sebuah fitur dibuka pertama kali (pinjaman, kendaraan,
## properti; v1.5c langkah 4). Tampil sebelum popup fiturnya.
func _hint(key: String) -> void:
	if GameState.consume_hint(key):
		_enqueue(%InfoPopup.open.bind(tr("HINT_TITLE"), tr(key)))


## Cerita pertama kali menghuni rumah sendiri (sekali per permainan).
func _check_first_home() -> void:
	var home := GameState.properties.home()
	if home.is_empty() or not GameState.mark_story("first_home"):
		return
	var name := tr(GameState.properties.def(home["id"])["name"])
	_enqueue(_celebrating(%InfoPopup.open.bind(tr("STORY_HOME_TITLE"), tr("STORY_HOME_BODY") % name)))


func _celebrating(show_popup: Callable) -> Callable:
	return func() -> void:
		show_popup.call()
		Sfx.vibrate()
		Confetti.burst(self)


## Notifikasi singkat di bawah top bar (target selesai, naik level). Tidak menghalangi sentuhan.
func _build_toast() -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	holder.offset_top = 200.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast = PanelContainer.new()
	_toast.theme_type_variation = &"PillPanel"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.hide()
	_toast_label = Label.new()
	_toast_label.theme_type_variation = &"PillLabel"
	_toast_label.add_theme_font_size_override("font_size", 18)
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.custom_minimum_size.x = 600.0  # teks panjang dibungkus, tidak melebar keluar layar
	_toast.add_child(_toast_label)
	holder.add_child(_toast)
	add_child(holder)


func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.show()
	_toast.modulate.a = 1.0
	Sfx.play("success")
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(_toast.hide)


## Konfirmasi daftar kuliah: lama, biaya per bulan & total, beban energi & kebahagiaan.
func _confirm_enroll(program_id: String) -> void:
	var option := GameState.education.program_option(program_id)
	if option.is_empty():
		return
	var load: Dictionary = GameState.education.data["load"]
	var fee := int(option["fee"])
	var body := tr("EDU_ENROLL_BODY") % [int(option["months"]), Fmt.rupiah(fee),
		Fmt.rupiah(fee * int(option["months"])), int(load["energy"]), -int(load["happiness"])]
	_enqueue(%InfoPopup.open.bind(tr(option["def"]["name"]), body, tr("EDU_ENROLL_CONFIRM"), func() -> void:
		if GameState.education.enroll(program_id)["ok"]:
			_show_toast(tr("TOAST_ENROLLED") % tr(option["def"]["name"])), tr("BTN_CANCEL")))


## Rencana gaji perlu dicek (belum pernah disimpan atau gaji berubah). Diperiksa lagi saat
## gilirannya tiba, karena event di antrean bisa saja mengubah gaji lebih dulu.
func _enqueue_plan_review() -> void:
	_enqueue(func() -> void:
		if GameState.budget.needs_review() and not GameState.is_over:
			%PlanPopup.open()
		else:
			_show_next_popup())


func _enqueue(show_popup: Callable) -> void:
	_popup_queue.append(show_popup)
	if not _popup_open:
		_show_next_popup()


func _show_next_popup() -> void:
	if _popup_queue.is_empty():
		_popup_open = false
		return
	_popup_open = true
	_popup_queue.pop_front().call()
