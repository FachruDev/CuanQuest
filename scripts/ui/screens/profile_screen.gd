extends ScrollContainer
## Tab Profil (GDD 5.12, tema "Senja Cuan"): kartu pemain, profil risiko, target kemenangan,
## daya beli (inflasi), statistik, riwayat permainan, simpan/muat, pengaturan, menu.

signal glossary_requested
signal text_requested(title: String, body: String)

const TITLE_SCENE := "res://scenes/title.tscn"
const TUTORIAL_SCENE := "res://scenes/tutorial.tscn"
const LEGAL_PATH := "res://data/legal.json"
const CHEVRON := preload("res://assets/icons/chevron_right.svg")
const HISTORY_COLORS := {"win": Palette.GAIN, "lose": Palette.LOSS}

var _slot_labels: Dictionary = {}  # slot -> Label
var _confirm_reset := false
var _reset_label: Label


func _ready() -> void:
	_setup_settings()
	_setup_risk_profile()
	_build_slots()
	_build_history()
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
	_clear(%InfoChips)
	%InfoChips.add_child(_chip(tr(GameState.background["name_key"]), &"MoodGold"))
	%InfoChips.add_child(_chip(tr("PROFILE_AGE") % GameState.age(), &"MoodNeutral"))
	%InfoChips.add_child(_chip(tr("PROFILE_DIFFICULTY") % tr(GameState.difficulty["name_key"]), &"MoodNeutral"))
	%InfoChips.add_child(_chip(tr("ACT_LEVEL") % GameState.level(), &"MoodGold"))

	var end_cfg: Dictionary = GameState.economy["end"]
	var target: float = end_cfg["win_net_worth"]
	%MillionaireBar.max_value = target
	%MillionaireBar.value = clampf(GameState.net_worth(), 0, target)
	%MillionaireValue.text = tr("GOAL_PROGRESS_VALUE") % [Fmt.rupiah(GameState.net_worth()), Fmt.rupiah(target)]
	var expenses := float(GameState.monthly_expenses())
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
	for p: Dictionary in GameState.risk_profiles():
		var id: String = p["id"]
		var button := _segment(tr(p["name"]), group, id == GameState.risk_profile_id)
		button.pressed.connect(func() -> void:
			GameState.set_risk_profile(id)
			%RiskDesc.text = tr(GameState.risk_profile()["desc"]))
		%RiskRow.add_child(button)
	%RiskDesc.text = tr(GameState.risk_profile()["desc"])


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
func _add_menu_row(key: String, icon: String, tile: StringName, on_press: Callable) -> void:
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
