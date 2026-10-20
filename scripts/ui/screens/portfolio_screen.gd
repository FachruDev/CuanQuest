extends VBoxContainer
## Tab Portofolio v2 (tema "Senja Cuan"): tiga bagian lewat tombol segmen di atas (dulu ±10 layar gulir).
## - Ringkasan : kekayaan bersih + grafik, nilai investasi & untung/rugi, alokasi (batang), neraca ringkas
## - Aset      : kepemilikan per kelas aset (ketuk = detail di Pasar), posisi leverage, dana kelolaan
## - Riwayat   : laporan bulan lalu dalam 4 arus uang (+ laporan lengkap), transaksi per bulan dengan
##               saringan; autodebet satu bulan dilipat jadi satu baris

signal fund_requested  # tombol Kelola Dana (v2c)
signal asset_requested(asset_id: String)  # kepemilikan diketuk: buka detail aset di tab Pasar
signal report_requested  # "Lihat laporan lengkap": popup laporan bulan terakhir
signal popup_requested(title: String, blocks: Array)  # rincian neraca (InfoPopup.open_rich)

enum Page { SUMMARY, ASSETS, HISTORY }
const PAGE_KEYS: Array[String] = ["PORT_SEG_SUMMARY", "PORT_SEG_ASSETS", "PORT_SEG_HISTORY"]
## Warna per kelas aset (urutan = urutan legenda & kelompok kepemilikan).
const CLASS_COLORS := {
	"cash": Color("#b5a089"), "savings": Color("#4a6fb0"), "deposit": Color("#23877b"),
	"mutual_fund": Color("#f6b93b"), "stock": Color("#f07a5f"), "crypto": Color("#7a4fb0"),
	"commodity": Color("#9c6b30"), "forex": Color("#2f9fb5"),
}
## Chip jenis transaksi: beli hijau, jual emas, jual paksa/panik merah.
const TX_CHIPS := {"buy": &"MoodGreen", "auto": &"MoodGreen", "sell": &"MoodGold", "forced": &"MoodRed", "panic": &"MoodRed",
	"stop_loss": &"MoodRed", "take_profit": &"MoodGreen",
	"lev_open": &"MoodGold", "lev_close": &"MoodGold", "lev_liquidated": &"MoodRed", "lev_forced": &"MoodRed"}
const BUY_KINDS := ["buy", "auto", "lev_open"]  # transaksi beli/buka posisi tidak punya untung/rugi terealisasi
## Saringan riwayat transaksi: id -> jenis transaksi yang ikut ([] = semua).
const TX_FILTERS := {"all": [], "buy": ["buy", "auto"], "sell": ["sell", "forced", "panic", "stop_loss", "take_profit"],
	"lev": ["lev_open", "lev_close", "lev_liquidated", "lev_forced"]}
const MONTHS_STEP := 3  # jumlah bulan riwayat yang ditambahkan per ketukan "Tampilkan ..."
const FUND_ICON := "res://assets/icons/classes/mutual_fund.svg"
const DEBT_GREEN := Color("#3fb8a2")
const DEBT_RED := Color("#e0644a")

var _page := Page.SUMMARY
var _segments: Array[Button] = []
var _pages: Array[VBoxContainer] = []
var _render: Dictionary = {}  # kunci data terakhir per bagian (UiText.changed_key)

# --- Ringkasan
var _worth_label: Label
var _worth_chip: PanelContainer
var _worth_chip_label: Label
var _chart: PriceChart
var _invest_value: Label
var _invest_sub: Label
var _pnl_tile: PanelContainer
var _pnl_caps: Label
var _pnl_value: Label
var _pnl_sub: Label
var _alloc_bar: FlowBar
var _alloc_legend: GridContainer
var _concentration: VBoxContainer
var _sheet_box: VBoxContainer

# --- Riwayat
var _report_caps: Label
var _report_box: VBoxContainer
var _filter_row: HBoxContainer
var _filter := "all"
var _months_shown := MONTHS_STEP
var _expanded: Dictionary = {}  # bulan -> true (baris autodebet yang dibuka)
var _tx_box: VBoxContainer


func _ready() -> void:
	_pages = [%Summary, %Assets, %History]
	_build_segments()
	_build_summary()
	_build_history()
	GameState.changed.connect(_refresh)
	visibility_changed.connect(_refresh)
	show_page(Page.SUMMARY)


func show_page(page: int) -> void:
	_page = page
	for i in _pages.size():
		_pages[i].visible = i == page
		_segments[i].set_pressed_no_signal(i == page)
	%Scroll.scroll_vertical = 0
	_refresh()


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	match _page:
		Page.SUMMARY:
			_refresh_summary()
		Page.ASSETS:
			_refresh_assets()
		Page.HISTORY:
			_refresh_history()


func _build_segments() -> void:
	var group := ButtonGroup.new()
	for i in PAGE_KEYS.size():
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = &"SegmentButton"
		button.text = tr(PAGE_KEYS[i])
		button.add_theme_font_size_override("font_size", 20)
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(show_page.bind(i))
		%Segments.get_node("Row").add_child(button)
		_segments.append(button)


