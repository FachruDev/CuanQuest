extends MarginContainer
## Tab Pasar (tema "Senja Cuan"). Dua "view" dalam satu scene (mirip route /market dan /market/:id):
## - ListView  : rumor yang beredar, berita terbaru, kondisi pasar, daftar aset per kelas
## - DetailView: grafik/info bunga + beli/jual untuk satu aset (+ rumor jika aset ini dirumorkan)
## Node yang diawali "%" adalah "unique name" di scene (mirip document.getElementById).

const QUICK_PERCENTS := [0.25, 0.5, 1.0]
const CLASS_ORDER := ["savings", "deposit", "mutual_fund", "stock", "crypto", "commodity", "forex"]
## Warna teks risiko 1-5 (cukup gelap agar terbaca di kartu putih).
const RISK_COLORS := [Color("#1e7f5c"), Color("#1e7f5c"), Color("#a86a12"), Color("#c25a1e"), Color("#c2452d")]
const REGIME_CHIPS := {"bull": &"MoodGreen", "sideways": &"MoodNeutral", "bear": &"MoodRed"}
const NEWS_SHOWN := 4

enum Mode { BUY, SELL }

## Tombol Beli/Jual ditekan: main membuka layar konfirmasi (rincian fee, pajak, peringatan).
signal trade_requested(asset_id: String, is_buy: bool, amount: int)
## Tombol "Atur stop loss / take profit" ditekan: main membuka popup pesanan otomatis.
signal order_requested(asset_id: String)
## Kartu leverage (v2a): buka posisi, tambah margin, atau tutup posisi (main membuka popup / konfirmasi).
signal leverage_requested(asset_id: String)
signal margin_requested(uid: int)
signal close_position_requested(uid: int)

var mode := Mode.BUY
var _selected_id := ""
var _rows: Dictionary = {}  # asset_id -> { "button": Button, "risk": Label, "price": Label, "change": Label }
var _rumor_cards: Dictionary = {}  # "list" / "detail" -> kartu rumor yang sedang tampil (v1.5d)
var _rumor_error := ""  # pesan riset gagal terakhir (mis. energi habis)
var _lev_box: VBoxContainer  # isi kartu leverage di detail aset (v2a)


func _ready() -> void:
	var group := ButtonGroup.new()  # supaya Beli/Jual saling eksklusif seperti radio button
	%ModeBuy.button_group = group
	%ModeSell.button_group = group
	%ModeBuy.pressed.connect(_set_mode.bind(Mode.BUY))
	%ModeSell.pressed.connect(_set_mode.bind(Mode.SELL))

	var quick_buttons := [%Quick25, %Quick50, %Quick100]
	for i in quick_buttons.size():
		quick_buttons[i].pressed.connect(_fill_percent.bind(QUICK_PERCENTS[i]))

	%AmountEdit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	%ConfirmButton.pressed.connect(_on_confirm_pressed)
	var order_button := UiText.chunky_button(tr("MARKET_ORDER_BUTTON"), &"NeutralButton", &"NeutralButtonLabel", 64.0, 24)
	order_button.pressed.connect(func() -> void: order_requested.emit(_selected_id))
	%OrderHolder.add_child(order_button)
	%BackButton.pressed.connect(_show_list)
	_build_leverage_card()

	_build_asset_list()
	UiText.build_period_buttons(%PeriodRow, %Chart, 3, [1, 3, 12, 0])  # data harian
	GameState.changed.connect(_refresh)
	visibility_changed.connect(_refresh)  # tab tersembunyi tidak diperbarui (penutup v1.5)
	_show_list()


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	_refresh_list()
	if _selected_id != "":
		_refresh_detail()


# --- List view ----------------------------------------------------------------

func _show_list() -> void:
	_selected_id = ""
	%DetailView.hide()
	%ListView.show()
	_refresh()


## Dibuat sekali: header per kelas aset + satu tombol per aset.
func _build_asset_list() -> void:
	for asset_class: String in CLASS_ORDER:
		var header := _make_label(tr("CLASS_" + asset_class.to_upper()), &"ClassHeaderLabel")
		%AssetList.add_child(header)
		for asset: MarketAsset in GameState.market.assets.values():
			if asset.asset_class == asset_class:
				%AssetList.add_child(_make_asset_row(asset))


