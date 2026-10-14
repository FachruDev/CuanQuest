extends MarginContainer
## Tab Pasar (tema "Senja Cuan"). Dua "view" dalam satu scene (mirip route /market dan /market/:id):
## - ListView  : berita terbaru, kondisi pasar, daftar aset per kelas
## - DetailView: grafik/info bunga + beli/jual untuk satu aset
## Node yang diawali "%" adalah "unique name" di scene (mirip document.getElementById).

const QUICK_PERCENTS := [0.25, 0.5, 1.0]
const CLASS_ORDER := ["savings", "deposit", "mutual_fund", "stock", "crypto"]
## Warna teks risiko 1-5 (cukup gelap agar terbaca di kartu putih).
const RISK_COLORS := [Color("#1e7f5c"), Color("#1e7f5c"), Color("#a86a12"), Color("#c25a1e"), Color("#c2452d")]
const REGIME_CHIPS := {"bull": &"MoodGreen", "sideways": &"MoodNeutral", "bear": &"MoodRed"}
const NEWS_SHOWN := 4

enum Mode { BUY, SELL }

var mode := Mode.BUY
var _selected_id := ""
var _rows: Dictionary = {}  # asset_id -> { "button": Button, "risk": Label, "price": Label, "change": Label }


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
	%BackButton.pressed.connect(_show_list)

	_build_asset_list()
	UiText.build_period_buttons(%PeriodRow, %Chart, 3, [1, 3, 12, 0])  # data harian
	GameState.changed.connect(_refresh)
	_show_list()


func _refresh() -> void:
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
		var unlocked := GameState.is_asset_unlocked(asset_id)
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


## Chip kondisi pasar: tren saham, tren kripto, suku bunga acuan, inflasi.
func _refresh_mood(market: Market) -> void:
	for child in %MoodRow.get_children():
		%MoodRow.remove_child(child)
		child.queue_free()
	for kind: String in ["stock", "crypto"]:
		var regime := market.regime_of(kind)
		var text := tr("MARKET_MOOD_" + kind.to_upper()) % tr("REGIME_" + regime.to_upper())
		%MoodRow.add_child(_make_chip(text, REGIME_CHIPS.get(regime, &"MoodNeutral")))
	%MoodRow.add_child(_make_chip(tr("MARKET_MOOD_RATE") % Fmt.percent_plain(market.policy_rate), &"MoodGold"))
	%MoodRow.add_child(_make_chip(tr("MARKET_MOOD_INFLATION") % Fmt.percent_plain(market.inflation), &"MoodNeutral"))


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


# --- Detail view --------------------------------------------------------------

func _show_detail(asset_id: String) -> void:
	_selected_id = asset_id
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
	%RiskWarning.visible = GameState.exceeds_risk_profile(asset)
	%RiskWarningLabel.text = tr("MARKET_RISK_WARNING") % tr(GameState.risk_profile()["name"])

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
		%InfoLabel.text = tr("INFO_TRADED") % [
			Fmt.percent_plain(asset.volatility),
			Fmt.percent_plain(asset.buy_fee),
			Fmt.percent_plain(asset.sell_fee)]

	var unlocked := GameState.is_asset_unlocked(_selected_id)
	%TradeBox.visible = unlocked
	%LockedBox.visible = not unlocked
	if not unlocked:
		UiText.fill_requirements(%LockedReqs, GameState.stage_def(asset.stage))

	var units := GameState.units_of(_selected_id)
	if units > 0.0:
		var value := GameState.holding_value(_selected_id)
		var cost := GameState.cost_of(_selected_id)
		var text: String
		if asset.is_interest():
			text = tr("LBL_BALANCE") % [Fmt.rupiah(value), Fmt.signed_rupiah(value - cost)]
		else:
			text = tr("LBL_HOLDING") % [Fmt.units(units), Fmt.rupiah(value), Fmt.percent((value - cost) / cost)]
		if GameState.is_locked(_selected_id):
			text += "\n" + tr("LBL_LOCKED_UNTIL") % Fmt.game_date(GameState.locked_until(_selected_id))
		%HoldingLabel.text = text
	else:
		%HoldingLabel.text = tr("LBL_NO_HOLDING")


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	%ConfirmLabel.text = tr("BTN_CONFIRM_BUY" if mode == Mode.BUY else "BTN_CONFIRM_SELL")
	%AmountEdit.text = ""


func _fill_percent(percent: float) -> void:
	var base: float = GameState.cash if mode == Mode.BUY else GameState.holding_value(_selected_id)
	var amount := floori(maxf(base, 0.0) * percent)
	if mode == Mode.SELL and percent >= 1.0:
		amount = ceili(base)  # pastikan "100%" benar-benar menjual semua
	%AmountEdit.text = str(amount)


func _on_confirm_pressed() -> void:
	var amount := _parse_amount(%AmountEdit.text)
	var result: Dictionary
	if mode == Mode.BUY:
		result = GameState.buy(_selected_id, amount)
		if result.ok and GameState.market.get_asset(_selected_id).is_interest():
			_show_message(tr("MSG_DEPOSIT_OK") % Fmt.rupiah(amount))
		elif result.ok:
			_show_message(tr("MSG_BUY_OK") % [Fmt.units(result.units), Fmt.rupiah(result.fee)])
	else:
		result = GameState.sell(_selected_id, amount)
		if result.ok:
			var msg: String
			if GameState.market.get_asset(_selected_id).is_interest():
				msg = tr("MSG_WITHDRAW_OK") % [Fmt.rupiah(result.proceeds), Fmt.rupiah(result.fee)]
			else:
				msg = tr("MSG_SELL_OK") % [
					Fmt.units(result.units), Fmt.rupiah(result.proceeds), Fmt.rupiah(result.fee)]
			if result.penalty:
				msg += " " + tr("MSG_PENALTY")
			_show_message(msg)

	if result.ok:
		%AmountEdit.text = ""
	else:
		_show_message(tr(result.error), true)


func _show_message(text: String, is_error := false) -> void:
	%FeedbackLabel.text = text
	%FeedbackLabel.add_theme_color_override("font_color", Palette.LOSS if is_error else Palette.GAIN)


func _make_label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