# ==================================================================================================
# Ringkasan
# ==================================================================================================

func _build_summary() -> void:
	var page: VBoxContainer = %Summary
	var hero := _card(12)
	var hero_box: VBoxContainer = hero.get_child(0)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	texts.add_child(_label(tr("SHEET_NET_WORTH").to_upper(), &"TileCapsLabel"))
	_worth_label = _label("", &"TileValueLabel")
	_worth_label.add_theme_font_size_override("font_size", 32)
	texts.add_child(_worth_label)
	head.add_child(texts)
	_worth_chip_label = _label("", &"MoodLabel")
	_worth_chip = _chip_with(_worth_chip_label, &"MoodGreen")
	_worth_chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(_worth_chip)
	hero_box.add_child(head)
	_chart = PriceChart.new()
	_chart.light_style = true
	_chart.max_points = 600
	_chart.custom_minimum_size = Vector2(0, 160)
	hero_box.add_child(_chart)
	var periods := HBoxContainer.new()
	periods.add_theme_constant_override("separation", 8)
	UiText.build_period_buttons(periods, _chart, 0)
	hero_box.add_child(periods)
	page.add_child(hero)

	var tiles := GridContainer.new()
	tiles.columns = 2
	tiles.add_theme_constant_override("h_separation", 12)
	tiles.add_theme_constant_override("v_separation", 12)
	var invest := _tile(tr("PORT_INVESTED"))
	_invest_value = invest[1]
	_invest_sub = invest[2]
	tiles.add_child(invest[0])
	var pnl := _tile(tr("PORT_PNL"))
	_pnl_tile = pnl[0]
	_pnl_value = pnl[1]
	_pnl_sub = pnl[2]
	_pnl_caps = pnl[3]
	tiles.add_child(_pnl_tile)
	page.add_child(tiles)

	page.add_child(_label(tr("PORT_ALLOCATION"), &"SubSectionLabel"))
	var alloc := _card(14)
	var alloc_box: VBoxContainer = alloc.get_child(0)
	_alloc_bar = FlowBar.new()
	_alloc_bar.custom_minimum_size = Vector2(0, 28)
	alloc_box.add_child(_alloc_bar)
	_alloc_legend = GridContainer.new()
	_alloc_legend.columns = 2
	_alloc_legend.add_theme_constant_override("h_separation", 24)
	_alloc_legend.add_theme_constant_override("v_separation", 8)
	alloc_box.add_child(_alloc_legend)
	page.add_child(alloc)
	_concentration = VBoxContainer.new()
	page.add_child(_concentration)

	page.add_child(_label(tr("SHEET_TITLE"), &"SubSectionLabel"))
	var sheet := _card(12)
	_sheet_box = sheet.get_child(0)
	page.add_child(sheet)


func _refresh_summary() -> void:
	var worth := GameState.net_worth()
	var history := GameState.net_worth_history
	var portfolio := GameState.portfolio
	var key := [GameState.run_id, GameState.month, Fmt.compact, roundi(worth), roundi(GameState.cash), history.size(),
		portfolio.holdings, GameState.debt.outstanding(), GameState.leverage.positions.size()]
	if not UiText.changed_key(_render, "summary", key):
		return
	_worth_label.text = Fmt.rupiah(worth)
	_worth_label.add_theme_color_override("font_color", Palette.LOSS if worth < 0 else Palette.INK)
	var before := float(history[-2]) if history.size() >= 2 else 0.0
	_worth_chip.visible = before > 0.0
	if before > 0.0:
		var change := float(history[-1]) / before - 1.0
		_worth_chip_label.text = tr("PORT_LAST_MONTH_CHIP") % Fmt.percent(change)
		_worth_chip.theme_type_variation = &"MoodGreen" if change >= 0.0 else &"MoodRed"
	_chart.set_data(history)

	var invested := portfolio.investments_value()
	var cost := portfolio.total_cost()
	var pnl := invested - cost
	_invest_value.text = Fmt.rupiah(invested)
	_invest_sub.text = tr("PORT_INVESTED_SUB") % [portfolio.holdings.size(), Fmt.rupiah(cost)]
	_pnl_value.text = Fmt.signed_rupiah(pnl)
	_pnl_sub.text = tr("PORT_PNL_SUB") % Fmt.percent(pnl / cost) if cost > 0 else tr("PORT_PNL_NONE")
	var color := MonthReport.signed_color(pnl) if pnl != 0 else Palette.INK
	_pnl_value.add_theme_color_override("font_color", color)
	_pnl_caps.add_theme_color_override("font_color", color if pnl != 0 else Palette.MUTED)
	_pnl_tile.theme_type_variation = &"StatTileNegative" if pnl < 0 else (&"StatTilePositive" if pnl > 0 else &"StatTile")

	_fill_allocation()
	_fill_sheet()


