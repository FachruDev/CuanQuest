extends ModalPopup
## Popup stop loss & take profit (v1.5a langkah 4) untuk satu aset yang dimiliki.
## Batas dipilih sebagai jarak (persen) dari harga sekarang; yang disimpan adalah harga batasnya.
## Pesanan dicek setiap hari saat pasar bergerak (GameState._execute_orders).

var _asset_id := ""
var _index := {"stop_loss": 0, "take_profit": 0}  # indeks pilihan di economy.json "orders"
var _values: Dictionary = {}     # "stop_loss"/"take_profit" -> Label nilai
var _estimates: Dictionary = {}  # "stop_loss"/"take_profit" -> Label perkiraan hasil


func open(asset_id: String) -> void:
	_asset_id = asset_id
	var asset := GameState.market.get_asset(asset_id)
	var cfg := GameState.orders_config()
	var order := GameState.order_of(asset_id)
	if order.is_empty():
		_index["stop_loss"] = _nearest(cfg["stop_loss_steps"], cfg["default_stop_loss"])
		_index["take_profit"] = _nearest(cfg["take_profit_steps"], cfg["default_take_profit"])
	else:
		var sl := float(order["stop_loss"])
		var tp := float(order["take_profit"])
		_index["stop_loss"] = _nearest(cfg["stop_loss_steps"], 1.0 - sl / asset.price if sl > 0.0 else 0.0)
		_index["take_profit"] = _nearest(cfg["take_profit_steps"], tp / asset.price - 1.0 if tp > 0.0 else 0.0)

	%Title.text = tr("ORDER_TITLE")
	%SubtitleHolder.show()
	%Subtitle.text = tr(asset.name_key)
	%Body.show()
	%Body.text = tr("ORDER_BODY")
	_clear(%Rows)
	_values.clear()
	_estimates.clear()
	_row(tr("ORDER_PRICE_NOW"), asset.price_text())
	_row(tr("ORDER_HOLDING"), Fmt.rupiah(GameState.holding_value(asset_id)))
	for kind: String in ["stop_loss", "take_profit"]:
		%Rows.add_child(_label(tr("ORDER_" + kind.to_upper()).to_upper(), &"ReportHeaderLabel"))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_step_button("−", kind, -1))
		var value := _label("", &"RowValueLabel")
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(value)
		row.add_child(_step_button("+", kind, 1))
		%Rows.add_child(row)
		_values[kind] = value
		%Rows.add_child(_label(tr("ORDER_" + ("SL" if kind == "stop_loss" else "TP") + "_NOTE"), &"SmallMutedLabel"))
		var estimate := _label("", &"InfoLabel")
		%Rows.add_child(estimate)
		_estimates[kind] = estimate
	_refresh()

	_clear(%Buttons)
	var save := UiText.chunky_button(tr("ORDER_SAVE"), &"PrimaryButton", &"PrimaryButtonLabel", 80.0, 30)
	save.pressed.connect(func() -> void:
		GameState.set_order(_asset_id, _limit_price("stop_loss"), _limit_price("take_profit"))
		close())
	%Buttons.add_child(save)
	if not order.is_empty():
		var remove := UiText.chunky_button(tr("ORDER_REMOVE"), &"DangerButton", &"DangerButtonLabel", 68.0, 26)
		remove.pressed.connect(func() -> void:
			GameState.set_order(_asset_id, 0.0, 0.0)
			close())
		%Buttons.add_child(remove)
	var close_button := UiText.chunky_button(tr("BTN_CLOSE"), &"NeutralButton", &"NeutralButtonLabel", 68.0, 26)
	close_button.pressed.connect(close)
	%Buttons.add_child(close_button)
	%Scroll.scroll_vertical = 0
	show()
	_fit_scroll()


func _refresh() -> void:
	var asset := GameState.market.get_asset(_asset_id)
	for kind: String in ["stop_loss", "take_profit"]:
		var distance := _distance(kind)
		var price := _limit_price(kind)
		if price <= 0.0:
			_values[kind].text = tr("ORDER_OFF")
			_estimates[kind].text = ""
			continue
		var direction := -1.0 if kind == "stop_loss" else 1.0
		_values[kind].text = tr("ORDER_VALUE") % [Fmt.percent(direction * distance), asset.price_text(price)]
		var units := GameState.units_of(_asset_id)
		var quote := GameState.trade_quote(_asset_id, false, ceili(units * price), price)
		_estimates[kind].text = tr("ORDER_ESTIMATE") % [Fmt.rupiah(quote["net"]), Fmt.signed_rupiah(quote["pnl"])]


func _distance(kind: String) -> float:
	var steps: Array = GameState.orders_config()[kind + "_steps"]
	return float(steps[_index[kind]])


## Harga batas per unit dari pilihan jarak (0 = mati).
func _limit_price(kind: String) -> float:
	var distance := _distance(kind)
	if distance <= 0.0:
		return 0.0
	var price := GameState.market.get_asset(_asset_id).price
	return price * (1.0 - distance) if kind == "stop_loss" else price * (1.0 + distance)


func _step_button(text: String, kind: String, direction: int) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"QuickButton"
	button.text = text
	button.custom_minimum_size = Vector2(72, 56)
	button.pressed.connect(func() -> void:
		var count: int = GameState.orders_config()[kind + "_steps"].size()
		_index[kind] = clampi(_index[kind] + direction, 0, count - 1)
		_refresh())
	return button


static func _nearest(steps: Array, value: float) -> int:
	var best := 0
	for i in steps.size():
		if absf(float(steps[i]) - value) < absf(float(steps[best]) - value):
			best = i
	return best


func _row(name: String, value: String) -> void:
	var row := HBoxContainer.new()
	var name_label := _label(name, &"RowLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := _label(value, &"RowValueLabel")
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(name_label)
	row.add_child(value_label)
	%Rows.add_child(row)


## Area isi di-scroll; tingginya mengikuti isi (dibatasi) setelah label selesai ditata.
func _fit_scroll() -> void:
	await get_tree().process_frame
	%Scroll.custom_minimum_size.y = minf(%Rows.get_combined_minimum_size().y, 560.0)


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
