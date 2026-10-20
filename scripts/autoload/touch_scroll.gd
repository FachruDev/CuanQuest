extends Node
## Gulir dengan geser jari dari mana saja di dalam ScrollContainer, termasuk di atas kartu & tombol.
##
## Masalah bawaan Godot: geser bawaan ScrollContainer hanya jalan jika sentuhan jatuh langsung di ScrollContainer;
## kartu (PanelContainer) dan tombol menahan sentuhan, jadi pemain harus menyentuh "dasar" layar untuk menggulir.
## Autoload ini membaca gerakan jari lebih dulu (_input): begitu jari bergeser vertikal melewati ambang, ScrollContainer
## di bawah jari digulir manual, tekanan tombol yang sempat terjadi dibatalkan (tidak ikut terpencet), lalu ada
## luncuran (inersia) setelah jari diangkat. Geser bawaan dimatikan (scroll_deadzone) agar tidak menggulir dua kali.
##
## Scrollbar bawaan disembunyikan; gantinya indikator tipis bergaya tema yang muncul saat menggulir dan memudar
## sendiri. Analogi web: seperti "overflow: overlay" + kinetic scrolling di HP.

const START_DISTANCE := 12.0  # px layar sebelum geseran dianggap gulir (di bawahnya tetap ketukan biasa)
const FRICTION := 4.5  # perlambatan luncuran per detik (eksponensial)
const MIN_FLING := 60.0  # kecepatan minimal (px/detik) agar luncuran berjalan
const NATIVE_OFF := 1_000_000  # scroll_deadzone sebesar ini mematikan geser bawaan
const BAR_WIDTH := 6.0
const BAR_MARGIN := 3.0
const BAR_MIN := 36.0
const BAR_COLOR := Color(0.1686, 0.1294, 0.2784, 0.38)  # tinta tema, transparan
const BAR_HOLD := 0.6  # detik indikator tetap terlihat setelah gulir berhenti
const FAR := Vector2(-100000, -100000)  # posisi kejadian palsu untuk membatalkan tekanan tombol

var _pressing := false
var _dragging := false
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _scroll: ScrollContainer
var _velocity := 0.0  # px/detik, arah konten (positif = scroll_vertical bertambah)
var _last_motion_ms := 0
var _fling: ScrollContainer
var _bars: Dictionary = {}  # ScrollContainer -> Control indikator


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.find_children("*", "ScrollContainer", true, false):
		_on_node_added(node)


func _on_node_added(node: Node) -> void:
	if node is ScrollContainer:
		_setup.call_deferred(node)


func _setup(scroll: ScrollContainer) -> void:
	if not is_instance_valid(scroll) or _bars.has(scroll):
		return
	scroll.scroll_deadzone = NATIVE_OFF
	if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var bar := Control.new()
	bar.top_level = true  # tidak ikut ditata/digulir sebagai isi ScrollContainer
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.modulate.a = 0.0
	bar.z_index = 10
	bar.draw.connect(_draw_bar.bind(bar, scroll))
	scroll.add_child(bar, false, Node.INTERNAL_MODE_BACK)
	_bars[scroll] = bar
	scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: _show_bar(scroll))
	scroll.tree_exiting.connect(func() -> void: _bars.erase(scroll))


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position == FAR:
			return  # lepasan palsu dari _cancel_press: biarkan sampai ke tombol
		if event.pressed:
			_pressing = true
			_dragging = false
			_start = event.position
			_last = event.position
			_velocity = 0.0
			_fling = null  # sentuhan baru menghentikan luncuran
		else:
			if _dragging:
				get_viewport().set_input_as_handled()  # tombol tidak menerima lepasan setelah gulir
				if absf(_velocity) >= MIN_FLING and Time.get_ticks_msec() - _last_motion_ms < 90:
					_fling = _scroll
			_pressing = false
			_dragging = false
		return
	if event is InputEventMouseMotion and event.position == FAR:
		return  # gerakan palsu dari _cancel_press
	if event is InputEventMouseMotion and _pressing and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if not _dragging:
			var moved: Vector2 = event.position - _start
			if absf(moved.y) < START_DISTANCE or absf(moved.y) < absf(moved.x):
				return
			_scroll = _scroll_under_pointer()
			if _scroll == null:
				_pressing = false  # geser horizontal / di luar area gulir: biarkan kontrol lain
				return
			_dragging = true
			_cancel_press()
			_last = event.position
			_last_motion_ms = Time.get_ticks_msec()
		var dy: float = event.position.y - _last.y
		_last = event.position
		var now := Time.get_ticks_msec()
		var dt := maxf((now - _last_motion_ms) / 1000.0, 0.001)
		_last_motion_ms = now
		_velocity = lerpf(_velocity, -dy / dt, 0.4)
		_scroll_by(_scroll, -dy)
		get_viewport().set_input_as_handled()
		return
	if _dragging and (event is InputEventScreenDrag or event is InputEventScreenTouch):
		get_viewport().set_input_as_handled()  # aliran sentuhan asli juga ditahan selama menggulir