## Batang alokasi per kelas aset (kas termasuk) + legenda 2 kolom, lalu peringatan konsentrasi.
func _fill_allocation() -> void:
	var totals := {"cash": maxf(GameState.cash, 0.0)}
	for asset_id: String in GameState.portfolio.holdings:
		var asset_class: String = GameState.market.get_asset(asset_id).asset_class
		totals[asset_class] = totals.get(asset_class, 0.0) + GameState.portfolio.holding_value(asset_id)
	var grand_total := 0.0
	for value: float in totals.values():
		grand_total += value
	var parts: Array = []
	var shares: Array = []
	for asset_class: String in CLASS_COLORS:
		var value: float = totals.get(asset_class, 0.0)
		if value > 0.0:
			shares.append([asset_class, value])
	shares.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	_clear(_alloc_legend)
	for item: Array in shares:
		var color: Color = CLASS_COLORS[item[0]]
		parts.append([item[1], color])
		var name_key := "LBL_CASH" if item[0] == "cash" else "CLASS_" + str(item[0]).to_upper()
		_alloc_legend.add_child(_legend_cell(color, tr(name_key).capitalize(), Fmt.percent_plain(float(item[1]) / grand_total)))
	_alloc_bar.set_parts(parts)
	if shares.is_empty():
		_alloc_legend.add_child(_label(tr("ALLOC_EMPTY"), &"MutedLabel"))

	# Peringatan konsentrasi (GDD 5.8): satu aset > 70% dari investasi.
	var share := EndAnalysis.largest_holding_share(GameState)
	var concentrated := share > 0.7 and GameState.portfolio.investments_value() > 5_000_000
	InfoBlocks.build(_concentration, [{"warn": tr("PORT_CONCENTRATION_WARNING") % Fmt.percent_plain(share)}]
		if concentrated else [])
	_concentration.visible = concentrated


