extends ScrollContainer
## Tab Profil (GDD 5.12, tema "Senja Cuan"): kartu pemain, profil risiko, target kemenangan,
## daya beli (inflasi), statistik, perjalanan karier, orang terdekat, rekam jejak riset, pencapaian &
## tampilan (bingkai avatar, gelar), riwayat permainan, simpan/muat, pengaturan, menu.

signal glossary_requested
signal text_requested(title: String, body: String)
## Menu "Laporan Tahunan Terakhir" ditekan (v1.5d).
signal annual_requested

const TITLE_SCENE := "res://scenes/title.tscn"
const TUTORIAL_SCENE := "res://scenes/tutorial.tscn"
const LEGAL_PATH := "res://data/legal.json"
const CHEVRON := preload("res://assets/icons/chevron_right.svg")
const HISTORY_COLORS := {"win": Palette.GAIN, "lose": Palette.LOSS}

var _slot_labels: Dictionary = {}  # slot -> Label
var _confirm_reset := false
var _reset_label: Label
var _career_log_box: VBoxContainer  # perjalanan karier (v1.5b langkah 4)
var _people_box: VBoxContainer  # orang terdekat (v1.5d)
var _research_title: Label  # rekam jejak riset rumor (v1.5d langkah 2)
var _research_box: VBoxContainer
var _title_label: Label  # gelar di bawah nama (v1.5d langkah 4)
var _achievement_title: Label
var _achievement_box: VBoxContainer  # daftar pencapaian
var _style_box: VBoxContainer  # pilihan bingkai avatar & gelar
var _annual_row: Button  # menu laporan tahunan terakhir


func _ready() -> void:
	_setup_settings()
	_setup_risk_profile()
	_build_slots()
	_build_history()
	_build_career_log()
	_build_people()
	_build_research()
	_build_achievements()
	_build_menu()
	GameState.changed.connect(_refresh)
	visibility_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	%Avatar.avatar_index = GameState.avatar
	%Avatar.display_name = GameState.player_name
	%NameLabel.text = GameState.player_name
	UiText.apply_avatar_frame(%Avatar.get_parent(), GameState.achievements.current_frame())
	_title_label.text = GameState.achievements.current_title()
	_title_label.visible = _title_label.text != ""
	_clear(%InfoChips)
	var job_title := tr(GameState.career.current_job_def()["title"]) if GameState.career.is_employed() else tr("CAREER_UNEMPLOYED")
	%InfoChips.add_child(_chip(job_title, &"MoodGold"))
	%InfoChips.add_child(_chip(GameState.education.level_name(GameState.education.level), &"MoodNeutral"))
	%InfoChips.add_child(_chip(tr("PROFILE_AGE") % GameState.age(), &"MoodNeutral"))
	%InfoChips.add_child(_chip(tr("PROFILE_DIFFICULTY") % tr(GameState.difficulty["name_key"]), &"MoodNeutral"))
	%InfoChips.add_child(_chip(tr("ACT_LEVEL") % GameState.progress.level(), &"MoodGold"))

	var end_cfg: Dictionary = GameState.economy["end"]
	var target: float = end_cfg["win_net_worth"]
	%MillionaireBar.max_value = target
	%MillionaireBar.value = clampf(GameState.net_worth(), 0, target)
	%MillionaireValue.text = tr("GOAL_PROGRESS_VALUE") % [Fmt.rupiah(GameState.net_worth()), Fmt.rupiah(target)]
	var expenses := float(GameState.monthly_spending())  # biaya hidup + premi + gaya hidup
	%FreedomBar.max_value = expenses
	%FreedomBar.value = clampf(GameState.passive_income(), 0, expenses)
	%FreedomValue.text = tr("GOAL_FREEDOM_VALUE") % [Fmt.rupiah(GameState.passive_income()), Fmt.rupiah(expenses)]

	_refresh_power()

	var s := GameState.stats
	var best: Dictionary = s["best_trade"]
	_clear(%StatsGrid)
	%StatsGrid.add_child(_stat_tile("PROFILE_STAT_PEAK", Fmt.rupiah(s["peak_net_worth"])))
	%StatsGrid.add_child(_stat_tile("PROFILE_STAT_MONTHS", str(GameState.month)))
	%StatsGrid.add_child(_stat_tile("PROFILE_STAT_EVENTS", str(int(s["events"]))))
	%StatsGrid.add_child(_stat_tile("PROFILE_STAT_QUIZ", str(GameState.quiz.correct_ids.size())))
	%StatsGrid.add_child(_stat_tile("PROFILE_STAT_COSTS", Fmt.rupiah(float(s["total_taxes"]) + float(s["total_fees"]))))
	%StatsGrid.add_child(_stat_tile("PROFILE_STAT_BEST",
		("%s %s" % [tr(best["asset_key"]), Fmt.signed_rupiah(best["value"])]) if not best.is_empty() else "-"))
	%StatsGrid.add_child(_stat_tile("PROFILE_STAT_PROMOTIONS", str(int(s["promotions"]))))
	%StatsGrid.add_child(_stat_tile("PROFILE_STAT_UNEMPLOYED", str(int(s["months_unemployed"]))))
	%StatsGrid.add_child(_stat_tile("PROFILE_STAT_PROJECTS", tr("PROFILE_STAT_PROJECTS_VALUE") % [
		int(s.get("projects_done", 0)), int(s.get("projects_failed", 0))]))
	%StatsGrid.add_child(_stat_tile("PROFILE_STAT_PROJECT_INCOME", Fmt.rupiah(float(s.get("project_income", 0)))))
	UiText.fill_career_log(_career_log_box, 8)
	_refresh_people()
	_refresh_research()
	_refresh_achievements()
	_annual_row.visible = not GameState.annual.reports.is_empty()

	for slot: String in _slot_labels:
		_slot_labels[slot].text = SaveManager.slot_summary(slot)


