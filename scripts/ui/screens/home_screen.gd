extends VBoxContainer
## Tab Beranda v2 (tema "Senja Cuan"): tiga bagian lewat tombol segmen di atas, sehingga tiap bagian
## cukup 1-2 layar gulir (dulu 12 kartu dalam satu gulungan panjang).
## - Hari Ini   : ilustrasi hunian & kendaraan + kondisi, peringatan penting, karier, target, impian
## - Keuangan   : ke mana gaji pergi (batang bertumpuk + rincian per pos), utang & kredit, perlindungan
## - Gaya Hidup : makan & tempat tinggal, ringkasan kendaraan & properti -> menu Rumah & Kendaraan

signal plan_requested
signal dream_requested(dream_id: String)
signal add_dream_requested
signal insurance_requested
## Tombol di kartu Karier: buka tab Karier (lowongan / pekerjaan / aktivitas pemulihan).
signal career_requested
## Peringatan margin call ditekan (v2a): buka detail aset posisinya.
signal leverage_alert_requested(asset_id: String)
## Kartu Utang & Kredit (v1.5c): ajukan pinjaman baru / buka rincian pinjaman.
signal loan_requested(product_id: String)
signal loan_detail_requested(loan_id: int)
## Menu Rumah & Kendaraan (Beranda v2): tab "home" | "vehicles" | "properties".
signal assets_requested(tab: String)

enum Page { TODAY, MONEY, LIFE }
const PAGE_KEYS: Array[String] = ["HOME_SEG_TODAY", "HOME_SEG_MONEY", "HOME_SEG_LIFE"]
## Kelompok arus kas (bagian Keuangan), urutan tetap; warna lolos uji buta warna & kontras.
const FLOW_GROUPS: Array[Array] = [
	["duty", "HOME_FLOW_DUTY", Color("#d45a3c")],
	["lifestyle", "HOME_FLOW_LIFESTYLE", Color("#8360d1")],
	["saving", "HOME_FLOW_SAVING", Color("#00907c")],
	["left", "HOME_FLOW_LEFT", Color("#c2810f")],
]
## Ikon impian: assets/icons/dreams/<id>.svg (cadangan: bintang); warna kotak mengikuti jangka waktunya.
const DREAM_ICON := "res://assets/icons/dreams/%s.svg"
const DREAM_ICON_FALLBACK := "res://assets/icons/badge_star.svg"
const DREAM_TILES := {"short": &"IconTileGold", "medium": &"IconTileBlue", "long": &"IconTileCoral"}
const CHEVRON := preload("res://assets/icons/chevron_right.svg")
const WARNING_ICON := "res://assets/icons/warning_small.svg"
const TARGET_ICONS := {
	"done": preload("res://assets/icons/req_ok.svg"), "failed": preload("res://assets/icons/req_no.svg"),
	"open": preload("res://assets/icons/target_open.svg"),
}
const TARGET_CHIPS := {"done": &"MoodGreen", "failed": &"MoodRed", "open": &"MoodNeutral"}

var _page := Page.TODAY
var _segments: Array[Button] = []
var _pages: Array[VBoxContainer] = []

# --- Hari Ini
var _scene: HomeScene
var _scene_caption: Label
var _health_bar: ProgressBar
var _health_value: Label
var _happiness_bar: ProgressBar
var _happiness_value: Label
var _workload_label: Label
var _alerts_box: VBoxContainer
var _career_box: VBoxContainer
var _targets_box: VBoxContainer
var _targets_side: Label
var _dreams_grid: GridContainer
var _dreams_side: Label

# --- Keuangan
var _flow_caps: Label
var _flow_value: Label
var _flow_note: Label
var _flow_bar: FlowBar
var _flow_legend: GridContainer
var _flow_details: VBoxContainer
var _details_label: Label
var _debt_box: VBoxContainer
var _insurance_box: VBoxContainer
var _premium_side: Label

# --- Gaya Hidup
var _food_buttons: Dictionary = {}     # option_id -> Button
var _housing_buttons: Dictionary = {}
var _food_desc: Label
var _housing_desc: Label
var _own_home_panel: PanelContainer
var _own_home_title: Label
var _own_home_sub: Label
var _move_hint: Label
var _assets_entry_box: HBoxContainer
var _vehicle_box: VBoxContainer
var _vehicle_side: Label
var _property_box: VBoxContainer
var _property_side: Label


func _ready() -> void:
	_pages = [%Today, %Money, %Life]
	_build_segments()
	_build_today()
	_build_money()
	_build_life()
	GameState.changed.connect(_refresh)
	visibility_changed.connect(_refresh)  # tab tersembunyi tidak diperbarui (penutup v1.5)
	show_page(Page.TODAY)


## Pindah bagian (juga dipakai main.gd, mis. kembali dari menu Rumah & Kendaraan ke Gaya Hidup).
func show_page(page: int) -> void:
	_page = page
	for i in _pages.size():
		_pages[i].visible = i == page
		_segments[i].set_pressed_no_signal(i == page)
	%Scroll.scroll_vertical = 0
	_refresh()


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	match _page:
		Page.TODAY:
			_refresh_today()
		Page.MONEY:
			_refresh_money()
		Page.LIFE:
			_refresh_life()


func _build_segments() -> void:
	var group := ButtonGroup.new()
	for i in PAGE_KEYS.size():
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = &"SegmentButton"
		button.text = tr(PAGE_KEYS[i])
		button.add_theme_font_size_override("font_size", 22)
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(show_page.bind(i))
		%Segments.get_node("Row").add_child(button)
		_segments.append(button)


# ==================================================================================================
# Hari Ini
# ==================================================================================================

