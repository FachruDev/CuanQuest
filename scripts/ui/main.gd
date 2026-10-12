extends Control
## Shell aplikasi: top bar, area konten (5 tab), tombol Lanjut, navigasi bawah, popup.
## Analogi web: ini "layout" + router sederhana. Tiap tab adalah scene terpisah.
##
## Antrean popup: beberapa popup bisa muncul berurutan dalam satu giliran
## (laporan bulan -> instrumen baru terbuka -> event hidup). Popup berikutnya
## baru tampil setelah popup sebelumnya ditutup (signal `closed` dari ModalPopup).

const END_SCENE := "res://scenes/end_screen.tscn"

## Petunjuk kontekstual saat tab dibuka pertama kali (index tab -> key teks).
const TAB_HINTS := {1: "HINT_MARKET", 2: "HINT_PORTFOLIO", 3: "HINT_ACTIVITY", 4: "HINT_PROFILE"}
const BOLT_ICON := preload("res://assets/icons/bolt.svg")
const BOLT_FULL := Color("#ffc95c")
const BOLT_EMPTY := Color("#5a4e78")
const NAV_MUTED := Color("#7a6650")
## Tab yang belum didesain ulang (teks putih) ditaruh di panel gelap sementara.
const REDESIGNED_TABS := [0]

@onready var _screens: Array[Control] = [
	%HomeScreen, %MarketScreen, %PortfolioScreen, %ActivityScreen, %ProfileScreen]
@onready var _nav_buttons: Array[Button] = [
	%NavHome, %NavMarket, %NavPortfolio, %NavActivity, %NavProfile]

var _popup_queue: Array[Callable] = []
var _popup_open := false


func _ready() -> void:
	# Saat scene ini dijalankan langsung dari editor (F6) tanpa lewat layar judul.
	if not GameState.is_active:
		GameState.new_game()

	var group := ButtonGroup.new()
	for i in _nav_buttons.size():
		_nav_buttons[i].button_group = group
		_nav_buttons[i].pressed.connect(_show_screen.bind(i))
		_nav_buttons[i].toggled.connect(_style_nav.bind(_nav_buttons[i]))
		_style_nav(false, _nav_buttons[i])
	%PlayerAvatar.avatar_index = GameState.avatar
	%PlayerName.text = GameState.player_name

	%NextButton.pressed.connect(func() -> void:
		Sfx.play("coin")
		GameState.advance_month())
	%Skip6Button.pressed.connect(_fast_forward.bind(6))
	%Skip12Button.pressed.connect(_fast_forward.bind(12))
	%GlossaryButton.pressed.connect(func() -> void: _enqueue(%GlossaryPopup.open))
	%ProfileScreen.glossary_requested.connect(func() -> void: _enqueue(%GlossaryPopup.open))
	GameState.changed.connect(_refresh_top_bar)
	GameState.month_advanced.connect(func(report: Dictionary) -> void:
		_enqueue(%SummaryPopup.show_report.bind(report)))
	GameState.stage_unlocked.connect(func(stage: Dictionary) -> void:
		_enqueue(%InfoPopup.open.bind(tr("UNLOCK_POPUP_TITLE"),
			tr("UNLOCK_POPUP_BODY") % [tr(stage["name_key"]), UiText.stage_assets_text(int(stage["stage"]))])))
	GameState.event_triggered.connect(func(event: Dictionary) -> void:
		_enqueue(%EventPopup.open.bind(event)))
	GameState.goal_reached.connect(func(goal: String) -> void:
		_enqueue(%InfoPopup.open.bind(tr("GOAL_TITLE_" + goal.to_upper()), tr("GOAL_BODY_" + goal.to_upper()),
			tr("GOAL_FINISH_NOW"), GameState.finish_game.bind("win", goal))))
	# Game berakhir: popup yang masih mengantre (event, unlock) dibuang karena tidak relevan lagi.
	# Popup yang sedang tampil (mis. laporan bulan terakhir) tetap dibaca dulu, lalu pindah ke layar akhir.
	GameState.game_ended.connect(func(_result: Dictionary) -> void:
		_popup_queue.clear()
		_enqueue(func() -> void: get_tree().change_scene_to_file(END_SCENE)))
	%ProfileScreen.text_requested.connect(func(title: String, body: String) -> void:
		_enqueue(%TextPopup.open.bind(title, body)))
	%ActivityScreen.quiz_requested.connect(func(question: Dictionary) -> void:
		_enqueue(%QuizPopup.open.bind(question)))
	for popup: ModalPopup in [%SummaryPopup, %InfoPopup, %EventPopup, %QuizPopup, %GlossaryPopup, %TextPopup]:
		popup.closed.connect(_show_next_popup)

	_show_screen(0)
	_refresh_top_bar()
	# Event yang belum diputuskan saat game disimpan muncul lagi setelah dimuat.
	if GameState.has_pending_event():
		_enqueue(%EventPopup.open.bind(GameState.pending_event))


func _show_screen(index: int) -> void:
	_nav_buttons[index].button_pressed = true  # lewat ButtonGroup: tombol lain otomatis lepas
	for i in _screens.size():
		_screens[i].visible = i == index
	%LegacyFrame.visible = index not in REDESIGNED_TABS
	if TAB_HINTS.has(index) and GameState.consume_hint(TAB_HINTS[index]):
		_enqueue(%InfoPopup.open.bind(tr("HINT_TITLE"), tr(TAB_HINTS[index])))


func _refresh_top_bar() -> void:
	%CashValue.text = Fmt.rupiah(GameState.cash)
	%CashValue.add_theme_color_override("font_color", Palette.LOSS if GameState.cash < 0 else Palette.INK)
	%NetWorthValue.text = Fmt.rupiah(GameState.net_worth())
	%DateLabel.text = Fmt.game_date(GameState.month)
	%AgeLabel.text = tr("TOPBAR_AGE") % GameState.age()
	%LevelLabel.text = tr("TOPBAR_LEVEL") % GameState.level()
	_refresh_energy()
	var busy := GameState.has_pending_event() or GameState.is_over
	for button: Button in [%NextButton, %Skip6Button, %Skip12Button]:
		button.disabled = busy
		button.get_child(0).modulate.a = 0.45 if busy else 1.0


## Satu ikon petir per poin energi bulan ini: kuning = tersisa, ungu redup = terpakai.
func _refresh_energy() -> void:
	var icons: Control = %EnergyIcons
	while icons.get_child_count() < GameState.energy_capacity:
		var bolt := TextureRect.new()
		bolt.texture = BOLT_ICON
		bolt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bolt.custom_minimum_size = Vector2(18, 22)
		bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icons.add_child(bolt)
	for i in icons.get_child_count():
		var bolt: TextureRect = icons.get_child(i)
		bolt.visible = i < GameState.energy_capacity
		bolt.self_modulate = BOLT_FULL if i < GameState.energy else BOLT_EMPTY
	%EnergyPill.tooltip_text = tr("TOPBAR_ENERGY") % [GameState.energy, GameState.energy_capacity]


## Tab aktif: ikon & label tinta di atas pil emas; tab lain: cokelat redup.
func _style_nav(active: bool, button: Button) -> void:
	var color := Palette.INK if active else NAV_MUTED
	button.get_node("Content/Icon").self_modulate = color
	button.get_node("Content/Label").add_theme_color_override("font_color", color)


## Lompat beberapa bulan. Berhenti otomatis jika ada event/peringatan (lihat GameState.fast_forward).
func _fast_forward(months: int) -> void:
	Sfx.play("coin")
	GameState.fast_forward(months)


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
