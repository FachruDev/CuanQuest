extends ModalPopup
## Popup "Properti" (v1.5c langkah 3), tiga mode:
## - open_market(): daftar jenis properti dengan harga, sewa, dan kenaikan harga.
## - open_buy(id): biaya beli & rutin, rencana pemakaian (dihuni / disewakan / kosong), Tunai / KPR
##   (uang muka & tenor), rincian & syarat ✓/✗.
## - open_detail(uid): nilai, pemakaian, KPR berjalan, dan jual (laku 1-3 bulan).
## Angka diambil dari GameState.properties.buy_quote() / sell_quote(), sama dengan yang dijalankan.

signal property_bought(name: String)
signal property_listed(name: String)
## Pemain mulai menghuni properti miliknya sendiri (cerita rumah pertama di main.gd).
signal moved_in

const MAX_ROWS_HEIGHT := 560.0
const USES := ["live", "rent", "empty"]

var _id := ""
var _uid := -1
var _method := "cash"  # "cash" atau id produk KPR
var _use := "live"
var _dp_index := 0
var _tenor := 0
var _from_market := false
var _values: Dictionary = {}  # kunci baris rincian -> Label nilai
var _dp_label: Label
var _reqs_box: VBoxContainer
var _action: Button


func open_market() -> void:
	var properties := GameState.properties
	%Title.text = tr("PROPERTY_MARKET_TITLE")
	%SubtitleHolder.show()
	%Subtitle.text = tr("PROPERTY_MARKET_PILL")
	%Body.show()
	%Body.text = tr("PROPERTY_MARKET_BODY")
	_reset_rows()
	for d: Dictionary in properties.defs():
		%Rows.add_child(_market_row(d))
	%Rows.add_child(_label(tr("PROPERTY_MARKET_NOTE"), &"SmallMutedLabel"))
	_clear(%Buttons)
	_add_close_button()
	_show()


func _market_row(d: Dictionary) -> Button:
	var properties := GameState.properties
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
	var price := _label(Fmt.rupiah_short(properties.price(d["id"])), &"AssetValueLabel")
	price.autowrap_mode = TextServer.AUTOWRAP_OFF
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(price)
	box.add_child(top)
	var sub := tr("PROPERTY_ROW_YIELD") % Fmt.percent_plain(d["rent_yield"]) if float(d["rent_yield"]) > 0.0 \
		else tr("PROPERTY_ROW_NO_RENT")
	sub += " · " + tr("PROPERTY_ROW_GROWTH") % Fmt.percent_plain(d["growth"])
	var sub_label := _label(sub, &"AssetSubLabel")
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sub_label)
	button.add_child(box)
	UiText.fit_to_content(button, box, 20.0)
	return button


func open_buy(id: String) -> void:
	_from_market = false
	_show_buy(id)


func _show_buy(id: String) -> void:
	var properties := GameState.properties
	var d := properties.def(id)
	_id = id
	_method = "cash"
	_dp_index = 0
	_use = "live" if d.get("livable", false) and properties.home().is_empty() else \
		("rent" if properties.can_rent(id) else ("live" if d.get("livable", false) else "empty"))
	%Title.text = tr(d["name"])
	%SubtitleHolder.show()
	%Subtitle.text = tr("PROPERTY_PRICE_PILL") % Fmt.rupiah(properties.price(id))
	%Body.show()
	%Body.text = tr(d["desc"])
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