func _build_today() -> void:
	var page: VBoxContainer = %Today
	var hero := _card(page, &"HeroCard", 14)
	var scene_button := Button.new()  # ketuk ilustrasi: buka menu Rumah & Kendaraan
	scene_button.flat = true
	scene_button.focus_mode = Control.FOCUS_NONE
	scene_button.custom_minimum_size = Vector2(0, 258)
	scene_button.pressed.connect(assets_requested.emit.bind("home"))
	_scene = HomeScene.new()
	_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene_button.add_child(_scene)
	var pill := PanelContainer.new()
	pill.theme_type_variation = &"DatePill"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_caption = _label("", &"TopChipLabel")
	pill.add_child(_scene_caption)
	scene_button.add_child(pill)
	pill.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hero.add_child(scene_button)

	var meters := GridContainer.new()
	meters.columns = 2
	meters.add_theme_constant_override("h_separation", 18)
	var health := _meter("res://assets/icons/heart.svg", &"IconTileCoral", "STAT_HEALTH", &"HealthBar")
	var happiness := _meter("res://assets/icons/smile.svg", &"IconTileGold", "STAT_HAPPINESS", &"HappinessBar")
	_health_bar = health[1]
	_health_value = health[2]
	_happiness_bar = happiness[1]
	_happiness_value = happiness[2]
	meters.add_child(health[0])
	meters.add_child(happiness[0])
	hero.add_child(_padded(meters, 6))
	_workload_label = _wrap(&"SmallMutedLabel")
	hero.add_child(_padded(_workload_label, 6))

	_alerts_box = VBoxContainer.new()
	_alerts_box.add_theme_constant_override("separation", 12)
	page.add_child(_alerts_box)

	_career_box = VBoxContainer.new()
	_career_box.add_theme_constant_override("separation", 10)
	page.add_child(_career_box)

	_targets_side = _title(page, tr("TARGETS_TITLE"))
	_targets_box = _card(page, &"HomeCard", 0)

	_dreams_side = _title(page, tr("DREAMS_TITLE"))
	_dreams_grid = GridContainer.new()
	_dreams_grid.columns = 2
	_dreams_grid.add_theme_constant_override("h_separation", 14)
	_dreams_grid.add_theme_constant_override("v_separation", 14)
	page.add_child(_dreams_grid)


func _refresh_today() -> void:
	_scene.refresh()
	_scene_caption.text = HomeScene.caption()
	_health_bar.value = GameState.health
	_health_value.text = str(GameState.health)
	_happiness_bar.value = GameState.happiness
	_happiness_value.text = str(GameState.happiness)
	_workload_label.text = _workload_text()
	_refresh_alerts()
	_refresh_career()
	_refresh_targets()
	_refresh_dreams()


## Penyebab perubahan kesehatan & kebahagiaan tiap bulan: beban kerja, stres mencari kerja, cuti,
## beban kuliah, dan usia.
func _workload_text() -> String:
	var text := ""
	if GameState.life.retired:  # v2b: tanpa beban kerja & tanpa stres mencari kerja
		text = tr("HOME_RETIRED_NOTE")
	elif not GameState.career.is_employed():
		var unemployed: Dictionary = GameState.economy["monthly_drift"].get("unemployed", {})
		text = tr("HOME_JOBLESS_NOTE") % int(unemployed.get("happiness", 0))
	elif GameState.career.unpaid_months > 0:
		text = tr("HOME_LEAVE_NOTE")
	else:
		var def := GameState.career.current_job_def()
		var workload: Dictionary = def.get("workload", {})
		text = tr("HOME_WORKLOAD_NOTE") % [tr(def["title"]), int(workload.get("health", 0)), int(workload.get("happiness", 0))]
	if GameState.education.is_studying():
		var load: Dictionary = GameState.education.data["load"]
		text += " " + tr("HOME_STUDY_NOTE") % [int(load["energy"]), -int(load["happiness"])]
	var aging := UiText.aging_short()  # v2b: energi & kesehatan menurun seiring usia
	if aging != "":
		text += " " + aging
	return text


## Peringatan penting, urut dari yang paling mendesak: kondisi kritis, margin call, suasana hati rendah /
## Depresi, impian lewat tenggat, cicilan menunggak.
func _refresh_alerts() -> void:
	_clear(_alerts_box)
	if GameState.life.critical:
		_alerts_box.add_child(_alert(tr("HOME_ALERT_CRITICAL"),
			tr("HOME_CRITICAL") % [GameState.health, int(GameState.life.data["mortality"]["critical_exit"])],
			tr("HOME_CRITICAL_ACTION"), career_requested.emit))
	var calls := GameState.leverage.calls()
	if not calls.is_empty():
		_alerts_box.add_child(_alert(tr("HOME_ALERT_MARGIN"), tr("HOME_MARGIN_CALL") % calls.size(),
			tr("HOME_MARGIN_CALL_SEE"), func() -> void:
				var current := GameState.leverage.calls()
				if not current.is_empty():
					leverage_alert_requested.emit(current[0]["asset"])))
	var mental := GameState.mental
	if mental.depressed or GameState.happiness < int(mental.data["enter_below"]):
		var body := tr("HOME_DEPRESSED") % [-int(mental.data["effects"]["energy"]), int(mental.data["exit_above"])] \
			if mental.depressed else tr("HOME_LOW_MOOD")
		_alerts_box.add_child(_alert(tr("HOME_ALERT_MOOD"), body, tr("HOME_MOOD_HELP"), career_requested.emit, true))
	var late: Array[Dictionary] = []
	for entry: Dictionary in GameState.dreams.active():
		if int(entry["deadline"]) < GameState.month:
			late.append(entry)
	if not late.is_empty():
		var first := tr(GameState.dreams.find_def(late[0]["id"])["name"])
		var dream_id: String = late[0]["id"]
		_alerts_box.add_child(_alert(tr("HOME_ALERT_DREAMS") % late.size(), tr("HOME_ALERT_DREAMS_SUB") % first,
			tr("HOME_ALERT_REVIEW"), dream_requested.emit.bind(dream_id)))
	for loan: Dictionary in GameState.debt.loans:
		if int(loan["missed"]) > 0:
			var loan_id := int(loan["id"])
			_alerts_box.add_child(_alert(tr("HOME_ALERT_ARREARS") % tr(GameState.debt.product(loan["product"])["name"]),
				UiText.loan_status(loan), tr("HOME_ALERT_REVIEW"), loan_detail_requested.emit.bind(loan_id)))
	_alerts_box.visible = _alerts_box.get_child_count() > 0