func _legend_cell(color: Color, text: String, percent: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	row.add_child(_swatch(color))
	var name_label := _label(text, &"RowLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(_label(percent, &"RowValueLabel"))
	return row


## Neraca ringkas: total aset, total utang (nama pinjaman), batang porsi utang, kekayaan bersih, catatan rasio,
## dan tombol rincian (semua baris neraca di popup).
func _fill_sheet() -> void:
	_clear(_sheet_box)
	var sheet := GameState.balance_sheet()
	var assets := float(sheet["total_assets"])
	var debt := float(sheet["total_debt"])
	_sheet_box.add_child(_value_row(tr("SHEET_TOTAL_ASSETS"), Fmt.rupiah(assets), Palette.LOSS if assets < 0 else Palette.INK))
	var names: PackedStringArray = []
	for item: Dictionary in sheet["debts"]:
		names.append(tr(item["name"]))
	var debt_row := _value_row(tr("SHEET_TOTAL_DEBT"), Fmt.signed_rupiah(-debt) if debt > 0.0 else Fmt.rupiah(0),
		Palette.LOSS if debt > 0.0 else Palette.MUTED)
	if not names.is_empty():
		var sub := _label(" · " + ", ".join(names), &"SmallMutedLabel")
		sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var debt_label: Label = debt_row.get_child(0)
		debt_label.size_flags_horizontal = Control.SIZE_FILL
		debt_label.autowrap_mode = TextServer.AUTOWRAP_OFF  # lebar mengikuti teks; nama pinjaman yang mengisi sisa
		debt_row.add_child(sub)
		debt_row.move_child(sub, 1)
	_sheet_box.add_child(debt_row)
	if debt > 0.0 and assets > 0.0:
		var bar := FlowBar.new()
		bar.custom_minimum_size = Vector2(0, 14)
		bar.set_parts([[maxf(assets - debt, 0.0), DEBT_GREEN], [debt, DEBT_RED]])
		_sheet_box.add_child(bar)
	_sheet_box.add_child(_divider())
	var worth := float(sheet["net_worth"])
	var worth_row := _value_row(tr("SHEET_NET_WORTH"), Fmt.rupiah(worth), Palette.GAIN if worth >= 0 else Palette.LOSS)
	worth_row.get_child(0).theme_type_variation = &"RowValueLabel"
	_sheet_box.add_child(worth_row)
	if debt <= 0.0:
		_sheet_box.add_child(_wrap(tr("SHEET_NO_DEBT"), &"SmallMutedLabel"))
	elif assets > 0.0:
		_sheet_box.add_child(_wrap(tr("SHEET_RATIO") % roundi(debt / assets * 100.0), &"SmallMutedLabel"))
	var detail := UiText.chunky_button(tr("PORT_SHEET_DETAIL"), &"NeutralButton", &"NeutralButtonLabel", 56.0, 19)
	detail.pressed.connect(func() -> void: popup_requested.emit(tr("SHEET_TITLE"), _sheet_blocks()))
	_sheet_box.add_child(detail)


## Semua baris neraca untuk popup "Rincian neraca" (blok InfoBlocks).
func _sheet_blocks() -> Array:
	var sheet := GameState.balance_sheet()
	var rows: Array = []
	for item: Dictionary in sheet["assets"]:
		var value := float(item["value"])
		if is_zero_approx(value) and item["key"] != "LBL_CASH":
			continue
		rows.append([tr(item["key"]), Fmt.rupiah(value)] + ([Palette.LOSS] if value < 0 else []))
	rows.append([tr("SHEET_TOTAL_ASSETS"), Fmt.rupiah(sheet["total_assets"])])
	var blocks: Array = [{"caps": tr("SHEET_ASSETS")}, {"rows": rows}, {"caps": tr("SHEET_DEBTS")}]
	var debts: Array = []
	for item: Dictionary in sheet["debts"]:
		debts.append([tr(item["name"]), Fmt.signed_rupiah(-float(item["value"])), Palette.LOSS])
	if debts.is_empty():
		blocks.append({"text": tr("SHEET_NO_DEBT")})
	else:
		debts.append([tr("SHEET_TOTAL_DEBT"), Fmt.signed_rupiah(-float(sheet["total_debt"])), Palette.LOSS])
		blocks.append({"rows": debts})
	var worth := float(sheet["net_worth"])
	blocks.append({"rows": [[tr("SHEET_NET_WORTH"), Fmt.rupiah(worth), Palette.GAIN if worth >= 0 else Palette.LOSS]]})
	var assets := float(sheet["total_assets"])
	if float(sheet["total_debt"]) > 0.0 and assets > 0.0:
		blocks.append({"tip": tr("SHEET_RATIO") % roundi(float(sheet["total_debt"]) / assets * 100.0)})
	return blocks


# ==================================================================================================
# Aset
# ==================================================================================================

func _refresh_assets() -> void:
	var fund := GameState.fund
	var key := [GameState.run_id, GameState.month, Fmt.compact, GameState.portfolio.holdings, GameState.leverage.positions,
		fund.is_unlocked(), fund.investors, fund.board, fund.allocation, fund.reputation, GameState.cash]
	if not UiText.changed_key(_render, "assets", key):
		return
	var page: VBoxContainer = %Assets
	_clear(page)
	_add_holdings(page)
	_add_leverage(page)
	_add_fund(page)


## Kepemilikan dikelompokkan per kelas aset: judul kecil + subtotal, lalu satu kartu berisi baris aset.
func _add_holdings(page: VBoxContainer) -> void:
	var portfolio := GameState.portfolio
	if portfolio.holdings.is_empty():
		page.add_child(_label(tr("PORT_HOLDINGS"), &"SubSectionLabel"))
		page.add_child(_wrap(tr("PORT_EMPTY"), &"MutedLabel"))
		return
	var groups := {}
	for asset_id: String in portfolio.holdings:
		var asset_class: String = GameState.market.get_asset(asset_id).asset_class
		if not groups.has(asset_class):
			groups[asset_class] = []
		groups[asset_class].append(asset_id)
	var totals := {}
	for asset_class: String in groups:
		totals[asset_class] = 0.0
		for asset_id: String in groups[asset_class]:
			totals[asset_class] += portfolio.holding_value(asset_id)
	var order: Array = groups.keys()
	order.sort_custom(func(a: String, b: String) -> bool: return totals[a] > totals[b])  # kelompok terbesar di atas
	for asset_class: String in order:
		var ids: Array = groups[asset_class]
		ids.sort_custom(func(a: String, b: String) -> bool: return portfolio.holding_value(a) > portfolio.holding_value(b))
		var subtotal := 0.0
		for asset_id: String in ids:
			subtotal += portfolio.holding_value(asset_id)
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 8)
		section.add_child(_caps_row(tr("CLASS_" + asset_class.to_upper()), Fmt.rupiah(subtotal),
			CLASS_COLORS.get(asset_class, Palette.MUTED)))
		var card := PanelContainer.new()
		card.theme_type_variation = &"HomeCard"
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 4)
		card.add_child(list)
		for i in ids.size():
			if i > 0:
				list.add_child(_divider())
			list.add_child(_holding_row(ids[i]))
		section.add_child(card)
		page.add_child(section)


