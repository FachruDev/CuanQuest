extends ModalPopup
## Popup leverage (v2a langkah 3): membuka posisi (arah, leverage, margin, pratinjau risiko) atau
## menambah margin posisi yang sudah ada. Semua angka dari GameState.leverage.quote(), jadi yang
## tampil sama dengan yang dijalankan (mirip endpoint "preview" sebelum "checkout").

signal opened(result: Dictionary)
signal margin_added(asset_id: String, amount: int)

var _asset_id := ""
var _uid := -1  # posisi yang ditambah marginnya (mode tambah margin)
var _side := Leverage.LONG
var _lev_index := 0
var _margin_index := 0
var _margins: Array[int] = []
var _side_buttons: Dictionary = {}  # side -> Button
var _lev_value: Label
var _margin_value: Label
var _preview: VBoxContainer
var _error: Label
var _confirm: Button


## Mode buka posisi untuk aset `asset_id`.
func open(asset_id: String) -> void:
	_asset_id = asset_id
	_uid = -1
	var lev := GameState.leverage
	var asset := GameState.market.get_asset(asset_id)
	_side = Leverage.LONG
	_lev_index = 0
	_margins.assign(lev.margin_steps().filter(func(m: int) -> bool: return m >= lev.min_margin()))
	_margin_index = _default_margin_index()
	_begin(tr("LEV_OPEN_TITLE"), tr(asset.name_key), tr("LEV_OPEN_BODY"))
	%Rows.add_child(_label(tr("LEV_DIRECTION").to_upper(), &"ReportHeaderLabel"))
	var track := PanelContainer.new()  # gaya sama dengan tombol Beli/Jual di detail aset
	track.theme_type_variation = &"ModeTrack"
	var side_row := HBoxContainer.new()
	side_row.add_theme_constant_override("separation", 6)
	track.add_child(side_row)
	_side_buttons.clear()
	for side: int in [Leverage.LONG, Leverage.SHORT]:
		var button := Button.new()
		button.theme_type_variation = &"ModeButton"
		button.toggle_mode = true
		button.text = LeverageView.side_text(side)
		button.custom_minimum_size = Vector2(0, 54)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = side == Leverage.SHORT and not lev.can_short(asset_id)
		button.pressed.connect(func() -> void:
			_side = side
			_refresh())
		side_row.add_child(button)
		_side_buttons[side] = button
	%Rows.add_child(track)
	if not lev.can_short(asset_id):
		%Rows.add_child(_label(tr("LEV_LONG_ONLY"), &"SmallMutedLabel"))
	%Rows.add_child(_label(tr("LEV_LEVERAGE").to_upper(), &"ReportHeaderLabel"))
	_lev_value = _stepper(func(direction: int) -> void:
		_lev_index = clampi(_lev_index + direction, 0, lev.leverage_options(_asset_id).size() - 1)
		_refresh())
	%Rows.add_child(_label(tr("LEV_MARGIN").to_upper(), &"ReportHeaderLabel"))
	_margin_value = _stepper(func(direction: int) -> void:
		_margin_index = clampi(_margin_index + direction, 0, _margins.size() - 1)
		_refresh())
	_finish(tr("LEV_OPEN_CONFIRM"), func() -> void:
		var result := GameState.leverage.open(_asset_id, _side, _leverage(), _margins[_margin_index])
		if result["ok"]:
			close()
			opened.emit(result)
		else:
			_refresh())


## Mode tambah margin untuk posisi `uid`.
func open_margin(uid: int) -> void:
	var p := GameState.leverage.find(uid)
	if p.is_empty():
		return
	_uid = uid
	_asset_id = p["asset"]
	var asset := GameState.market.get_asset(_asset_id)
	_margins = GameState.leverage.margin_steps()
	_margin_index = _default_margin_index()
	_begin(tr("LEV_MARGIN_TITLE"), "%s · %s %dx" % [tr(asset.name_key), LeverageView.side_text(p["side"]), int(p["leverage"])],
		tr("LEV_MARGIN_BODY"))
	%Rows.add_child(_label(tr("LEV_MARGIN_ADD").to_upper(), &"ReportHeaderLabel"))
	_margin_value = _stepper(func(direction: int) -> void:
		_margin_index = clampi(_margin_index + direction, 0, _margins.size() - 1)
		_refresh())
	_finish(tr("LEV_MARGIN_CONFIRM"), func() -> void:
		var amount := _margins[_margin_index]
		if GameState.leverage.add_margin(_uid, amount)["ok"]:
			close()
			margin_added.emit(_asset_id, amount)
		else:
			_refresh())


func _begin(title: String, subtitle: String, body: String) -> void:
	%Title.text = title
	%SubtitleHolder.show()
	%Subtitle.text = subtitle
	%Body.show()
	%Body.text = body
	_clear(%Rows)


