class_name PriceChart
extends Control
## Line chart sederhana yang digambar manual lewat _draw().
## Analogi web: seperti menggambar di <canvas> dengan ctx.lineTo().

const PADDING := 16.0

@export var max_points := 24   ## batas titik saat periode = 0 ("Semua")
@export var period := 0        ## jumlah bulan yang ditampilkan; 0 = semua (dibatasi max_points)
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

const LIGHT_TEXT := Color("#8a6e4e")

var _all: Array[float] = []   # semua data dari pemanggil
var _data: Array[float] = []  # bagian yang sedang digambar (sesuai periode)


func _ready() -> void:
	resized.connect(queue_redraw)


func set_data(values: Array[float]) -> void:
	_all.assign(values)
	_apply_period()


## Periode N bulan butuh N+1 titik (harga awal + N perubahan bulanan).
func set_period(months: int) -> void:
	period = months
	_apply_period()


func _apply_period() -> void:
	var count := period + 1 if period > 0 else max_points
	_data.assign(_all.slice(-count))
	queue_redraw()  # minta Godot memanggil _draw() di frame berikutnya


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	var text_color := LIGHT_TEXT if light_style else Color(1, 1, 1, 0.6)
	if _data.size() < 2:
		draw_string(get_theme_default_font(), Vector2(0, size.y / 2.0), tr(empty_text_key),
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, text_color)
		return

	var lo: float = _data.min()
	var hi: float = _data.max()
	if hi - lo < 0.0001:
		hi = lo + 1.0

	var area := Rect2(Vector2(PADDING, PADDING), size - Vector2(PADDING, PADDING) * 2)

	for i in 5:  # garis bantu horizontal
		var y := area.position.y + area.size.y * i / 4.0
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), grid_color)

	var points := PackedVector2Array()
	for i in _data.size():
		var x := area.position.x + area.size.x * i / (_data.size() - 1)
		var y := area.position.y + area.size.y * (1.0 - (_data[i] - lo) / (hi - lo))
		points.append(Vector2(x, y))

	var color := up_color if _data[-1] >= _data[0] else down_color
	if light_style:  # area lembut di bawah garis
		var fill := points.duplicate()
		fill.append(Vector2(area.end.x, area.end.y))
		fill.append(Vector2(area.position.x, area.end.y))
		draw_colored_polygon(fill, Color(color, 0.15))
	draw_polyline(points, color, 4.0, true)
	if light_style:
		draw_circle(points[-1], 9.0, Color.WHITE)
	draw_circle(points[-1], 7.0 if not light_style else 6.0, color)

	var font := get_theme_default_font()
	var font_size := 20 if not light_style else 16
	draw_string(font, Vector2(area.position.x + 4, area.position.y + font_size),
			Fmt.rupiah(hi), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	draw_string(font, Vector2(area.position.x + 4, area.end.y - 4),
			Fmt.rupiah(lo), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
