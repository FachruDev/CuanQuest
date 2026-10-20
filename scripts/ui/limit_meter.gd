class_name LimitMeter
extends Control
## Meteran satu rasio terhadap batas (mis. rasio cicilan 27% dari batas 35%): isian teal, merah jika
## melewati batas, dan garis tinta di posisi batas.

const TRACK := Color("#eadfcc")
const HEIGHT := 12.0

var _value := 0.0
var _limit := 0.35


func _init() -> void:
	custom_minimum_size = Vector2(0, 22)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `value` dan `limit` sebagai rasio 0-1 dari lebar penuh.
func set_values(value: float, limit: float) -> void:
	_value = clampf(value, 0.0, 1.0)
	_limit = clampf(limit, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var top := (size.y - HEIGHT) / 2.0
	draw_style_box(_box(TRACK), Rect2(0.0, top, size.x, HEIGHT))
	if _value > 0.0:
		var fill := Palette.LOSS if _value > _limit else Palette.TEAL
		draw_style_box(_box(fill), Rect2(0.0, top, maxf(HEIGHT, size.x * _value), HEIGHT))
	draw_rect(Rect2(size.x * _limit - 1.5, 0.0, 3.0, size.y), Palette.INK)


func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(HEIGHT / 2.0))
	box.anti_aliasing_size = 1.0
	return box