# --- Daya beli (v1.5a langkah 1) ------------------------------------------------

## Inflasi, suku bunga, bunga tabungan bersih, kenaikan harga sejak awal, dan kekayaan riil.
func _refresh_power() -> void:
	var market := GameState.market
	var savings := GameState.savings_rate()
	_clear(%PowerGrid)
	%PowerGrid.add_child(_stat_tile("POWER_INFLATION", Fmt.percent_plain(market.inflation)))
	%PowerGrid.add_child(_stat_tile("POWER_RATE", Fmt.percent_plain(market.policy_rate)))
	%PowerGrid.add_child(_stat_tile("POWER_SAVINGS", Fmt.percent_plain(savings)))
	%PowerGrid.add_child(_stat_tile("POWER_PRICES", Fmt.percent(GameState.price_level() - 1.0)))
	%PowerReal.text = tr("POWER_REAL_WORTH") % [Fmt.rupiah(GameState.real_value(GameState.net_worth())),
		Fmt.rupiah(GameState.net_worth())]
	%PowerHint.text = tr("POWER_HINT_LOSING" if savings < market.inflation else "POWER_HINT_OK")


# --- Profil risiko (bisa diubah kapan saja, GDD 5.8) ---------------------------

func _setup_risk_profile() -> void:
	var group := ButtonGroup.new()
	for p: Dictionary in GameState.portfolio.risk_profiles():
		var id: String = p["id"]
		var button := _segment(tr(p["name"]), group, id == GameState.portfolio.risk_profile_id)
		button.pressed.connect(func() -> void:
			GameState.portfolio.set_risk_profile(id)
			%RiskDesc.text = tr(GameState.portfolio.risk_profile()["desc"]))
		%RiskRow.add_child(button)
	%RiskDesc.text = tr(GameState.portfolio.risk_profile()["desc"])


# --- Pengaturan ---------------------------------------------------------------

func _setup_settings() -> void:
	%SfxToggle.button_pressed = Settings.sfx_enabled
	%VibrationToggle.button_pressed = Settings.vibration_enabled
	%CompactToggle.button_pressed = Settings.compact_numbers
	%SfxToggle.toggled.connect(Settings.set_sfx)
	%VibrationToggle.toggled.connect(Settings.set_vibration)
	%CompactToggle.toggled.connect(func(on: bool) -> void:
		Settings.set_compact_numbers(on)
		GameState.changed.emit())  # gambar ulang semua angka

	var group := ButtonGroup.new()
	for code: String in Settings.LANGUAGES:
		var button := _segment(tr("LANG_" + code.to_upper()), group, code == Settings.language)
		button.pressed.connect(func() -> void:
			if code == Settings.language:
				return
			Settings.set_language(code)
			SaveManager.save_slot(SaveManager.AUTO_SLOT)
			get_tree().reload_current_scene())  # semua teks dibuat ulang dalam bahasa baru
		%LanguageRow.add_child(button)