## Isi popup beli. Dibangun ulang saat cara bayar berganti; DP, tenor & pemakaian cukup _refresh_buy().
func _build_buy() -> void:
	var properties := GameState.properties
	var d := properties.def(_id)
	_reset_rows()
	%Rows.add_child(_label(tr("PROPERTY_COSTS"), &"ReportHeaderLabel"))
	_info_row(tr("PROPERTY_BUY_COSTS") % roundi((float(properties.data["buy_tax"]) + float(properties.data["buy_fee"])) * 100.0),
		Fmt.rupiah(properties.buy_costs(_id)), Palette.LOSS)
	var running := roundi(properties.price(_id) * (float(properties.data["pbb_rate"]) + float(d["maintenance"])) / 12.0 / 1000.0) * 1000
	_info_row(tr("PROPERTY_RUNNING"), tr("VEHICLE_PER_MONTH") % Fmt.rupiah(running), Palette.LOSS)
	if properties.can_rent(_id):
		_info_row(tr("PROPERTY_RENT_NET"), tr("VEHICLE_PER_MONTH") % Fmt.rupiah(properties.rent_net(_id)), Palette.GAIN)
	if d.get("livable", false):
		_info_row(tr("PROPERTY_HAPPINESS"), "%+d" % int(d["happiness"]), Palette.GAIN)
	if int(d.get("commute_cost", 0)) > 0:  # rumah di pinggir kota
		_info_row(tr("PROPERTY_COMMUTE"), tr("VEHICLE_PER_MONTH") % Fmt.rupiah(GameState.option_cost({"cost": d["commute_cost"]})),
			Palette.LOSS)
	%Rows.add_child(_label(tr("PROPERTY_COSTS_NOTE"), &"SmallMutedLabel"))
	if int(d.get("min_hold_months", 0)) > 0:
		%Rows.add_child(_label(tr("PROPERTY_HOLD_NOTE") % (int(d["min_hold_months"]) / 12), &"SmallMutedLabel"))

	if d.get("livable", false):
		%Rows.add_child(_label(tr("PROPERTY_USE"), &"ReportHeaderLabel"))
		%Rows.add_child(_use_row(_use, func(use: String) -> void:
			_use = use
			_refresh_buy()))

	%Rows.add_child(_label(tr("VEHICLE_PAYMENT"), &"ReportHeaderLabel"))
	var method_row := HBoxContainer.new()
	method_row.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	var methods: Array = ["cash"]
	methods.append_array(d.get("loans", []))
	for method: String in methods:
		var text := tr("VEHICLE_METHOD_CASH") if method == "cash" else tr(GameState.debt.product(method)["short"])
		var button := _segment(text, group, method == _method)
		button.toggled.connect(func(on: bool) -> void:
			if on and _method != method:
				_method = method
				if method != "cash":
					_dp_index = 0
					_tenor = _affordable_tenor()
				_build_buy())
		method_row.add_child(button)
	%Rows.add_child(method_row)

	if _method != "cash":
		var prod := GameState.debt.product(_method)
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
			var button := _segment(tr("PROPERTY_TENOR_YEARS") % (tenor / 12), tenor_group, tenor == _tenor)
			button.toggled.connect(func(on: bool) -> void:
				if on:
					_tenor = tenor
					_refresh_buy())
			tenor_row.add_child(button)
		%Rows.add_child(tenor_row)
		%Rows.add_child(_label(tr("PROPERTY_KPR_DETAILS"), &"ReportHeaderLabel"))
		for key: String in ["principal", "rate", "payment", "payment_after", "interest", "dsr"]:
			%Rows.add_child(_value_row(key, tr("PROPERTY_ROW_" + key.to_upper())))
		%Rows.add_child(_label(tr("PROPERTY_FLOAT_NOTE"), &"SmallMutedLabel"))
	var fund := roundi(float(properties.dream_entry().get("saved", 0.0)))
	if fund >= 1000:
		%Rows.add_child(_label(tr("PROPERTY_DREAM_FUND") % Fmt.rupiah(fund), &"SmallMutedLabel"))
	%Rows.add_child(_label(tr("LOAN_REQUIREMENTS"), &"ReportHeaderLabel"))
	_reqs_box = VBoxContainer.new()
	_reqs_box.add_theme_constant_override("separation", 4)
	%Rows.add_child(_reqs_box)
	%Rows.add_child(_label(tr("PROPERTY_TIP"), &"SmallMutedLabel"))
	_refresh_buy()
	_fit()