## Satu baris kepemilikan (bisa diketuk): ikon kelas | nama + unit @ rata-rata | nilai + untung/rugi.
func _holding_row(asset_id: String) -> Button:
	var asset := GameState.market.get_asset(asset_id)
	var units := GameState.portfolio.units_of(asset_id)
	var cost := GameState.portfolio.cost_of(asset_id)
	var value := GameState.portfolio.holding_value(asset_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(UiText.class_tile(asset.asset_class, 44.0))
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	middle.add_theme_constant_override("separation", 0)
	var name_label := _label(tr(asset.name_key), &"AssetNameLabel")
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size.x = 1
	middle.add_child(name_label)
	var detail_text: String
	if asset.is_interest():
		detail_text = tr("FMT_RATE_PA") % Fmt.percent_plain(GameState.market.rate_for(asset))
		if GameState.portfolio.is_locked(asset_id):
			detail_text += " · " + tr("LBL_LOCKED_UNTIL") % Fmt.game_date(GameState.portfolio.locked_until(asset_id))
	else:
		detail_text = tr("PORT_HOLDING_DETAIL") % [Fmt.units(units), asset.price_text(cost / units)]
	middle.add_child(_wrap(detail_text, &"SmallMutedLabel"))
	row.add_child(middle)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 0)
	var value_label := _label(Fmt.rupiah(value), &"AssetValueLabel")
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(value_label)
	var pnl_label := _label("%s (%s)" % [Fmt.signed_rupiah(value - cost), Fmt.percent((value - cost) / cost)] if cost > 0
		else Fmt.signed_rupiah(value - cost), &"AssetSubLabel")
	pnl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pnl_label.add_theme_color_override("font_color", MonthReport.signed_color(value - cost))
	right.add_child(pnl_label)
	row.add_child(right)
	return _row_button(row, func() -> void: asset_requested.emit(asset_id))


## Posisi leverage (v2a): judul + total ekuitas, lalu kartu per posisi dengan meteran jarak ke likuidasi.
func _add_leverage(page: VBoxContainer) -> void:
	var lev := GameState.leverage
	if lev.positions.is_empty():
		return
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 10)
	section.add_child(_caps_row(tr("PORT_LEV_CAPS") % lev.positions.size(), tr("PORT_LEV_TOTAL") % Fmt.rupiah(lev.total_equity())))
	for p: Dictionary in lev.positions:
		section.add_child(_leverage_card(p))
	page.add_child(section)


func _leverage_card(p: Dictionary) -> PanelContainer:
	var lev := GameState.leverage
	var asset := GameState.market.get_asset(p["asset"])
	var equity := lev.equity(p)
	var pnl := equity - float(p["margin"])
	var card := _card(10)
	var box: VBoxContainer = card.get_child(0)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var name_label := _wrap(tr(asset.name_key), &"AssetNameLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var long := int(p["side"]) == Leverage.LONG
	var side := _chip_with(_label(tr("LEV_CHIP_LONG" if long else "LEV_CHIP_SHORT") % int(p["leverage"]), &"MoodLabel"),
		&"MoodGreen" if long else &"MoodGold")
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(side)
	box.add_child(head)
	var money := _value_row(tr("PORT_LEV_EQUITY") % [Fmt.rupiah(equity), Fmt.rupiah(p["margin"])],
		"%s (%s)" % [Fmt.signed_rupiah(pnl), Fmt.percent(pnl / float(p["margin"]))], MonthReport.signed_color(pnl))
	box.add_child(money)

	var liq := lev.liquidation_price(p)
	var room := 1.0 - liq / asset.price if long else liq / asset.price - 1.0
	var safe := long and liq <= 0.0  # margin menutup seluruh posisi: harga 0 pun tidak melikuidasi
	var danger := not safe and room < 0.15
	var meter := VBoxContainer.new()
	meter.add_theme_constant_override("separation", 6)
	var room_text := tr("PORT_LEV_SAFE") if safe else tr("PORT_LEV_ROOM_DOWN" if long else "PORT_LEV_ROOM_UP") % Fmt.percent_plain(room)
	meter.add_child(_value_row(tr("PORT_LEV_DISTANCE"), room_text, Palette.LOSS if danger else Palette.GAIN, &"SmallMutedLabel"))
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"HealthBar" if danger else &"XpBar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = 1.0 if safe else clampf(room, 0.0, 1.0)
	meter.add_child(bar)
	box.add_child(meter)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 6)
	chips.add_child(_small_chip(tr("PORT_LEV_PRICE") % [asset.price_text(p["entry"]), asset.price_text()]))
	var financing := lev.monthly_financing(p)
	chips.add_child(_small_chip(tr("PORT_LEV_FIN") % Fmt.rupiah(financing) if financing >= 1.0 else tr("PORT_LEV_NO_FIN")))
	box.add_child(chips)
	if p.get("call", false):
		var call := _wrap(tr("LEV_POS_CALL") % Fmt.percent_plain(equity / float(p["margin"])), &"InfoLabel")
		call.add_theme_color_override("font_color", Palette.LOSS)
		box.add_child(call)
	return card


