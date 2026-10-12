extends Control
## Shell aplikasi: top bar, area konten (5 tab), tombol Lanjut, navigasi bawah, popup.
## Analogi web: ini "layout" + router sederhana. Tiap tab adalah scene terpisah.
##
## Antrean popup: beberapa popup bisa muncul berurutan dalam satu giliran
## (laporan bulan -> instrumen baru terbuka -> event hidup). Popup berikutnya
## baru tampil setelah popup sebelumnya ditutup (signal `closed` dari ModalPopup).

@onready var _screens: Array[Control] = [
	%HomeScreen, %MarketScreen, %PortfolioScreen, %ActivityScreen, %ProfileScreen]
@onready var _nav_buttons: Array[Button] = [
	%NavHome, %NavMarket, %NavPortfolio, %NavActivity, %NavProfile]

var _popup_queue: Array[Callable] = []
var _popup_open := false


func _ready() -> void:
	var group := ButtonGroup.new()
	for i in _nav_buttons.size():
		_nav_buttons[i].button_group = group
		_nav_buttons[i].pressed.connect(_show_screen.bind(i))

	%NextButton.pressed.connect(GameState.advance_month)
	GameState.changed.connect(_refresh_top_bar)
	GameState.month_advanced.connect(func(report: Dictionary) -> void:
		_enqueue(%SummaryPopup.show_report.bind(report)))
	GameState.stage_unlocked.connect(func(stage: Dictionary) -> void:
		_enqueue(%InfoPopup.open.bind(tr("UNLOCK_POPUP_TITLE"),
			tr("UNLOCK_POPUP_BODY") % [tr(stage["name_key"]), UiText.stage_assets_text(int(stage["stage"]))])))
	GameState.event_triggered.connect(func(event: Dictionary) -> void:
		_enqueue(%EventPopup.open.bind(event)))
	%ActivityScreen.quiz_requested.connect(func(question: Dictionary) -> void:
		_enqueue(%QuizPopup.open.bind(question)))
	for popup: ModalPopup in [%SummaryPopup, %InfoPopup, %EventPopup, %QuizPopup]:
		popup.closed.connect(_show_next_popup)

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
	%DateLabel.text = "%s  |  Level %d" % [Fmt.game_date(GameState.month), GameState.level()]
	%NextButton.disabled = GameState.has_pending_event()


func _enqueue(show_popup: Callable) -> void:
	_popup_queue.append(show_popup)
	if not _popup_open:
		_show_next_popup()


func _show_next_popup() -> void:
	if _popup_queue.is_empty():
		_popup_open = false
		return
	_popup_open = true
	_popup_queue.pop_front().call()