## Satu baris aset: ikon kelas | nama + risiko | harga/bunga + perubahan. Tombol "tebal" yang bisa ditekan.
func _make_asset_row(asset: MarketAsset) -> Button:
	var button := ChunkyButton.new()
	button.theme_type_variation = &"AssetRowButton"
	button.press_depth = 5.0
	button.custom_minimum_size = Vector2(0, 84)
	button.pressed.connect(_show_detail.bind(asset.id))

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_right = -16
	row.offset_bottom = -5  # bibir bawah tombol
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tile := UiText.class_tile(asset.asset_class)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 0)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := _make_label(tr(asset.name_key), &"AssetNameLabel")
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	left.add_child(name_label)
	var risk := _make_label(tr("RISK_%d" % asset.risk), &"AssetSubLabel")
	left.add_child(risk)

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 0)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var price := _make_label("", &"AssetValueLabel")
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var change := _make_label("", &"AssetSubLabel")
	change.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(price)
	right.add_child(change)

	row.add_child(tile)
	row.add_child(left)
	row.add_child(right)
	button.add_child(row)
	_rows[asset.id] = {"button": button, "risk": risk, "price": price, "change": change}
	return button


func _refresh_list() -> void:
	var market := GameState.market
	for asset_id: String in _rows:
		var asset := market.get_asset(asset_id)
		var labels: Dictionary = _rows[asset_id]
		var unlocked := GameState.progress.is_asset_unlocked(asset_id)
		labels["button"].modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.5)
		labels["risk"].text = tr("RISK_%d" % asset.risk) if unlocked else tr("MARKET_LOCKED_ROW") % asset.stage
		labels["risk"].add_theme_color_override("font_color", RISK_COLORS[asset.risk - 1] if unlocked else Palette.MUTED)
		if asset.is_interest():
			labels["price"].text = tr("FMT_RATE_PA") % Fmt.percent_plain(market.rate_for(asset))
			labels["change"].text = tr("LBL_INTEREST")
			labels["change"].add_theme_color_override("font_color", Palette.MUTED)
		else:
			labels["price"].text = asset.price_text()
			labels["change"].text = Fmt.percent(asset.change_ratio())
			labels["change"].add_theme_color_override("font_color", MonthReport.signed_color(asset.change_ratio()))

	_refresh_mood(market)
	_refresh_news(market)
	_refresh_rumor("list")


## Chip kondisi pasar: tren saham, tren kripto, tren komoditas (setelah tahap 4 terbuka), suku bunga acuan,
## inflasi, kurs dolar (v2a).
func _refresh_mood(market: Market) -> void:
	for child in %MoodRow.get_children():
		%MoodRow.remove_child(child)
		child.queue_free()
	var kinds := ["stock", "crypto"]
	if GameState.progress.is_stage_unlocked(4):
		kinds.append("commodity")
	for kind: String in kinds:
		var regime := market.regime_of(kind)
		var text := tr("MARKET_MOOD_" + kind.to_upper()) % tr("REGIME_" + regime.to_upper())
		%MoodRow.add_child(_make_chip(text, REGIME_CHIPS.get(regime, &"MoodNeutral")))
	%MoodRow.add_child(_make_chip(tr("MARKET_MOOD_RATE") % Fmt.percent_plain(market.policy_rate), &"MoodGold"))
	%MoodRow.add_child(_make_chip(tr("MARKET_MOOD_INFLATION") % Fmt.percent_plain(market.inflation), &"MoodNeutral"))
	var usd := market.get_asset("USDIDR")
	if usd != null:
		%MoodRow.add_child(_make_chip(tr("MARKET_MOOD_FX") % usd.price_text(), &"MoodNeutral"))


