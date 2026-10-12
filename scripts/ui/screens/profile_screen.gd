extends ScrollContainer
## Tab Profil: kartu pemain, simpan/muat manual, glosarium, ulangi tutorial, menu utama.
## (Pengaturan, statistik & pencapaian menyusul di Milestone 6.)

signal glossary_requested

const TITLE_SCENE := "res://scenes/title.tscn"
const TUTORIAL_SCENE := "res://scenes/tutorial.tscn"

var _slot_labels: Dictionary = {}  # slot -> Label


func _ready() -> void:
	%GlossaryButton.pressed.connect(func() -> void: glossary_requested.emit())
	%TutorialButton.pressed.connect(func() -> void: _leave_to(TUTORIAL_SCENE))
	%TitleButton.pressed.connect(func() -> void: _leave_to(TITLE_SCENE))
	_build_slots()
	GameState.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	%Avatar.avatar_index = GameState.avatar
	%Avatar.display_name = GameState.player_name
	%NameLabel.text = GameState.player_name
	%InfoLabel.text = tr("PROFILE_INFO") % [
		tr(GameState.background["name_key"]), GameState.age(),
		tr(GameState.difficulty["name_key"]), GameState.level()]
	for slot: String in _slot_labels:
		_slot_labels[slot].text = SaveManager.slot_summary(slot)


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