## Dana kelolaan (v2c): uang investor terpisah dari kekayaan pribadi, jadi kartunya berdiri sendiri.
func _add_fund(page: VBoxContainer) -> void:
	var fund := GameState.fund
	if not fund.is_unlocked():
		return
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 10)
	section.add_child(_label(tr("PORT_FUND_CAPS").to_upper(), &"TileCapsLabel"))
	var card := _card(12)
	var box: VBoxContainer = card.get_child(0)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(UiText.icon_tile(FUND_ICON, &"IconTileGold"))
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 0)
	if fund.is_active():
		var start := float(fund.data["start_nav"])
		texts.add_child(_wrap(tr("PORT_FUND_HEAD") % [Fmt.rupiah(fund.value()), fund.investors.size()], &"AssetNameLabel"))
		texts.add_child(_wrap(tr("PORT_FUND_SUB") % [Fmt.rupiah(fund.current_nav()), Fmt.percent(fund.current_nav() / start - 1.0),
			UiText.fund_profile(fund.profile_of()), Fmt.rupiah(float(fund.record["mgmt_fees"]) + float(fund.record["perf_fees"]))],
			&"SmallMutedLabel"))
	else:
		texts.add_child(_wrap(tr("PORT_FUND_TITLE"), &"AssetNameLabel"))
		texts.add_child(_wrap(tr("PORT_FUND_EMPTY"), &"SmallMutedLabel"))
	head.add_child(texts)
	box.add_child(head)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 6)
	var warned := fund.investors.filter(func(inv: Dictionary) -> bool: return fund.is_warned(inv)).size()
	if warned > 0:  # investor yang sudah menegur
		chips.add_child(_chip_with(_label(tr("PORT_FUND_WARNED") % warned, &"MoodLabel"), &"MoodRed"))
	if not fund.board.is_empty():
		chips.add_child(_chip_with(_label(tr("PORT_FUND_OFFERS") % fund.board.size(), &"MoodLabel"), &"MoodGold"))
	if chips.get_child_count() > 0:
		box.add_child(chips)
	box.add_child(_wrap(tr("PORT_FUND_NOTE"), &"SmallMutedLabel"))
	var button := UiText.chunky_button(tr("PORT_FUND_OPEN"), &"PrimaryButton", &"PrimaryButtonLabel", 60.0, 22)
	button.pressed.connect(func() -> void: fund_requested.emit())
	box.add_child(button)
	section.add_child(card)
	page.add_child(section)


# ==================================================================================================
# Riwayat
# ==================================================================================================

func _build_history() -> void:
	var page: VBoxContainer = %History
	var report := VBoxContainer.new()
	report.add_theme_constant_override("separation", 8)
	_report_caps = _label("", &"TileCapsLabel")
	report.add_child(_report_caps)
	var card := _card(12)
	_report_box = card.get_child(0)
	report.add_child(card)
	page.add_child(report)

	page.add_child(_label(tr("PORT_TRANSACTIONS"), &"SubSectionLabel"))
	_filter_row = HBoxContainer.new()
	_filter_row.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for id: String in TX_FILTERS:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = &"PeriodButton"
		button.custom_minimum_size = Vector2(0, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("filter", id)
		button.button_pressed = id == _filter
		button.pressed.connect(func() -> void:
			_filter = id
			_months_shown = MONTHS_STEP
			_render.erase("tx")
			_refresh_history())
		_filter_row.add_child(button)
	page.add_child(_filter_row)
	_tx_box = VBoxContainer.new()
	_tx_box.add_theme_constant_override("separation", 14)
	page.add_child(_tx_box)


func _refresh_history() -> void:
	var r := GameState.last_report
	var base := [GameState.run_id, Fmt.compact]
	if UiText.changed_key(_render, "report", base + [r.get("to_month", -1), r.size()]):
		_fill_report(r)
	var txs := GameState.portfolio.transactions
	if UiText.changed_key(_render, "tx", base + [txs.size(), txs[0] if not txs.is_empty() else {}, _filter, _months_shown,
			_expanded]):
		_fill_transactions()


## Laporan bulan lalu dalam 4 arus uang + perubahan kekayaan bersih + tombol laporan lengkap.
func _fill_report(r: Dictionary) -> void:
	_clear(_report_box)
	if r.is_empty():
		_report_caps.text = tr("PORT_REPORT_CAPS_EMPTY").to_upper()
		_report_box.add_child(_wrap(tr("REPORT_EMPTY"), &"MutedLabel"))
		return
	var months := int(r.get("months", 1))
	_report_caps.text = (tr("PORT_REPORT_CAPS_MULTI") % months if months > 1
		else tr("PORT_REPORT_CAPS") % Fmt.game_date(r["from_month"])).to_upper()
	var f := MonthReport.flows(r)
	_report_box.add_child(_flow_row("res://assets/icons/flows/income.svg", &"IconTileMint", tr("PORT_FLOW_INCOME"),
		tr("PORT_FLOW_INCOME_SUB"), Fmt.signed_rupiah(f["income"]), Palette.GAIN if f["income"] > 0 else Palette.MUTED))
	_report_box.add_child(_flow_row("res://assets/icons/flows/expense.svg", &"IconTileCoral", tr("PORT_FLOW_EXPENSE"),
		tr("PORT_FLOW_EXPENSE_SUB"), Fmt.signed_rupiah(-f["expense"]), Palette.LOSS if f["expense"] > 0 else Palette.MUTED))
	_report_box.add_child(_flow_row("res://assets/icons/flows/saved.svg", &"IconTileGold", tr("PORT_FLOW_SAVED"),
		tr("PORT_FLOW_SAVED_SUB"), Fmt.rupiah(f["saved"]), Palette.INK))
	_report_box.add_child(_flow_row("res://assets/icons/flows/invest.svg", &"IconTileBlue", tr("PORT_FLOW_INVEST"),
		tr("PORT_FLOW_INVEST_SUB"), Fmt.signed_rupiah(f["invest"]), MonthReport.signed_color(f["invest"])))
	var change := float(r["net_worth_after"]) - float(r["net_worth_before"])
	var worth := PanelContainer.new()
	worth.theme_type_variation = &"StatTilePositive" if change >= 0.0 else &"StatTileNegative"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 0)
	left.add_child(_label(tr("SHEET_NET_WORTH"), &"AssetNameLabel"))
	left.add_child(_label(tr("PORT_FLOW_WORTH_SUB"), &"SmallMutedLabel"))
	row.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 0)
	var after := _label(Fmt.rupiah(r["net_worth_after"]), &"AssetValueLabel")
	after.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(after)
	var delta := _label(MonthReport.net_worth_change_text(r), &"RowValueLabel")
	delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	delta.add_theme_color_override("font_color", MonthReport.signed_color(change))
	right.add_child(delta)
	row.add_child(right)
	worth.add_child(row)
	_report_box.add_child(worth)
	var full := UiText.chunky_button(tr("PORT_REPORT_FULL"), &"NeutralButton", &"NeutralButtonLabel", 56.0, 19)
	full.pressed.connect(func() -> void: report_requested.emit())
	_report_box.add_child(full)