## Kartu peringatan: ikon, judul, keterangan, tombol aksi. `gentle` = kartu emas yang tenang (pedoman
## konten sensitif: suasana hati tidak ditampilkan sebagai "bahaya" merah).
func _alert(title: String, body: String, action: String, on_action: Callable, gentle := false) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"ActionCard" if gentle else &"AlertCard"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(UiText.icon_tile("res://assets/icons/heart.svg" if gentle else WARNING_ICON,
		&"IconTileGold" if gentle else &"IconTileCoral", 48.0))
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	texts.add_child(_wrap(&"AssetNameLabel", title))
	texts.add_child(_wrap(&"SmallMutedLabel", body))
	row.add_child(texts)
	var button := UiText.chunky_button(action, &"NeutralButton", &"NeutralButtonLabel", 52.0, 20)
	button.custom_minimum_size.x = 130
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(on_action)
	row.add_child(button)
	card.add_child(row)
	return card


## Belum bekerja: kartu "langkah pertama" dengan tombol utama Lihat Lowongan. Bekerja: kartu karier
## ringkas (ketuk untuk membuka tab Karier). Pensiun: pensiun bulanan & pendapatan pasif.
func _refresh_career() -> void:
	_clear(_career_box)
	if not GameState.career.is_employed() and not GameState.life.retired:
		_career_box.add_child(_jobless_card())
		return
	_career_box.add_child(_label(tr("HOME_CAREER_TITLE"), &"SubSectionLabel"))
	var button := Button.new()
	button.theme_type_variation = &"AssetRowButton"
	button.pressed.connect(career_requested.emit)
	var box := _button_box(button, 18, 14)
	box.add_theme_constant_override("separation", 12)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if GameState.life.retired:  # v2b
		head.add_child(UiText.icon_tile("res://assets/icons/badge_retire.svg", &"IconTileTeal", 50.0))
		var title := _wrap(&"AssetNameLabel", tr("HOME_RETIRED_TITLE"))
		title.add_theme_color_override("font_color", Palette.GAIN)
		texts.add_child(title)
		texts.add_child(_wrap(&"SmallMutedLabel", tr("HOME_RETIRED_INCOME") % [Fmt.rupiah(GameState.life.pension_payment()),
			Fmt.rupiah(GameState.passive_income())]))
	else:
		var def := GameState.career.current_job_def()
		head.add_child(UiText.icon_tile(UiText.track_icon(def["track"]), UiText.track_tile(def["track"]), 50.0))
		texts.add_child(_wrap(&"AssetNameLabel", tr(def["title"])))
		var sub: String = GameState.career.job["company"]
		if GameState.career.is_career():
			sub = tr("CAREER_LEVEL") % int(def["level"]) + " · " + sub
		sub += " · " + tr("CAREER_PER_MONTH") % Fmt.rupiah_short(GameState.career.salary)
		texts.add_child(_wrap(&"SmallMutedLabel", sub))
	head.add_child(texts)
	head.add_child(_chevron())
	box.add_child(head)

	if GameState.career.is_employed() and GameState.career.unpaid_months > 0:
		var leave := _wrap(&"RowLabel", tr("HOME_UNPAID") % GameState.career.unpaid_months)
		leave.add_theme_color_override("font_color", Palette.LOSS)
		box.add_child(leave)
	if GameState.career.is_career():
		var perf := HBoxContainer.new()
		perf.add_theme_constant_override("separation", 12)
		perf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		perf.add_child(_label(tr("CAREER_PERFORMANCE") % [roundi(GameState.career.performance),
			tr(GameState.career.performance_label())], &"RowLabel"))
		var bar := _bar(GameState.career.performance / 100.0, &"XpBar")
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		perf.add_child(bar)
		box.add_child(perf)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 6)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var next := GameState.career.next_job_def() if GameState.career.is_career() else {}
	if not next.is_empty():
		var missing := GameState.career.promotion_requirements().filter(func(r: Dictionary) -> bool: return not r["met"]).size()
		chips.add_child(_chip(tr("HOME_PROMOTION_READY") % tr(next["title"]) if missing == 0
			else tr("HOME_NEXT_PROMOTION") % [tr(next["title"]), missing], &"MoodGreen" if missing == 0 else &"MoodGold"))
	if GameState.education.is_studying():
		var study := GameState.education.study
		var program := tr(GameState.education.program_def(study["id"])["name"])
		var total := int(study["months_total"])
		chips.add_child(_chip(tr("HOME_STUDY_STARTS") % program if GameState.month < int(study["since"])
			else tr("HOME_STUDYING") % [program, total - int(study["months_left"]), total], &"MoodNeutral"))
	if not GameState.contracts.active.is_empty():
		chips.add_child(_chip(tr("HOME_PROJECTS_CHIP") % GameState.contracts.active.size(), &"MoodNeutral"))
	if chips.get_child_count() > 0:
		box.add_child(chips)
	UiText.fit_to_content(button, box, 36.0)
	_career_box.add_child(button)


func _jobless_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"ActionCard"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(UiText.icon_tile("res://assets/icons/background_employee.svg", &"IconTileGold", 52.0))
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	texts.add_child(_wrap(&"CardTitleLabel", tr("HOME_JOBLESS_TITLE")))
	var runway := GameState.runway_months()
	var runway_label := _wrap(&"RowLabel", tr("HOME_RUNWAY") % runway if runway > 0 else tr("HOME_RUNWAY_LOW"))
	if runway < 2:
		runway_label.add_theme_color_override("font_color", Palette.LOSS)
	texts.add_child(runway_label)
	head.add_child(texts)
	box.add_child(head)
	var hint := tr("HOME_JOBLESS_HINT")
	if not GameState.career.applications.is_empty():
		hint = tr("HOME_APPLIED") % GameState.career.applications.size()
	box.add_child(_wrap(&"InfoLabel", hint))
	var button := UiText.chunky_button(tr("HOME_SEE_OPENINGS"), &"PrimaryButton", &"PrimaryButtonLabel", 72.0)
	button.pressed.connect(career_requested.emit)
	box.add_child(button)
	card.add_child(box)
	return card


