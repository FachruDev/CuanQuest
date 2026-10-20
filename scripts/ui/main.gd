extends Control
## Shell aplikasi: top bar, area konten (5 tab), tombol Lanjut, navigasi bawah, popup.
## Analogi web: ini "layout" + router sederhana. Tiap tab adalah scene terpisah.
##
## Antrean popup: beberapa popup bisa muncul berurutan dalam satu giliran
## (laporan bulan -> instrumen baru terbuka -> event hidup). Popup berikutnya
## baru tampil setelah popup sebelumnya ditutup (signal `closed` dari ModalPopup).

const END_SCENE := "res://scenes/end_screen.tscn"
const ANNUAL_POPUP := preload("res://scenes/ui/annual_popup.tscn")
const LEVERAGE_POPUP := preload("res://scenes/ui/leverage_popup.tscn")
const FUND_POPUP := preload("res://scenes/ui/fund_popup.tscn")
const QUIET_ICON := preload("res://assets/icons/badge_retire.svg")  # masa senja & perpisahan (v2b)
const HEART_ICON := preload("res://assets/icons/heart.svg")  # kesehatan mental (v2b langkah 4)

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
var _annual_popup: ModalPopup  # laporan tahunan (v1.5d), dibuat lewat kode
var _leverage_popup: ModalPopup  # buka posisi / tambah margin (v2a), dibuat lewat kode
var _fund_popup: ModalPopup  # dana kelolaan investor (v2c), dibuat lewat kode
var _year_button: Button  # "+1 Tahun" di masa pensiun (v2b)


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
	_build_year_button()
	%GlossaryButton.pressed.connect(func() -> void: _enqueue(%GlossaryPopup.open))
	%ProfileScreen.glossary_requested.connect(func() -> void: _enqueue(%GlossaryPopup.open))
	GameState.changed.connect(_refresh_top_bar)
	GameState.month_advanced.connect(func(report: Dictionary) -> void:
		_enqueue(%SummaryPopup.show_report.bind(report))
		_enqueue_leverage_alert(report)
		if report.has("critical_ended"):  # v2b: pulih dari kondisi kritis
			_show_toast(tr("TOAST_CRITICAL_ENDED"))
		if report.has("depression_ended"):  # v2b langkah 4: pulih dari masa sulit
			_show_toast(tr("TOAST_DEPRESSION_ENDED"))
		if int(report.get("fund", {}).get("offers", 0)) > 0:  # v2c: tawaran investor baru
			_show_toast(tr("TOAST_FUND_OFFERS"))
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
	%ActivityScreen.contract_accepted.connect(_hint.bind("HINT_CONTRACT"))  # proyek sampingan pertama (v1.5d)
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
	# Menu Rumah & Kendaraan (Beranda v2): dibuka dari Beranda, popup-nya tetap lewat antrean di sini.
	%HomeScreen.assets_requested.connect(_show_assets)
	%AssetsScreen.back_requested.connect(_show_screen.bind(0))
	%AssetsScreen.vehicle_sell_requested.connect(_confirm_vehicle_sale)
	%AssetsScreen.property_sell_requested.connect(_confirm_property_listing)
	%AssetsScreen.moved_in.connect(_check_first_home)
	%AssetsScreen.vehicle_market_requested.connect(func() -> void:
		_hint("HINT_VEHICLE")
		_enqueue(%VehiclePopup.open_market))
	%AssetsScreen.vehicle_detail_requested.connect(func(uid: int) -> void:
		_enqueue(%VehiclePopup.open_detail.bind(uid)))
	%VehiclePopup.vehicle_bought.connect(func(vehicle_name: String) -> void:
		_show_toast(tr("TOAST_VEHICLE_BOUGHT") % tr(vehicle_name))
		_enqueue_plan_review())
	%VehiclePopup.vehicle_sold.connect(func(vehicle_name: String, net: int) -> void:
		_show_toast(tr("TOAST_VEHICLE_SOLD") % [tr(vehicle_name), Fmt.rupiah(net)]))
	%AssetsScreen.property_market_requested.connect(func() -> void:
		_hint("HINT_PROPERTY")
		_enqueue(%PropertyPopup.open_market))
	%AssetsScreen.property_detail_requested.connect(func(uid: int) -> void:
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
		_enqueue(_celebrating(%InfoPopup.open.bind(tr(stage.get("title_key", "UNLOCK_POPUP_TITLE")),
			tr(stage.get("body_key", "UNLOCK_POPUP_BODY")) % [tr(stage["name_key"]), UiText.stage_assets_text(int(stage["stage"]))]))))
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
	GameState.game_ended.connect(func(result: Dictionary) -> void:
		_popup_queue.clear()
		if result["type"] == "died":  # v2b: perpisahan yang tenang sebelum layar akhir
			_enqueue(%InfoPopup.open_quiet.bind(tr("DEATH_POPUP_TITLE"),
				UiText.death_text(result) + "\n\n" + tr("DEATH_POPUP_NOTE"), tr("DEATH_POPUP_OK"), QUIET_ICON))
		_enqueue(func() -> void: get_tree().change_scene_to_file(END_SCENE)))
	%ProfileScreen.text_requested.connect(func(title: String, body: String) -> void:
		_enqueue(%TextPopup.open.bind(title, body)))
	%ActivityScreen.quiz_requested.connect(func(question: Dictionary) -> void:
		_enqueue(%QuizPopup.open.bind(question)))
	_annual_popup = ANNUAL_POPUP.instantiate()
	add_child(_annual_popup)
	GameState.year_closed.connect(func(report: Dictionary) -> void:
		_enqueue(_annual_popup.open.bind(report)))
	%ProfileScreen.annual_requested.connect(func() -> void:
		_enqueue(_annual_popup.open.bind(GameState.annual.latest())))
	GameState.achievements_unlocked.connect(_on_achievements_unlocked)
	_setup_leverage()
	_setup_fund()
	GameState.chapter_changed.connect(func(summary: Dictionary) -> void:
		_enqueue(_celebrating(%InfoPopup.open.bind(tr("CHAPTER_POPUP_TITLE") % tr("CHAPTER_" + str(summary["to"]).to_upper()),
			_chapter_text(summary)))))
	GameState.retirement_started.connect(func(info: Dictionary) -> void:
		_enqueue(_celebrating(%InfoPopup.open.bind(tr("RETIRE_POPUP_TITLE"), _retirement_text(info)))))
	GameState.aging_changed.connect(func(age: int) -> void:
		_enqueue(%InfoPopup.open.bind(tr("AGING_POPUP_TITLE") % age, _aging_text())))
	GameState.critical_started.connect(func(info: Dictionary) -> void:
		_enqueue(%InfoPopup.open_warning.bind(tr("CRITICAL_POPUP_TITLE"), _critical_text(info), "", Callable(),
			tr("CRITICAL_POPUP_OK"))))
	GameState.depression_started.connect(func(info: Dictionary) -> void:
		_enqueue(%InfoPopup.open_quiet.bind(tr("DEPRESSION_POPUP_TITLE"), _depression_text(info), "", HEART_ICON)))
	GameState.twilight_notice.connect(func(info: Dictionary) -> void:
		_enqueue(%InfoPopup.open_quiet.bind(tr("TWILIGHT_POPUP_TITLE") % int(info["age"]), _twilight_text(info), "",
			QUIET_ICON)))
	for popup: ModalPopup in [%SummaryPopup, %InfoPopup, %EventPopup, %QuizPopup, %GlossaryPopup, %TextPopup,
			%PlanPopup, %DreamPickerPopup, %DreamPopup, %TradeConfirmPopup, %InsurancePopup, %OrderPopup, %OfferPopup,
			%LoanPopup, %VehiclePopup, %PropertyPopup, _annual_popup, _leverage_popup, _fund_popup]:
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
	GameState.check_achievements()  # pencapaian yang syaratnya sudah terpenuhi (mis. save lama)


func _show_screen(index: int) -> void:
	_nav_buttons[index].button_pressed = true  # lewat ButtonGroup: tombol lain otomatis lepas
	%AssetsScreen.hide()
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
	UiText.apply_avatar_frame(%PlayerAvatar.get_parent(), GameState.achievements.current_frame())
	if GameState.progress.level() > _last_level:
		_show_toast(tr("TOAST_LEVEL") % GameState.progress.level())
	_last_level = GameState.progress.level()
	_refresh_energy()
	var busy := GameState.events.has_pending() or GameState.is_over
	%NextButton.disabled = busy
	%NextButton.get_child(0).modulate.a = 0.45 if busy else 1.0
	_year_button.visible = GameState.life.retired
	_year_button.disabled = busy


## Pencapaian baru: satu popup perayaan berisi semua pencapaian yang terbuka bersamaan + hadiahnya.
func _on_achievements_unlocked(ids: Array[String]) -> void:
	var lines: Array[String] = []
	for id: String in ids:
		var def := GameState.achievements.def(id)
		var rewards: Array[String] = []
		if def.get("title", false):
			rewards.append(tr("ACH_REWARD_TITLE") % tr("TITLE_" + id.to_upper()))
		if def.has("frame"):
			rewards.append(tr("ACH_REWARD_FRAME") % tr("FRAME_" + str(def["frame"]).to_upper()))
		var line := "• " + tr("ACH_" + id.to_upper())
		if not rewards.is_empty():
			line += ": " + ", ".join(rewards)
		lines.append(line)
	_enqueue(_celebrating(%InfoPopup.open.bind(tr("ACH_POPUP_TITLE"), "\n".join(lines) + "\n\n" + tr("ACH_POPUP_NOTE"))))


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


## Leverage (v2a langkah 3): popup buka posisi & tambah margin, konfirmasi tutup posisi.
func _setup_leverage() -> void:
	_leverage_popup = LEVERAGE_POPUP.instantiate()
	add_child(_leverage_popup)
	%MarketScreen.leverage_requested.connect(_request_leverage)
	%HomeScreen.leverage_alert_requested.connect(_show_asset)
	%MarketScreen.margin_requested.connect(func(uid: int) -> void:
		_enqueue(_leverage_popup.open_margin.bind(uid)))
	%MarketScreen.close_position_requested.connect(_confirm_close_position)
	_leverage_popup.opened.connect(func(result: Dictionary) -> void:
		_show_toast(tr("TOAST_LEV_OPENED") % [LeverageView.side_text(result["side"]), int(result["leverage"]),
			tr(GameState.market.get_asset(result["asset_id"]).name_key)]))
	_leverage_popup.margin_added.connect(func(_asset_id: String, amount: int) -> void:
		_show_toast(tr("TOAST_LEV_MARGIN") % Fmt.rupiah(amount)))


## Dana kelolaan (v2c langkah 1): popup dari kartu Dana Kelolaan di Portofolio, toast hasil aksinya.
func _setup_fund() -> void:
	_fund_popup = FUND_POPUP.instantiate()
	add_child(_fund_popup)
	%PortfolioScreen.fund_requested.connect(func() -> void: _enqueue(_fund_popup.open))
	_fund_popup.accepted.connect(func(investor_name: String, amount: int) -> void:
		_show_toast(tr("TOAST_FUND_ACCEPTED") % [investor_name, Fmt.rupiah(amount)]))
	_fund_popup.funds_returned.connect(func(investor_name: String, payout: int) -> void:
		_show_toast(tr("TOAST_FUND_RETURNED") % [investor_name, Fmt.rupiah(payout)]))
	_fund_popup.allocation_applied.connect(func(cost: float) -> void:
		_show_toast(tr("TOAST_FUND_APPLIED") % Fmt.rupiah(cost)))
	GameState.fund_notice.connect(_on_fund_notice)


## Kabar investor bulan ini (v2c langkah 2) dalam satu popup; peringatan & investor pergi = popup merah.
func _on_fund_notice(notices: Array) -> void:
	var lines: PackedStringArray = []
	var bad := false
	for n: Dictionary in notices:
		lines.append(UiText.fund_notice_text(n))
		bad = bad or UiText.fund_notice_is_bad(n)
	if bad:
		lines.append(tr("FUND_NOTICE_TIP"))
		_enqueue(%InfoPopup.open_warning.bind(tr("FUND_NOTICE_TITLE"), "\n\n".join(lines), tr("PORT_FUND_OPEN"),
			func() -> void: _enqueue(_fund_popup.open), tr("BTN_CLOSE")))
	else:
		_enqueue(%InfoPopup.open.bind(tr("FUND_NOTICE_TITLE"), "\n\n".join(lines)))


# --- Siklus hidup (v2b) ---------------------------------------------------------------------------

## Tombol kedua di samping Lanjut, hanya di masa pensiun: lompat 12 bulan (berhenti otomatis bila ada
## event, peringatan, atau target tercapai; lihat GameState.fast_forward).
func _build_year_button() -> void:
	_year_button = UiText.chunky_button(tr("NEXT_YEAR_BUTTON"), &"NeutralButton", &"NeutralButtonLabel", 88.0, 24)
	_year_button.custom_minimum_size.x = 170
	_year_button.pressed.connect(func() -> void:
		Sfx.play("coin")
		GameState.fast_forward(12))
	%NextButton.get_parent().add_child(_year_button)


## Ringkasan bab yang selesai + pesan bab berikutnya.
func _chapter_text(summary: Dictionary) -> String:
	var start: Dictionary = summary["start"]
	var end: Dictionary = summary["end"]
	var ages := GameState.life.chapter_ages(summary["from"])
	var lines: PackedStringArray = [
		tr("CHAPTER_DONE") % [tr("CHAPTER_" + str(summary["from"]).to_upper()), ages[0], int(end["age"]) - 1],
		tr("CHAPTER_WORTH") % [Fmt.rupiah(start["worth"]), Fmt.rupiah(end["worth"]), Fmt.rupiah(end["real_worth"])],
		tr("CHAPTER_DREAMS") % (int(end["dreams"]) - int(start["dreams"])),
	]
	var job_id: String = end["job_id"]
	lines.append(tr("CHAPTER_JOB") % (tr(GameState.career.job_def(job_id)["title"]) if job_id != "" else tr("CHAPTER_NO_JOB")))
	var next_ages := GameState.life.chapter_ages(summary["to"])
	var range_text := "%d-%d" % next_ages if next_ages[1] >= 0 else "%d+" % next_ages[0]
	lines.append("")
	lines.append(tr("CHAPTER_NEXT") % [tr("CHAPTER_" + str(summary["to"]).to_upper()), range_text,
		tr("CHAPTER_TIP_" + str(summary["to"]).to_upper())])
	if summary.get("aging", false):  # efek usia berubah di ulang tahun yang sama (v2b langkah 2)
		lines.append("")
		lines.append(tr("CHAPTER_AGING"))
		for line in UiText.aging_lines():
			lines.append("• " + line)
	lines.append("")
	lines.append(tr("CHAPTER_SAVED"))
	return "\n".join(lines)


## Peringatan status Kritis (v2b langkah 3): peluang meninggal per tahun di usia ini (atau aturan
## kesehatan 0 selama 3 bulan bagi yang masih muda) dan cara memulihkan diri.
func _critical_text(info: Dictionary) -> String:
	var lines: PackedStringArray = [tr("CRITICAL_POPUP_BODY") % int(info["health"])]
	if float(info["chance"]) > 0.0:
		lines.append(tr("CRITICAL_POPUP_CHANCE") % UiText.percent_short(info["chance"]))
	else:
		lines.append(tr("CRITICAL_POPUP_YOUNG") % int(GameState.economy["end"]["danger_months"]))
	lines.append("")
	lines.append(tr("CRITICAL_POPUP_TIP") % int(GameState.life.data["mortality"]["critical_exit"]))
	return "\n".join(lines)


## Status Depresi dimulai (v2b langkah 4, pedoman konten sensitif): apa artinya di game, bahwa kamu
## bisa pulih dan bantuan apa yang tersedia, penjelasan bahwa ini simulasi, dan pesan dukungan untuk
## pemain sungguhan saat pertama kali muncul di permainan ini (tidak bisa dimatikan).
func _depression_text(info: Dictionary) -> String:
	var cfg: Dictionary = GameState.mental.data
	var lines: PackedStringArray = [
		tr("DEPRESSION_POPUP_BODY") % [int(cfg["enter_below"]), int(cfg["enter_months"]), -int(cfg["effects"]["energy"])],
		"", tr("DEPRESSION_POPUP_HELP") % int(cfg["exit_above"]), "", tr("DEPRESSION_POPUP_SIM")]
	if info.get("first", false):
		lines.append("")
		lines.append(tr("SUPPORT_MESSAGE"))
	return "\n".join(lines)


## Pemberitahuan masa senja tahunan (usia 70+): peluang tutup usia tahun ini dan saran; di usia 70
## sekaligus daftar efek usia.
func _twilight_text(info: Dictionary) -> String:
	var lines: PackedStringArray = [tr("TWILIGHT_POPUP_BODY") % UiText.percent_short(info["chance"]),
		tr("TWILIGHT_POPUP_HEALTH"), "", tr("TWILIGHT_POPUP_TIP"), ""]
	lines.append_array(UiText.runway_lines())  # v2b langkah 5
	if info.get("aging", false):
		lines.append("")
		lines.append(tr("CHAPTER_AGING"))
		for line in UiText.aging_lines():
			lines.append("• " + line)
	return "\n".join(lines)


## Popup ulang tahun saat efek penuaan berubah: daftar efek yang berlaku + saran menjaga kesehatan.
func _aging_text() -> String:
	var lines: PackedStringArray = [tr("AGING_POPUP_INTRO"), ""]
	for line in UiText.aging_lines():
		lines.append("• " + line)
	lines.append("")
	lines.append(tr("AGING_POPUP_TIP"))
	return "\n".join(lines)


func _retirement_text(info: Dictionary) -> String:
	var lines: PackedStringArray = [tr("RETIRE_POPUP_INTRO"), "", tr("RETIRE_JHT") % Fmt.rupiah(info["jht"])]
	if int(info["jp_monthly"]) > 0:
		lines.append(tr("RETIRE_JP_MONTHLY") % [Fmt.rupiah(info["jp_monthly"]), Fmt.number(info["years"], 1)])
	elif int(info["jp_lump"]) > 0:
		lines.append(tr("RETIRE_JP_LUMP") % Fmt.rupiah(info["jp_lump"]))
	else:
		lines.append(tr("RETIRE_JP_NONE"))
	lines.append("")
	lines.append_array(UiText.runway_lines())  # v2b langkah 5: sampai kapan dana pensiun cukup
	lines.append("")
	lines.append(tr("RETIRE_POPUP_TIP"))
	return "\n".join(lines)


## Sebelum transaksi leverage pertama di permainan ini, peringatan risiko wajib disetujui (v2a langkah 4).
func _request_leverage(asset_id: String) -> void:
	if GameState.leverage.risk_ack:
		_enqueue(_leverage_popup.open.bind(asset_id))
		return
	_enqueue(%InfoPopup.open_warning.bind(tr("LEV_RISK_TITLE"), tr("LEV_RISK_BODY"), tr("LEV_RISK_ACCEPT"), func() -> void:
		GameState.leverage.acknowledge_risk()
		_enqueue(_leverage_popup.open.bind(asset_id)), tr("BTN_CANCEL")))


## Laporan bulan ini memuat likuidasi atau margin call: peringatan tampil setelah laporan, dengan
## tombol ke detail aset yang perlu diurus (tambah margin / tutup posisi).
func _enqueue_leverage_alert(report: Dictionary) -> void:
	var lev: Dictionary = report.get("leverage", {})
	if lev.is_empty() or (lev["liquidated"].is_empty() and lev["margin_calls"].is_empty()):
		return
	var lines: PackedStringArray = []
	for item: Dictionary in lev["liquidated"]:
		lines.append(tr("LEV_ALERT_LIQUIDATED") % [tr(item["asset_key"]), LeverageView.side_text(item["side"]),
			int(item["leverage"]), int(item["day"]), Fmt.signed_rupiah(item["pnl"])])
		if float(item["shortfall"]) > 0.0:
			lines.append(tr("LEV_ALERT_SHORTFALL") % Fmt.rupiah(item["shortfall"]))
	var target := ""
	for item: Dictionary in lev["margin_calls"]:
		var asset := GameState.market.get_asset(item["asset_id"])
		lines.append(tr("LEV_ALERT_CALL") % [tr(item["asset_key"]), Fmt.percent_plain(float(item["equity"]) / float(item["margin"])),
			asset.price_text(item["liquidation_price"])])
		if target == "" and not GameState.leverage.position_of(asset.id).is_empty():
			target = asset.id
	var title := tr("LEV_ALERT_TITLE_CALL") if not lev["margin_calls"].is_empty() else tr("LEV_ALERT_TITLE_LIQ")
	if target != "":
		_enqueue(%InfoPopup.open_warning.bind(title, "\n".join(lines), tr("LEV_ALERT_SEE"), _show_asset.bind(target), tr("BTN_CLOSE")))
	else:
		_enqueue(%InfoPopup.open_warning.bind(title, "\n".join(lines)))


## Buka tab Pasar di detail aset (mis. dari peringatan margin call).
func _show_asset(asset_id: String) -> void:
	_show_screen(1)
	%MarketScreen.show_asset(asset_id)


## Konfirmasi tutup posisi: harga sekarang, fee tutup, uang kembali ke kas, untung/rugi.
func _confirm_close_position(uid: int) -> void:
	var p := GameState.leverage.find(uid)
	if p.is_empty():
		return
	var asset := GameState.market.get_asset(p["asset"])
	var q := GameState.leverage.close_quote(uid)
	var body := tr("LEV_CLOSE_BODY") % [LeverageView.side_text(p["side"]), int(p["leverage"]), tr(asset.name_key),
		asset.price_text(q["price"]), Fmt.rupiah(q["fee"]), Fmt.rupiah(q["proceeds"]), Fmt.signed_rupiah(q["pnl"])]
	_enqueue(%InfoPopup.open.bind(tr("LEV_CLOSE_TITLE"), body, tr("LEV_CLOSE_BUTTON"), func() -> void:
		var result := GameState.leverage.close(uid)
		if result["ok"]:
			_show_toast(tr("TOAST_LEV_CLOSED") % Fmt.signed_rupiah(result["pnl"])), tr("BTN_CANCEL")))


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


## Menu Rumah & Kendaraan menggantikan isi Beranda (tab Beranda tetap aktif di navigasi bawah).
func _show_assets(tab: String) -> void:
	for screen in _screens:
		screen.hide()
	%AssetsScreen.show()
	%AssetsScreen.open(tab)


## Konfirmasi jual kendaraan ke dealer: nilai pasar, harga jual, pelunasan kredit, diterima bersih.
func _confirm_vehicle_sale(uid: int) -> void:
	var vehicles := GameState.vehicles
	var entry := vehicles.find(uid)
	if entry.is_empty():
		return
	var vehicle_name := tr(vehicles.def(entry["id"])["name"])
	var q := vehicles.sell_quote(uid)
	var lines: PackedStringArray = [
		"%s: %s" % [tr("VEHICLE_ROW_VALUE"), Fmt.rupiah(q["value"])],
		"%s: %s" % [tr("VEHICLE_ROW_SELL_PRICE") % roundi(float(vehicles.data["sell_ratio"]) * 100.0), Fmt.rupiah(q["proceeds"])],
	]
	if int(q["payoff"]) > 0:
		lines.append("%s: %s" % [tr("VEHICLE_ROW_PAYOFF"), Fmt.signed_rupiah(-q["payoff"])])
	lines.append("%s: %s" % [tr("VEHICLE_ROW_NET"), Fmt.signed_rupiah(q["net"])])
	var title := tr("ASSETS_SELL_TITLE") % vehicle_name
	if not q["ok"]:
		lines.append("")
		lines.append(tr("VEHICLE_SELL_NO_CASH") % Fmt.rupiah(GameState.cash))
		_enqueue(%InfoPopup.open_warning.bind(title, "\n".join(lines)))
		return
	_enqueue(%InfoPopup.open.bind(title, "\n".join(lines), tr("ASSETS_SELL_CONFIRM"), func() -> void:
		var net: int = GameState.vehicles.sell_quote(uid)["net"]
		if GameState.vehicles.sell(uid):
			Sfx.play("coin")
			_show_toast(tr("TOAST_VEHICLE_SOLD") % [vehicle_name, Fmt.rupiah(net)]), tr("BTN_CANCEL")))


## Konfirmasi pasang iklan jual properti: harga hari ini dikurangi pajak, komisi agen, dan pelunasan KPR.
func _confirm_property_listing(uid: int) -> void:
	var properties := GameState.properties
	var entry := properties.find(uid)
	if entry.is_empty():
		return
	var property_name := tr(properties.def(entry["id"])["name"])
	var q := properties.sell_quote(entry)
	var lines: PackedStringArray = [
		"%s: %s" % [tr("PROPERTY_ROW_SELL_PRICE"), Fmt.rupiah(q["price"])],
		"%s: %s" % [tr("PROPERTY_ROW_SELL_TAX") % Fmt.percent_plain(properties.data["sell_tax"]), Fmt.signed_rupiah(-q["tax"])],
		"%s: %s" % [tr("PROPERTY_ROW_SELL_FEE") % Fmt.percent_plain(properties.data["sell_fee"]), Fmt.signed_rupiah(-q["fee"])],
	]
	if int(q["payoff"]) > 0:
		lines.append("%s: %s" % [tr("VEHICLE_ROW_PAYOFF"), Fmt.signed_rupiah(-q["payoff"])])
	lines.append("%s: %s" % [tr("VEHICLE_ROW_NET"), Fmt.signed_rupiah(q["net"])])
	lines.append("")
	lines.append(tr("PROPERTY_SELL_NOTE") % [int(properties.data["sell_months"][0]), int(properties.data["sell_months"][1])])
	var title := tr("ASSETS_LIST_TITLE") % property_name
	if not q["ok"]:
		lines.append("")
		lines.append(tr("PROPERTY_SELL_LOCKED") % Fmt.game_date(properties.sellable_from(entry)) if q["locked"]
			else tr("VEHICLE_SELL_NO_CASH") % Fmt.rupiah(GameState.cash))
		_enqueue(%InfoPopup.open_warning.bind(title, "\n".join(lines)))
		return
	_enqueue(%InfoPopup.open.bind(title, "\n".join(lines), tr("PROPERTY_LIST_BUTTON"), func() -> void:
		if GameState.properties.list_for_sale(uid):
			_show_toast(tr("TOAST_PROPERTY_LISTED") % property_name), tr("BTN_CANCEL")))


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
