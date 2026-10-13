extends Control
## Layar judul bertema "Senja Cuan".
## - Ada simpanan otomatis: kartu simpanan + Lanjutkan, lalu Game Baru (minta konfirmasi) & Muat Game.
## - Belum ada: kartu sambutan + Game Baru sebagai tombol utama.
## Muat Game membuka panel geser dari bawah berisi slot manual.

const MAIN_SCENE := "res://scenes/main.tscn"
const NEW_GAME_SCENE := "res://scenes/new_game.tscn"
const SLOT_BUTTON := preload("res://scenes/ui/save_slot_button.tscn")
const LOCK_ICON := preload("res://assets/icons/lock.svg")
const TREND_DOWN_ICON := preload("res://assets/icons/trend_down.svg")
const OPEN_TIME := 0.28
const CLOSE_TIME := 0.14


func _ready() -> void:
	var has_auto := SaveManager.has_slot(SaveManager.AUTO_SLOT)
	%SaveCard.visible = has_auto
	%ContinueButton.visible = has_auto
	%NewGameButton.visible = has_auto
	%WelcomeCard.visible = not has_auto
	%StartButton.visible = not has_auto
	if has_auto:
		_fill_save_card(SaveManager.slot_meta(SaveManager.AUTO_SLOT))

	%ContinueButton.pressed.connect(_load.bind(SaveManager.AUTO_SLOT))
	%StartButton.pressed.connect(_start_new_game)
	%NewGameButton.pressed.connect(_open_overlay.bind(%ConfirmOverlay, %ConfirmDialog))
	%ConfirmYesButton.pressed.connect(_start_new_game)
	%ConfirmCancelButton.pressed.connect(_close_overlay.bind(%ConfirmOverlay))
	%LoadButton.pressed.connect(_open_overlay.bind(%LoadOverlay, %LoadSheet))
	%CloseLoadButton.pressed.connect(_close_overlay.bind(%LoadOverlay))
	# Ketuk area gelap di luar panel = tutup.
	%LoadDim.gui_input.connect(_on_dim_input.bind(%LoadOverlay))
	%ConfirmDim.gui_input.connect(_on_dim_input.bind(%ConfirmOverlay))

	var any_manual := false
	for i in SaveManager.MANUAL_SLOTS.size():
		var slot: String = SaveManager.MANUAL_SLOTS[i]
		var button := SLOT_BUTTON.instantiate()
		%SlotList.add_child(button)
		button.setup(i, slot)
		button.pressed.connect(_load.bind(slot))
		any_manual = any_manual or SaveManager.has_slot(slot)
	%LoadButton.disabled = not any_manual
	if not any_manual:
		%LoadIcon.texture = LOCK_ICON
		%LoadLabel.add_theme_color_override("font_color", Palette.DISABLED_TEXT)

	# Pita "QUEST" miring -3 derajat, berputar di titik tengahnya.
	%Ribbon.resized.connect(func() -> void: %Ribbon.pivot_offset = %Ribbon.size / 2)
	%Ribbon.rotation_degrees = -3.0


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	for overlay: Control in [%ConfirmOverlay, %LoadOverlay]:
		if overlay.visible:
			_close_overlay(overlay)
			get_viewport().set_input_as_handled()
			return


func _fill_save_card(meta: Dictionary) -> void:
	var player_name: String = meta["player_name"]
	var date := Fmt.game_date(int(meta["month"]))
	var net_worth: float = meta["net_worth"]
	%SaveName.text = player_name
	%SaveInitial.text = player_name.left(1).to_upper()
	%SaveDetail.text = "%s · %s" % [date, SaveManager.saved_at_text(meta)]
	%SaveNetWorth.text = Fmt.rupiah_short(net_worth)
	if net_worth < 0:
		%SaveNetWorth.add_theme_color_override("font_color", Palette.LOSS)
		%TrendIcon.texture = TREND_DOWN_ICON
	%ConfirmBody.text = tr("TITLE_CONFIRM_NEW_BODY") % [player_name, date, Fmt.rupiah_short(net_worth)]


func _open_overlay(overlay: Control, panel: Control) -> void:
	overlay.modulate.a = 0.0
	overlay.show()
	await get_tree().process_frame  # tunggu container menata posisi panel dulu
	var rest_y := panel.position.y
	var tween := create_tween().set_parallel()
	tween.tween_property(overlay, "modulate:a", 1.0, OPEN_TIME * 0.6)
	tween.tween_property(panel, "position:y", rest_y, OPEN_TIME).from(rest_y + 140.0) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_overlay(overlay: Control) -> void:
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, CLOSE_TIME)
	tween.tween_callback(overlay.hide)


func _on_dim_input(event: InputEvent, overlay: Control) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_overlay(overlay)


func _start_new_game() -> void:
	get_tree().change_scene_to_file(NEW_GAME_SCENE)


func _load(slot: String) -> void:
	if SaveManager.load_slot(slot):
		get_tree().change_scene_to_file(MAIN_SCENE)
		return
	%LoadOverlay.hide()
	%ErrorLabel.text = SaveManager.load_error_text(slot)
	%ErrorLabel.show()
	Sfx.play("fail")