func _refresh_targets() -> void:
	_clear(_targets_box)
	var cfg := GameState.targets.config()
	_targets_side.text = tr("HOME_TARGETS_REWARD") % [int(cfg["reward_happiness"]), int(cfg["reward_xp"])]
	var first := true
	for target: Dictionary in GameState.targets.items:
		if not first:
			_targets_box.add_child(_divider())
		first = false
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var state: String = target["state"]
		var icon := TextureRect.new()
		icon.texture = TARGET_ICONS.get(state, TARGET_ICONS["open"])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(26, 26)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 0)
		texts.add_child(_wrap(&"RowLabel", UiText.target_text(target)))
		if target["type"] in ["invest", "dream_deposit"] and state == "open":
			texts.add_child(_wrap(&"SmallMutedLabel", tr("HOME_TARGET_PROGRESS") % [Fmt.rupiah_short(target["progress"]),
				Fmt.rupiah_short(target["goal"])]))
		row.add_child(texts)
		var status := UiText.target_status(target)
		var chip := _chip(status["text"], TARGET_CHIPS.get(state, &"MoodNeutral"))
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)
		_targets_box.add_child(_padded(row, 0, 12))
	if GameState.targets.items.is_empty():
		_targets_box.add_child(_padded(_wrap(&"SmallMutedLabel", tr("HOME_TARGETS_NONE")), 0, 12))


func _refresh_dreams() -> void:
	_clear(_dreams_grid)
	var active := GameState.dreams.active()
	_dreams_side.text = tr("HOME_DREAMS_COUNT") % [active.size(), int(GameState.dreams.config()["max_active"])]
	for entry: Dictionary in active:
		_dreams_grid.add_child(_dream_card(GameState.dreams.view_of(entry)))
	if GameState.dreams.can_add() and not GameState.dreams.available().is_empty():
		var add := Button.new()
		add.theme_type_variation = &"AssetRowButton"
		add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add.custom_minimum_size = Vector2(0, 200)
		add.pressed.connect(add_dream_requested.emit)
		var box := _button_box(add, 14, 14)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		var plus := _label("+", &"CardTitleLabel")
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.add_theme_font_size_override("font_size", 40)
		plus.add_theme_color_override("font_color", Palette.MUTED)
		box.add_child(plus)
		var text := _wrap(&"RowLabel", tr("HOME_DREAMS_ADD_SHORT"))
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(text)
		_dreams_grid.add_child(add)
	elif active.is_empty():
		_dreams_grid.add_child(_wrap(&"MutedLabel", tr("DREAMS_EMPTY")))


## Satu impian (kartu setengah lebar): ikon, chip tenggat, nama, progress, terkumpul / biaya.
func _dream_card(view: Dictionary) -> Button:
	var def: Dictionary = view["def"]
	var button := Button.new()
	button.theme_type_variation = &"AssetRowButton"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(dream_requested.emit.bind(view["id"]))
	var box := _button_box(button, 14, 14)
	box.add_theme_constant_override("separation", 10)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := DREAM_ICON % view["id"]
	top.add_child(UiText.icon_tile(icon if ResourceLoader.exists(icon) else DREAM_ICON_FALLBACK,
		DREAM_TILES.get(def["horizon"], &"IconTileGold"), 46.0))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	var months_left := int(view["deadline"]) - GameState.month
	var chip := _chip(tr("HOME_DREAM_LATE") if months_left < 0 else tr("HOME_DREAM_MONTHS") % months_left,
		&"MoodRed" if months_left < 0 else &"MoodNeutral")
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(chip)
	box.add_child(top)
	box.add_child(_wrap(&"AssetNameLabel", tr(def["name"])))
	box.add_child(_bar(view["ratio"], &"HappinessBar"))
	box.add_child(_wrap(&"SmallMutedLabel", tr("HOME_DREAM_PROGRESS") % [Fmt.rupiah_short(view["saved"]),
		Fmt.rupiah_short(view["cost"]), roundi(float(view["ratio"]) * 100.0)]))
	UiText.fit_to_content(button, box, 36.0)
	return button


# ==================================================================================================
# Keuangan
# ==================================================================================================

func _build_money() -> void:
	var page: VBoxContainer = %Money
	_title(page, tr("HOME_FLOW_TITLE"))
	var card := _card(page, &"HomeCard", 16)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 0)
	_flow_caps = _label("", &"TileCapsLabel")
	left.add_child(_flow_caps)
	_flow_value = _label("", &"TileValueLabel")
	_flow_value.add_theme_font_size_override("font_size", 34)
	left.add_child(_flow_value)
	head.add_child(left)
	_flow_note = _label("", &"SmallMutedLabel")
	_flow_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_flow_note.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_flow_note)
	card.add_child(head)
	_flow_bar = FlowBar.new()
	card.add_child(_flow_bar)
	_flow_legend = GridContainer.new()
	_flow_legend.columns = 4
	_flow_legend.add_theme_constant_override("h_separation", 12)
	_flow_legend.add_theme_constant_override("v_separation", 14)
	card.add_child(_flow_legend)
	_flow_details = VBoxContainer.new()
	_flow_details.add_theme_constant_override("separation", 6)
	_flow_details.hide()
	card.add_child(_flow_details)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	var details := UiText.chunky_button(tr("HOME_FLOW_DETAILS"), &"NeutralButton", &"NeutralButtonLabel", 64.0, 21)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_label = details.get_node("Content")
	details.pressed.connect(func() -> void:
		_flow_details.visible = not _flow_details.visible
		_details_label.text = tr("HOME_FLOW_HIDE" if _flow_details.visible else "HOME_FLOW_DETAILS"))
	buttons.add_child(details)
	var plan := UiText.chunky_button(tr("HOME_PLAN_BUTTON"), &"NeutralButton", &"NeutralButtonLabel", 64.0, 21)
	plan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan.pressed.connect(plan_requested.emit)
	buttons.add_child(plan)
	card.add_child(buttons)

	_title(page, tr("DEBT_TITLE"))
	_debt_box = _card(page, &"HomeCard", 14)
	_premium_side = _title(page, tr("INS_TITLE"))
	_insurance_box = _card(page, &"HomeCard", 14)


