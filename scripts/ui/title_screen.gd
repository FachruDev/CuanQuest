extends Control
## Layar judul: Lanjutkan (simpan otomatis), Game Baru, Muat Game (slot manual).

const MAIN_SCENE := "res://scenes/main.tscn"
const NEW_GAME_SCENE := "res://scenes/new_game.tscn"

var _confirm_new := false  # tekan dua kali untuk menimpa simpanan otomatis


func _ready() -> void:
	%ContinueButton.pressed.connect(_load.bind(SaveManager.AUTO_SLOT))
	%NewGameButton.pressed.connect(_on_new_game)
	%LoadButton.pressed.connect(func() -> void: %LoadPanel.visible = not %LoadPanel.visible)

	var has_auto := SaveManager.has_slot(SaveManager.AUTO_SLOT)
	%ContinueButton.visible = has_auto
	%ContinueInfo.visible = has_auto
	if has_auto:
		%ContinueInfo.text = SaveManager.slot_summary(SaveManager.AUTO_SLOT)

	var any_manual := false
	for slot: String in SaveManager.MANUAL_SLOTS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 72)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 20)
		button.text = "%s: %s" % [tr("SAVE_SLOT") % (SaveManager.MANUAL_SLOTS.find(slot) + 1), SaveManager.slot_summary(slot)]
		button.disabled = not SaveManager.has_slot(slot)
		any_manual = any_manual or SaveManager.has_slot(slot)
		button.pressed.connect(_load.bind(slot))
		%LoadPanel.add_child(button)
	%LoadButton.disabled = not any_manual
	%LoadPanel.hide()


func _on_new_game() -> void:
	if SaveManager.has_slot(SaveManager.AUTO_SLOT) and not _confirm_new:
		_confirm_new = true
		%NewGameButton.text = tr("TITLE_NEW_CONFIRM")
		return
	get_tree().change_scene_to_file(NEW_GAME_SCENE)


func _load(slot: String) -> void:
	if SaveManager.load_slot(slot):
		get_tree().change_scene_to_file(MAIN_SCENE)
	else:
		%ContinueInfo.show()
		%ContinueInfo.text = tr("SAVE_LOAD_FAILED")
		%ContinueInfo.modulate = MonthReport.RED