func _refresh_news(market: Market) -> void:
	for child in %NewsList.get_children():
		%NewsList.remove_child(child)
		child.queue_free()
	if market.news_log.is_empty():
		var empty := _make_label(tr("NEWS_NONE"), &"NewsTextLabel")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		%NewsList.add_child(empty)
	for i in mini(NEWS_SHOWN, market.news_log.size()):
		var item: Dictionary = market.news_log[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"NewsDateChip"
		chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		chip.add_child(_make_label(Fmt.game_date(item["month"]), &"NewsDateLabel"))
		var text := _make_label(MonthReport.news_text(item), &"NewsTextLabel")
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(chip)
		row.add_child(text)
		%NewsList.add_child(row)


# --- Rumor & riset (v1.5d langkah 2) -----------------------------------------------

## Kartu rumor di atas berita (daftar) atau di bawah judul aset yang dirumorkan (detail).
func _refresh_rumor(where: String) -> void:
	if _rumor_cards.has(where):
		var old: Control = _rumor_cards[where]
		old.get_parent().remove_child(old)
		old.queue_free()
		_rumor_cards.erase(where)
	var research := GameState.research
	if not research.has_rumor() or (where == "detail" and research.rumor["asset"] != _selected_id):
		return
	var card := _rumor_card(where == "list")
	var page: VBoxContainer = %ListView.get_node("VBox") if where == "list" else %DetailView.get_node("VBox")
	page.add_child(card)
	page.move_child(card, 0 if where == "list" else 1)  # detail: setelah baris judul
	_rumor_cards[where] = card


## Teks rumor, gerak harga saat rumor beredar, hasil riset yang sudah dilakukan, tombol riset.
func _rumor_card(with_link: bool) -> PanelContainer:
	var research := GameState.research
	var rumor := research.rumor
	var asset := GameState.market.get_asset(rumor["asset"])
	var card := PanelContainer.new()
	card.theme_type_variation = &"HomeCard"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(_make_chip(tr("RUMOR_TAG"), &"MoodGold"))
	var date := _make_label(Fmt.game_date(int(rumor["month"])), &"SmallMutedLabel")
	date.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(date)
	box.add_child(head)
	box.add_child(_wrap_label(tr("RUMOR_" + str(rumor["id"]).to_upper()) % tr(asset.name_key), &"AssetNameLabel"))
	var pump := float(rumor["pump"])
	box.add_child(_wrap_label(tr("RUMOR_PUMP_UP" if pump >= 0.0 else "RUMOR_PUMP_DOWN") % [asset.id,
		Fmt.percent_plain(absf(pump))], &"SmallMutedLabel"))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	for level: String in Research.LEVELS:
		var accuracy := roundi(research.accuracy(level) * 100.0)
		if research.is_researched(level):
			var row := HBoxContainer.new()
			var name_label := _make_label(tr("RESEARCH_" + level.to_upper()) + " · " + tr("RESEARCH_ACCURACY") % accuracy, &"RowLabel")
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)
			var verdict := _make_label(tr("RESEARCH_SAYS_TRUE" if research.verdict(level) else "RESEARCH_SAYS_FALSE"), &"RowValueLabel")
			row.add_child(verdict)
			box.add_child(row)
			continue
		var cost := research.cost(level)
		var price_text := tr("RESEARCH_ENERGY") % int(research.level_def(level)["energy"])
		if cost > 0:
			price_text += " · " + UiText.amount_short(cost)
		var deep := level == "deep"
		var button := UiText.chunky_button("%s\n%s" % [tr("RESEARCH_" + level.to_upper()), price_text],
			&"PrimaryButton" if deep else &"NeutralButton", &"PrimaryButtonLabel" if deep else &"NeutralButtonLabel", 76.0, 18)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_research.bind(level))
		buttons.add_child(button)
	if buttons.get_child_count() > 0:
		box.add_child(buttons)
	if _rumor_error != "":
		var error := _wrap_label(_rumor_error, &"SmallMutedLabel")
		error.add_theme_color_override("font_color", Palette.LOSS)
		box.add_child(error)
	if with_link:
		var link := UiText.chunky_button(tr("RUMOR_SEE_ASSET") % asset.id, &"NeutralButton", &"NeutralButtonLabel", 60.0, 18)
		link.pressed.connect(_show_detail.bind(asset.id))
		box.add_child(link)
	box.add_child(_wrap_label(tr("RUMOR_NOTE") % [roundi(research.accuracy("basic") * 100.0),
		roundi(research.accuracy("deep") * 100.0)], &"SmallMutedLabel"))
	return card