# --- Menu ---------------------------------------------------------------------

func _build_menu() -> void:
	_annual_row = _add_menu_row("PROFILE_ANNUAL", "res://assets/icons/calendar_badge.svg", &"IconTileGold",
		func() -> void: annual_requested.emit())
	_add_menu_row("PROFILE_GLOSSARY", "res://assets/icons/book.svg", &"IconTileTeal",
		func() -> void: glossary_requested.emit())
	_add_menu_row("PROFILE_TUTORIAL", "res://assets/icons/lightbulb.svg", &"IconTileGold",
		_leave_to.bind(TUTORIAL_SCENE))
	_add_menu_row("SETTINGS_PRIVACY", "res://assets/icons/shield.svg", &"IconTileInk", _show_legal.bind("privacy"))
	_add_menu_row("SETTINGS_TERMS", "res://assets/icons/news.svg", &"IconTileInk", _show_legal.bind("terms"))
	_add_menu_row("PROFILE_TO_TITLE", "res://assets/icons/nav_home.svg", &"IconTileTeal", _leave_to.bind(TITLE_SCENE))

	var reset := _chunky(&"DangerButton", tr("SETTINGS_RESET"), &"DangerButtonLabel", 84.0, 8.0)
	_reset_label = reset.get_child(0)
	_reset_label.add_theme_font_size_override("font_size", 22)
	_reset_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reset.pressed.connect(_on_reset)
	%MenuList.add_child(reset)


## Satu baris menu: ikon | judul | panah. Tombol "tebal" bergaya kartu.
func _add_menu_row(key: String, icon: String, tile: StringName, on_press: Callable) -> Button:
	var button := ChunkyButton.new()
	button.theme_type_variation = &"AssetRowButton"
	button.press_depth = 5.0
	button.custom_minimum_size = Vector2(0, 78)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_right = -18
	row.offset_bottom = -5  # bibir bawah tombol
	row.add_theme_constant_override("separation", 14)
	row.add_child(UiText.icon_tile(icon, tile, 46.0))
	var title := _label(tr(key), &"StatNameLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var chevron := TextureRect.new()
	chevron.texture = CHEVRON
	chevron.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chevron.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chevron.custom_minimum_size = Vector2(12, 20)
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chevron)
	_ignore_mouse(row)
	button.add_child(row)
	button.pressed.connect(on_press)
	%MenuList.add_child(button)
	return button


func _show_legal(key: String) -> void:
	var doc: Dictionary = DataLoader.load_json(LEGAL_PATH)[key]
	text_requested.emit(tr(doc["title"]), tr(doc["body"]))


## Tekan dua kali untuk konfirmasi, lalu hapus semua simpanan & kembali ke layar judul.
func _on_reset() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_reset_label.text = tr("SETTINGS_RESET_CONFIRM")
		_reset_label.add_theme_font_size_override("font_size", 18)
		return
	SaveManager.reset_all()
	get_tree().change_scene_to_file(TITLE_SCENE)


# --- Simpan / muat ------------------------------------------------------------

