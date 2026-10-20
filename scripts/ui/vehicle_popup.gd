extends ModalPopup
## Popup "Kendaraan" (v1.5c langkah 2; showroom & garasi: tambahan v2), tiga mode:
## - open_market(): showroom, semua model per jenis (motor, mobil) dengan harga, biaya rutin, penyusutan,
##   dan kebahagiaan; ketuk untuk membeli.
## - open_buy(id): biaya kepemilikan (termasuk pajak progresif & kebahagiaan yang benar-benar bertambah),
##   pilih Tunai / Kredit (uang muka & tenor), rincian & syarat ✓/✗.
## - open_detail(uid): nilai sekarang, penyusutan, biaya rutin, kredit berjalan, dan jual ke dealer.
## Angka diambil dari GameState.vehicles.buy_quote() / sell_quote(), sama dengan yang dijalankan.

signal vehicle_bought(name: String)
signal vehicle_sold(name: String, net: int)

const MAX_ROWS_HEIGHT := 560.0

var _id := ""   # model yang sedang dilihat di mode beli
var _uid := -1  # unit yang sedang dilihat di mode rincian
var _from_market := false
var _method := "cash"  # "cash" | "credit"
var _dp_index := 0
var _tenor := 0
var _values: Dictionary = {}  # kunci baris rincian -> Label nilai
var _dp_label: Label
var _reqs_box: VBoxContainer
var _action: Button


# --- Showroom ----------------------------------------------------------------------------

func open_market() -> void:
	var vehicles := GameState.vehicles
	%Title.text = tr("VEHICLE_MARKET_TITLE")
	%SubtitleHolder.show()
	%Subtitle.text = tr("VEHICLE_MARKET_PILL") % [vehicles.owned.size(), vehicles.max_owned()]
	%Body.show()
	%Body.text = tr("VEHICLE_MARKET_BODY")
	_reset_rows()
	if vehicles.is_full():
		var full := _label(tr("VEHICLE_MARKET_FULL") % vehicles.max_owned(), &"SmallMutedLabel")
		full.add_theme_color_override("font_color", Palette.LOSS)
		%Rows.add_child(full)
	for c: Dictionary in vehicles.categories():
		%Rows.add_child(_label(tr(c["name"]), &"ReportHeaderLabel"))
		for d: Dictionary in vehicles.defs():
			if d["category"] == c["id"]:
				%Rows.add_child(_market_row(d))
	%Rows.add_child(_label(tr("VEHICLE_MARKET_NOTE"), &"SmallMutedLabel"))
	_clear(%Buttons)
	_add_close_button()
	_show()


func _market_row(d: Dictionary) -> Button:
	var vehicles := GameState.vehicles
	var button := Button.new()
	button.theme_type_variation = &"AssetRowButton"
	button.custom_minimum_size = Vector2(0, 88)
	button.pressed.connect(func() -> void:
		_from_market = true
		_show_buy(d["id"]))
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
	var name_label := _label(tr(d["name"]), &"AssetNameLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(name_label)
	var price := _label(Fmt.rupiah_short(vehicles.price(d["id"])), &"AssetValueLabel")
	price.autowrap_mode = TextServer.AUTOWRAP_OFF
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(price)
	box.add_child(top)
	var sub := tr("VEHICLE_MARKET_ROW") % [Fmt.rupiah_short(vehicles.base_cost(d["id"])),
		roundi(float(d["depreciation"]) * 100.0), int(d["happiness"])]
	if d.get("used", false):
		sub = tr("VEHICLE_MARKET_USED") + " · " + sub
	var sub_label := _label(sub, &"AssetSubLabel")
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sub_label)
	button.add_child(box)
	UiText.fit_to_content(button, box, 20.0)
	return button


# --- Membeli -----------------------------------------------------------------------------

func open_buy(id: String) -> void:
	_from_market = false
	_show_buy(id)


func _show_buy(id: String) -> void:
	var vehicles := GameState.vehicles
	var def := vehicles.def(id)
	_id = id
	_method = "cash"
	_dp_index = 0
	_tenor = GameState.debt.tenor_options(_loan_product())[0] if vehicles.credit_allowed(id) else 0
	%Title.text = tr("VEHICLE_BUY_TITLE") % tr(def["name"])
	%SubtitleHolder.show()
	%Subtitle.text = (tr("VEHICLE_PRICE_USED") if def.get("used", false) else tr("VEHICLE_PRICE")) % Fmt.rupiah(vehicles.price(id))
	%Body.show()
	%Body.text = tr(def["desc"])
	_clear(%Buttons)
	_action = UiText.chunky_button("", &"PrimaryButton", &"PrimaryButtonLabel", 80.0, 28)
	_action.pressed.connect(_on_buy)
	%Buttons.add_child(_action)
	if _from_market:
		var back := UiText.chunky_button(tr("PROPERTY_BACK"), &"NeutralButton", &"NeutralButtonLabel", 64.0, 24)
		back.pressed.connect(open_market)
		%Buttons.add_child(back)
	_add_close_button()
	_build_buy()
	_show()


