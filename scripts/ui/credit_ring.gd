class_name CreditRing
extends Control
## Cincin progres 0-100 dengan angka di tengah: skor kredit (Beranda > Keuangan) dan target kemenangan
## (Profil > Ringkasan, dengan akhiran "%").

const TRACK := Color("#f4eadb")

var width := 10.0
var _score := 0
var _color := Palette.GAIN
var _label: Label


func _init(diameter := 88.0, line_width := 10.0, font_size := 28) -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	width = line_width
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.theme_type_variation = &"TileValueLabel"
	_label.add_theme_font_size_override("font_size", font_size)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_label)


func set_score(score: int, color: Color, suffix := "") -> void:
	_score = clampi(score, 0, 100)
	_color = color
	_label.text = str(_score) + suffix
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - width / 2.0 - 1.0
	draw_arc(center, radius, 0.0, TAU, 72, TRACK, width, true)
	if _score > 0:
		draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU * _score / 100.0, 72, _color, width, true)
