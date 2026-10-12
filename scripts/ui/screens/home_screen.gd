extends ScrollContainer
## Tab Beranda: kondisi karakter, arus kas bulanan, dan pilihan biaya hidup.

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

	var expenses := GameState.monthly_expenses()
	var income := GameState.salary if GameState.unemployed_months == 0 else 0
	var surplus := income - expenses
	%SalaryLabel.text = tr("HOME_SALARY") % Fmt.rupiah(GameState.salary)
	var volatility := float(GameState.background["income_volatility"])
	if volatility > 0.0:
		%SalaryLabel.text = tr("HOME_SALARY_VARIABLE") % [Fmt.rupiah(GameState.salary), roundi(volatility * 100)]
	%SalaryLabel.modulate = Color.WHITE
	if GameState.unemployed_months > 0:
		%SalaryLabel.text = tr("HOME_UNEMPLOYED") % GameState.unemployed_months
		%SalaryLabel.modulate = MonthReport.RED
	%ExpenseLabel.text = tr("HOME_EXPENSES") % Fmt.rupiah(expenses)
	%SurplusLabel.text = tr("HOME_SURPLUS") % Fmt.signed_rupiah(surplus)
	%SurplusLabel.modulate = MonthReport.GREEN if surplus >= 0 else MonthReport.RED

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
		button.custom_minimum_size = Vector2(0, 96)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(on_select.bind(option["id"]))

		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE  # klik diteruskan ke Button
		content.add_child(_make_label(tr(option["name_key"]), 24))
		var cost_label := _make_label(Fmt.rupiah(GameState.option_cost(option)), 18)
		cost_label.modulate = Color(1, 1, 1, 0.7)
		content.add_child(cost_label)
		button.add_child(content)

		container.add_child(button)
		buttons[option["id"]] = button
	return buttons


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _effect_text(option: Dictionary) -> String:
	return tr("HOME_EFFECT") % [tr(option["name_key"]), int(option["health"]), int(option["happiness"])]