## Satu kartu per slot: nomor + ringkasan, lalu tombol Simpan (teal) & Muat.
func _build_slots() -> void:
	for i in SaveManager.MANUAL_SLOTS.size():
		var slot: String = SaveManager.MANUAL_SLOTS[i]
		var card := PanelContainer.new()
		card.theme_type_variation = &"HomeCard"
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 12)
		card.add_child(box)

		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 12)
		var badge := PanelContainer.new()
		badge.theme_type_variation = &"NumberBadge"
		badge.custom_minimum_size = Vector2(40, 40)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var number := _label(str(i + 1), &"NumberLabel")
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(number)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 0)
		var title := _label(tr("SAVE_SLOT") % (i + 1), &"CapsLabel")
		title.uppercase = true
		var info := _label("", &"SmallMutedLabel")
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(title)
		texts.add_child(info)
		head.add_child(badge)
		head.add_child(texts)
		box.add_child(head)
		_slot_labels[slot] = info

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var save_button := _chunky(&"SecondaryButton", tr("SAVE_BUTTON"), &"SecondaryButtonLabel", 72.0, 7.0)
		save_button.pressed.connect(_on_save.bind(slot))
		var load_button := _chunky(&"NeutralButton", tr("LOAD_BUTTON"), &"NeutralButtonLabel", 72.0, 7.0)
		load_button.pressed.connect(_on_load.bind(slot))
		save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(save_button)
		row.add_child(load_button)
		box.add_child(row)
		%SlotList.add_child(card)


## Riwayat permainan selesai: "Nama · hasil" + alasan & lama bermain, kekayaan akhir berwarna.
func _build_history() -> void:
	if GameState.history.is_empty():
		%HistoryList.add_child(_label(tr("HISTORY_EMPTY"), &"MutedLabel"))
		return
	for i in GameState.history.size():
		var record: Dictionary = GameState.history[i]
		if i > 0:
			var line := Panel.new()
			line.theme_type_variation = &"Divider"
			line.custom_minimum_size = Vector2(0, 2)
			%HistoryList.add_child(line)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 0)
		var title := _label("%s · %s" % [record["name"], tr("END_TITLE_" + str(record["type"]).to_upper())],
				&"AssetNameLabel")
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var meta := _label(tr("HISTORY_META") % [tr("END_REASON_SHORT_" + str(record["reason"]).to_upper()),
				int(record["months"])], &"SmallMutedLabel")
		texts.add_child(title)
		texts.add_child(meta)
		var value := _label(Fmt.rupiah(record["net_worth"]), &"AssetValueLabel")
		value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		value.add_theme_color_override("font_color", HISTORY_COLORS.get(record["type"], Palette.INK))
		row.add_child(texts)
		row.add_child(value)
		%HistoryList.add_child(row)


func _on_save(slot: String) -> void:
	var ok := SaveManager.save_slot(slot)
	_show_save_feedback(tr("SAVE_OK") if ok else tr("SAVE_FAILED"), ok)
	_refresh()


func _on_load(slot: String) -> void:
	if not SaveManager.has_slot(slot):
		_show_save_feedback(tr("SAVE_EMPTY"), false)
		return
	if SaveManager.load_slot(slot):
		get_tree().reload_current_scene()  # bangun ulang semua layar dari state yang dimuat
	else:
		_show_save_feedback(SaveManager.load_error_text(slot), false)


func _show_save_feedback(text: String, ok: bool) -> void:
	%SaveFeedbackBox.show()
	%SaveFeedbackBox.theme_type_variation = &"FeedbackGood" if ok else &"FeedbackBad"
	%SaveFeedback.text = text
	%SaveFeedback.add_theme_color_override("font_color", Color("#1e5e45") if ok else Palette.LOSS)


## Simpan otomatis dulu sebelum meninggalkan layar utama.
func _leave_to(scene: String) -> void:
	SaveManager.save_slot(SaveManager.AUTO_SLOT)
	get_tree().change_scene_to_file(scene)


# --- bantuan ------------------------------------------------------------------

## Tombol "tebal" dengan satu label di tengah (bibir bawah setinggi `lip`).
func _chunky(variation: StringName, text: String, label_variation: StringName, height: float, lip: float) -> ChunkyButton:
	var button := ChunkyButton.new()
	button.theme_type_variation = variation
	button.custom_minimum_size = Vector2(0, height)
	var label := _label(text, label_variation)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 16
	label.offset_right = -16
	label.offset_bottom = -lip
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	return button


func _segment(text: String, group: ButtonGroup, pressed: bool) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = group
	button.theme_type_variation = &"SegmentButton"
	button.text = text
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.button_pressed = pressed
	return button


