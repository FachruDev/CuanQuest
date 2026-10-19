class_name PriceChart
extends Control
## Line chart sederhana yang digambar manual lewat _draw().
## Analogi web: seperti menggambar di <canvas> dengan ctx.lineTo().
##
## Data bisa harian (harga aset) atau bulanan (kekayaan bersih). `points_per_period`
## menentukan berapa titik membentuk satu "bulan" saat memilih periode.

signal reveal_finished

const PADDING := 16.0

@export var max_points := 24   ## batas titik saat periode = 0 ("Semua") dan tidak ada data jangka panjang
@export var period := 0        ## jumlah bulan yang ditampilkan; 0 = semua
@export var points_per_period := 1  ## titik per bulan: 1 untuk data bulanan, 21/30 untuk data harian
@export var up_color := Color("#2ecc71")
@export var down_color := Color("#e74c3c")
@export var background_color := Color("#182030")
@export var grid_color := Color(1, 1, 1, 0.08)
@export var empty_text_key := "CHART_EMPTY"
## Gaya terang "Senja Cuan": tanpa latar, area di bawah garis diwarnai, teks cokelat.
@export var light_style := false:
	set(value):
		light_style = value
		if value:
			up_color = Palette.GAIN
			down_color = Palette.LOSS
			background_color = Color(0, 0, 0, 0)
			grid_color = Color("#f4eadb")
		queue_redraw()

## Bagian garis yang sudah tergambar (0..1), dipakai animasi play_reveal().
var reveal := 1.0:
	set(value):
		reveal = clampf(value, 0.0, 1.0)
		queue_redraw()

const LIGHT_TEXT := Color("#8a6e4e")
const MARK_FONT := 14

var _all: Array[float] = []   # semua data dari pemanggil
var _long: Array[float] = []  # data jangka panjang (mis. penutupan bulanan) untuk periode "Semua"
var _data: Array[float] = []  # bagian yang sedang digambar (sesuai periode)
var _offset := 0  # indeks _all untuk titik pertama _data
var _marks: Array = []  # penanda tegak [indeks di _all, teks] (mis. pergantian bab di layar akhir, v2b)
var _reveal_tween: Tween


func _ready() -> void:
	resized.connect(queue_redraw)


func set_data(values: Array[float]) -> void:
	_all.assign(values)
	_apply_period()


## Data jangka panjang yang dipakai saat periode = 0 ("Semua"). Kosongkan untuk memakai data biasa.
func set_long_data(values: Array[float]) -> void:
	_long.assign(values)
	_apply_period()


## Garis tegak dengan teks di bagian atas grafik, mis. pergantian bab kehidupan: [[indeks, teks], ...].
## Teks yang tidak muat di ruas grafiknya tidak digambar.
func set_marks(marks: Array) -> void:
	_marks = marks
	queue_redraw()


## Periode N bulan butuh N x points_per_period + 1 titik (harga awal + perubahannya).
func set_period(months: int) -> void:
	period = months
	_apply_period()


