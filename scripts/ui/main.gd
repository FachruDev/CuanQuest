extends Control
## Layar prototipe: 1 aset, grafik, beli/jual, tombol Lanjut.
## Node yang diawali "%" adalah "unique name" di scene (mirip document.getElementById).

const ASSET_ID := "NUSA"
const QUICK_PERCENTS := [0.25, 0.5, 1.0]

enum Mode { BUY, SELL }

var mode := Mode.BUY


func _ready() -> void:
	var group := ButtonGroup.new()  # supaya Beli/Jual saling eksklusif seperti radio button
	%ModeBuy.button_group = group
	%ModeSell.button_group = group
	%ModeBuy.button_pressed = true
	%ModeBuy.pressed.connect(_set_mode.bind(Mode.BUY))
	%ModeSell.pressed.connect(_set_mode.bind(Mode.SELL))

	var quick_buttons := [%Quick25, %Quick50, %Quick100]
	for i in quick_buttons.size():
		quick_buttons[i].pressed.connect(_fill_percent.bind(QUICK_PERCENTS[i]))

	%AmountEdit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	%ConfirmButton.pressed.connect(_on_confirm_pressed)
	%NextButton.pressed.connect(_on_next_pressed)

	GameState.changed.connect(_refresh)
	_set_mode(Mode.BUY)
	_refresh()


func _refresh() -> void:
	var asset := GameState.market.get_asset(ASSET_ID)

	%CashValue.text = Fmt.rupiah(GameState.cash)
	%NetWorthValue.text = Fmt.rupiah(GameState.net_worth())
	%DateLabel.text = Fmt.game_date(GameState.month)

	%AssetName.text = tr(asset.name_key)
	%PriceLabel.text = Fmt.rupiah(asset.price)
	var change := asset.change_ratio()
	%ChangeLabel.text = Fmt.percent(change)
	%ChangeLabel.modulate = Color("#2ecc71") if change >= 0 else Color("#e74c3c")
	%Chart.set_data(asset.history)

	var units := GameState.units_of(ASSET_ID)
	if units > 0.0:
		var value := GameState.holding_value(ASSET_ID)
		var cost := GameState.cost_of(ASSET_ID)
		%HoldingLabel.text = tr("LBL_HOLDING") % [
			Fmt.number(units), Fmt.rupiah(value), Fmt.percent((value - cost) / cost)]
	else:
		%HoldingLabel.text = tr("LBL_NO_HOLDING")


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	%ConfirmButton.text = tr("BTN_CONFIRM_BUY" if mode == Mode.BUY else "BTN_CONFIRM_SELL")
	%AmountEdit.text = ""


func _fill_percent(percent: float) -> void:
	var base: float = GameState.cash if mode == Mode.BUY else GameState.holding_value(ASSET_ID)
	var amount := floori(base * percent)
	if mode == Mode.SELL and percent >= 1.0:
		amount = ceili(base)  # pastikan "100%" benar-benar menjual semua
	%AmountEdit.text = str(amount)


func _on_confirm_pressed() -> void:
	var amount := _parse_amount(%AmountEdit.text)
	var result: Dictionary
	if mode == Mode.BUY:
		result = GameState.buy(ASSET_ID, amount)
		if result.ok:
			_show_message(tr("MSG_BUY_OK") % [Fmt.number(result.units), Fmt.rupiah(result.fee)])
	else:
		result = GameState.sell(ASSET_ID, amount)
		if result.ok:
			_show_message(tr("MSG_SELL_OK") % [
				Fmt.number(result.units), Fmt.rupiah(result.proceeds), Fmt.rupiah(result.fee)])

	if result.ok:
		%AmountEdit.text = ""
	else:
		_show_message(tr(result.error), true)


func _on_next_pressed() -> void:
	GameState.advance_month()
	var asset := GameState.market.get_asset(ASSET_ID)
	_show_message(tr("MSG_NEW_MONTH") % [tr(asset.name_key), Fmt.percent(asset.change_ratio())])


func _show_message(text: String, is_error := false) -> void:
	%FeedbackLabel.text = text
	%FeedbackLabel.modulate = Color("#e74c3c") if is_error else Color(1, 1, 1, 0.85)


## "1.500.000" atau "1500000" -> 1500000
func _parse_amount(text: String) -> int:
	var digits := ""
	for c in text:
		if c >= "0" and c <= "9":
			digits += c
	return digits.to_int() if digits != "" else 0