## Judul + kartu "Perjalanan Karier" tepat setelah statistik.
func _build_career_log() -> void:
	var page: VBoxContainer = $VBox
	var index := %StatsGrid.get_index() + 1
	var title := _label(tr("PROFILE_CAREER_TITLE"), &"SubSectionLabel")
	var card := PanelContainer.new()
	card.theme_type_variation = &"HomeCard"
	_career_log_box = VBoxContainer.new()
	_career_log_box.add_theme_constant_override("separation", 6)
	card.add_child(_career_log_box)
	page.add_child(title)
	page.move_child(title, index)
	page.add_child(card)
	page.move_child(card, index + 1)


## Judul + kartu "Orang Terdekat" setelah Perjalanan Karier.
func _build_people() -> void:
	var page: VBoxContainer = $VBox
	var index := _career_log_box.get_parent().get_index() + 1
	var title := _label(tr("PROFILE_PEOPLE_TITLE"), &"SubSectionLabel")
	var card := PanelContainer.new()
	card.theme_type_variation = &"HomeCard"
	_people_box = VBoxContainer.new()
	_people_box.add_theme_constant_override("separation", 12)
	card.add_child(_people_box)
	page.add_child(title)
	page.move_child(title, index)
	page.add_child(card)
	page.move_child(card, index + 1)


## Satu baris per tokoh yang sudah dikenal: potret, nama & peran, bar kedekatan.
func _refresh_people() -> void:
	_clear(_people_box)
	var characters := GameState.characters
	for id: String in characters.known():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var portrait := CharacterPortrait.new(52.0)
		portrait.character_id = id
		row.add_child(portrait)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 2)
		var top := HBoxContainer.new()
		var name_label := _label(characters.name_of(id), &"AssetNameLabel")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name_label)
		var value := characters.rel_of(id)
		top.add_child(_label(tr("CHAR_LEVEL_VALUE") % [tr(characters.level_key(value)), value], &"AssetValueLabel"))
		texts.add_child(top)
		var bar := ProgressBar.new()
		bar.theme_type_variation = &"XpBar"
		bar.custom_minimum_size = Vector2(0, 12)
		bar.show_percentage = false
		bar.max_value = 100
		bar.value = value
		texts.add_child(bar)
		var role := _label(tr(characters.def(id)["role"]) + " · " + tr(characters.def(id)["desc"]), &"SmallMutedLabel")
		role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		role.custom_minimum_size.x = 1
		texts.add_child(role)
		row.add_child(texts)
		_people_box.add_child(row)
	_people_box.add_child(_label(tr("PROFILE_PEOPLE_NOTE"), &"SmallMutedLabel"))
	_people_box.get_child(-1).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_people_box.get_child(-1).custom_minimum_size.x = 1


## Judul + kartu "Rekam Jejak Riset" setelah Orang Terdekat; tampil setelah rumor pertama beredar.
func _build_research() -> void:
	var page: VBoxContainer = $VBox
	var index := _people_box.get_parent().get_index() + 1
	_research_title = _label(tr("PROFILE_RESEARCH_TITLE"), &"SubSectionLabel")
	var card := PanelContainer.new()
	card.theme_type_variation = &"HomeCard"
	_research_box = VBoxContainer.new()
	_research_box.add_theme_constant_override("separation", 6)
	card.add_child(_research_box)
	page.add_child(_research_title)
	page.move_child(_research_title, index)
	page.add_child(card)
	page.move_child(card, index + 1)


## Jumlah rumor & yang terbukti, lalu akurasi nyata tiap tingkat riset dibanding tingkat keyakinannya.
func _refresh_research() -> void:
	var research := GameState.research
	var record := research.record
	var shown := int(record["rumors"]) > 0 or research.has_rumor()
	_research_title.visible = shown
	_research_box.get_parent().visible = shown
	if not shown:
		return
	_clear(_research_box)
	_research_box.add_child(_value_row(tr("PROFILE_RESEARCH_RUMORS"),
		tr("PROFILE_RESEARCH_RUMORS_VALUE") % [int(record["rumors"]), int(record["true"])]))
	for level: String in Research.LEVELS:
		var done: Array = record[level]
		var value := "-"
		if int(done[0]) > 0:
			value = tr("PROFILE_RESEARCH_VALUE") % [int(done[1]), int(done[0]), roundi(100.0 * done[1] / done[0])]
		_research_box.add_child(_value_row(tr("RESEARCH_" + level.to_upper()) + " · "
			+ tr("RESEARCH_ACCURACY") % roundi(research.accuracy(level) * 100.0), value))
	if int(record["costs"]) > 0:
		_research_box.add_child(_value_row(tr("PROFILE_RESEARCH_COSTS"), Fmt.rupiah(record["costs"])))
	var note := _label(tr("PROFILE_RESEARCH_NOTE"), &"SmallMutedLabel")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 1
	_research_box.add_child(note)


