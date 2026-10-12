extends ScrollContainer
## Tab Profil (GDD 5.12): kartu pemain, target kemenangan, statistik, riwayat permainan,
## simpan/muat, pengaturan, kebijakan privasi, menu.

signal glossary_requested
signal text_requested(title: String, body: String)

const TITLE_SCENE := "res://scenes/title.tscn"
const TUTORIAL_SCENE := "res://scenes/tutorial.tscn"
const LEGAL_PATH := "res://data/legal.json"

var _slot_labels: Dictionary = {}  # slot -> Label
var _confirm_reset := false


func _ready() -> void:
	%GlossaryButton.pressed.connect(func() -> void: glossary_requested.emit())
	%TutorialButton.pressed.connect(func() -> void: _leave_to(TUTORIAL_SCENE))
	%TitleButton.pressed.connect(func() -> void: _leave_to(TITLE_SCENE))
	%PrivacyButton.pressed.connect(_show_legal.bind("privacy"))
	%TermsButton.pressed.connect(_show_legal.bind("terms"))
	%ResetButton.pressed.connect(_on_reset)
	_setup_settings()
	_build_slots()
	_build_history()
	GameState.changed.connect(_refresh)
	visibility_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	%Avatar.avatar_index = GameState.avatar
	%Avatar.display_name = GameState.player_name
	%NameLabel.text = GameState.player_name
	%InfoLabel.text = tr("PROFILE_INFO") % [
		tr(GameState.background["name_key"]), GameState.age(),
		tr(GameState.difficulty["name_key"]), GameState.level()]

	var end_cfg: Dictionary = GameState.economy["end"]
	var target: float = end_cfg["win_net_worth"]
	%MillionaireBar.max_value = target
	%MillionaireBar.value = clampf(GameState.net_worth(), 0, target)
	%MillionaireLabel.text = tr("GOAL_MILLIONAIRE_PROGRESS") % [Fmt.rupiah(GameState.net_worth()), Fmt.rupiah(target)]
	var expenses := float(GameState.monthly_expenses())
	%FreedomBar.max_value = expenses
	%FreedomBar.value = clampf(GameState.passive_income(), 0, expenses)
	%FreedomLabel.text = tr("GOAL_FREEDOM_PROGRESS") % [Fmt.rupiah(GameState.passive_income()), Fmt.rupiah(expenses)]

	var s := GameState.stats
	var best: Dictionary = s["best_trade"]
	%StatsLabel.text = tr("PROFILE_STATS") % [
		Fmt.rupiah(s["peak_net_worth"]), GameState.month, int(s["events"]),
		GameState.quiz.correct_ids.size(),
		("%s %s" % [tr(best["asset_key"]), Fmt.signed_rupiah(best["value"])]) if not best.is_empty() else "-"]

	for slot: String in _slot_labels:
		_slot_labels[slot].text = SaveManager.slot_summary(slot)


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

	%LanguageOption.clear()
	for code: String in Settings.LANGUAGES:
		%LanguageOption.add_item(tr("LANG_" + code.to_upper()))
	%LanguageOption.selected = Settings.LANGUAGES.find(Settings.language)
	%LanguageOption.item_selected.connect(func(index: int) -> void:
		Settings.set_language(Settings.LANGUAGES[index])
		SaveManager.save_slot(SaveManager.AUTO_SLOT)
		get_tree().reload_current_scene())  # semua teks dibuat ulang dalam bahasa baru


func _show_legal(key: String) -> void:
	var doc: Dictionary = DataLoader.load_json(LEGAL_PATH)[key]
	text_requested.emit(tr(doc["title"]), tr(doc["body"]))


## Tekan dua kali untuk konfirmasi, lalu hapus semua simpanan & kembali ke layar judul.
func _on_reset() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		%ResetButton.text = tr("SETTINGS_RESET_CONFIRM")
		return
	SaveManager.reset_all()
	get_tree().change_scene_to_file(TITLE_SCENE)


# --- Simpan / muat ------------------------------------------------------------

## Satu baris per slot: ringkasan + tombol Simpan + tombol Muat.
func _build_slots() -> void:
	for i in SaveManager.MANUAL_SLOTS.size():
		var slot: String = SaveManager.MANUAL_SLOTS[i]
		var card := PanelContainer.new()
		var box := VBoxContainer.new()
		card.add_child(box)
		var title := Label.new()
		title.text = tr("SAVE_SLOT") % (i + 1)
		title.add_theme_font_size_override("font_size", 22)
		box.add_child(title)
		var info := Label.new()
		info.modulate = MonthReport.MUTED
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_font_size_override("font_size", 18)
		box.add_child(info)
		_slot_labels[slot] = info

		var row := HBoxContainer.new()
		var save_button := _make_button("SAVE_BUTTON")
		save_button.pressed.connect(_on_save.bind(slot))
		var load_button := _make_button("LOAD_BUTTON")
		load_button.pressed.connect(_on_load.bind(slot))
		row.add_child(save_button)
		row.add_child(load_button)
		box.add_child(row)
		%SlotList.add_child(card)


func _build_history() -> void:
	if GameState.history.is_empty():
		var empty := Label.new()
		empty.text = tr("HISTORY_EMPTY")
		empty.modulate = MonthReport.MUTED
		empty.add_theme_font_size_override("font_size", 20)
		%HistoryList.add_child(empty)
		return
	for record: Dictionary in GameState.history:
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 19)
		label.text = tr("HISTORY_ROW") % [record["name"], tr("END_TITLE_" + str(record["type"]).to_upper()),
			tr("END_REASON_SHORT_" + str(record["reason"]).to_upper()), int(record["months"]),
			Fmt.rupiah(record["net_worth"])]
		label.modulate = {"win": MonthReport.GREEN, "lose": MonthReport.RED}.get(record["type"], Color.WHITE)
		%HistoryList.add_child(label)


func _make_button(key: String) -> Button:
	var button := Button.new()
	button.text = tr(key)
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 22)
	return button


func _on_save(slot: String) -> void:
	var ok := SaveManager.save_slot(slot)
	%SaveFeedback.text = tr("SAVE_OK") if ok else tr("SAVE_FAILED")
	%SaveFeedback.modulate = MonthReport.GREEN if ok else MonthReport.RED
	_refresh()


func _on_load(slot: String) -> void:
	if not SaveManager.has_slot(slot):
		%SaveFeedback.text = tr("SAVE_EMPTY")
		%SaveFeedback.modulate = MonthReport.RED
		return
	if SaveManager.load_slot(slot):
		get_tree().reload_current_scene()  # bangun ulang semua layar dari state yang dimuat
	else:
		%SaveFeedback.text = tr("SAVE_LOAD_FAILED")
		%SaveFeedback.modulate = MonthReport.RED


## Simpan otomatis dulu sebelum meninggalkan layar utama.
func _leave_to(scene: String) -> void:
	SaveManager.save_slot(SaveManager.AUTO_SLOT)
	get_tree().change_scene_to_file(scene)