## Animasi garis tergambar dari kiri ke kanan. Mengetuk grafik melewati animasi.
func play_reveal(duration := 1.5) -> void:
	skip_reveal()
	reveal = 0.0
	_reveal_tween = create_tween()
	_reveal_tween.tween_property(self, "reveal", 1.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_reveal_tween.finished.connect(reveal_finished.emit)


func skip_reveal() -> void:
	if _reveal_tween and _reveal_tween.is_running():
		_reveal_tween.kill()
		reveal = 1.0
		reveal_finished.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		skip_reveal()


func _apply_period() -> void:
	if period == 0 and not _long.is_empty():
		_data.assign(_long)
		_offset = 0
	else:
		var count := period * points_per_period + 1 if period > 0 else max_points
		_data.assign(_all.slice(-count))
		_offset = _all.size() - _data.size()
	queue_redraw()  # minta Godot memanggil _draw() di frame berikutnya


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	var text_color := LIGHT_TEXT if light_style else Color(1, 1, 1, 0.6)
	if _data.size() < 2:
		draw_string(get_theme_default_font(), Vector2(0, size.y / 2.0), tr(empty_text_key),
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, text_color)
		return

	# Skala sumbu Y dihitung dari SEMUA data, agar garis tidak "melompat" selama animasi.
	var lo: float = _data.min()
	var hi: float = _data.max()
	if hi - lo < 0.0001:
		hi = lo + 1.0

	var area := Rect2(Vector2(PADDING, PADDING), size - Vector2(PADDING, PADDING) * 2)
	var label_size := 20 if not light_style else 16
	if light_style:  # sisakan ruang di atas & bawah agar label harga tidak menimpa garis
		area = area.grow_individual(0, -label_size - 4, 0, -label_size - 4)

	for i in 5:  # garis bantu horizontal
		var y := area.position.y + area.size.y * i / 4.0
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), grid_color)
	_draw_marks(area, text_color)

	var all_points := PackedVector2Array()
	for i in _data.size():
		var x := area.position.x + area.size.x * i / (_data.size() - 1)
		var y := area.position.y + area.size.y * (1.0 - (_data[i] - lo) / (hi - lo))
		all_points.append(Vector2(x, y))

	# Selama animasi: hanya sebagian titik, ujungnya diinterpolasi agar gerakannya mulus.
	var points := all_points
	var last_value := _data[-1]
	if reveal < 1.0:
		var progress := reveal * (all_points.size() - 1)
		var whole := floori(progress)
		points = all_points.slice(0, whole + 1)
		if whole < all_points.size() - 1:
			var t := progress - whole
			points.append(all_points[whole].lerp(all_points[whole + 1], t))
			last_value = lerpf(_data[whole], _data[whole + 1], t)
		else:
			last_value = _data[whole]
		if points.size() < 2:
			points.append(points[0])

	var color := up_color if last_value >= _data[0] else down_color
	if light_style and points[-1].x - points[0].x > 1.0:  # area lembut di bawah garis
		var fill := points.duplicate()
		fill.append(Vector2(points[-1].x, area.end.y))
		fill.append(Vector2(area.position.x, area.end.y))
		draw_colored_polygon(fill, Color(color, 0.15))
	draw_polyline(points, color, 4.0, true)
	if light_style:
		draw_circle(points[-1], 9.0, Color.WHITE)
	draw_circle(points[-1], 7.0 if not light_style else 6.0, color)

	var font := get_theme_default_font()
	var hi_y := area.position.y + label_size  # gaya gelap: label di dalam area
	var lo_y := area.end.y - 4
	if light_style:  # gaya terang: label di luar area garis
		hi_y = area.position.y - 6
		lo_y = area.end.y + label_size + 2
	draw_string(font, Vector2(area.position.x + 4, hi_y),
			Fmt.rupiah(hi), HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, text_color)
	draw_string(font, Vector2(area.position.x + 4, lo_y),
			Fmt.rupiah(lo), HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, text_color)


## Penanda tegak putus-putus + teks di awal tiap ruas (tidak digambar jika tidak muat sampai penanda berikutnya).
func _draw_marks(area: Rect2, text_color: Color) -> void:
	var font := get_theme_default_font()
	var xs: Array[float] = []
	for mark: Array in _marks:
		var i := int(mark[0]) - _offset
		xs.append(area.position.x + area.size.x * clampf(float(i) / maxf(_data.size() - 1, 1.0), 0.0, 1.0))
	for k in _marks.size():
		var x: float = xs[k]
		if x > area.position.x + 1.0:
			draw_dashed_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color(text_color, 0.45), 2.0, 6.0)
		var room := (xs[k + 1] if k + 1 < xs.size() else area.end.x) - x - 8.0
		var text := String(_marks[k][1])
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, MARK_FONT).x <= room:
			draw_string(font, Vector2(x + 5, area.position.y + MARK_FONT + 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				MARK_FONT, text_color)