# --- Pencapaian & tampilan (v1.5d langkah 4) ---------------------------------------

## Gelar di bawah nama, lalu judul + kartu Tampilan (bingkai & gelar) dan judul + daftar Pencapaian
## setelah Rekam Jejak Riset.
func _build_achievements() -> void:
	_title_label = _label("", &"AssetNameLabel")
	_title_label.add_theme_color_override("font_color", Palette.TEAL)
	var texts: VBoxContainer = %NameLabel.get_parent()
	texts.add_child(_title_label)
	texts.move_child(_title_label, %NameLabel.get_index() + 1)

	var page: VBoxContainer = $VBox
	var index := _research_box.get_parent().get_index() + 1
	var style_title := _label(tr("PROFILE_STYLE_TITLE"), &"SubSectionLabel")
	var style_card := PanelContainer.new()
	style_card.theme_type_variation = &"HomeCard"
	_style_box = VBoxContainer.new()
	_style_box.add_theme_constant_override("separation", 10)
	style_card.add_child(_style_box)
	_achievement_title = _label("", &"SubSectionLabel")
	var card := PanelContainer.new()
	card.theme_type_variation = &"HomeCard"
	_achievement_box = VBoxContainer.new()
	_achievement_box.add_theme_constant_override("separation", 12)
	card.add_child(_achievement_box)
	for node: Control in [style_title, style_card, _achievement_title, card]:
		page.add_child(node)
		page.move_child(node, index)
		index += 1


func _refresh_achievements() -> void:
	var achievements := GameState.achievements
	_achievement_title.text = tr("PROFILE_ACHIEVEMENTS_TITLE") % [achievements.unlocked.size(), achievements.defs().size()]
	_refresh_style()
	_clear(_achievement_box)
	var ordered: Array = achievements.defs().filter(func(d: Dictionary) -> bool: return achievements.is_unlocked(d["id"]))
	ordered.append_array(achievements.defs().filter(func(d: Dictionary) -> bool: return not achievements.is_unlocked(d["id"])))
	for d: Dictionary in ordered:
		_achievement_box.add_child(_achievement_row(d))