func _flow_row(icon: String, tile: StringName, title: String, sub: String, value: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(UiText.icon_tile(icon if ResourceLoader.exists(icon) else "res://assets/icons/wallet.svg", tile, 40.0))
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 0)
	texts.add_child(_label(title, &"AssetNameLabel"))
	texts.add_child(_wrap(sub, &"SmallMutedLabel"))
	row.add_child(texts)
	var value_label := _label(value, &"AssetValueLabel")
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value_label.add_theme_color_override("font_color", color)
	row.add_child(value_label)
	return row


## Transaksi per bulan (terbaru di atas) sesuai saringan; autodebet dalam satu bulan dilipat jadi satu baris
## yang bisa dibuka. Hanya `_months_shown` bulan terbaru yang ditampilkan.
func _fill_transactions() -> void:
	var txs := GameState.portfolio.transactions
	for button: Button in _filter_row.get_children():
		var id: String = button.get_meta("filter")
		var count := txs.size() if id == "all" else txs.filter(func(t: Dictionary) -> bool: return t["kind"] in TX_FILTERS[id]).size()
		button.text = tr("PORT_TX_FILTER_" + id.to_upper()) + (" · %d" % count if id != "all" else "")
		button.set_pressed_no_signal(id == _filter)
	_clear(_tx_box)
	var shown: Array = txs if _filter == "all" else txs.filter(func(t: Dictionary) -> bool: return t["kind"] in TX_FILTERS[_filter])
	if shown.is_empty():
		_tx_box.add_child(_wrap(tr("TX_EMPTY"), &"MutedLabel"))
		return
	var months: Array[int] = []
	var by_month := {}
	for t: Dictionary in shown:
		var month := int(t["month"])
		if not by_month.has(month):
			months.append(month)
			by_month[month] = []
		by_month[month].append(t)
	for i in mini(_months_shown, months.size()):
		_tx_box.add_child(_month_group(months[i], by_month[months[i]]))
	var left := months.size() - _months_shown
	if left > 0:
		var more := UiText.chunky_button(tr("PORT_TX_MORE") % mini(left, MONTHS_STEP), &"NeutralButton", &"NeutralButtonLabel",
			56.0, 19)
		more.pressed.connect(func() -> void:
			_months_shown += MONTHS_STEP
			_refresh_history())
		_tx_box.add_child(more)


func _month_group(month: int, items: Array) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 8)
	group.add_child(_label(Fmt.game_date(month).to_upper(), &"TileCapsLabel"))
	var card := PanelContainer.new()
	card.theme_type_variation = &"HomeCard"
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	card.add_child(list)
	var autos := items.filter(func(t: Dictionary) -> bool: return t["kind"] == "auto")
	var rows: Array[Control] = []
	if autos.size() >= 2:
		var open: bool = _expanded.get(month, false)
		var total := 0.0
		var fees := 0.0
		for t: Dictionary in autos:
			total += float(t["amount"])
			fees += float(t["fee"])
		var head := _tx_row(&"MoodGreen", tr("TX_AUTO"), tr("PORT_TX_AUTO_GROUP") % autos.size(), tr("PORT_TX_FEE") % Fmt.rupiah(fees),
			Fmt.rupiah(total), "", "▴" if open else "▾")
		rows.append(_row_button(head, func() -> void:
			_expanded[month] = not open
			_refresh_history()))
		if open:
			for t: Dictionary in autos:
				var child := _tx_row(&"", "", tr(t["asset_key"]), _fee_text(t), Fmt.rupiah(t["amount"]), "", "")
				child.add_theme_constant_override("separation", 12)
				rows.append(child)
	for t: Dictionary in items:
		if t["kind"] == "auto" and autos.size() >= 2:
			continue
		var kind := str(t["kind"])
		var pnl := "" if kind in BUY_KINDS else tr("TX_PNL") % Fmt.signed_rupiah(t["pnl"])
		var row := _tx_row(TX_CHIPS.get(kind, &"MoodNeutral"), tr("TX_" + kind.to_upper()), tr(t["asset_key"]), _fee_text(t),
			Fmt.rupiah(t["amount"]), pnl, "")
		if pnl != "":
			row.get_child(1).get_child(2).add_theme_color_override("font_color", MonthReport.signed_color(t["pnl"]))
		rows.append(row)
	for i in rows.size():
		if i > 0:
			list.add_child(_divider())
		list.add_child(rows[i])
	group.add_child(card)
	return group