func _refresh_money() -> void:
	_refresh_flow()
	_refresh_debt()
	_refresh_insurance()


## "Ke Mana Gajimu Pergi": penghasilan bersih (+ sewa) dibagi ke kewajiban, gaya hidup, tabungan &
## investasi, dan sisa ke kas, sesuai rencana gaji. Angka dari Budget.preview_for (sama dengan yang
## dijalankan di awal bulan).
func _refresh_flow() -> void:
	var unemployed := not GameState.career.is_employed() or GameState.career.unpaid_months > 0
	var income := 0 if unemployed else GameState.career.net_salary()
	var salary_tax := 0 if unemployed else GameState.income_tax(GameState.career.salary)
	var p := GameState.budget.preview_for(GameState.budget.plan, income)
	var volatility := GameState.career.income_volatility()
	var pension := GameState.life.pension_payment()

	_flow_caps.text = tr("HOME_FLOW_CAPS_AVG" if volatility > 0.0 else "HOME_FLOW_CAPS")
	_flow_value.text = Fmt.rupiah(income)
	_flow_value.add_theme_color_override("font_color", Palette.LOSS if unemployed and pension <= 0 else Palette.INK)
	if GameState.life.retired:
		_flow_note.text = tr("HOME_FLOW_PENSION") % Fmt.rupiah(pension)
	elif unemployed:
		_flow_note.text = tr("HOME_UNEMPLOYED") if not GameState.career.is_employed() \
			else tr("HOME_UNPAID") % GameState.career.unpaid_months
	elif volatility > 0.0:
		_flow_note.text = tr("HOME_INCOME_VARIES") % roundi(volatility * 100)
	elif salary_tax > 0:
		_flow_note.text = tr("HOME_FLOW_GROSS") % [Fmt.rupiah(GameState.career.salary), Fmt.rupiah(salary_tax)]
	else:
		_flow_note.text = ""

	var duty: int = p["basic"] + p["vehicle"] + p["property"] + p["debt"] + p["insurance"] + p["tuition"]
	var saving: int = p["emergency"] + p["dreams_total"] + p["invest_total"]
	var surplus: int = p["surplus"]
	var values := {"duty": duty, "lifestyle": p["lifestyle"], "saving": saving, "left": maxi(surplus, 0)}
	var inflow: int = income + p["rent"]
	var base := maxf(1.0, maxf(inflow, duty + p["lifestyle"] + saving))
	var parts: Array = []
	for group: Array in FLOW_GROUPS:
		parts.append([values[group[0]], group[2]])
	_flow_bar.set_parts(parts)

	var subs := {
		"duty": _joined([["HOME_FLOW_ITEM_BASIC", p["basic"]], ["HOME_FLOW_ITEM_VEHICLE", p["vehicle"]],
			["HOME_FLOW_ITEM_PROPERTY", p["property"]], ["HOME_FLOW_ITEM_DEBT", p["debt"]],
			["HOME_FLOW_ITEM_INSURANCE", p["insurance"]], ["HOME_FLOW_ITEM_TUITION", p["tuition"]]]),
		"lifestyle": tr("HOME_FLOW_LIFESTYLE_SUB") % roundi(float(GameState.budget.plan.get("lifestyle", 0.0)) * 100.0),
		"saving": _joined([["HOME_FLOW_ITEM_EMERGENCY", p["emergency"]], ["HOME_FLOW_ITEM_DREAMS", p["dreams_total"]],
			["HOME_FLOW_ITEM_INVEST", p["invest_total"]]]),
		"left": tr("HOME_FLOW_LEFT_SUB") if p["rent"] <= 0 else tr("HOME_FLOW_RENT_SUB") % Fmt.rupiah_short(p["rent"]),
	}
	_clear(_flow_legend)
	for group: Array in FLOW_GROUPS:
		var key: String = group[0]
		if key == "left" and surplus < 0:
			_legend_row(Palette.LOSS, tr("HOME_FLOW_DEFICIT"), tr("HOME_FLOW_DEFICIT_SUB"), Fmt.signed_rupiah(surplus), "",
				Palette.LOSS)
			continue
		_legend_row(group[2], tr(group[1]), subs[key], Fmt.rupiah(values[key]),
			"%d%%" % roundi(100.0 * values[key] / base))

	_clear(_flow_details)
	for item: Array in [["HOME_EXPENSES_LABEL", -p["basic"]], ["PLAN_RENT", p["rent"]], ["PLAN_VEHICLE", -p["vehicle"]],
			["PLAN_PROPERTY", -p["property"]], ["PLAN_DEBT", -p["debt"]], ["PLAN_INSURANCE", -p["insurance"]],
			["PLAN_TUITION", -p["tuition"]], ["PLAN_LIFESTYLE", -p["lifestyle"]], ["PLAN_EMERGENCY", p["emergency"]],
			["PLAN_DREAMS", p["dreams_total"]], ["PLAN_INVEST", p["invest_total"]], ["PLAN_SURPLUS", surplus]]:
		if int(item[1]) == 0 and item[0] != "PLAN_SURPLUS":
			continue
		var color := Palette.TEAL if item[0] in ["PLAN_EMERGENCY", "PLAN_DREAMS", "PLAN_INVEST"] \
			else (Palette.GAIN if int(item[1]) > 0 else Palette.LOSS)
		var text := Fmt.rupiah(item[1]) if item[0] in ["PLAN_EMERGENCY", "PLAN_DREAMS", "PLAN_INVEST"] \
			else Fmt.signed_rupiah(item[1])
		_flow_details.add_child(_value_row(tr(item[0]), text, color))


## Nama-nama pos yang nilainya > 0, digabung: "Biaya hidup, kendaraan, cicilan".
func _joined(items: Array) -> String:
	var names := PackedStringArray()
	for item: Array in items:
		if int(item[1]) > 0:
			names.append(tr(item[0]))
	var text := ", ".join(names)
	return text.left(1).to_upper() + text.substr(1) if text != "" else tr("HOME_FLOW_NONE")


