extends ScrollContainer
## Tab Portofolio (tema "Senja Cuan"): ringkasan kekayaan, grafik net worth, neraca (aset - utang),
## alokasi aset, daftar kepemilikan, laporan terakhir, riwayat transaksi.

const TX_SHOWN := 30
## Warna per kelas aset untuk grafik alokasi (urutan = urutan legenda).
const CLASS_COLORS := {
	"cash": Color("#b5a089"), "savings": Color("#4a6fb0"), "deposit": Color("#23877b"),
	"mutual_fund": Color("#f6b93b"), "stock": Color("#f07a5f"), "crypto": Color("#7a4fb0"),
	"commodity": Color("#9c6b30"),
}
## Chip jenis transaksi: beli hijau, jual emas, jual paksa/panik merah.
const TX_CHIPS := {"buy": &"MoodGreen", "auto": &"MoodGreen", "sell": &"MoodGold", "forced": &"MoodRed", "panic": &"MoodRed",
	"stop_loss": &"MoodRed", "take_profit": &"MoodGreen"}
const BUY_KINDS := ["buy", "auto"]  # transaksi beli tidak punya untung/rugi terealisasi

var _sheet_box: VBoxContainer  # isi kartu Neraca (v1.5c langkah 4)
var _render: Dictionary = {}  # kunci data terakhir per bagian (UiText.changed_key)


func _ready() -> void:
	UiText.build_period_buttons(%PeriodRow, %NetWorthChart, 0)
	_build_sheet_card()
	GameState.changed.connect(_refresh)
	visibility_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	var invested := GameState.portfolio.investments_value()
	var cost := GameState.portfolio.total_cost()
	var pnl := invested - cost

	%CashValue.text = Fmt.rupiah(GameState.cash)
	%CashValue.add_theme_color_override("font_color", Palette.LOSS if GameState.cash < 0 else Palette.INK)
	%InvestedValue.text = Fmt.rupiah(invested)
	%CostValue.text = Fmt.rupiah(cost)
	%PnlValue.text = Fmt.signed_rupiah(pnl)
	if cost > 0:
		%PnlValue.text += " (%s)" % Fmt.percent(pnl / cost)
	var pnl_color := MonthReport.signed_color(pnl)
	%PnlValue.add_theme_color_override("font_color", pnl_color)
	%PnlName.add_theme_color_override("font_color", pnl_color if pnl != 0 else Palette.MUTED)
	%PnlTile.theme_type_variation = &"StatTileNegative" if pnl < 0 else (&"StatTilePositive" if pnl > 0 else &"StatTile")

	%NetWorthChart.set_data(GameState.net_worth_history)
	BalanceSheet.fill(_sheet_box, GameState.balance_sheet())
	_build_allocation()
	var base := [GameState.run_id, GameState.month, Fmt.compact]
	if UiText.changed_key(_render, "holdings", base + [GameState.portfolio.holdings, GameState.portfolio.orders,
			GameState.portfolio.risk_profile_id]):
		_build_holdings()
	if UiText.changed_key(_render, "report", base + [GameState.last_report.get("to_month", -1), GameState.last_report.size()]):
		MonthReport.fill(%ReportBox, GameState.last_report)
	var txs := GameState.portfolio.transactions
	if UiText.changed_key(_render, "tx", base + [txs.size(), txs[0] if not txs.is_empty() else {}]):
		_build_transactions()


## Judul + kartu Neraca disisipkan setelah grafik kekayaan bersih.
func _build_sheet_card() -> void:
	var page: VBoxContainer = $VBox
	var index := page.get_node("Gap2").get_index()
	var title := _label(tr("SHEET_TITLE"), &"SubSectionLabel")
	var card := PanelContainer.new()
	card.theme_type_variation = &"HomeCard"
	_sheet_box = VBoxContainer.new()
	_sheet_box.add_theme_constant_override("separation", 8)
	card.add_child(_sheet_box)
	page.add_child(title)
	page.move_child(title, index)
	page.add_child(card)
	page.move_child(card, index + 1)


## Donat alokasi per kelas aset (kas termasuk) + legenda dengan persentase.
func _build_allocation() -> void:
	var totals := {"cash": maxf(GameState.cash, 0.0)}
	for asset_id: String in GameState.portfolio.holdings:
		var asset_class: String = GameState.market.get_asset(asset_id).asset_class
		totals[asset_class] = totals.get(asset_class, 0.0) + GameState.portfolio.holding_value(asset_id)
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
		var name_key := "LBL_CASH" if asset_class == "cash" else "CLASS_" + asset_class.to_upper()
		%AllocLegend.add_child(_legend_row(CLASS_COLORS[asset_class], tr(name_key).capitalize(),
				Fmt.percent_plain(value / grand_total)))
	%AllocationChart.set_slices(slices)
	if slices.is_empty():
		%AllocLegend.add_child(_label(tr("ALLOC_EMPTY"), &"MutedLabel"))

	# Peringatan konsentrasi (GDD 5.8): satu aset > 70% dari investasi.
	var share := EndAnalysis.largest_holding_share(GameState)
	var concentrated := share > 0.7 and GameState.portfolio.investments_value() > 5_000_000
	%ConcentrationWarning.visible = concentrated
	if concentrated:
		%ConcentrationLabel.text = tr("PORT_CONCENTRATION_WARNING") % Fmt.percent_plain(share)


