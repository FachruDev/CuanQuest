extends Node
## Gulir seperti aplikasi HP biasa: geser jari dari mana saja di dalam daftar, termasuk di atas kartu & tombol.
##
## Masalah bawaan Godot: geser bawaan ScrollContainer hanya jalan jika sentuhan jatuh langsung di ScrollContainer;
## kartu (PanelContainer) dan tombol menahan sentuhan, jadi pemain harus menyentuh "dasar" layar untuk menggulir.
## Autoload ini membaca sentuhan lebih dulu (_input). Begitu jari bergeser vertikal melewati ambang, daftar di bawah
## jari ikut jari 1:1, tekanan tombol yang sempat terjadi dibatalkan (tidak ikut terpencet), dan setelah jari diangkat
## daftar meluncur lalu melambat. Ketukan saat daftar meluncur hanya menghentikan luncuran. Geser bawaan dimatikan
## (scroll_deadzone) agar tidak menggulir dua kali.
##
## Scrollbar bawaan disembunyikan; gantinya indikator tipis bergaya tema yang muncul saat menggulir dan memudar
## sendiri. Analogi web: seperti "overflow: overlay" + kinetic scrolling di HP.

const SLOP := 12.0  # px layar game sebelum geseran dianggap gulir (di bawahnya tetap ketukan biasa)
const FRICTION := 2.8  # perlambatan luncuran per detik (eksponensial); makin kecil makin jauh meluncur
const MIN_FLING := 120.0  # kecepatan minimal (px/detik) agar luncuran berjalan
const MAX_FLING := 6000.0
const STOP_SPEED := 15.0  # luncuran berhenti di bawah kecepatan ini
const TAP_STOPS_FLING := 250.0  # ketukan saat meluncur secepat ini hanya menghentikan luncuran
const VELOCITY_WINDOW := 100  # ms gerakan terakhir yang dipakai menghitung kecepatan kibasan
const PAUSE_BEFORE_LIFT := 80  # ms; jari diam selama ini sebelum diangkat = tidak meluncur
const NATIVE_OFF := 1_000_000  # scroll_deadzone sebesar ini mematikan geser bawaan
const SYNTH_DEVICE := 4747  # penanda kejadian palsu dari _cancel_press (diabaikan autoload ini)
const FAR := Vector2(-100000, -100000)  # posisi kejadian palsu untuk membatalkan tekanan tombol
const BAR_WIDTH := 6.0
const BAR_MARGIN := 3.0
const BAR_MIN := 36.0
const BAR_COLOR := Color(0.1686, 0.1294, 0.2784, 0.38)  # tinta tema, transparan
const BAR_HOLD := 0.6  # detik indikator tetap terlihat setelah gulir berhenti

var _down := false  # jari/tombol kiri sedang menekan
var _dragging := false
var _swallow := false  # tahan sisa kejadian sentuhan sampai tekanan berikutnya (setelah menggulir)
var _start := Vector2.ZERO
var _scroll: ScrollContainer
var _anchor_y := 0.0  # posisi jari saat gulir mulai
var _anchor_value := 0.0  # posisi gulir saat gulir mulai
var _samples: Array[Vector2] = []  # (waktu ms, posisi y jari) untuk kecepatan kibasan
var _fling: ScrollContainer
var _fling_value := 0.0
var _velocity := 0.0  # px/detik, arah konten (positif = makin ke bawah daftar)
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


## Di HP setiap sentuhan datang dua kali: sentuhan asli (ScreenTouch/ScreenDrag) dan tiruannya sebagai mouse
## (device DEVICE_ID_EMULATION) yang dipakai tombol. Logika gulir hanya membaca kejadian asli (sentuhan di HP, mouse
## di laptop); tiruannya cukup ikut ditahan selama menggulir agar tombol tidak menerimanya.
func _input(event: InputEvent) -> void:
	if event.device == SYNTH_DEVICE:
		return  # pembatal tekanan dari _cancel_press: biarkan sampai ke tombol
	var is_button: bool = event is InputEventScreenTouch \
			or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)
	var is_drag: bool = event is InputEventScreenDrag \
			or (event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT)
	if not is_button and not is_drag:
		return
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) and event.index != 0:
		return  # jari kedua diabaikan
	if event.device != InputEvent.DEVICE_ID_EMULATION:
		if is_button and event.pressed:
			_press(event.position)
		elif is_button:
			_release()
		else:
			_move(event.position)
	if _swallow and not (is_button and event.pressed):
		get_viewport().set_input_as_handled()


func _press(pos: Vector2) -> void:
	var was_flinging := _fling != null and absf(_velocity) >= TAP_STOPS_FLING
	_fling = null
	_down = true
	_dragging = false
	_swallow = false
	_start = pos
	if was_flinging:
		_cancel_press()  # ketukan untuk menghentikan luncuran tidak ikut memencet kartu di bawahnya


func _move(pos: Vector2) -> void:
	if not _down:
		return
	if not _dragging:
		var moved := pos - _start
		if moved.length() < SLOP:
			return
		_down = false
		if absf(moved.y) < absf(moved.x):
			return  # geser horizontal: bukan urusan gulir vertikal
		_scroll = _scroll_at(_start)
		if _scroll == null:
			return
		_down = true
		_dragging = true
		_swallow = true
		_cancel_press()
		_scroll.scroll_vertical = _scroll.scroll_vertical  # setter ini juga menghentikan geser bawaan yang sempat mulai
		_anchor_y = pos.y
		_anchor_value = _scroll.get_v_scroll_bar().value
		_samples.clear()
	if not is_instance_valid(_scroll):
		_down = false
		_dragging = false
		return
	_set_value(_scroll, _anchor_value - (pos.y - _anchor_y))  # isi menempel di jari
	var now := Time.get_ticks_msec()
	_samples.append(Vector2(now, pos.y))
	while _samples.size() > 2 and now - _samples[0].x > VELOCITY_WINDOW:
		_samples.pop_front()