func _legend_row(color: Color, title: String, sub: String, amount: String, percent: String,
		amount_color := Palette.INK) -> void:
	var swatch := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	swatch.add_theme_stylebox_override("panel", style)
	swatch.custom_minimum_size = Vector2(16, 16)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_flow_legend.add_child(swatch)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	texts.add_child(_wrap(&"AssetNameLabel", title))
	texts.add_child(_wrap(&"SmallMutedLabel", sub))
	_flow_legend.add_child(texts)
	var value := _label(amount, &"AssetValueLabel")
	value.add_theme_color_override("font_color", amount_color)
	_flow_legend.add_child(value)
	var pct := _label(percent, &"SmallMutedLabel")
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.custom_minimum_size.x = 48
	_flow_legend.add_child(pct)


## Skor kredit (cincin), pinjaman aktif (ketuk: rincian & pelunasan), rasio cicilan terhadap gaji.
func _refresh_debt() -> void:
	_clear(_debt_box)
	var debt := GameState.debt
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	var ring := CreditRing.new()
	ring.set_score(debt.credit_score, UiText.credit_color(debt.credit_score))
	head.add_child(ring)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 4)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	title_row.add_child(_label(tr("CREDIT_SCORE"), &"AssetNameLabel"))
	var good := debt.credit_score >= 60
	title_row.add_child(_chip(tr(debt.grade()["key"]), &"MoodGreen" if good else
		(&"MoodRed" if not debt.score_ok() else &"MoodGold")))
	texts.add_child(title_row)
	texts.add_child(_wrap(&"SmallMutedLabel", tr("HOME_CREDIT_NOTE")))
	head.add_child(texts)
	_debt_box.add_child(head)

	if debt.loans.is_empty():
		_debt_box.add_child(_wrap(&"SmallMutedLabel", tr("DEBT_EMPTY")))
	for loan: Dictionary in debt.loans:
		_debt_box.add_child(_divider())
		_debt_box.add_child(_loan_row(loan))
	var dsr := debt.dsr_with(0)
	if not debt.loans.is_empty() and dsr >= 0.0:
		var meter_card := PanelContainer.new()
		meter_card.theme_type_variation = &"TipCard"
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		var limit := float(debt.data["dsr_limit"])
		box.add_child(_value_row(tr("HOME_DSR"), tr("HOME_DSR_VALUE") % [UiText.percent_short(dsr),
			UiText.percent_short(limit)], Palette.LOSS if dsr > limit else Palette.INK))
		var meter := LimitMeter.new()
		meter.set_values(dsr, limit)
		box.add_child(meter)
		meter_card.add_child(box)
		_debt_box.add_child(meter_card)
	var button := UiText.chunky_button(tr("DEBT_APPLY"), &"NeutralButton", &"NeutralButtonLabel", 64.0, 21)
	button.pressed.connect(loan_requested.emit.bind("kta"))
	_debt_box.add_child(button)


## Satu pinjaman: nama & cicilan, bar porsi pokok yang lunas, sisa utang atau tunggakan; ketuk = rincian.
func _loan_row(loan: Dictionary) -> Button:
	var debt := GameState.debt
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(loan_detail_requested.emit.bind(int(loan["id"])))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paid := 1.0 - float(loan["balance"]) / maxf(1.0, float(loan["principal"]))
	box.add_child(_value_row(tr(debt.product(loan["product"])["name"]),
		tr("DEBT_PER_MONTH") % Fmt.rupiah(debt.installment(loan)), Palette.INK, &"AssetNameLabel"))
	box.add_child(_bar(paid, &"XpBar"))
	var sub := _wrap(&"SmallMutedLabel", tr("HOME_LOAN_PAID") % roundi(paid * 100.0) + " · " + UiText.loan_status(loan))
	if int(loan["missed"]) > 0:
		sub.add_theme_color_override("font_color", Palette.LOSS)
	box.add_child(sub)
	row.add_child(box)
	row.add_child(_chevron())
	button.add_child(row)
	UiText.fit_to_content(button, row, 0.0)
	return button


## Perlindungan: satu ubin per kategori (aktif hijau, masa tunggu emas, belum ada redup).
func _refresh_insurance() -> void:
	_clear(_insurance_box)
	_premium_side.text = tr("HOME_INS_PREMIUM") % Fmt.rupiah(GameState.insurance.premiums_total()) \
		if GameState.insurance.premiums_total() > 0 else ""
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	for category: String in GameState.insurance.data["categories"]:
		var product := GameState.insurance.policy_product(category)
		var active := not product.is_empty() and not GameState.insurance.active_policy(category).is_empty()
		var tile := PanelContainer.new()
		tile.theme_type_variation = &"StatTilePositive" if active else &"StatTile"
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		var icon := TextureRect.new()
		icon.texture = load("res://assets/icons/shield.svg")
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(30, 30)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		icon.modulate.a = 1.0 if active else 0.45
		box.add_child(icon)
		box.add_child(_wrap(&"AssetNameLabel", tr("INS_NAME_" + category.to_upper())))
		box.add_child(_wrap(&"SmallMutedLabel", tr(product["name"]) if not product.is_empty() else tr("HOME_INS_NONE")))
		var chip: PanelContainer
		if active:
			chip = _chip(tr("HOME_INS_ACTIVE"), &"ChipWhite")
		elif not product.is_empty():
			chip = _chip(tr("HOME_INS_WAITING_CHIP"), &"MoodGold")
		else:
			chip = _chip(tr("HOME_INS_INACTIVE"), &"MoodNeutral")
		chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		box.add_child(chip)
		tile.add_child(box)
		grid.add_child(tile)
	_insurance_box.add_child(grid)
	var button := UiText.chunky_button(tr("HOME_INS_BUTTON"), &"NeutralButton", &"NeutralButtonLabel", 64.0, 21)
	button.pressed.connect(insurance_requested.emit)
	_insurance_box.add_child(button)