## Satu baris legenda: kotak warna, nama kelas, persentase.
func _legend_row(color: Color, text: String, percent: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var swatch := Panel.new()
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	swatch.add_theme_stylebox_override("panel", style)
	var name_label := _label(text, &"RowLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(swatch)
	row.add_child(name_label)
	row.add_child(_label(percent, &"RowValueLabel"))
	return row


## Riwayat transaksi: chip jenis | nama aset + tanggal & fee | nominal. Dipisah garis tipis.
func _build_transactions() -> void:
	_clear(%TxList)
	if GameState.portfolio.transactions.is_empty():
		%TxList.add_child(_label(tr("TX_EMPTY"), &"MutedLabel"))
		return
	for i in mini(TX_SHOWN, GameState.portfolio.transactions.size()):
		var t: Dictionary = GameState.portfolio.transactions[i]
		var kind := str(t["kind"])
		if i > 0:
			var line := Panel.new()
			line.theme_type_variation = &"Divider"
			line.custom_minimum_size = Vector2(0, 2)
			%TxList.add_child(line)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var chip := PanelContainer.new()
		chip.theme_type_variation = TX_CHIPS.get(kind, &"MoodNeutral")
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(_label(tr("TX_" + kind.to_upper()), &"MoodLabel"))

		var middle := VBoxContainer.new()
		middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		middle.add_theme_constant_override("separation", 0)
		var name_label := _label(tr(t["asset_key"]), &"AssetNameLabel")
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var tax := float(t.get("tax", 0.0))
		var meta_text := tr("TX_META") % [Fmt.game_date(t["month"]), Fmt.rupiah(t["fee"])]
		if tax > 0.0:
			meta_text = tr("TX_META_TAX") % [Fmt.game_date(t["month"]), Fmt.rupiah(t["fee"]), Fmt.rupiah(tax)]
		var meta := _label(meta_text, &"SmallMutedLabel")
		meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		middle.add_child(name_label)
		middle.add_child(meta)
		if kind not in BUY_KINDS:
			var pnl := _label(tr("TX_PNL") % Fmt.signed_rupiah(t["pnl"]), &"AssetSubLabel")
			pnl.add_theme_color_override("font_color", MonthReport.signed_color(t["pnl"]))
			middle.add_child(pnl)

		var amount := _label(Fmt.rupiah(t["amount"]), &"AssetValueLabel")
		amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)
		row.add_child(middle)
		row.add_child(amount)
		%TxList.add_child(row)


func _build_holdings() -> void:
	_clear(%HoldingsList)
	if GameState.portfolio.holdings.is_empty():
		var empty := _label(tr("PORT_EMPTY"), &"MutedLabel")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		%HoldingsList.add_child(empty)
		return
	for asset_id: String in GameState.portfolio.holdings:
		%HoldingsList.add_child(_make_holding_card(asset_id))


## Satu kartu kepemilikan: ikon kelas | nama + unit @ harga rata-rata | nilai + untung/rugi.
func _make_holding_card(asset_id: String) -> PanelContainer:
	var asset := GameState.market.get_asset(asset_id)
	var units := GameState.portfolio.units_of(asset_id)
	var cost := GameState.portfolio.cost_of(asset_id)
	var value := GameState.portfolio.holding_value(asset_id)

	var card := PanelContainer.new()
	card.theme_type_variation = &"HomeCard"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	row.add_child(UiText.class_tile(asset.asset_class, 44.0))

	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 0)
	var name_label := _label(tr(asset.name_key), &"AssetNameLabel")
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	middle.add_child(name_label)
	var detail_text: String
	if asset.is_interest():
		detail_text = tr("FMT_RATE_PA") % Fmt.percent_plain(GameState.market.rate_for(asset))
		if GameState.portfolio.is_locked(asset_id):
			detail_text += " | " + tr("LBL_LOCKED_UNTIL") % Fmt.game_date(GameState.portfolio.locked_until(asset_id))
	else:
		detail_text = tr("PORT_HOLDING_DETAIL") % [Fmt.units(units), asset.price_text(cost / units)]
	var detail := _label(detail_text, &"SmallMutedLabel")
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	middle.add_child(detail)
	row.add_child(middle)

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 0)
	var value_label := _label(Fmt.rupiah(value), &"AssetValueLabel")
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var pnl_label := _label("%s (%s)" % [Fmt.signed_rupiah(value - cost), Fmt.percent((value - cost) / cost)],
			&"AssetSubLabel")
	pnl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pnl_label.add_theme_color_override("font_color", MonthReport.signed_color(value - cost))
	right.add_child(value_label)
	right.add_child(pnl_label)
	row.add_child(right)
	return card


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label


func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
