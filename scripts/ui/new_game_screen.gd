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
var _risk_scores: Array[int] = []  # skor jawaban per pertanyaan profil risiko


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
	_build_risk_questions()


## Kuesioner profil risiko (GDD 5.8): tiap pertanyaan punya 3 jawaban berskor 0-2.
## Jawaban tengah dipilih sebagai default.
func _build_risk_questions() -> void:
	var questions := GameState.risk_questions()
	for qi in questions.size():
		var question: Dictionary = questions[qi]
		_risk_scores.append(1)
		var label := Label.new()
		label.text = "%d. %s" % [qi + 1, tr(question["q"])]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 21)
		%RiskQuestions.add_child(label)
		var group := ButtonGroup.new()
		for option: Dictionary in question["options"]:
			var button := Button.new()
			button.toggle_mode = true
			button.button_group = group
			button.text = tr(option["text"])
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.custom_minimum_size = Vector2(0, 60)
			button.add_theme_font_size_override("font_size", 20)
			button.button_pressed = int(option["score"]) == 1
			button.pressed.connect(func() -> void:
				_risk_scores[qi] = int(option["score"])
				_update_risk_result())
			%RiskQuestions.add_child(button)
	_update_risk_result()


func _risk_profile_id() -> String:
	var total := 0
	for score in _risk_scores:
		total += score
	return GameState.profile_from_score(total)


func _update_risk_result() -> void:
	var id := _risk_profile_id()
	for p: Dictionary in GameState.risk_profiles():
		if p["id"] == id:
			%RiskResult.text = tr("NG_RISK_RESULT") % [tr(p["name"]), tr(p["desc"])]


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
		"risk_profile": _risk_profile_id(),
	})
	SaveManager.save_slot(SaveManager.AUTO_SLOT)
	if GameState.tutorial_done:
		get_tree().change_scene_to_file(MAIN_SCENE)
	else:
		get_tree().change_scene_to_file(TUTORIAL_SCENE)