## Isi popup beli. Dibangun ulang saat cara bayar berganti; jumlah DP & tenor cukup _refresh_buy().
func _build_buy() -> void:
	var vehicles := GameState.vehicles
	var def := vehicles.def(_id)
	var category := vehicles.category_of(_id)
	_reset_rows()
	%Rows.add_child(_label(tr("VEHICLE_OWNERSHIP"), &"ReportHeaderLabel"))
	_info_row(tr("VEHICLE_RUNNING_COST"), tr("VEHICLE_PER_MONTH") % Fmt.rupiah(vehicles.new_cost(_id)), Palette.LOSS)
	_info_row(tr("VEHICLE_DEPRECIATION"), tr("VEHICLE_PER_YEAR") % roundi(float(def["depreciation"]) * 100.0), Palette.LOSS)
	var gain := vehicles.happiness_gain(_id)
	_info_row(tr("VEHICLE_HAPPINESS"), "%+d" % gain, Palette.GAIN if gain > 0 else Palette.MUTED)
	var insurance := GameState.insurance.products_in("vehicle")
	if not insurance.is_empty():
		var premium := roundi(vehicles.price(_id) * float(insurance[0]["premium_rate"]) / 12.0 / 1000.0) * 1000
		_info_row(tr("VEHICLE_INSURANCE"), tr("VEHICLE_PER_MONTH") % Fmt.rupiah(premium), Palette.MUTED)
	%Rows.add_child(_label(tr("VEHICLE_OWNERSHIP_NOTE"), &"SmallMutedLabel"))
	var order := vehicles.count_in(category) + 1
	if vehicles.progressive_rate(order) > 0.0:
		%Rows.add_child(_label(tr("VEHICLE_PROGRESSIVE_NOTE") % [tr(vehicles.category_name(category)), order,
			UiText.percent_rate(vehicles.progressive_rate(order))], &"SmallMutedLabel"))
	if gain < int(def["happiness"]):
		var best := vehicles.best_in(category)
		%Rows.add_child(_label(tr("VEHICLE_HAPPINESS_SHARED") % [tr(vehicles.def(best["id"])["name"]),
			int(vehicles.def(best["id"])["happiness"]), gain], &"SmallMutedLabel"))
	var dream := vehicles.dream_of(_id)
	if not dream.is_empty() and float(dream["saved"]) >= 1000.0:
		%Rows.add_child(_label(tr("VEHICLE_DREAM_FUND") % [tr(GameState.dreams.find_def(dream["id"])["name"]),
			Fmt.rupiah(dream["saved"])], &"SmallMutedLabel"))

	%Rows.add_child(_label(tr("VEHICLE_PAYMENT"), &"ReportHeaderLabel"))
	if not vehicles.credit_allowed(_id):
		%Rows.add_child(_label(tr("VEHICLE_CASH_ONLY"), &"SmallMutedLabel"))
	else:
		var method_row := HBoxContainer.new()
		method_row.add_theme_constant_override("separation", 8)
		var group := ButtonGroup.new()
		for method: String in ["cash", "credit"]:
			var button := _segment(tr("VEHICLE_METHOD_" + method.to_upper()), group, method == _method)
			button.toggled.connect(func(on: bool) -> void:
				if on and _method != method:
					_method = method
					if method == "credit":
						_tenor = _affordable_tenor()
					_build_buy())
			method_row.add_child(button)
		%Rows.add_child(method_row)

	if _method == "credit":
		var prod := _loan_product()
		%Rows.add_child(_label(tr(prod["desc"]), &"SmallMutedLabel"))
		%Rows.add_child(_label(tr("VEHICLE_DP"), &"ReportHeaderLabel"))
		var stepper := HBoxContainer.new()
		stepper.add_theme_constant_override("separation", 8)
		stepper.add_child(_step_button("−", -1))
		_dp_label = _label("", &"AssetValueLabel")
		_dp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_dp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stepper.add_child(_dp_label)
		stepper.add_child(_step_button("+", 1))
		%Rows.add_child(stepper)
		%Rows.add_child(_label(tr("LOAN_TENOR"), &"ReportHeaderLabel"))
		var tenor_row := HBoxContainer.new()
		tenor_row.add_theme_constant_override("separation", 6)
		var tenor_group := ButtonGroup.new()
		for tenor: int in GameState.debt.tenor_options(prod):
			var button := _segment(tr("VEHICLE_TENOR_SHORT") % tenor, tenor_group, tenor == _tenor)
			button.toggled.connect(func(on: bool) -> void:
				if on:
					_tenor = tenor
					_refresh_buy())
			tenor_row.add_child(button)
		%Rows.add_child(tenor_row)
		%Rows.add_child(_label(tr("VEHICLE_CREDIT_DETAILS"), &"ReportHeaderLabel"))
		for key: String in ["principal", "rate", "payment", "interest", "total", "dsr"]:
			%Rows.add_child(_value_row(key, tr("VEHICLE_ROW_" + key.to_upper())))

	%Rows.add_child(_label(tr("LOAN_REQUIREMENTS"), &"ReportHeaderLabel"))
	_reqs_box = VBoxContainer.new()
	_reqs_box.add_theme_constant_override("separation", 4)
	%Rows.add_child(_reqs_box)
	%Rows.add_child(_label(tr("VEHICLE_TIP"), &"SmallMutedLabel"))
	_refresh_buy()
	_fit()