## Satu baris transaksi: chip jenis (kosong = baris anak autodebet, menjorok) | nama + fee (+ untung/rugi) |
## nominal | panah buka/tutup.
func _tx_row(chip_variation: StringName, chip_text: String, title: String, meta: String, amount: String, pnl: String,
		arrow: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var chip: Control
	if chip_variation != &"":
		var chip_label := _label(chip_text, &"MoodLabel")
		chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip = _chip_with(chip_label, chip_variation)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	else:
		chip = Control.new()  # baris anak autodebet: ruang kosong selebar chip agar menjorok
	chip.custom_minimum_size.x = 112
	row.add_child(chip)
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	middle.add_theme_constant_override("separation", 0)
	var name_label := _label(title, &"AssetNameLabel")
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size.x = 1
	middle.add_child(name_label)
	middle.add_child(_wrap(meta, &"SmallMutedLabel"))
	if pnl != "":
		middle.add_child(_label(pnl, &"AssetSubLabel"))
	row.add_child(middle)
	var amount_label := _label(amount, &"AssetValueLabel")
	amount_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(amount_label)
	if arrow != "":
		var arrow_label := _label(arrow, &"MutedLabel")
		arrow_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(arrow_label)
	return row


func _fee_text(t: Dictionary) -> String:
	var tax := float(t.get("tax", 0.0))
	return tr("PORT_TX_FEE_TAX") % [Fmt.rupiah(t["fee"]), Fmt.rupiah(tax)] if tax > 0.0 else tr("PORT_TX_FEE") % Fmt.rupiah(t["fee"])


# ==================================================================================================
# Bantuan
# ==================================================================================================

## Kartu putih (HomeCard) berisi VBox dengan jarak `gap`; isi lewat get_child(0).
func _card(gap: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"HomeCard"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	card.add_child(box)
	return card


## Ubin angka: [panel, label nilai, label keterangan, label judul].
func _tile(title: String) -> Array:
	var tile := PanelContainer.new()
	tile.theme_type_variation = &"StatTile"
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var caps := _label(title, &"TileCapsLabel")
	box.add_child(caps)
	var value := _label("", &"TileValueLabel")
	box.add_child(value)
	var sub := _wrap("", &"SmallMutedLabel")
	box.add_child(sub)
	tile.add_child(box)
	return [tile, value, sub, caps]


## Judul kecil berhuruf kapital (+ kotak warna) di kiri, nilai di kanan.
func _caps_row(title: String, value: String, color := Color.TRANSPARENT) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if color.a > 0.0:
		row.add_child(_swatch(color))
	var caps := _label(title.to_upper(), &"TileCapsLabel")
	caps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caps)
	row.add_child(_label(value, &"RowValueLabel"))
	return row


func _value_row(name: String, value: String, color: Color, name_variation := &"RowLabel") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := _wrap(name, name_variation)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value_label := _label(value, &"RowValueLabel")
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", color)
	row.add_child(value_label)
	return row


## Isi baris dibungkus Button datar agar bisa diketuk (klik diteruskan dari isi ke Button).
func _row_button(content: Control, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ignore_mouse(content)
	button.add_child(content)
	UiText.fit_to_content(button, content)
	button.pressed.connect(on_pressed)
	return button


func _swatch(color: Color) -> Panel:
	var swatch := Panel.new()
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	swatch.add_theme_stylebox_override("panel", style)
	return swatch


func _chip_with(label: Label, variation: StringName) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = variation
	chip.add_child(label)
	return chip


func _small_chip(text: String) -> PanelContainer:
	var label := _label(text, &"SmallChipNeutralLabel")
	label.add_theme_color_override("font_color", Palette.INK)
	return _chip_with(label, &"SmallChipNeutral")


func _divider() -> Panel:
	var line := Panel.new()
	line.theme_type_variation = &"Divider"
	line.custom_minimum_size = Vector2(0, 2)
	return line


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label


func _wrap(text: String, variation: StringName) -> Label:
	var label := _label(text, variation)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1
	return label


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
