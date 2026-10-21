extends Control
## Buat karakter, wizard 3 langkah bertema "Senja Cuan" (GDD 4.1, 5.8):
## 1. Identitas (nama + avatar)  2. Latar belakang + tingkat kesulitan  3. Profil risiko.
## Setelah "Mulai Bermain": tutorial (jika belum pernah) lalu layar utama.

const MAIN_SCENE := "res://scenes/main.tscn"
const TUTORIAL_SCENE := "res://scenes/tutorial.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
const STEP_TITLES: Array[String] = ["NG_STEP1_TITLE", "NG_STEP2_TITLE", "NG_STEP3_TITLE"]
const ARROW_ICON := preload("res://assets/icons/arrow_badge.svg")
const PLAY_ICON := preload("res://assets/icons/play_badge.svg")
const CHECK_ICON := preload("res://assets/icons/check_badge.svg")
const RADIO_ON := preload("res://assets/icons/radio_on.svg")
const RADIO_OFF := preload("res://assets/icons/radio_off.svg")
const BACKGROUND_ICON := "res://assets/icons/background_%s.svg"
const BACKGROUND_TILES := {"sma": &"IconTileMint", "d3": &"IconTileCoral", "s1": &"IconTileGold"}
## Gaya meter & warna nama per profil risiko.
const PROFILE_LOOK := {
	"conservative": [&"MeterTeal", Color("#23877b")],
	"moderate": [&"MeterGold", Color("#c7841a")],
	"aggressive": [&"MeterCoral", Color("#c2452d")],
}

var _step := 0
var _avatar := 0
var _background_id := ""
var _difficulty_id := ""
var _risk_scores: Array[int] = []  # skor jawaban per pertanyaan profil risiko
var _avatar_tiles: Array[Button] = []
var _meter_bars := {}  # id profil -> Panel


func _ready() -> void:
	Music.play("title")
	_background_id = GameState.economy["default_background"]
	_difficulty_id = GameState.economy["default_difficulty"]
	%HeaderBackButton.pressed.connect(_go_back)
	%BackStepButton.pressed.connect(_go_back)
	%NextButton.pressed.connect(_go_next)
	%NameEdit.text_submitted.connect(func(_t: String) -> void: %NameEdit.release_focus())
	_build_avatar_grid()
	_build_background_cards()
	_build_difficulty()
	_build_meter()
	_build_risk_questions()
	_select_avatar(0)
	_show_step(0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- langkah

func _show_step(step: int) -> void:
	_step = step
	var steps: Array[Control] = [%Step1, %Step2, %Step3]
	var bars: Array[Panel] = [%Progress1, %Progress2, %Progress3]
	for i in steps.size():
		steps[i].visible = i == step
		bars[i].theme_type_variation = &"ProgressOn" if i <= step else &"ProgressOff"
	%StepTitle.text = tr(STEP_TITLES[step])
	%StepLabel.text = tr("NG_STEP") % [step + 1, steps.size()]
	%BackStepButton.visible = step > 0
	var last := step == steps.size() - 1
	%NextLabel.text = tr("NG_START" if last else "NG_NEXT")
	%NextIcon.texture = PLAY_ICON if last else ARROW_ICON
	%HBox.move_child(%NextIcon, 0 if last else -1)  # ikon play di depan, panah di belakang
	%NameEdit.release_focus()
	%Scroll.scroll_vertical = 0


func _go_back() -> void:
	if _step == 0:
		get_tree().change_scene_to_file(TITLE_SCENE)
	else:
		_show_step(_step - 1)


func _go_next() -> void:
	if _step < STEP_TITLES.size() - 1:
		_show_step(_step + 1)
	else:
		_on_start()


# ---------------------------------------------------------------- 1. identitas

func _build_avatar_grid() -> void:
	var group := ButtonGroup.new()
	for i in AvatarView.COUNT:
		var tile := Button.new()
		tile.toggle_mode = true
		tile.button_group = group
		tile.theme_type_variation = &"AvatarTileButton"
		tile.custom_minimum_size = Vector2(0, 118)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.tooltip_text = AvatarView.NAMES[i]
		var view := AvatarView.new()
		view.avatar_index = i
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view.offset_left = 7
		view.offset_top = 7
		view.offset_right = -7
		view.offset_bottom = -12
		tile.add_child(view)
		var check := TextureRect.new()  # lencana centang di pojok kanan atas
		check.texture = CHECK_ICON
		check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		check.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		check.offset_left = -26
		check.offset_top = -8
		check.offset_right = 8
		check.offset_bottom = 26
		check.hide()
		tile.add_child(check)
		tile.toggled.connect(func(on: bool) -> void: check.visible = on)
		tile.pressed.connect(_select_avatar.bind(i))
		(%MaleGrid if i < AvatarView.MALE_COUNT else %FemaleGrid).add_child(tile)
		_avatar_tiles.append(tile)


func _select_avatar(index: int) -> void:
	_avatar = index
	_avatar_tiles[index].button_pressed = true
	%PreviewAvatar.avatar_index = index
	%AvatarDesc.text = AvatarView.description(index)
	%NameHint.text = tr("NG_NAME_DEFAULT") % AvatarView.NAMES[index]


# ---------------------------------------------------------------- 2. jalan hidup

func _build_background_cards() -> void:
	var group := ButtonGroup.new()
	for option: Dictionary in GameState.economy["backgrounds"]:
		var id: String = option["id"]
		var card := Button.new()
		card.toggle_mode = true
		card.button_group = group
		card.theme_type_variation = &"OptionCardButton"

		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side: String in ["left", "right"]:
			margin.add_theme_constant_override("margin_" + side, 21)
		margin.add_theme_constant_override("margin_top", 18)
		margin.add_theme_constant_override("margin_bottom", 24)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 18)
		margin.add_child(row)

		var tile := PanelContainer.new()
		tile.theme_type_variation = BACKGROUND_TILES.get(id, &"IconTileGold")
		tile.custom_minimum_size = Vector2(72, 72)
		tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_path := BACKGROUND_ICON % option.get("icon", id)
		if ResourceLoader.exists(icon_path):
			var icon := TextureRect.new()
			icon.texture = load(icon_path)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(40, 40)
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tile.add_child(icon)
		row.add_child(tile)

		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_theme_constant_override("separation", 4)
		var title_row := HFlowContainer.new()
		title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_row.add_theme_constant_override("h_separation", 10)
		title_row.add_theme_constant_override("v_separation", 4)
		title_row.add_child(_label(tr(option["name_key"]), &"OptionTitleLabel"))
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"SalaryChip"
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(_label(tr("NG_BACKGROUND_CHIP") % [
			GameState.education.level_name(GameState.education.level_index(option["education"])), int(option["skill"])], &"SalaryLabel"))
		title_row.add_child(chip)
		text.add_child(title_row)
		var desc := _label(tr(option["desc_key"]), &"OptionDescLabel")
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(desc)
		row.add_child(text)

		var radio := TextureRect.new()
		radio.texture = RADIO_OFF
		radio.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		radio.custom_minimum_size = Vector2(30, 30)
		radio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		radio.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(radio)

		card.add_child(margin)
		card.toggled.connect(func(on: bool) -> void: radio.texture = RADIO_ON if on else RADIO_OFF)
		card.pressed.connect(func() -> void: _background_id = id)
		%BackgroundOptions.add_child(card)
		card.button_pressed = id == _background_id
		UiText.fit_to_content(card, margin)