func _refresh_buy() -> void:
	var q := _quote()
	if _method != "cash":
		var loan: Dictionary = q["loan"]
		_dp_label.text = tr("VEHICLE_DP_VALUE") % [roundi(_dp_ratio() * 100.0), Fmt.rupiah(q["price"] - int(loan["amount"]))]
		_values["principal"].text = Fmt.rupiah(loan["amount"])
		var fixed_months := int(loan["fixed_months"])
		_values["rate"].text = tr("PROPERTY_RATE_FIXED_YEARS") % [Fmt.percent_plain(loan["rate"]), fixed_months / 12] \
			if fixed_months > 0 else tr("LOAN_RATE_VALUE") % Fmt.percent_plain(loan["rate"])
		_values["payment"].text = Fmt.rupiah(loan["payment"])
		_values["payment_after"].get_parent().visible = fixed_months > 0
		if fixed_months > 0:
			_values["payment_after"].text = tr("PROPERTY_PAYMENT_AFTER_VALUE") % [Fmt.rupiah(loan["payment_after"]),
				Fmt.percent_plain(loan["float_rate"])]
			_values["payment_after"].add_theme_color_override("font_color", Palette.LOSS)
		_values["interest"].text = Fmt.rupiah(loan["interest"])
		_values["interest"].add_theme_color_override("font_color", Palette.LOSS)
		var dsr: float = loan["dsr"]
		_values["dsr"].text = tr("LOAN_DSR_NONE") if dsr < 0.0 else \
			tr("LOAN_DSR_VALUE") % [roundi(dsr * 100.0), roundi(float(loan["dsr_limit"]) * 100.0)]
		_values["dsr"].add_theme_color_override("font_color",
			Palette.GAIN if dsr >= 0.0 and dsr <= float(loan["dsr_limit"]) + 0.0001 else Palette.LOSS)
	UiText.fill_loan_requirements(_reqs_box, q["requirements"])
	var text := tr("VEHICLE_BUY_CASH") % Fmt.rupiah_short(q["upfront"]) if _method == "cash" \
		else tr("PROPERTY_BUY_KPR") % Fmt.rupiah_short(q["upfront"])
	_action.get_node("Content").text = text if q["ok"] else tr("LOAN_APPLY_BLOCKED")
	_set_enabled(_action, q["ok"])


func open_detail(uid: int) -> void:
	var properties := GameState.properties
	var entry := properties.find(uid)
	if entry.is_empty():
		close()  # sudah laku / dilelang sebelum popup sempat tampil
		return
	_uid = uid
	_id = entry["id"]
	var d := properties.def(_id)
	%Title.text = tr(d["name"])
	%SubtitleHolder.show()
	%Subtitle.text = tr("VEHICLE_VALUE_PILL") % Fmt.rupiah(properties.value(entry))
	%Body.show()
	%Body.text = tr("VEHICLE_DETAIL_BODY") % [Fmt.game_date(int(entry["since"])), Fmt.rupiah(entry["paid"])]
	_reset_rows()
	_info_row(tr("VEHICLE_ROW_VALUE"), Fmt.rupiah(properties.value(entry)))
	var gain := properties.value(entry) - int(entry["paid"])
	_info_row(tr("PROPERTY_ROW_GAIN"), Fmt.signed_rupiah(gain), Palette.GAIN if gain >= 0 else Palette.LOSS)
	_info_row(tr("PROPERTY_RUNNING"), tr("VEHICLE_PER_MONTH") % Fmt.rupiah(properties.cost_of(entry)), Palette.LOSS)
	%Rows.add_child(_label(UiText.property_status(entry), &"SmallMutedLabel"))
	if d.get("livable", false):
		%Rows.add_child(_label(tr("PROPERTY_USE"), &"ReportHeaderLabel"))
		%Rows.add_child(_use_row(entry["use"], func(use: String) -> void:
			if properties.set_use(_uid, use):
				open_detail(_uid)
				if use == "live":
					moved_in.emit()))
		%Rows.add_child(_label(tr("PROPERTY_USE_NOTE"), &"SmallMutedLabel"))
	var loan := properties.loan_of(entry)
	if not loan.is_empty():
		%Rows.add_child(_label(tr(GameState.debt.product(loan["product"])["name"]), &"ReportHeaderLabel"))
		var fixed_until := int(loan["fixed_until"])
		var rate_text := tr("LOAN_RATE_VALUE") % Fmt.percent_plain(loan["rate"])
		if fixed_until >= 0:
			rate_text = tr("PROPERTY_RATE_FIXED_UNTIL") % [Fmt.percent_plain(loan["rate"]), Fmt.game_date(fixed_until)] \
				if GameState.month < fixed_until else tr("PROPERTY_RATE_FLOATING") % Fmt.percent_plain(loan["rate"])
		_info_row(tr("LOAN_ROW_RATE"), rate_text)
		_info_row(tr("LOAN_ROW_PAYMENT"), Fmt.rupiah(GameState.debt.installment(loan)))
		var status := _label(UiText.loan_status(loan), &"SmallMutedLabel")
		if int(loan["missed"]) > 0:
			status.add_theme_color_override("font_color", Palette.LOSS)
		%Rows.add_child(status)

	var q := properties.sell_quote(entry)
	%Rows.add_child(_label(tr("PROPERTY_SELL"), &"ReportHeaderLabel"))
	_info_row(tr("PROPERTY_ROW_SELL_PRICE"), Fmt.rupiah(q["price"]))
	_info_row(tr("PROPERTY_ROW_SELL_TAX") % Fmt.percent_plain(properties.data["sell_tax"]), Fmt.signed_rupiah(-q["tax"]), Palette.LOSS)
	_info_row(tr("PROPERTY_ROW_SELL_FEE") % Fmt.percent_plain(properties.data["sell_fee"]), Fmt.signed_rupiah(-q["fee"]), Palette.LOSS)
	if int(q["payoff"]) > 0:
		_info_row(tr("VEHICLE_ROW_PAYOFF"), Fmt.signed_rupiah(-q["payoff"]), Palette.LOSS)
	_info_row(tr("VEHICLE_ROW_NET"), Fmt.signed_rupiah(q["net"]), Palette.GAIN if int(q["net"]) >= 0 else Palette.LOSS)
	var selling := int(entry["selling_left"]) > 0
	%Rows.add_child(_label(tr("PROPERTY_SELLING") % int(entry["selling_left"]) if selling
		else tr("PROPERTY_SELL_NOTE") % [int(properties.data["sell_months"][0]), int(properties.data["sell_months"][1])],
		&"SmallMutedLabel"))
	if not q["ok"] and not selling:
		var short := _label(tr("PROPERTY_SELL_LOCKED") % Fmt.game_date(properties.sellable_from(entry)) if q["locked"]
			else tr("VEHICLE_SELL_NO_CASH") % Fmt.rupiah(GameState.cash), &"SmallMutedLabel")
		short.add_theme_color_override("font_color", Palette.LOSS)
		%Rows.add_child(short)

	_clear(%Buttons)
	if selling:
		_action = UiText.chunky_button(tr("PROPERTY_CANCEL_SALE"), &"NeutralButton", &"NeutralButtonLabel", 72.0, 26)
		_action.pressed.connect(func() -> void:
			properties.cancel_sale(_uid)
			open_detail(_uid))
	else:
		_action = UiText.chunky_button(tr("PROPERTY_LIST_BUTTON"), &"DangerButton", &"DangerButtonLabel", 76.0, 26)
		_action.pressed.connect(_on_list)
		_set_enabled(_action, q["ok"])
	%Buttons.add_child(_action)
	_add_close_button()
	_show()


