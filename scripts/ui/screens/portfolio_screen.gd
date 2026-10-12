extends ScrollContainer
## Tab Portofolio: ringkasan kekayaan, grafik net worth, alokasi aset, daftar kepemilikan,
## laporan terakhir, riwayat transaksi.

const TX_SHOWN := 30
## Warna per kelas aset untuk grafik alokasi (urutan = urutan legenda).
const CLASS_COLORS := {
	"cash": Color("#95a5a6"), "savings": Color("#5dade2"), "deposit": Color("#48c9b0"),
	"mutual_fund": Color("#f4d03f"), "stock": Color("#eb984e"), "crypto": Color("#af7ac5"),
}


func _ready() -> void:
	UiText.build_period_buttons(%PeriodRow, %NetWorthChart, 0)
	GameState.changed.connect(_refresh)
	visibility_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if not is_visible_in_tree():
		return
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
	_build_allocation()
	_build_holdings()
	MonthReport.fill(%ReportBox, GameState.last_report)
	_build_transactions()


## Donat alokasi per kelas aset (kas termasuk) + legenda dengan persentase.
func _build_allocation() -> void:
	var totals := {"cash": maxf(GameState.cash, 0.0)}
	for asset_id: String in GameState.holdings:
		var asset_class: String = GameState.market.get_asset(asset_id).asset_class
		totals[asset_class] = totals.get(asset_class, 0.0) + GameState.holding_value(asset_id)
	var grand_total := 0.0
	for value: float in totals.values():
		grand_total += value

	var slices: Array[Dictionary] = []
	_clear(%AllocLegend)
	for asset_class: String in CLASS_COLORS:
		var value: float = totals.get(asset_class, 0.0)
		if value <= 0:
			continue
		slices.append({"label": asset_class, "value": value, "color": CLASS_COLORS[asset_class]})
		var label := Label.new()
		var name_key := "LBL_CASH" if asset_class == "cash" else "CLASS_" + asset_class.to_upper()
		label.text = "%s  %s" % [tr(name_key).capitalize(), Fmt.percent_plain(value / grand_total)]
		label.modulate = CLASS_COLORS[asset_class]
		label.add_theme_font_size_override("font_size", 21)
		%AllocLegend.add_child(label)
	%AllocationChart.set_slices(slices)

	# Peringatan konsentrasi (GDD 5.8): satu aset > 70% dari investasi.
	var share := EndAnalysis.largest_holding_share(GameState)
	if share > 0.7 and GameState.investments_value() > 5_000_000:
		var warning := Label.new()
		warning.text = tr("PORT_CONCENTRATION_WARNING") % Fmt.percent_plain(share)
		warning.modulate = MonthReport.RED
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warning.add_theme_font_size_override("font_size", 18)
		%AllocLegend.add_child(warning)


func _build_transactions() -> void:
	_clear(%TxList)
	if GameState.transactions.is_empty():
		var empty := Label.new()
		empty.text = tr("TX_EMPTY")
		empty.modulate = MonthReport.MUTED
		empty.add_theme_font_size_override("font_size", 20)
		%TxList.add_child(empty)
		return
	for i in mini(TX_SHOWN, GameState.transactions.size()):
		var t: Dictionary = GameState.transactions[i]
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 19)
		label.text = tr("TX_ROW") % [Fmt.game_date(t["month"]), tr("TX_" + str(t["kind"]).to_upper()),
			tr(t["asset_key"]), Fmt.rupiah(t["amount"]), Fmt.rupiah(t["fee"])]
		if t["kind"] != "buy":
			label.text += " | " + tr("TX_PNL") % Fmt.signed_rupiah(t["pnl"])
			label.modulate = MonthReport.color_of(t["pnl"])
		%TxList.add_child(label)


func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


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
	if asset.is_interest():
		detail.text = tr("FMT_RATE_PA") % Fmt.percent_plain(GameState.market.rate_for(asset))
		if GameState.is_locked(asset_id):
			detail.text += " | " + tr("LBL_LOCKED_UNTIL") % Fmt.game_date(GameState.locked_until(asset_id))
	else:
		detail.text = tr("PORT_HOLDING_DETAIL") % [Fmt.units(units), asset.price_text(cost / units)]
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
