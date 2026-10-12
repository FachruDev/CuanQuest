extends Control
## Buat karakter: nama, avatar, latar belakang, tingkat kesulitan (GDD 4.1).
## Setelah "Mulai": tutorial (jika belum pernah) lalu layar utama.

const MAIN_SCENE := "res://scenes/main.tscn"
const TUTORIAL_SCENE := "res://scenes/tutorial.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"

var _avatar := 0
var _background_id := ""
var _difficulty_id := ""
var _avatar_views: Array[AvatarView] = []


func _ready() -> void:
	_background_id = GameState.economy["default_background"]
	_difficulty_id = GameState.economy["default_difficulty"]
	%NameEdit.text_changed.connect(func(_t: String) -> void: _update_avatars())
	%StartButton.pressed.connect(_on_start)
	%BackButton.pressed.connect(func() -> void: get_tree().change_scene_to_file(TITLE_SCENE))
	_build_avatars()
	_build_options(%BackgroundOptions, GameState.economy["backgrounds"], _background_id,
			func(id: String) -> void: _background_id = id, true)
	_build_options(%DifficultyOptions, GameState.economy["difficulties"], _difficulty_id,
			func(id: String) -> void: _difficulty_id = id, false)


func _build_avatars() -> void:
	var group := ButtonGroup.new()
	for i in AvatarView.COLORS.size():
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(96, 96)
		button.button_pressed = i == _avatar
		button.pressed.connect(func() -> void: _avatar = i)
		var view := AvatarView.new()
		view.avatar_index = i
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view.offset_left = 10
		view.offset_top = 10
		view.offset_right = -10
		view.offset_bottom = -10
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(view)
		%AvatarRow.add_child(button)
		_avatar_views.append(view)
	_update_avatars()


func _update_avatars() -> void:
	for view in _avatar_views:
		view.display_name = %NameEdit.text


## Tombol pilihan 2 baris (nama + deskripsi). `show_salary`: tampilkan gaji latar belakang.
func _build_options(container: VBoxContainer, options: Array, selected: String,
		on_select: Callable, show_salary: bool) -> void:
	var group := ButtonGroup.new()
	for option: Dictionary in options:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0, 96)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 22)
		var text := tr(option["name_key"])
		if show_salary:
			text += "  (%s)" % (tr("NG_SALARY") % Fmt.rupiah(option["salary"]))
		button.text = text + "\n" + tr(option["desc_key"])
		button.button_pressed = option["id"] == selected
		button.pressed.connect(on_select.bind(option["id"]))
		container.add_child(button)


func _on_start() -> void:
	GameState.new_game({
		"name": %NameEdit.text.strip_edges(),
		"avatar": _avatar,
		"background": _background_id,
		"difficulty": _difficulty_id,
	})
	SaveManager.save_slot(SaveManager.AUTO_SLOT)
	if GameState.tutorial_done:
		get_tree().change_scene_to_file(MAIN_SCENE)
	else:
		get_tree().change_scene_to_file(TUTORIAL_SCENE)