# ==================================================================================================
# Gaya Hidup
# ==================================================================================================

func _build_life() -> void:
	var page: VBoxContainer = %Life
	var entry := Button.new()  # pintu masuk menu Rumah & Kendaraan
	entry.theme_type_variation = &"AssetRowButton"
	entry.pressed.connect(assets_requested.emit.bind("home"))
	var entry_box := _button_box(entry, 14, 14)
	_assets_entry_box = HBoxContainer.new()
	_assets_entry_box.add_theme_constant_override("separation", 14)
	_assets_entry_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry_box.add_child(_assets_entry_box)
	page.add_child(entry)
	UiText.fit_to_content(entry, entry_box, 36.0)

	var side := _title(page, tr("HOME_LIFE_TITLE"))
	side.text = tr("HOME_LIFE_NEXT_MONTH")
	var card := _card(page, &"HomeCard", 12)
	card.add_child(_label(tr("HOME_FOOD").to_upper(), &"TileCapsLabel"))
	var food_row := HBoxContainer.new()
	food_row.add_theme_constant_override("separation", 10)
	card.add_child(food_row)
	_food_buttons = _build_options(food_row, GameState.economy["food"], GameState.set_food, 76.0)
	_food_desc = _wrap(&"SmallMutedLabel")
	card.add_child(_food_desc)
	card.add_child(_divider())
	card.add_child(_label(tr("HOME_HOUSING").to_upper(), &"TileCapsLabel"))
	_own_home_panel = PanelContainer.new()
	_own_home_panel.theme_type_variation = &"StatTilePositive"
	var own_row := HBoxContainer.new()
	own_row.add_theme_constant_override("separation", 14)
	own_row.add_child(UiText.icon_tile("res://assets/icons/nav_home.svg", &"IconTileGold", 46.0))
	var own_texts := VBoxContainer.new()
	own_texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	own_texts.add_theme_constant_override("separation", 0)
	_own_home_title = _wrap(&"AssetNameLabel")
	_own_home_sub = _wrap(&"SmallMutedLabel")
	own_texts.add_child(_own_home_title)
	own_texts.add_child(_own_home_sub)
	own_row.add_child(own_texts)
	var lived := _chip(tr("PROPERTY_USE_LIVE"), &"MoodGreen")
	lived.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	own_row.add_child(lived)
	_own_home_panel.add_child(own_row)
	card.add_child(_own_home_panel)
	_move_hint = _wrap(&"SmallMutedLabel", tr("HOME_MOVE_TO_RENT"))
	card.add_child(_move_hint)
	var housing_row := HBoxContainer.new()
	housing_row.add_theme_constant_override("separation", 8)
	card.add_child(housing_row)
	_housing_buttons = _build_options(housing_row, GameState.economy["housing"], GameState.set_housing, 76.0, 18)
	_housing_desc = _wrap(&"SmallMutedLabel")
	card.add_child(_housing_desc)

	_vehicle_side = _title(page, tr("VEHICLE_TITLE"))
	_vehicle_box = _card(page, &"HomeCard", 10)
	_property_side = _title(page, tr("PROPERTY_TITLE"))
	_property_box = _card(page, &"HomeCard", 10)


func _refresh_life() -> void:
	_clear(_assets_entry_box)
	_assets_entry_box.add_child(ArtThumb.new(HomeScene.home_art(HomeScene.home_art_id()), HomeScene.HOME_CROP,
		Vector2(132, 94)))
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 2)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(_wrap(&"CardTitleLabel", tr("ASSETS_TITLE")))
	texts.add_child(_wrap(&"SmallMutedLabel", tr("HOME_ASSETS_ENTRY_SUB")))
	_assets_entry_box.add_child(texts)
	_assets_entry_box.add_child(_chevron())

	for id: String in _food_buttons:
		_food_buttons[id].set_pressed_no_signal(id == GameState.food_id)
	var home := GameState.properties.home()
	var own_home := not home.is_empty()
	for id: String in _housing_buttons:
		_housing_buttons[id].set_pressed_no_signal(id == GameState.housing_id and not own_home)
	_food_desc.text = _effect_text(GameState.food_option())
	_own_home_panel.visible = own_home
	_move_hint.visible = own_home
	if own_home:
		var option := GameState.housing_option()
		_own_home_title.text = tr("HOME_OWN_HOME_TITLE") % tr(GameState.properties.def(home["id"])["name"])
		_own_home_sub.text = tr("HOME_OWN_HOME_SUB") % [int(option["health"]), int(option["happiness"])]
		var commute := GameState.option_cost(option)  # rumah di pinggir kota
		_housing_desc.text = tr("HOME_COMMUTE_NOTE") % Fmt.rupiah(commute) if commute > 0 else ""
		_housing_desc.visible = commute > 0
	else:
		_housing_desc.text = _effect_text(GameState.housing_option())
		_housing_desc.visible = true

	_refresh_vehicles()
	_refresh_properties()


## Ringkasan garasi: satu baris per kendaraan (ketuk: menu Rumah & Kendaraan, tab Kendaraan).
func _refresh_vehicles() -> void:
	_clear(_vehicle_box)
	var vehicles := GameState.vehicles
	_vehicle_side.text = tr("HOME_VEHICLE_COST") % Fmt.rupiah_short(vehicles.running_cost()) if vehicles.has_any() else ""
	if not vehicles.has_any():
		_vehicle_box.add_child(_wrap(&"SmallMutedLabel", tr("VEHICLE_EMPTY")))
	for entry: Dictionary in vehicles.owned:
		var def := vehicles.def(entry["id"])
		var sub := tr("HOME_VEHICLE_ROW_SUB") % Fmt.rupiah_short(vehicles.cost_of(entry))
		var loan := vehicles.loan_of(entry)
		if not loan.is_empty():
			sub += " · " + tr("VEHICLE_ROW_LOAN") % Fmt.rupiah_short(GameState.debt.installment(loan))
		_vehicle_box.add_child(_asset_row(ArtThumb.new(HomeScene.vehicle_art(entry["id"]), HomeScene.VEHICLE_CROP,
			Vector2(96, 68)), tr(def["name"]), "", &"MoodNeutral", sub, Fmt.rupiah_short(vehicles.value(entry)), "vehicles"))
	var button := UiText.chunky_button(tr("HOME_MANAGE_VEHICLES"), &"NeutralButton", &"NeutralButtonLabel", 64.0, 21)
	button.pressed.connect(assets_requested.emit.bind("vehicles"))
	_vehicle_box.add_child(button)


