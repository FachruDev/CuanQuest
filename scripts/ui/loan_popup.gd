extends ModalPopup
## Popup "Pinjaman" (v1.5c langkah 1), dua mode:
## - open_apply(product_id): pilih jumlah & tenor, lalu lihat cicilan, total bunga, rasio cicilan
##   terhadap gaji, dan syarat ✓/✗. "Ajukan" langsung mencairkan uang (GameState.debt.take).
## - open_detail(loan_id): rincian pinjaman aktif + pelunasan dipercepat (GameState.debt.pay_off).
## Semua angka diambil dari GameState.debt.quote() / payoff_quote(), sama dengan yang dijalankan.

signal loan_taken(name: String, amount: int)
signal loan_paid_off(name: String)

const MAX_ROWS_HEIGHT := 560.0

var _product_id := ""
var _amounts: Array[int] = []
var _tenors: Array[int] = []
var _amount_index := 0
var _tenor := 0
var _loan_id := -1
var _values: Dictionary = {}  # kunci baris rincian -> Label nilai
var _amount_label: Label
var _reqs_box: VBoxContainer
var _action: Button


func open_apply(product_id: String) -> void:
	var debt := GameState.debt
	var prod := debt.product(product_id)
	_product_id = product_id
	_amounts = debt.amount_options(prod)
	_tenors = debt.tenor_options(prod)
	_amount_index = 0  # mulai dari jumlah & tenor terkecil: pinjam secukupnya, bunga paling sedikit
	_tenor = _tenors[0]
	%Title.text = tr(prod["name"])
	%SubtitleHolder.show()
	%Subtitle.text = tr("CREDIT_SCORE_PILL") % [debt.credit_score, tr(debt.grade()["key"])]
	%Body.show()
	%Body.text = UiText.money(tr(prod["desc"]))
	_reset_rows()

	%Rows.add_child(_label(tr("LOAN_AMOUNT"), &"ReportHeaderLabel"))
	var stepper := HBoxContainer.new()
	stepper.add_theme_constant_override("separation", 8)
	stepper.add_child(_step_button("−", -1))
	_amount_label = _label("", &"AssetValueLabel")
	_amount_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stepper.add_child(_amount_label)
	stepper.add_child(_step_button("+", 1))
	%Rows.add_child(stepper)
	%Rows.add_child(_label(tr("LOAN_LIMIT_NOTE") % [int(prod["max_salary_mult"]), Fmt.rupiah(debt.max_amount(prod))],
		&"SmallMutedLabel"))

	%Rows.add_child(_label(tr("LOAN_TENOR"), &"ReportHeaderLabel"))
	var tenor_row := HBoxContainer.new()
	tenor_row.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for tenor: int in _tenors:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = &"SegmentButton"
		button.text = tr("LOAN_MONTHS") % tenor
		button.custom_minimum_size = Vector2(0, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.button_pressed = tenor == _tenor
		button.toggled.connect(func(on: bool) -> void:
			if on:
				_tenor = tenor
				_refresh_apply())
		tenor_row.add_child(button)
	%Rows.add_child(tenor_row)

	%Rows.add_child(_label(tr("LOAN_DETAILS"), &"ReportHeaderLabel"))
	for key: String in ["rate", "payment", "interest", "total", "dsr"]:
		%Rows.add_child(_value_row(key, tr("LOAN_ROW_" + key.to_upper())))
	%Rows.add_child(_label(tr("LOAN_RATE_NOTE") % [Fmt.percent_plain(GameState.market.policy_rate),
		Fmt.percent_plain(float(prod["rate_spread"]))], &"SmallMutedLabel"))
	%Rows.add_child(_label(tr("LOAN_REQUIREMENTS"), &"ReportHeaderLabel"))
	_reqs_box = VBoxContainer.new()
	_reqs_box.add_theme_constant_override("separation", 4)
	%Rows.add_child(_reqs_box)
	%Rows.add_child(_label(tr("LOAN_TIP"), &"SmallMutedLabel"))

	_clear(%Buttons)
	_action = UiText.chunky_button("", &"PrimaryButton", &"PrimaryButtonLabel", 80.0, 28)
	_action.pressed.connect(_on_apply)
	%Buttons.add_child(_action)
	_add_close_button()
	_refresh_apply()
	_show()


func open_detail(loan_id: int) -> void:
	var debt := GameState.debt
	var loan := debt.find(loan_id)
	if loan.is_empty():
		close()  # pinjaman sudah lunas/macet sebelum popup sempat tampil
		return
	_loan_id = loan_id
	var prod := debt.product(loan["product"])
	var kol := Debt.collectibility(int(loan["missed"]))
	%Title.text = tr(prod["name"])
	%SubtitleHolder.show()
	%Subtitle.text = tr("LOAN_KOL") % [kol, tr("KOL_%d" % kol)]
	%Body.show()
	%Body.text = tr("LOAN_DETAIL_BODY") % Fmt.game_date(int(loan["start_month"]))
	_reset_rows()

	_info_row(tr("LOAN_ROW_PRINCIPAL"), Fmt.rupiah(loan["principal"]))
	_info_row(tr("LOAN_ROW_BALANCE"), Fmt.rupiah(ceili(loan["balance"])))
	_info_row(tr("LOAN_ROW_RATE"), tr("LOAN_RATE_VALUE") % Fmt.percent_plain(loan["rate"]))
	_info_row(tr("LOAN_ROW_PAYMENT"), Fmt.rupiah(debt.installment(loan)))
	_info_row(tr("LOAN_ROW_MONTHS_LEFT"), tr("LOAN_MONTHS_OF") % [int(loan["months_left"]), int(loan["months_total"])])
	_info_row(tr("LOAN_ROW_INTEREST_PAID"), Fmt.rupiah(loan["interest_paid"]))
	if int(loan["arrears"]) > 0:
		_info_row(tr("LOAN_ROW_ARREARS"), Fmt.rupiah(loan["arrears"]), Palette.LOSS)
		var note := _label(tr("LOAN_ARREARS_NOTE") % [roundi(float(debt.data["late_fee"]) * 100.0),
			int(debt.data["default_after"])], &"SmallMutedLabel")
		note.add_theme_color_override("font_color", Palette.LOSS)
		%Rows.add_child(note)

	var q := debt.payoff_quote(loan)
	%Rows.add_child(_label(tr("LOAN_PAYOFF"), &"ReportHeaderLabel"))
	_info_row(tr("LOAN_ROW_BALANCE"), Fmt.rupiah(q["balance"]))
	if int(q["arrears"]) > 0:
		_info_row(tr("LOAN_ROW_ARREARS"), Fmt.rupiah(q["arrears"]), Palette.LOSS)
	_info_row(tr("LOAN_ROW_PENALTY") % roundi(float(prod.get("prepay_penalty", 0.0)) * 100.0),
		Fmt.rupiah(q["penalty"]), Palette.LOSS)
	_info_row(tr("LOAN_ROW_PAYOFF_TOTAL"), Fmt.rupiah(q["total"]))
	var remaining := Debt.schedule_total(loan["balance"], loan["rate"], int(loan["months_left"]))
	var saved := remaining - int(q["balance"]) - int(q["penalty"])
	%Rows.add_child(_label(tr("LOAN_PAYOFF_SAVES") % Fmt.rupiah(saved) if saved > 0 else tr("LOAN_PAYOFF_NO_SAVING"),
		&"SmallMutedLabel"))
	var enough := GameState.cash >= int(q["total"])
	if not enough:
		var short := _label(tr("LOAN_PAYOFF_NO_CASH") % Fmt.rupiah(GameState.cash), &"SmallMutedLabel")
		short.add_theme_color_override("font_color", Palette.LOSS)
		%Rows.add_child(short)

	_clear(%Buttons)
	_action = UiText.chunky_button(tr("LOAN_PAYOFF_BUTTON") % Fmt.rupiah(q["total"]), &"PrimaryButton",
		&"PrimaryButtonLabel", 80.0, 26)
	_action.pressed.connect(_on_pay_off)
	_set_enabled(_action, enough)
	%Buttons.add_child(_action)
	_add_close_button()
	_show()


func _refresh_apply() -> void:
	var q := GameState.debt.quote(_product_id, _amounts[_amount_index], _tenor)
	_amount_label.text = Fmt.rupiah(q["amount"])
	_values["rate"].text = tr("LOAN_RATE_VALUE") % Fmt.percent_plain(q["rate"])
	_values["payment"].text = Fmt.rupiah(q["payment"])
	_values["interest"].text = Fmt.rupiah(q["interest"])
	_values["interest"].add_theme_color_override("font_color", Palette.LOSS)
	_values["total"].text = Fmt.rupiah(q["total"])
	var dsr: float = q["dsr"]
	_values["dsr"].text = tr("LOAN_DSR_NONE") if dsr < 0.0 else \
		tr("LOAN_DSR_VALUE") % [roundi(dsr * 100.0), roundi(float(q["dsr_limit"]) * 100.0)]
	_values["dsr"].add_theme_color_override("font_color",
		Palette.GAIN if dsr >= 0.0 and dsr <= float(q["dsr_limit"]) + 0.0001 else Palette.LOSS)
	UiText.fill_loan_requirements(_reqs_box, q["requirements"])
	_action.get_node("Content").text = tr("LOAN_APPLY") % Fmt.rupiah(q["amount"]) if q["ok"] else tr("LOAN_APPLY_BLOCKED")
	_set_enabled(_action, q["ok"])


func _on_step(direction: int) -> void:
	_amount_index = clampi(_amount_index + direction, 0, _amounts.size() - 1)
	_refresh_apply()


func _on_apply() -> void:
	var amount := _amounts[_amount_index]
	if GameState.debt.take(_product_id, amount, _tenor)["ok"]:
		Sfx.play("coin")
		loan_taken.emit(GameState.debt.product(_product_id)["name"], amount)
		close()


func _on_pay_off() -> void:
	var loan := GameState.debt.find(_loan_id)
	if loan.is_empty():
		return
	var name: String = GameState.debt.product(loan["product"])["name"]
	if GameState.debt.pay_off(_loan_id):
		Sfx.play("success")
		loan_paid_off.emit(name)
		close()


func _show() -> void:
	%Scroll.scroll_vertical = 0
	show()
	await get_tree().process_frame  # tinggi label yang membungkus baru diketahui setelah ditata
	%Scroll.custom_minimum_size.y = minf(%Rows.get_combined_minimum_size().y, MAX_ROWS_HEIGHT)


func _reset_rows() -> void:
	_clear(%Rows)
	_values.clear()


func _value_row(key: String, title: String) -> HBoxContainer:
	var row := _row(title, "")
	_values[key] = row.get_child(1)
	return row


func _info_row(title: String, value: String, color := Palette.INK) -> void:
	var row := _row(title, value)
	row.get_child(1).add_theme_color_override("font_color", color)
	%Rows.add_child(row)


func _row(title: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label := _label(title, &"RowLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value_label := _label(value, &"RowValueLabel")
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	return row


func _step_button(text: String, direction: int) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"QuickButton"
	button.text = text
	button.custom_minimum_size = Vector2(72, 56)
	button.pressed.connect(_on_step.bind(direction))
	return button


func _add_close_button() -> void:
	var close_button := UiText.chunky_button(tr("BTN_CLOSE"), &"NeutralButton", &"NeutralButtonLabel", 68.0, 26)
	close_button.pressed.connect(close)
	%Buttons.add_child(close_button)


func _set_enabled(button: Button, enabled: bool) -> void:
	button.disabled = not enabled
	button.get_node("Content").modulate.a = 1.0 if enabled else 0.45


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1
	return label


func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
