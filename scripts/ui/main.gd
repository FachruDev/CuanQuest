extends Control
## Shell aplikasi: top bar, area konten (5 tab), tombol Lanjut, navigasi bawah.
## Analogi web: ini "layout" + router sederhana. Tiap tab adalah scene terpisah.

@onready var _screens: Array[Control] = [
	%HomeScreen, %MarketScreen, %PortfolioScreen, %ActivityScreen, %ProfileScreen]
@onready var _nav_buttons: Array[Button] = [
	%NavHome, %NavMarket, %NavPortfolio, %NavActivity, %NavProfile]


func _ready() -> void:
	var group := ButtonGroup.new()
	for i in _nav_buttons.size():
		_nav_buttons[i].button_group = group
		_nav_buttons[i].pressed.connect(_show_screen.bind(i))

	%NextButton.pressed.connect(GameState.advance_month)
	GameState.changed.connect(_refresh_top_bar)
	GameState.month_advanced.connect(%SummaryPopup.show_report)

	_nav_buttons[0].button_pressed = true
	_show_screen(0)
	_refresh_top_bar()


func _show_screen(index: int) -> void:
	_nav_buttons[index].button_pressed = true  # lewat ButtonGroup: tombol lain otomatis lepas
	for i in _screens.size():
		_screens[i].visible = i == index


func _refresh_top_bar() -> void:
	%CashValue.text = Fmt.rupiah(GameState.cash)
	%CashValue.modulate = MonthReport.RED if GameState.cash < 0 else Color.WHITE
	%NetWorthValue.text = Fmt.rupiah(GameState.net_worth())
	%DateLabel.text = Fmt.game_date(GameState.month)
