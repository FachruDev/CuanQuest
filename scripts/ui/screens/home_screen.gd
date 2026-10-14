extends ScrollContainer
## Tab Beranda (tema "Senja Cuan"): kondisi karakter, arus kas bulanan (sesuai rencana gaji),
## dan pilihan biaya hidup.

signal plan_requested
signal dream_requested(dream_id: String)
signal add_dream_requested

var _food_buttons: Dictionary = {}     # option_id -> Button
var _housing_buttons: Dictionary = {}
var _plan_values: Dictionary = {}      # "lifestyle" | "emergency" | "dreams" | "invest" -> Label nilai
var _dreams_box: VBoxContainer         # isi kartu Impian (dibangun ulang saat data berubah)
var _targets_box: VBoxContainer        # isi kartu Target Bulan Ini


func _ready() -> void:
	_food_buttons = _build_options(%FoodOptions, GameState.economy["food"], GameState.set_food)
	_housing_buttons = _build_options(%HousingOptions, GameState.economy["housing"], GameState.set_housing)
	_build_plan_rows()
	_build_goal_cards()
	GameState.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	%HealthBar.value = GameState.health
	%HappinessBar.value = GameState.happiness
	%HealthValue.text = "%d / 100" % GameState.health
	%HappinessValue.text = "%d / 100" % GameState.happiness

	var expenses := GameState.monthly_expenses()
	var unemployed := GameState.unemployed_months > 0
	var income := 0 if unemployed else GameState.net_salary()
	var salary_tax := 0 if unemployed else GameState.income_tax(GameState.salary)
	var preview := GameState.plan_preview(GameState.plan, income)
	var surplus: int = preview["surplus"]
	_plan_values["lifestyle"].text = Fmt.signed_rupiah(-preview["lifestyle"])
	_plan_values["emergency"].text = Fmt.rupiah(preview["emergency"])
	_plan_values["dreams"].text = Fmt.rupiah(preview["dreams_total"])
	_plan_values["invest"].text = Fmt.rupiah(preview["invest_total"])
	var volatility := float(GameState.background["income_volatility"])

	%SalaryName.text = tr("HOME_INCOME_AVG_LABEL" if volatility > 0.0 else
		("HOME_NET_SALARY_LABEL" if salary_tax > 0 else "HOME_SALARY_LABEL"))
	%SalaryValue.text = Fmt.signed_rupiah(income)
	%SalaryValue.add_theme_color_override("font_color", Palette.LOSS if unemployed else Palette.GAIN)
	%SalaryNote.visible = unemployed or volatility > 0.0 or salary_tax > 0
	if unemployed:
		%SalaryNote.text = tr("HOME_UNEMPLOYED") % GameState.unemployed_months
		%SalaryNote.add_theme_color_override("font_color", Palette.LOSS)
	elif volatility > 0.0:
		%SalaryNote.text = tr("HOME_INCOME_VARIES") % roundi(volatility * 100)
		%SalaryNote.remove_theme_color_override("font_color")
	elif salary_tax > 0:
		%SalaryNote.text = tr("HOME_SALARY_TAX_NOTE") % [Fmt.rupiah(GameState.salary), Fmt.rupiah(salary_tax)]
		%SalaryNote.remove_theme_color_override("font_color")

	%ExpenseValue.text = Fmt.signed_rupiah(-expenses)
	%ExpenseValue.add_theme_color_override("font_color", Palette.LOSS)
	%SurplusValue.text = Fmt.signed_rupiah(surplus)
	%SurplusValue.add_theme_color_override("font_color", Palette.GAIN if surplus >= 0 else Palette.LOSS)
	%SurplusBox.theme_type_variation = &"SurplusPositive" if surplus >= 0 else &"SurplusNegative"

	_refresh_dreams()
	_refresh_targets()

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
			["dreams", "PLAN_DREAMS", Palette.TEAL], ["invest", "PLAN_INVEST", Palette.TEAL]]:
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


## Kartu "Impian" dan "Target Bulan Ini" disisipkan tepat setelah kartu Kondisi.
func _build_goal_cards() -> void:
	var page: VBoxContainer = $VBox
	var index := page.get_node("WellbeingCard").get_index() + 1
	for item: Array in [["DREAMS_TITLE", "_dreams_box"], ["TARGETS_TITLE", "_targets_box"]]:
		var title := Label.new()
		title.text = tr(item[0])
		title.theme_type_variation = &"SubSectionLabel"
		var card := PanelContainer.new()
		card.theme_type_variation = &"HomeCard"
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
		card.add_child(box)
		page.add_child(title)
		page.move_child(title, index)
		page.add_child(card)
		page.move_child(card, index + 1)
		index += 2
		set(item[1], box)


func _refresh_dreams() -> void:
	_clear(_dreams_box)
	var active := GameState.active_dreams()
	if active.is_empty():
		_dreams_box.add_child(_wrap_label(tr("DREAMS_EMPTY"), &"MutedLabel"))
	for entry: Dictionary in active:
		_dreams_box.add_child(_dream_row(GameState.dream_view(entry)))
	if GameState.can_add_dream() and not GameState.available_dreams().is_empty():
		var add := UiText.chunky_button(tr("DREAMS_ADD"), &"NeutralButton", &"NeutralButtonLabel", 68.0)
		add.pressed.connect(add_dream_requested.emit)
		_dreams_box.add_child(add)


## Satu impian: nama, terkumpul/biaya, progress bar, tenggat. Diketuk membuka detail.
func _dream_row(view: Dictionary) -> Button:
	var def: Dictionary = view["def"]
	var button := Button.new()
	button.theme_type_variation = &"AssetRowButton"
	button.custom_minimum_size = Vector2(0, 104)
	button.pressed.connect(dream_requested.emit.bind(view["id"]))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_right = -16
	box.offset_top = 10
	box.offset_bottom = -10
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := _wrap_label(tr(def["name"]), &"AssetNameLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var percent := _wrap_label("%d%%" % roundi(view["ratio"] * 100.0), &"AssetValueLabel")
	percent.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(percent)
	box.add_child(top)
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"XpBar"
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = view["ratio"]
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	var months_left := int(view["deadline"]) - GameState.month
	var sub := tr("DREAM_PROGRESS") % [Fmt.rupiah_short(view["saved"]), Fmt.rupiah_short(view["cost"])]
	if months_left >= 0:
		sub += " · " + tr("DREAM_DEADLINE") % [Fmt.game_date(view["deadline"]), months_left]
	else:
		sub += " · " + tr("DREAM_DEADLINE_PASSED") % Fmt.game_date(view["deadline"])
	box.add_child(_wrap_label(sub, &"AssetSubLabel"))
	button.add_child(box)
	UiText.fit_to_content(button, box, 20.0)  # Button tidak ikut membesar mengikuti isinya
	return button


func _refresh_targets() -> void:
	_clear(_targets_box)
	for target: Dictionary in GameState.targets:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var text := UiText.target_text(target)
		if target["type"] in ["invest", "dream_deposit"] and target["state"] == "open":
			text += " (%s)" % Fmt.rupiah_short(target["progress"])
		var label := _wrap_label(text, &"RowLabel")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var status := UiText.target_status(target)
		var status_label := _wrap_label(status["text"], &"RowValueLabel")
		status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		status_label.add_theme_color_override("font_color", status["color"])
		row.add_child(status_label)
		_targets_box.add_child(row)
	var cfg := GameState.targets_config()
	_targets_box.add_child(_wrap_label(tr("TARGETS_REWARD") % [int(cfg["reward_happiness"]), int(cfg["reward_xp"])],
		&"SmallMutedLabel"))


func _wrap_label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


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