func _release() -> void:
	if _dragging and is_instance_valid(_scroll):
		var speed := _release_speed()
		if absf(speed) >= MIN_FLING:
			_fling = _scroll
			_fling_value = _scroll.get_v_scroll_bar().value
			_velocity = clampf(speed, -MAX_FLING, MAX_FLING)
	_down = false
	_dragging = false


## Kecepatan jari selama ~0,1 detik terakhir; 0 jika jari sempat diam sebelum diangkat.
func _release_speed() -> float:
	if _samples.size() < 2 or Time.get_ticks_msec() - _samples[-1].x > PAUSE_BEFORE_LIFT:
		return 0.0
	var span := (_samples[-1].x - _samples[0].x) / 1000.0
	if span <= 0.0:
		return 0.0
	return -(_samples[-1].y - _samples[0].y) / span


func _process(delta: float) -> void:
	if _fling != null:
		if not is_instance_valid(_fling) or not _fling.is_visible_in_tree():
			_fling = null
		else:
			_fling_value += _velocity * delta
			_velocity *= exp(-FRICTION * delta)
			var room := _room(_fling)
			if _fling_value <= 0.0 or _fling_value >= room or absf(_velocity) < STOP_SPEED:
				_fling_value = clampf(_fling_value, 0.0, room)
				_set_value(_fling, _fling_value)
				_fling = null
			else:
				_set_value(_fling, _fling_value)
	for scroll: ScrollContainer in _bars:
		var bar: Control = _bars[scroll]
		if bar.modulate.a > 0.0:
			_place_bar(scroll, bar)


## ScrollContainer yang menerima geseran di titik ini: kontrol paling atas di bawah jari (urutan sama seperti GUI
## Godot), lalu naik ke induknya sampai ketemu daftar yang bisa digulir. Popup yang menutupi layar ikut menghalangi,
## jadi layar di belakangnya tidak tergulir. Tidak memakai gui_get_hovered_control(): di Android nilainya bisa kosong.
func _scroll_at(pos: Vector2) -> ScrollContainer:
	var node: Node = _control_at(pos)
	while node != null:
		if node is ScrollContainer and node.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED \
				and _room(node) > 1.0:
			return node
		node = node.get_parent()
	return null


func _control_at(pos: Vector2) -> Control:
	var roots: Array = []  # [layer, urutan, Control]
	_collect_roots(get_tree().root, 0, roots)
	roots.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] if a[0] != b[0] else a[1] > b[1])
	for entry: Array in roots:
		var hit := _pick(entry[2], pos)
		if hit != null:
			return hit
	return null


## Kontrol akar = Control yang induknya bukan Control. Yang belakangan di pohon / layer lebih tinggi digambar di atas.
func _collect_roots(node: Node, layer: int, out: Array) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			if child.visible:
				_collect_roots(child, child.layer, out)
		elif child is Window:
			continue
		elif child is Control:
			if child.is_visible_in_tree():
				out.append([layer, out.size(), child])
		else:
			_collect_roots(child, layer, out)


func _pick(control: Control, pos: Vector2) -> Control:
	if not control.visible:
		return null
	var local := control.get_global_transform_with_canvas().affine_inverse() * pos
	var inside := Rect2(Vector2.ZERO, control.size).has_point(local)
	if control.clip_contents and not inside:
		return null
	for i in range(control.get_child_count(true) - 1, -1, -1):
		var child := control.get_child(i, true) as Control
		if child != null and not child.top_level:
			var hit := _pick(child, pos)
			if hit != null:
				return hit
	if inside and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return control
	return null


## Membatalkan tekanan tombol/kontrol yang sempat terjadi: gerakan palsu ke luar layar (tombol mencatat "jari sudah
## keluar") lalu lepasan palsu di sana, jadi tombol tidak terpencet. Dikirim dalam koordinat lokal agar posisinya
## tidak ikut diskalakan layar HP, dan diberi device khusus agar autoload ini tidak membacanya sebagai jari.
func _cancel_press() -> void:
	_send_cancel.call_deferred()


func _send_cancel() -> void:
	var away := InputEventMouseMotion.new()
	away.device = SYNTH_DEVICE
	away.position = FAR
	away.global_position = FAR
	away.button_mask = MOUSE_BUTTON_MASK_LEFT
	var release := InputEventMouseButton.new()
	release.device = SYNTH_DEVICE
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = FAR
	release.global_position = FAR
	get_viewport().push_input(away, true)
	get_viewport().push_input(release, true)


func _room(scroll: ScrollContainer) -> float:
	var v := scroll.get_v_scroll_bar()
	return maxf(v.max_value - v.page, 0.0)


func _set_value(scroll: ScrollContainer, value: float) -> void:
	scroll.get_v_scroll_bar().value = clampf(value, 0.0, _room(scroll))


func _show_bar(scroll: ScrollContainer) -> void:
	var bar: Control = _bars.get(scroll)
	if bar == null:
		return
	if _room(scroll) <= 1.0:
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
	var y := BAR_MARGIN + (track - length) * clampf(v.value / maxf(_room(scroll), 1.0), 0.0, 1.0)
	var style := StyleBoxFlat.new()
	style.bg_color = BAR_COLOR
	style.set_corner_radius_all(int(BAR_WIDTH / 2.0))
	bar.draw_style_box(style, Rect2(0, y, BAR_WIDTH, length))