func _finish(confirm_text: String, on_confirm: Callable) -> void:
	_preview = VBoxContainer.new()
	_preview.add_theme_constant_override("separation", 6)
	%Rows.add_child(_preview)
	_error = _label("", &"InfoLabel")
	_error.add_theme_color_override("font_color", Palette.LOSS)
	%Rows.add_child(_error)
	_clear(%Buttons)
	_confirm = UiText.chunky_button(confirm_text, &"PrimaryButton", &"PrimaryButtonLabel", 80.0, 30)
	_confirm.pressed.connect(on_confirm)
	%Buttons.add_child(_confirm)
	var cancel := UiText.chunky_button(tr("BTN_CANCEL"), &"NeutralButton", &"NeutralButtonLabel", 68.0, 26)
	cancel.pressed.connect(close)
	%Buttons.add_child(cancel)
	_refresh()
	%Scroll.scroll_vertical = 0
	show()
	_fit_scroll()


## Margin awal: sekitar 10% kas (dibulatkan ke pilihan terdekat yang tidak melebihi kas).
func _default_margin_index() -> int:
	var target := maxf(GameState.cash * 0.1, 0.0)
	var best := 0
	for i in _margins.size():
		if _margins[i] <= target:
			best = i
	return best


func _leverage() -> int:
	return GameState.leverage.leverage_options(_asset_id)[_lev_index]


func _refresh() -> void:
	_clear(_preview)
	var asset := GameState.market.get_asset(_asset_id)
	_margin_value.text = Fmt.rupiah(_margins[_margin_index]) if not _margins.is_empty() else "-"
	if _uid >= 0:
		_refresh_margin(asset)
		return
	for side: int in _side_buttons:
		_side_buttons[side].button_pressed = side == _side
	_lev_value.text = "%dx" % _leverage()
	var q := GameState.leverage.quote(_asset_id, _side, _leverage(), _margins[_margin_index])
	if q.has("notional"):
		_row(tr("LEV_PRICE_NOW"), asset.price_text())
		_row(tr("LEV_SIZE"), Fmt.rupiah(q["notional"]))
		_row(tr("LEV_FEE"), Fmt.rupiah(q["fee"]))
		_row(tr("LEV_TOTAL"), Fmt.rupiah(q["total"]))
		_row(tr("LEV_FINANCING"), tr("LEV_PER_MONTH") % Fmt.rupiah(q["financing_month"]))
		_row(tr("LEV_CALL_AT"), "%s (%s)" % [asset.price_text(q["call_price"]), Fmt.percent(q["call_price"] / q["price"] - 1.0)])
		_row(tr("LEV_LIQ_AT"), "%s (%s)" % [asset.price_text(q["liquidation_price"]),
			Fmt.percent(q["liquidation_price"] / q["price"] - 1.0)], Palette.LOSS)
		for move in [0.05, 0.10]:
			var loss: float = q["loss_5"] if move == 0.05 else q["loss_10"]
			_row(tr("LEV_LOSS_IF") % ("%d%%" % roundi(move * 100.0)), "%s (%s)" % [Fmt.signed_rupiah(-loss),
				Fmt.percent(-loss / float(q["margin"]))], Palette.LOSS)
	var args: Array = q["args"]
	_error.text = "" if q["error"] == "" else (tr(q["error"]) % args if not args.is_empty() else tr(q["error"]))
	_confirm.disabled = not q["ok"]


func _refresh_margin(asset: MarketAsset) -> void:
	var lev := GameState.leverage
	var p := lev.find(_uid)
	var amount := _margins[_margin_index]
	var after := p.duplicate()
	after["margin"] = float(p["margin"]) + amount
	_row(tr("LEV_EQUITY"), Fmt.rupiah(lev.equity(p)))
	_row(tr("LEV_MARGIN"), "%s → %s" % [Fmt.rupiah(p["margin"]), Fmt.rupiah(after["margin"])])
	_row(tr("LEV_LIQ_AT"), "%s → %s" % [asset.price_text(lev.liquidation_price(p)), asset.price_text(lev.liquidation_price(after))])
	_row(tr("LEV_FINANCING"), "%s → %s" % [Fmt.rupiah(lev.monthly_financing(p)), Fmt.rupiah(lev.monthly_financing(after))])
	var enough := amount <= GameState.cash
	_error.text = "" if enough else tr("ERR_NOT_ENOUGH_CASH")
	_confirm.disabled = not enough


## Baris − nilai + ; mengembalikan label nilai.
func _stepper(on_step: Callable) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for direction: int in [-1, 1]:
		var button := Button.new()
		button.theme_type_variation = &"QuickButton"
		button.text = "−" if direction < 0 else "+"
		button.custom_minimum_size = Vector2(72, 56)
		button.pressed.connect(on_step.bind(direction))
		row.add_child(button)
	var value := _label("", &"RowValueLabel")
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	row.move_child(value, 1)
	%Rows.add_child(row)
	return value


func _row(name: String, value: String, color := Color.TRANSPARENT) -> void:
	var row := HBoxContainer.new()
	var name_label := _label(name, &"RowLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := _label(value, &"RowValueLabel")
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if color != Color.TRANSPARENT:
		value_label.add_theme_color_override("font_color", color)
	row.add_child(name_label)
	row.add_child(value_label)
	_preview.add_child(row)


## Area isi di-scroll; tingginya mengikuti isi (dibatasi) setelah label selesai ditata.
func _fit_scroll() -> void:
	await get_tree().process_frame
	%Scroll.custom_minimum_size.y = minf(%Rows.get_combined_minimum_size().y, 620.0)


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
