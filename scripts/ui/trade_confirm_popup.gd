extends ModalPopup
## Layar konfirmasi beli/jual (v1.5a langkah 2): rincian fee & pajak, meter risiko, dan
## peringatan (profil risiko, konsentrasi, dana darurat, sisa kas, jual rugi, penalti).
## Angkanya dari GameState.portfolio.trade_quote(), sama persis dengan yang dijalankan buy()/sell().

signal trade_done(result: Dictionary)

## Warna meter risiko 1-5 (sama dengan label risiko di tab Pasar).
const RISK_COLORS := [Color("#1e7f5c"), Color("#1e7f5c"), Color("#a86a12"), Color("#c25a1e"), Color("#c2452d")]
const WARN_ICON := preload("res://assets/icons/warning_small.svg")

var _asset_id := ""
var _is_buy := true
var _amount := 0


func open(asset_id: String, is_buy: bool, amount: int) -> void:
	_asset_id = asset_id
	_is_buy = is_buy
	_amount = amount
	var q := GameState.portfolio.trade_quote(asset_id, is_buy, amount)
	var asset := GameState.market.get_asset(asset_id)
	%Title.text = tr("TRADE_TITLE_BUY" if is_buy else "TRADE_TITLE_SELL")
	%SubtitleHolder.show()
	%Subtitle.text = tr(asset.name_key)
	%Body.hide()

	_clear(%Rows)
	%Rows.add_child(_risk_meter(asset))
	if not asset.is_interest():
		_row(tr("TRADE_PRICE"), asset.price_text(), Palette.INK)
	_row(tr("TRADE_AMOUNT_BUY" if is_buy else "TRADE_AMOUNT_SELL"), Fmt.rupiah(amount), Palette.INK)
	var fee_rate := asset.buy_fee if is_buy else asset.sell_fee
	var tax_rate := asset.buy_tax if is_buy else asset.sell_tax
	if q["fee"] > 0.0:
		_row(tr("TRADE_FEE") % Fmt.percent_plain(fee_rate), Fmt.signed_rupiah(-q["fee"]), Palette.LOSS)
	if q["tax"] > 0.0:
		_row(tr("TRADE_TAX_BUY" if is_buy else "TRADE_TAX_SELL") % Fmt.percent_plain(tax_rate),
			Fmt.signed_rupiah(-q["tax"]), Palette.LOSS)
	if q["penalty"] > 0.0:
		_row(tr("TRADE_PENALTY") % Fmt.percent_plain(asset.early_penalty), Fmt.signed_rupiah(-q["penalty"]), Palette.LOSS)
	if q["fee"] + q["tax"] + q["penalty"] <= 0.0:
		%Rows.add_child(_label(tr("TRADE_NO_COSTS"), &"SmallMutedLabel"))
	var line := Panel.new()
	line.theme_type_variation = &"Divider"
	line.custom_minimum_size = Vector2(0, 2)
	%Rows.add_child(line)
	if is_buy:
		_row(tr("TRADE_NET_BUY"), Fmt.rupiah(q["net"]), Palette.INK)
		if not asset.is_interest():
			_row(tr("TRADE_UNITS"), "≈ " + Fmt.units(q["units"]), Palette.MUTED)
	else:
		_row(tr("TRADE_NET_SELL"), Fmt.rupiah(q["net"]), Palette.GAIN)
		if not asset.is_interest():
			_row(tr("TRADE_PNL"), Fmt.signed_rupiah(q["pnl"]), MonthReport.signed_color(q["pnl"]))
	for warning: Dictionary in q["warnings"]:
		%Rows.add_child(_warning(warning))

	_clear(%Buttons)
	var confirm := UiText.chunky_button(tr("TRADE_CONFIRM_BUY" if is_buy else "TRADE_CONFIRM_SELL"),
		&"PrimaryButton", &"PrimaryButtonLabel", 80.0, 30)
	confirm.pressed.connect(_on_confirm)
	%Buttons.add_child(confirm)
	var cancel := UiText.chunky_button(tr("BTN_CANCEL"), &"NeutralButton", &"NeutralButtonLabel", 68.0, 26)
	cancel.pressed.connect(close)
	%Buttons.add_child(cancel)
	show()
	_fit_scroll()


func _on_confirm() -> void:
	var result := GameState.portfolio.buy(_asset_id, _amount) if _is_buy else GameState.portfolio.sell(_asset_id, _amount)
	close()
	trade_done.emit(result)


## "Risiko" + 5 kotak (terisi sesuai level aset) + nama level, lalu batas profil risiko pemain.
func _risk_meter(asset: MarketAsset) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var name_label := _label(tr("TRADE_RISK"), &"RowLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	for i in 5:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(26, 14)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var style := StyleBoxFlat.new()
		style.bg_color = RISK_COLORS[asset.risk - 1] if i < asset.risk else Color(Palette.MUTED, 0.25)
		style.set_corner_radius_all(4)
		pip.add_theme_stylebox_override("panel", style)
		row.add_child(pip)
	var level := _label(tr("RISK_%d" % asset.risk), &"RowValueLabel")
	level.autowrap_mode = TextServer.AUTOWRAP_OFF
	level.add_theme_color_override("font_color", RISK_COLORS[asset.risk - 1])
	row.add_child(level)
	box.add_child(row)
	var profile := GameState.portfolio.risk_profile()
	box.add_child(_label(tr("TRADE_PROFILE") % [tr(profile["name"]), int(profile["max_asset_risk"])], &"SmallMutedLabel"))
	return box


func _warning(warning: Dictionary) -> PanelContainer:
	var args: Array = warning["args"]
	var text: String
	match warning["id"]:
		"risk":
			text = tr("TRADE_WARN_RISK") % tr(args[0])
		"concentration":
			text = tr("TRADE_WARN_CONCENTRATION") % Fmt.percent_plain(args[0])
		"emergency":
			text = tr("TRADE_WARN_EMERGENCY") % [Fmt.rupiah(args[0]), Fmt.rupiah(args[1])]
		"low_cash":
			text = tr("TRADE_WARN_LOW_CASH") % Fmt.rupiah(args[0])
		"penalty":
			text = tr("TRADE_WARN_PENALTY") % Fmt.game_date(args[0])
		"loss":
			text = tr("TRADE_WARN_LOSS") % Fmt.rupiah(args[0])
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"WarningBanner"
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	var icon := TextureRect.new()
	icon.texture = WARN_ICON
	icon.custom_minimum_size = Vector2(22, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(icon)
	var label := _label(text, &"WarningLabel")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)
	panel.add_child(hbox)
	return panel


func _row(name: String, value: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := _label(name, &"RowLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := _label(value, &"RowValueLabel")
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	value_label.add_theme_color_override("font_color", color)
	row.add_child(name_label)
	row.add_child(value_label)
	%Rows.add_child(row)


## Area isi di-scroll; tingginya mengikuti isi (dibatasi) setelah label selesai ditata.
func _fit_scroll() -> void:
	await get_tree().process_frame
	%Scroll.custom_minimum_size.y = minf(%Rows.get_combined_minimum_size().y, 600.0)


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