func _process(delta: float) -> void:
	if _fling != null:
		if not is_instance_valid(_fling) or not _fling.is_visible_in_tree():
			_fling = null
		else:
			var before := _fling.scroll_vertical
			_scroll_by(_fling, _velocity * delta)
			_velocity *= exp(-FRICTION * delta)
			if absf(_velocity) < MIN_FLING * 0.5 or _fling.scroll_vertical == before:
				_fling = null
	for scroll: ScrollContainer in _bars:
		var bar: Control = _bars[scroll]
		if bar.modulate.a > 0.0:
			_place_bar(scroll, bar)


## ScrollContainer pertama (dari kontrol di bawah jari ke atas) yang isinya bisa digulir vertikal.
## Kontrol di bawah jari dipakai agar popup di atas layar ikut menghalangi (latar tidak ikut tergulir).
func _scroll_under_pointer() -> ScrollContainer:
	var node: Node = get_viewport().gui_get_hovered_control()
	while node != null:
		if node is ScrollContainer and node.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			var v: ScrollBar = node.get_v_scroll_bar()
			if v.max_value - v.page > 1.0:
				return node
		node = node.get_parent()
	return null


## Membatalkan tekanan tombol/kontrol yang sempat terjadi: gerakan palsu ke luar layar (tombol mencatat "jari sudah
## keluar") lalu lepasan palsu di sana, jadi tombol tidak terpencet. Tanpa gerakan itu tombol mengira jari masih di
## atasnya, karena gerakan asli selama menggulir ditahan autoload ini.
func _cancel_press() -> void:
	var away := InputEventMouseMotion.new()
	away.position = FAR
	away.global_position = FAR
	away.button_mask = MOUSE_BUTTON_MASK_LEFT
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = FAR
	release.global_position = FAR
	get_viewport().push_input.call_deferred(away)
	get_viewport().push_input.call_deferred(release)


func _scroll_by(scroll: ScrollContainer, amount: float) -> void:
	var v := scroll.get_v_scroll_bar()
	scroll.scroll_vertical = int(clampf(scroll.scroll_vertical + amount, 0.0, maxf(v.max_value - v.page, 0.0)))


func _show_bar(scroll: ScrollContainer) -> void:
	var bar: Control = _bars.get(scroll)
	if bar == null:
		return
	var v := scroll.get_v_scroll_bar()
	if v.max_value - v.page <= 1.0:
		return
	_place_bar(scroll, bar)
	bar.queue_redraw()
	bar.modulate.a = 1.0
	if bar.has_meta("tween"):
		var old: Tween = bar.get_meta("tween")
		if old and old.is_valid():
			old.kill()
	var tween := bar.create_tween()
	tween.tween_interval(BAR_HOLD)
	tween.tween_property(bar, "modulate:a", 0.0, 0.35)
	bar.set_meta("tween", tween)


func _place_bar(scroll: ScrollContainer, bar: Control) -> void:
	var rect := scroll.get_global_rect()
	bar.global_position = Vector2(rect.end.x - BAR_WIDTH - BAR_MARGIN, rect.position.y)
	bar.size = Vector2(BAR_WIDTH, rect.size.y)
	bar.visible = scroll.is_visible_in_tree()
	bar.queue_redraw()


func _draw_bar(bar: Control, scroll: ScrollContainer) -> void:
	var v := scroll.get_v_scroll_bar()
	if v.max_value <= 0.0:
		return
	var track := bar.size.y - BAR_MARGIN * 2.0
	var length := clampf(track * v.page / v.max_value, BAR_MIN, track)
	var room := maxf(v.max_value - v.page, 1.0)
	var y := BAR_MARGIN + (track - length) * clampf(v.value / room, 0.0, 1.0)
	var style := StyleBoxFlat.new()
	style.bg_color = BAR_COLOR
	style.set_corner_radius_all(int(BAR_WIDTH / 2.0))
	bar.draw_style_box(style, Rect2(0, y, BAR_WIDTH, length))