## Satu pencapaian: ikon | nama, syarat, hadiah (terbuka) atau progres (terkunci).
func _achievement_row(d: Dictionary) -> HBoxContainer:
	var achievements := GameState.achievements
	var id: String = d["id"]
	var open := achievements.is_unlocked(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var icon := achievements.icon(id)
	if icon == "":
		icon = "res://assets/icons/badge_star.svg" if open else "res://assets/icons/lock.svg"
	var tile := UiText.icon_tile(icon, &"IconTileGold" if open else &"IconTileInk", 44.0)
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(tile)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	texts.add_child(_wrap(tr("ACH_" + id.to_upper()), &"AssetNameLabel"))
	texts.add_child(_wrap(tr("ACH_%s_DESC" % id.to_upper()), &"SmallMutedLabel"))
	var rewards: Array[String] = []
	if d.get("title", false):
		rewards.append(tr("ACH_REWARD_TITLE") % tr("TITLE_" + id.to_upper()))
	if d.has("frame"):
		rewards.append(tr("ACH_REWARD_FRAME") % tr("FRAME_" + str(d["frame"]).to_upper()))
	var status := ""
	if open:
		status = tr("ACH_OPEN")
	else:
		var target := achievements.target(d)
		var value := minf(achievements.value(d), target)
		status = tr("ACH_PROGRESS") % [_progress_text(d, value), _progress_text(d, target)] if target > 1.0 else tr("ACH_LOCKED")
	if not rewards.is_empty():
		status += " · " + ", ".join(rewards)
	var status_label := _wrap(status, &"ReqLabel")
	status_label.add_theme_color_override("font_color", Palette.GAIN if open else Palette.MUTED)
	texts.add_child(status_label)
	row.add_child(texts)
	if not open:
		tile.modulate = Color(1, 1, 1, 0.55)
	return row


func _progress_text(d: Dictionary, value: float) -> String:
	match d["type"]:
		"net_worth":
			return Fmt.rupiah_short(value)
		"emergency_months":
			return Fmt.number(value, 1)
	return str(floori(value))


## Pilihan bingkai avatar (lingkaran warna; terkunci = redup) dan gelar (tombol per gelar terbuka).
func _refresh_style() -> void:
	_clear(_style_box)
	var achievements := GameState.achievements
	_style_box.add_child(_label(tr("PROFILE_FRAME"), &"StatNameLabel"))
	var swatches := HFlowContainer.new()
	swatches.add_theme_constant_override("h_separation", 10)
	swatches.add_theme_constant_override("v_separation", 10)
	var current: String = achievements.current_frame()["id"]
	for f: Dictionary in achievements.frames():
		swatches.add_child(_frame_swatch(f, f["id"] == current, achievements.frame_unlocked(f["id"])))
	_style_box.add_child(swatches)
	_style_box.add_child(_wrap(tr("FRAME_" + current.to_upper()), &"SmallMutedLabel"))

	_style_box.add_child(_label(tr("PROFILE_TITLE_PICK"), &"StatNameLabel"))
	var titles := HFlowContainer.new()
	titles.add_theme_constant_override("h_separation", 8)
	titles.add_theme_constant_override("v_separation", 8)
	var options: Array[String] = [""]
	options.append_array(achievements.titles_unlocked())
	for id: String in options:
		var selected := achievements.title == id or (id == "" and achievements.current_title() == "")
		var text := tr("PROFILE_NO_TITLE") if id == "" else tr("TITLE_" + id.to_upper())
		var button := UiText.chunky_button(text, &"PrimaryButton" if selected else &"NeutralButton",
			&"PrimaryButtonLabel" if selected else &"NeutralButtonLabel", 50.0, 17)
		button.get_child(0).autowrap_mode = TextServer.AUTOWRAP_OFF
		button.custom_minimum_size.x = 40.0 + text.length() * 10.0  # label menempel penuh, jadi lebar diatur manual
		button.pressed.connect(achievements.set_title.bind(id))
		titles.add_child(button)
	_style_box.add_child(titles)
	if options.size() == 1:
		_style_box.add_child(_wrap(tr("PROFILE_STYLE_HINT"), &"SmallMutedLabel"))


## Lingkaran contoh bingkai. Terpilih = garis lebih tebal; terkunci = redup & tidak bisa ditekan.
func _frame_swatch(f: Dictionary, selected: bool, unlocked: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(48, 48)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tr("FRAME_" + str(f["id"]).to_upper())
	var style := StyleBoxFlat.new()
	style.bg_color = Color(f["bg"])
	style.border_color = Color(f["border"])
	style.set_border_width_all(8 if selected else 4)
	style.set_corner_radius_all(24)
	if f.has("glow"):
		style.shadow_color = Color(Color(f["glow"]), 0.6)
		style.shadow_size = 4
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, style)
	button.disabled = not unlocked
	button.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.35)
	button.pressed.connect(GameState.achievements.set_frame.bind(f["id"]))
	return button


func _wrap(text: String, variation: StringName) -> Label:
	var label := _label(text, variation)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1
	return label


func _value_row(name: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := _label(name, &"RowLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(_label(value, &"RowValueLabel"))
	return row


func _stat_tile(key: String, value: String) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.theme_type_variation = &"StatTile"
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(_label(tr(key), &"TileCapsLabel"))
	var value_label := _label(value, &"TileValueLabel")
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(value_label)
	tile.add_child(box)
	return tile


func _chip(text: String, variation: StringName) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = variation
	chip.add_child(_label(text, &"MoodLabel"))
	return chip


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