func _build_difficulty() -> void:
	var group := ButtonGroup.new()
	for option: Dictionary in GameState.economy["difficulties"]:
		var id: String = option["id"]
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = &"SegmentButton"
		button.text = tr(option["name_key"])
		button.custom_minimum_size = Vector2(0, 76)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			_difficulty_id = id
			%DifficultyDesc.text = tr(option["desc_key"]))
		%DifficultyRow.add_child(button)
		if id == _difficulty_id:
			button.button_pressed = true
			%DifficultyDesc.text = tr(option["desc_key"])


# ---------------------------------------------------------------- 3. profil risiko

## Tiap pertanyaan punya 3 jawaban berskor 0-2; jawaban tengah dipilih sebagai default.
func _build_risk_questions() -> void:
	var questions := GameState.portfolio.risk_questions()
	for qi in questions.size():
		var question: Dictionary = questions[qi]
		_risk_scores.append(1)
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 12)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 14)
		var badge := PanelContainer.new()
		badge.theme_type_variation = &"NumberBadge"
		badge.custom_minimum_size = Vector2(40, 40)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var number := _label(str(qi + 1), &"NumberLabel")
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(number)
		head.add_child(badge)
		var text := _label(tr(question["q"]), &"QuestionLabel")
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(text)
		block.add_child(head)

		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 10)
		var group := ButtonGroup.new()
		for option: Dictionary in question["options"]:
			var button := Button.new()
			button.toggle_mode = true
			button.button_group = group
			button.theme_type_variation = &"RiskOptionButton"
			button.text = tr(option["text"])
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.custom_minimum_size = Vector2(0, 88)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.button_pressed = int(option["score"]) == 1
			button.pressed.connect(func() -> void:
				_risk_scores[qi] = int(option["score"])
				_update_risk_result())
			grid.add_child(button)
		block.add_child(grid)
		%RiskQuestions.add_child(block)
	_update_risk_result()


func _build_meter() -> void:
	for profile: Dictionary in GameState.portfolio.risk_profiles():
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 4)
		var bar := Panel.new()
		bar.custom_minimum_size = Vector2(0, 16)
		bar.theme_type_variation = &"MeterOff"
		column.add_child(bar)
		var label := _label(tr(profile["name"]), &"MeterLabel")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
		%Meter.add_child(column)
		_meter_bars[profile["id"]] = bar


func _risk_profile_id() -> String:
	var total := 0
	for score in _risk_scores:
		total += score
	return GameState.portfolio.profile_from_score(total)


func _update_risk_result() -> void:
	var id := _risk_profile_id()
	var look: Array = PROFILE_LOOK.get(id, PROFILE_LOOK["moderate"])
	for profile: Dictionary in GameState.portfolio.risk_profiles():
		if profile["id"] == id:
			%ProfileName.text = tr(profile["name"])
			%ProfileDesc.text = tr(profile["desc"])
	%ProfileName.add_theme_color_override("font_color", look[1])
	for profile_id: String in _meter_bars:
		_meter_bars[profile_id].theme_type_variation = look[0] if profile_id == id else &"MeterOff"


# ---------------------------------------------------------------- mulai

func _on_start() -> void:
	var player_name: String = %NameEdit.text.strip_edges()
	if player_name == "":
		player_name = AvatarView.NAMES[_avatar]
	GameState.new_game({
		"name": player_name,
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


# ---------------------------------------------------------------- bantuan

func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label
