extends ScrollContainer
## Tab Portofolio: ringkasan kekayaan, grafik net worth, daftar kepemilikan, laporan terakhir.


func _ready() -> void:
	GameState.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var invested := GameState.investments_value()
	var cost := GameState.total_cost()
	var pnl := invested - cost

	%CashValue.text = Fmt.rupiah(GameState.cash)
	%InvestedValue.text = Fmt.rupiah(invested)
	%CostValue.text = Fmt.rupiah(cost)
	%PnlValue.text = Fmt.signed_rupiah(pnl)
	if cost > 0:
		%PnlValue.text += " (%s)" % Fmt.percent(pnl / cost)
	%PnlValue.modulate = MonthReport.color_of(pnl)

	%NetWorthChart.set_data(GameState.net_worth_history)
	_build_holdings()
	MonthReport.fill(%ReportBox, GameState.last_report)


func _build_holdings() -> void:
	for child in %HoldingsList.get_children():
		%HoldingsList.remove_child(child)
		child.queue_free()

	if GameState.holdings.is_empty():
		var empty := Label.new()
		empty.text = tr("PORT_EMPTY")
		empty.modulate = MonthReport.MUTED
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 22)
		%HoldingsList.add_child(empty)
		return

	for asset_id: String in GameState.holdings:
		%HoldingsList.add_child(_make_holding_card(asset_id))


## Satu kartu kepemilikan: nama, unit @ harga rata-rata, nilai, untung/rugi.
func _make_holding_card(asset_id: String) -> PanelContainer:
	var asset := GameState.market.get_asset(asset_id)
	var units := GameState.units_of(asset_id)
	var cost := GameState.cost_of(asset_id)
	var value := GameState.holding_value(asset_id)

	var card := PanelContainer.new()
	var box := VBoxContainer.new()
	card.add_child(box)

	var name_label := Label.new()
	name_label.text = tr(asset.name_key)
	name_label.add_theme_font_size_override("font_size", 24)
	box.add_child(name_label)

	var detail := Label.new()
	detail.text = tr("PORT_HOLDING_DETAIL") % [Fmt.number(units), Fmt.rupiah(cost / units)]
	detail.modulate = MonthReport.MUTED
	detail.add_theme_font_size_override("font_size", 20)
	box.add_child(detail)

	var row := HBoxContainer.new()
	var value_label := Label.new()
	value_label.text = Fmt.rupiah(value)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pnl_label := Label.new()
	pnl_label.text = "%s (%s)" % [Fmt.signed_rupiah(value - cost), Fmt.percent((value - cost) / cost)]
	pnl_label.modulate = MonthReport.color_of(value - cost)
	pnl_label.add_theme_font_size_override("font_size", 22)
	row.add_child(value_label)
	row.add_child(pnl_label)
	box.add_child(row)
	return card