func _refresh_buy() -> void:
	var q := _quote()
	if _method == "credit":
		var loan: Dictionary = q["loan"]
		_dp_label.text = tr("VEHICLE_DP_VALUE") % [roundi(_dp_ratio() * 100.0), Fmt.rupiah(q["upfront"])]
		_values["principal"].text = Fmt.rupiah(loan["amount"])
		_values["rate"].text = tr("LOAN_RATE_VALUE") % Fmt.percent_plain(loan["rate"])
		_values["payment"].text = Fmt.rupiah(loan["payment"])
		_values["interest"].text = Fmt.rupiah(loan["interest"])
		_values["interest"].add_theme_color_override("font_color", Palette.LOSS)
		_values["total"].text = tr("VEHICLE_TOTAL_VALUE") % [Fmt.rupiah(q["total"]), Fmt.rupiah(q["extra"])]
		var dsr: float = loan["dsr"]
		_values["dsr"].text = tr("LOAN_DSR_NONE") if dsr < 0.0 else \
			tr("LOAN_DSR_VALUE") % [roundi(dsr * 100.0), roundi(float(loan["dsr_limit"]) * 100.0)]
		_values["dsr"].add_theme_color_override("font_color",
			Palette.GAIN if dsr >= 0.0 and dsr <= float(loan["dsr_limit"]) + 0.0001 else Palette.LOSS)
	UiText.fill_loan_requirements(_reqs_box, q["requirements"])
	var text := tr("VEHICLE_BUY_CASH") % Fmt.rupiah(q["price"]) if _method == "cash" \
		else tr("VEHICLE_BUY_CREDIT") % Fmt.rupiah(q["upfront"])
	_action.get_node("Content").text = text if q["ok"] else tr("LOAN_APPLY_BLOCKED")
	_set_enabled(_action, q["ok"])


# --- Rincian & menjual -------------------------------------------------------------------