## Tombol pemakaian (Dihuni / Disewakan / Kosong) sesuai jenis properti.
func _use_row(current: String, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for use: String in USES:
		if use == "rent" and not GameState.properties.can_rent(_id):
			continue
		var button := _segment(tr("PROPERTY_USE_" + use.to_upper()), group, use == current)
		button.toggled.connect(func(on: bool) -> void:
			if on:
				on_pick.call(use))
		row.add_child(button)
	return row


func _quote() -> Dictionary:
	return GameState.properties.buy_quote(_id, _method, _dp_ratio(), _tenor)


func _dp_ratio() -> float:
	if _method == "cash":
		return 0.0
	return float(GameState.debt.product(_method)["dp_steps"][_dp_index])


## Tenor terpendek yang cicilannya lolos batas rasio cicilan; jika tidak ada, tenor terpanjang.
func _affordable_tenor() -> int:
	var tenors := GameState.debt.tenor_options(GameState.debt.product(_method))
	for tenor: int in tenors:
		var reqs: Array = GameState.properties.buy_quote(_id, _method, _dp_ratio(), tenor)["requirements"]
		if reqs.all(func(r: Dictionary) -> bool: return r["type"] != "dsr" or r["met"]):
			return tenor
	return tenors.back()


func _on_step(direction: int) -> void:
	_dp_index = clampi(_dp_index + direction, 0, GameState.debt.product(_method)["dp_steps"].size() - 1)
	_refresh_buy()


func _on_buy() -> void:
	var name: String = GameState.properties.def(_id)["name"]
	if GameState.properties.buy(_id, _method, _dp_ratio(), _tenor, _use)["ok"]:
		Sfx.play("coin")
		property_bought.emit(name)
		close()


func _on_list() -> void:
	var name: String = GameState.properties.def(_id)["name"]
	if GameState.properties.list_for_sale(_uid):
		property_listed.emit(name)
		open_detail(_uid)


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
	var close_button := UiText.chunky_button(tr("BTN_CLOSE"), &"NeutralButton", &"NeutralButtonLabel", 64.0, 24)
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
