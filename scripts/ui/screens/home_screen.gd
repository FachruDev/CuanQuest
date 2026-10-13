extends ScrollContainer
## Tab Beranda (tema "Senja Cuan"): kondisi karakter, arus kas bulanan (sesuai rencana gaji),
## dan pilihan biaya hidup.

signal plan_requested

var _food_buttons: Dictionary = {}     # option_id -> Button
var _housing_buttons: Dictionary = {}
var _plan_values: Dictionary = {}      # "lifestyle" | "emergency" | "invest" -> Label nilai


func _ready() -> void:
	_food_buttons = _build_options(%FoodOptions, GameState.economy["food"], GameState.set_food)
	_housing_buttons = _build_options(%HousingOptions, GameState.economy["housing"], GameState.set_housing)
	_build_plan_rows()
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
	var preview := GameState.plan_preview(GameState.plan, income)
	var surplus: int = preview["surplus"]
	_plan_values["lifestyle"].text = Fmt.signed_rupiah(-preview["lifestyle"])
	_plan_values["emergency"].text = Fmt.rupiah(preview["emergency"])
	_plan_values["invest"].text = Fmt.rupiah(preview["invest_total"])
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


## Baris rencana gaji (gaya hidup, dana darurat, investasi otomatis) disisipkan sebelum
## kotak "Sisa ke kas", lalu tombol "Atur rencana gaji" di bawahnya.
func _build_plan_rows() -> void:
	var card: VBoxContainer = %SurplusBox.get_parent()
	var index := %SurplusBox.get_index()
	for item: Array in [["lifestyle", "PLAN_LIFESTYLE", Palette.LOSS], ["emergency", "PLAN_EMERGENCY", Palette.TEAL],
			["invest", "PLAN_INVEST", Palette.TEAL]]:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = tr(item[1])
		name_label.theme_type_variation = &"RowLabel"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := Label.new()
		value.theme_type_variation = &"RowValueLabel"
		value.add_theme_color_override("font_color", item[2])
		row.add_child(name_label)
		row.add_child(value)
		card.add_child(row)
		card.move_child(row, index)
		index += 1
		_plan_values[item[0]] = value

	var button := ChunkyButton.new()
	button.theme_type_variation = &"NeutralButton"
	button.custom_minimum_size = Vector2(0, 72)
	var label := Label.new()
	label.text = tr("HOME_PLAN_BUTTON")
	label.theme_type_variation = &"NeutralButtonLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_bottom = -7.0
	button.add_child(label)
	button.pressed.connect(plan_requested.emit)
	card.add_child(button)


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