func open_detail(uid: int) -> void:
	var vehicles := GameState.vehicles
	var entry := vehicles.find(uid)
	if entry.is_empty():
		close()  # sudah dijual / ditarik sebelum popup sempat tampil
		return
	_uid = uid
	var def := vehicles.def(entry["id"])
	var market_value := vehicles.value(entry)
	%Title.text = tr(def["name"])
	%SubtitleHolder.show()
	%Subtitle.text = tr("VEHICLE_VALUE_PILL") % Fmt.rupiah(market_value)
	%Body.show()
	%Body.text = tr("VEHICLE_DETAIL_BODY") % [Fmt.game_date(int(entry["since"])), Fmt.rupiah(entry["paid"])]
	_reset_rows()
	_info_row(tr("VEHICLE_ROW_VALUE"), Fmt.rupiah(market_value))
	var drop := int(entry["paid"]) - market_value
	_info_row(tr("VEHICLE_ROW_DROP"), Fmt.signed_rupiah(-drop), Palette.LOSS if drop > 0 else Palette.GAIN)
	_info_row(tr("VEHICLE_RUNNING_COST"), tr("VEHICLE_PER_MONTH") % Fmt.rupiah(vehicles.cost_of(entry)), Palette.LOSS)
	var order := vehicles.order_of(entry)
	var tax := vehicles.progressive_tax(market_value, order)
	if tax > 0:
		_info_row(tr("VEHICLE_PROGRESSIVE") % UiText.percent_rate(vehicles.progressive_rate(order)),
			tr("VEHICLE_PER_MONTH") % Fmt.rupiah(tax), Palette.LOSS)
	if vehicles.counts_happiness(entry):
		_info_row(tr("VEHICLE_HAPPINESS"), "%+d" % int(def["happiness"]), Palette.GAIN)
	else:
		var best := vehicles.best_in(vehicles.category_of(entry["id"]))
		_info_row(tr("VEHICLE_HAPPINESS"), tr("VEHICLE_HAPPINESS_COUNTED") % tr(vehicles.def(best["id"])["name"]), Palette.MUTED)
	%Rows.add_child(_label(tr("VEHICLE_DROP_NOTE") % roundi(float(def["depreciation"]) * 100.0), &"SmallMutedLabel"))
	var loan := vehicles.loan_of(entry)
	if not loan.is_empty():
		%Rows.add_child(_label(tr(GameState.debt.product(loan["product"])["name"]), &"ReportHeaderLabel"))
		_info_row(tr("LOAN_ROW_PAYMENT"), Fmt.rupiah(GameState.debt.installment(loan)))
		var status := _label(UiText.loan_status(loan), &"SmallMutedLabel")
		if int(loan["missed"]) > 0:
			status.add_theme_color_override("font_color", Palette.LOSS)
		%Rows.add_child(status)

	var q := vehicles.sell_quote(uid)
	%Rows.add_child(_label(tr("VEHICLE_SELL"), &"ReportHeaderLabel"))
	_info_row(tr("VEHICLE_ROW_SELL_PRICE") % roundi(float(vehicles.data["sell_ratio"]) * 100.0), Fmt.rupiah(q["proceeds"]))
	if int(q["payoff"]) > 0:
		_info_row(tr("VEHICLE_ROW_PAYOFF"), Fmt.signed_rupiah(-q["payoff"]), Palette.LOSS)
	_info_row(tr("VEHICLE_ROW_NET"), Fmt.signed_rupiah(q["net"]), Palette.GAIN if int(q["net"]) >= 0 else Palette.LOSS)
	if not q["ok"]:
		var short := _label(tr("VEHICLE_SELL_NO_CASH") % Fmt.rupiah(GameState.cash), &"SmallMutedLabel")
		short.add_theme_color_override("font_color", Palette.LOSS)
		%Rows.add_child(short)

	_clear(%Buttons)
	_action = UiText.chunky_button(tr("VEHICLE_SELL_BUTTON") % Fmt.signed_rupiah(q["net"]), &"DangerButton",
		&"DangerButtonLabel", 76.0, 26)
	_action.pressed.connect(_on_sell)
	_set_enabled(_action, q["ok"])
	%Buttons.add_child(_action)
	_add_close_button()
	_show()


func _quote() -> Dictionary:
	return GameState.vehicles.buy_quote(_id, _method, _dp_ratio(), _tenor)


## Tenor terpendek yang cicilannya lolos batas rasio cicilan (total bunga paling sedikit); jika tidak
## ada, tenor terpanjang.
func _affordable_tenor() -> int:
	var tenors := GameState.debt.tenor_options(_loan_product())
	for tenor: int in tenors:
		var reqs: Array = GameState.vehicles.buy_quote(_id, "credit", _dp_ratio(), tenor)["requirements"]
		if reqs.all(func(r: Dictionary) -> bool: return r["type"] != "dsr" or r["met"]):
			return tenor
	return tenors.back()


func _loan_product() -> Dictionary:
	return GameState.debt.product(GameState.vehicles.def(_id)["loan"])


func _dp_ratio() -> float:
	return float(_loan_product()["dp_steps"][_dp_index]) if _method == "credit" else 0.0


func _on_step(direction: int) -> void:
	_dp_index = clampi(_dp_index + direction, 0, _loan_product()["dp_steps"].size() - 1)
	_refresh_buy()


func _on_buy() -> void:
	var name: String = GameState.vehicles.def(_id)["name"]
	if GameState.vehicles.buy(_id, _method, _dp_ratio(), _tenor)["ok"]:
		Sfx.play("coin")
		vehicle_bought.emit(name)
		close()


func _on_sell() -> void:
	var entry := GameState.vehicles.find(_uid)
	if entry.is_empty():
		return
	var name: String = GameState.vehicles.def(entry["id"])["name"]
	var net: int = GameState.vehicles.sell_quote(_uid)["net"]
	if GameState.vehicles.sell(_uid):
		Sfx.play("coin")
		vehicle_sold.emit(name, net)
		close()


func _show() -> void:
	%Scroll.scroll_vertical = 0
	show()
	_fit()


## Tinggi area isi mengikuti isi (dibatasi), setelah label yang membungkus selesai ditata.
func _fit() -> void:
	await get_tree().process_frame
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


func _segment(text: String, group: ButtonGroup, pressed: bool) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = group
	button.theme_type_variation = &"SegmentButton"
	button.text = text
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.button_pressed = pressed
	return button


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