func _on_research(level: String) -> void:
	var result := GameState.research.research(level)
	_rumor_error = "" if result["ok"] else tr(result["error"])
	if result["ok"]:
		Sfx.play("success")
	else:
		Sfx.play("fail")
		_refresh()  # sukses sudah memicu GameState.changed


# --- Detail view --------------------------------------------------------------

func _show_detail(asset_id: String) -> void:
	_selected_id = asset_id
	_rumor_error = ""
	%ListView.hide()
	%DetailView.show()
	%DetailView.scroll_vertical = 0
	%FeedbackLabel.text = ""
	%ModeBuy.button_pressed = true
	_set_mode(Mode.BUY)
	_refresh_detail()


func _refresh_detail() -> void:
	var asset := GameState.market.get_asset(_selected_id)
	%AssetName.text = tr(asset.name_key)
	%ClassLabel.text = "%s · %s" % [tr("CLASS_" + asset.asset_class.to_upper()), tr("RISK_%d" % asset.risk)]
	%ClassLabel.add_theme_color_override("font_color", RISK_COLORS[asset.risk - 1])
	%DescLabel.text = tr("DESC_" + asset.asset_class.to_upper())
	var asset_desc := "DESC_" + asset.name_key  # penjelasan khusus aset (komoditas, v2a)
	if tr(asset_desc) != asset_desc:
		%DescLabel.text += "\n\n" + tr(asset_desc)
	%RiskWarning.visible = GameState.portfolio.exceeds_risk_profile(asset)
	%RiskWarningLabel.text = tr("MARKET_RISK_WARNING") % tr(GameState.portfolio.risk_profile()["name"])

	if asset.is_interest():
		var rate := GameState.market.rate_for(asset)
		%PriceLabel.text = tr("FMT_RATE_PA") % Fmt.percent_plain(rate)
		%ChangeChip.hide()
		%ChartCard.hide()
		var info := tr("INFO_INTEREST") % Fmt.percent_plain(rate * (1.0 - asset.interest_tax))
		if asset.interest_tax > 0:
			info += "\n" + tr("INFO_INTEREST_TAX") % Fmt.percent_plain(asset.interest_tax)
		if asset.lock_months > 0:
			info += "\n" + tr("INFO_LOCK") % [asset.lock_months, Fmt.percent_plain(asset.early_penalty)]
		%InfoLabel.text = info
	else:
		%PriceLabel.text = asset.price_text()
		var change := asset.change_ratio()
		%ChangeLabel.text = Fmt.percent(change)
		%ChangeLabel.add_theme_color_override("font_color", MonthReport.signed_color(change))
		%ChangeChip.theme_type_variation = &"ChangeUp" if change > 0 else (&"ChangeDown" if change < 0 else &"ChangeFlat")
		%ChangeChip.show()
		%ChartCard.show()
		%Chart.points_per_period = asset.days_per_month()
		%Chart.set_long_data(asset.month_closes)  # periode "Semua" memakai penutupan bulanan
		%Chart.set_data(asset.history)
		var info := tr("INFO_TRADED") % [
			Fmt.percent_plain(asset.volatility),
			Fmt.percent_plain(asset.buy_fee),
			Fmt.percent_plain(asset.sell_fee)]
		if asset.buy_tax > 0.0 or asset.sell_tax > 0.0:
			info += "\n" + tr("INFO_TAX") % [Fmt.percent_plain(asset.buy_tax), Fmt.percent_plain(asset.sell_tax)]
		if asset.unit_key != "":
			info += "\n" + tr("INFO_UNIT") % tr(asset.unit_key)
		var season := UiText.season_text(asset)
		if season != "":
			info += "\n" + season
		%InfoLabel.text = info

	_refresh_rumor("detail")
	var unlocked := GameState.progress.is_asset_unlocked(_selected_id)
	%TradeBox.visible = unlocked
	%LockedBox.visible = not unlocked
	if not unlocked:
		UiText.fill_requirements(%LockedReqs, GameState.progress.stage_def(asset.stage))

	var units := GameState.portfolio.units_of(_selected_id)
	if units > 0.0:
		var value := GameState.portfolio.holding_value(_selected_id)
		var cost := GameState.portfolio.cost_of(_selected_id)
		var text: String
		if asset.is_interest():
			text = tr("LBL_BALANCE") % [Fmt.rupiah(value), Fmt.signed_rupiah(value - cost)]
		else:
			text = tr("LBL_HOLDING") % [Fmt.units(units), Fmt.rupiah(value), Fmt.percent((value - cost) / cost)]
		if GameState.portfolio.is_locked(_selected_id):
			text += "\n" + tr("LBL_LOCKED_UNTIL") % Fmt.game_date(GameState.portfolio.locked_until(_selected_id))
		%HoldingLabel.text = text
	else:
		%HoldingLabel.text = tr("LBL_NO_HOLDING")
	_refresh_order(asset)
	_refresh_leverage(asset)