func _refresh_properties() -> void:
	_clear(_property_box)
	var properties := GameState.properties
	_property_side.text = tr("HOME_PROPERTY_VALUE") % Fmt.rupiah_short(properties.total_value()) \
		if not properties.owned.is_empty() else ""
	if properties.owned.is_empty():
		_property_box.add_child(_wrap(&"SmallMutedLabel", tr("PROPERTY_EMPTY")))
	for entry: Dictionary in properties.owned:
		var status := UiText.property_chip(entry)
		var sub := UiText.property_status(entry)
		var loan := properties.loan_of(entry)
		if not loan.is_empty():
			sub += " · " + tr("VEHICLE_ROW_LOAN") % Fmt.rupiah_short(GameState.debt.installment(loan))
		_property_box.add_child(_asset_row(ArtThumb.new(HomeScene.home_art(entry["id"]), HomeScene.HOME_CROP,
			Vector2(96, 68)), tr(properties.def(entry["id"])["name"]), status[0], status[1], sub,
			Fmt.rupiah_short(properties.value(entry)), "properties"))
	var button := UiText.chunky_button(tr("HOME_MANAGE_PROPERTIES"), &"NeutralButton", &"NeutralButtonLabel", 64.0, 21)
	button.pressed.connect(assets_requested.emit.bind("properties"))
	_property_box.add_child(button)


## Baris ringkas aset: potongan ilustrasi, nama (+ chip status), keterangan, nilai, panah.
func _asset_row(thumb: Control, title: String, chip_text: String, chip_variation: StringName, sub: String,
		value: String, tab: String) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(assets_requested.emit.bind(tab))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(thumb)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 4)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := HFlowContainer.new()
	head.add_theme_constant_override("h_separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_label(title, &"AssetNameLabel"))
	if chip_text != "":
		head.add_child(_chip(chip_text, chip_variation))
	texts.add_child(head)
	texts.add_child(_wrap(&"SmallMutedLabel", sub))
	row.add_child(texts)
	var value_label := _label(value, &"AssetValueLabel")
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value_label)
	row.add_child(_chevron())
	button.add_child(row)
	UiText.fit_to_content(button, row, 8.0)
	return button


# ==================================================================================================
# Alat bantu
# ==================================================================================================

## Judul bagian + keterangan kecil di kanan (mis. "Premi Rp969.000/bln"); mengembalikan label kanan.
func _title(page: Container, text: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var title := _label(text, &"SubSectionLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var side := _label("", &"SmallMutedLabel")
	side.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(side)
	page.add_child(row)
	return side


func _card(page: Container, variation: StringName, separation: int) -> VBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = variation
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	card.add_child(box)
	page.add_child(card)
	return box


## Isi tombol kartu (Button tidak menata anaknya): kotak penuh dengan jarak tepi; bibir bawah 8 px.
func _button_box(button: Button, side: int, vertical: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = side
	box.offset_right = -side
	box.offset_top = vertical
	box.offset_bottom = -vertical - 8
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	return box


func _meter(icon: String, tile: StringName, name_key: String, bar_variation: StringName) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(UiText.icon_tile(icon, tile, 44.0))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	var name_label := _label(tr(name_key), &"RowLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var value := _label("", &"RowValueLabel")
	head.add_child(value)
	column.add_child(head)
	var bar := ProgressBar.new()
	bar.theme_type_variation = bar_variation
	bar.show_percentage = false
	bar.max_value = 100
	bar.custom_minimum_size = Vector2(0, 14)
	column.add_child(bar)
	row.add_child(column)
	return [row, bar, value]


func _bar(ratio: float, variation: StringName) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.theme_type_variation = variation
	bar.custom_minimum_size = Vector2(0, 12)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = ratio
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _chip(text: String, variation: StringName) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = variation
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(_label(text, &"MoodLabel"))
	return chip


func _chevron() -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = CHEVRON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(14, 22)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _divider() -> Panel:
	var line := Panel.new()
	line.theme_type_variation = &"Divider"
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _padded(control: Control, side: int, vertical := 0) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", side)
	margin.add_theme_constant_override("margin_right", side)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_bottom", vertical)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(control)
	return margin


func _value_row(title: String, value: String, color: Color, title_variation := &"RowLabel") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := _wrap(title_variation, title)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value_label := _label(value, &"RowValueLabel")
	value_label.add_theme_color_override("font_color", color)
	row.add_child(value_label)
	return row


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _wrap(variation: StringName, text := "") -> Label:
	var label := _label(text, variation)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1
	return label


func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


## Tombol pilihan (segmented control) dari data JSON: nama pilihan & biayanya.
func _build_options(container: HBoxContainer, options: Array, on_select: Callable, height: float,
		name_size := 0) -> Dictionary:
	var group := ButtonGroup.new()
	var buttons := {}
	for option: Dictionary in options:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = &"ChoiceButton"
		button.custom_minimum_size = Vector2(0, height)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(on_select.bind(option["id"]))
		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_bottom = -5  # bibir bawah tombol
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 0)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE  # klik diteruskan ke Button
		var name_label := _label(tr(option["name_key"]), &"ChoiceNameLabel")
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if name_size > 0:
			name_label.add_theme_font_size_override("font_size", name_size)
		content.add_child(name_label)
		var cost := _label(Fmt.rupiah_short(GameState.option_cost(option)), &"ChoiceCostLabel")
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(cost)
		button.add_child(content)
		container.add_child(button)
		buttons[option["id"]] = button
	return buttons


func _effect_text(option: Dictionary) -> String:
	return tr("HOME_EFFECT") % [tr(option["name_key"]), int(option["health"]), int(option["happiness"])]
