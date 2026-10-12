extends ScrollContainer
## Tab Beranda (tema "Senja Cuan"): kondisi karakter, arus kas bulanan, dan pilihan biaya hidup.

var _food_buttons: Dictionary = {}     # option_id -> Button
var _housing_buttons: Dictionary = {}


func _ready() -> void:
	_food_buttons = _build_options(%FoodOptions, GameState.economy["food"], GameState.set_food)
	_housing_buttons = _build_options(%HousingOptions, GameState.economy["housing"], GameState.set_housing)
	GameState.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	%HealthBar.value = GameState.health
	%HappinessBar.value = GameState.happiness
	%HealthValue.text = "%d / 100" % GameState.health
	%HappinessValue.text = "%d / 100" % GameState.happiness

	var expenses := GameState.monthly_expenses()
	var unemployed := GameState.unemployed_months > 0
	var income := 0 if unemployed else GameState.salary
	var surplus := income - expenses
	var volatility := float(GameState.background["income_volatility"])

	%SalaryName.text = tr("HOME_INCOME_AVG_LABEL" if volatility > 0.0 else "HOME_SALARY_LABEL")
	%SalaryValue.text = Fmt.signed_rupiah(income)
	%SalaryValue.add_theme_color_override("font_color", Palette.LOSS if unemployed else Palette.GAIN)
	%SalaryNote.visible = unemployed or volatility > 0.0
	if unemployed:
		%SalaryNote.text = tr("HOME_UNEMPLOYED") % GameState.unemployed_months
		%SalaryNote.add_theme_color_override("font_color", Palette.LOSS)
	elif volatility > 0.0:
		%SalaryNote.text = tr("HOME_INCOME_VARIES") % roundi(volatility * 100)
		%SalaryNote.remove_theme_color_override("font_color")

	%ExpenseValue.text = Fmt.signed_rupiah(-expenses)
	%ExpenseValue.add_theme_color_override("font_color", Palette.LOSS)
	%SurplusValue.text = Fmt.signed_rupiah(surplus)
	%SurplusValue.add_theme_color_override("font_color", Palette.GAIN if surplus >= 0 else Palette.LOSS)
	%SurplusBox.theme_type_variation = &"SurplusPositive" if surplus >= 0 else &"SurplusNegative"

	for id: String in _food_buttons:
		_food_buttons[id].set_pressed_no_signal(id == GameState.food_id)
	for id: String in _housing_buttons:
		_housing_buttons[id].set_pressed_no_signal(id == GameState.housing_id)
	%FoodDesc.text = _effect_text(GameState.food_option())
	%HousingDesc.text = _effect_text(GameState.housing_option())


## Membuat tombol pilihan (segmented control) dari data JSON.
## Setiap tombol berisi 2 baris: nama pilihan & biayanya.
func _build_options(container: HBoxContainer, options: Array, on_select: Callable) -> Dictionary:
	var group := ButtonGroup.new()
	var buttons := {}
	for option: Dictionary in options:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = &"ChoiceButton"
		button.custom_minimum_size = Vector2(0, 84)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(on_select.bind(option["id"]))

		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_bottom = -5  # bibir bawah tombol
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 0)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE  # klik diteruskan ke Button
		content.add_child(_make_label(tr(option["name_key"]), &"ChoiceNameLabel"))
		content.add_child(_make_label(Fmt.rupiah(GameState.option_cost(option)), &"ChoiceCostLabel"))
		button.add_child(content)

		container.add_child(button)
		buttons[option["id"]] = button
	return buttons


func _make_label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _effect_text(option: Dictionary) -> String:
	return tr("HOME_EFFECT") % [tr(option["name_key"]), int(option["health"]), int(option["happiness"])]