# --- Leverage (v2a langkah 3) --------------------------------------------------------------------

## Dibuka dari luar tab (peringatan margin call di Beranda/laporan): detail aset, gulir ke kartu leverage.
func show_asset(asset_id: String) -> void:
	_show_detail(asset_id)
	await get_tree().process_frame
	var card := _lev_box.get_parent() as Control
	if card.visible:
		%DetailView.scroll_vertical = maxi(int(card.position.y) - 24, 0)


## Kartu leverage disisipkan setelah kotak beli/jual; isinya dibangun ulang di _refresh_leverage().
func _build_leverage_card() -> void:
	var page: VBoxContainer = %DetailView.get_node("VBox")
	var card := PanelContainer.new()
	card.name = "LeverageCard"
	card.theme_type_variation = &"HomeCard"
	_lev_box = VBoxContainer.new()
	_lev_box.add_theme_constant_override("separation", 8)
	card.add_child(_lev_box)
	page.add_child(card)
	page.move_child(card, page.get_node("BottomGap").get_index())


## Aset yang tidak bisa memakai leverage: kartu disembunyikan. Sebelum tahap 6: syaratnya (setelah
## tahap 5 terbuka). Ada posisi: ringkasan + tambah margin / tutup. Belum ada: tombol buka posisi.
func _refresh_leverage(asset: MarketAsset) -> void:
	var lev := GameState.leverage
	var card := _lev_box.get_parent() as Control
	for child in _lev_box.get_children():
		_lev_box.remove_child(child)
		child.queue_free()
	card.visible = not lev.rules_for(asset.id).is_empty() and (lev.is_open() or GameState.progress.is_stage_unlocked(5))
	if not card.visible:
		return
	_lev_box.add_child(_make_label(tr("LEV_CARD_TITLE"), &"SubSectionLabel"))
	if not lev.is_open():
		var note := _make_label(tr("LEV_LOCKED_NOTE"), &"InfoLabel")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lev_box.add_child(note)
		var reqs := VBoxContainer.new()
		_lev_box.add_child(reqs)
		UiText.fill_requirements(reqs, GameState.progress.stage_def(int(lev.data["stage"])))
		return
	var p := lev.position_of(asset.id)
	if p.is_empty():
		var intro := _make_label(tr("LEV_INTRO") % ", ".join(lev.leverage_options(asset.id).map(func(x: int) -> String:
			return "%dx" % x)), &"InfoLabel")
		intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lev_box.add_child(intro)
		var open := UiText.chunky_button(tr("LEV_OPEN_BUTTON"), &"PrimaryButton", &"PrimaryButtonLabel", 72.0, 26)
		open.pressed.connect(func() -> void: leverage_requested.emit(asset.id))
		_lev_box.add_child(open)
		return
	LeverageView.fill_position(_lev_box, p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var uid := int(p["uid"])
	var add := UiText.chunky_button(tr("LEV_ADD_MARGIN"), &"NeutralButton", &"NeutralButtonLabel", 64.0, 24)
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add.pressed.connect(func() -> void: margin_requested.emit(uid))
	var close_button := UiText.chunky_button(tr("LEV_CLOSE_BUTTON"), &"DangerButton", &"DangerButtonLabel", 64.0, 24)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.pressed.connect(func() -> void: close_position_requested.emit(uid))
	row.add_child(add)
	row.add_child(close_button)
	_lev_box.add_child(row)


## Status stop loss / take profit di kartu kepemilikan (hanya aset berharga harian yang dimiliki).
func _refresh_order(asset: MarketAsset) -> void:
	var available := GameState.portfolio.can_have_order(asset.id)
	%OrderLabel.visible = available
	%OrderHolder.visible = available
	if not available:
		return
	var order := GameState.portfolio.order_of(asset.id)
	if order.is_empty():
		%OrderLabel.text = tr("MARKET_ORDER_NONE")
		return
	var off := tr("ORDER_OFF")
	var sl := float(order["stop_loss"])
	var tp := float(order["take_profit"])
	%OrderLabel.text = tr("MARKET_ORDER_STATUS") % [asset.price_text(sl) if sl > 0.0 else off,
		asset.price_text(tp) if tp > 0.0 else off]


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	%ConfirmLabel.text = tr("BTN_CONFIRM_BUY" if mode == Mode.BUY else "BTN_CONFIRM_SELL")
	%AmountEdit.text = ""


func _fill_percent(percent: float) -> void:
	var base: float = GameState.cash if mode == Mode.BUY else GameState.portfolio.holding_value(_selected_id)
	var amount := floori(maxf(base, 0.0) * percent)
	if mode == Mode.SELL and percent >= 1.0:
		amount = ceili(base)  # pastikan "100%" benar-benar menjual semua
	%AmountEdit.text = str(amount)


## Cek dulu lewat GameState.portfolio.trade_quote(); jika valid, minta konfirmasi (layar rincian di main).
func _on_confirm_pressed() -> void:
	var amount := _parse_amount(%AmountEdit.text)
	var quote := GameState.portfolio.trade_quote(_selected_id, mode == Mode.BUY, amount)
	if not quote["ok"]:
		_show_message(tr(quote["error"]), true)
		return
	%FeedbackLabel.text = ""
	trade_requested.emit(_selected_id, mode == Mode.BUY, amount)


## Hasil transaksi dari layar konfirmasi.
func show_trade_result(result: Dictionary) -> void:
	if _selected_id == "":
		return
	if not result.ok:
		_show_message(tr(result.error), true)
		return
	%AmountEdit.text = ""
	var asset := GameState.market.get_asset(_selected_id)
	var costs: float = result.fee + result.tax
	if mode == Mode.BUY:
		if asset.is_interest():
			_show_message(tr("MSG_DEPOSIT_OK") % Fmt.rupiah(result.units * asset.price))
		else:
			_show_message(tr("MSG_BUY_OK") % [Fmt.units(result.units), Fmt.rupiah(costs)])
		return
	var msg: String
	if asset.is_interest():
		msg = tr("MSG_WITHDRAW_OK") % [Fmt.rupiah(result.proceeds), Fmt.rupiah(costs)]
	else:
		msg = tr("MSG_SELL_OK") % [Fmt.units(result.units), Fmt.rupiah(result.proceeds), Fmt.rupiah(costs)]
	if result.penalty:
		msg += " " + tr("MSG_PENALTY")
	_show_message(msg)


func _show_message(text: String, is_error := false) -> void:
	%FeedbackLabel.text = text
	%FeedbackLabel.add_theme_color_override("font_color", Palette.LOSS if is_error else Palette.GAIN)


func _make_label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _wrap_label(text: String, variation: StringName) -> Label:
	var label := _make_label(text, variation)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1  # biarkan kartu menentukan lebar, teks yang membungkus
	return label


func _make_chip(text: String, variation: StringName) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = variation
	chip.add_child(_make_label(text, &"MoodLabel"))
	return chip


## "1.500.000" atau "1500000" -> 1500000
func _parse_amount(text: String) -> int:
	var digits := ""
	for c in text:
		if c >= "0" and c <= "9":
			digits += c
	return digits.to_int() if digits != "" else 0
