class_name FlowBar
extends Control
## Batang bertumpuk "Ke Mana Gajimu Pergi" (Beranda v2): satu segmen per kelompok, jeda 3 px di antara
## segmen, hanya ujung luar yang membulat. Warna kelompok: lihat FLOW_GROUPS di home_screen.gd.

const GAP := 3.0
const RADIUS := 7
const EMPTY := Color("#f4eadb")

var _parts: Array = []  # [[nilai, warna], ...] (nilai <= 0 dilewati)


func _init() -> void:
	custom_minimum_size = Vector2(0, 30)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_parts(parts: Array) -> void:
	_parts = parts.filter(func(part: Array) -> bool: return float(part[0]) > 0.0)
	queue_redraw()


func _draw() -> void:
	var total := 0.0
	for part: Array in _parts:
		total += float(part[0])
	if total <= 0.0:
		draw_style_box(_box(EMPTY, true, true), Rect2(Vector2.ZERO, size))
		return
	var usable := size.x - GAP * (_parts.size() - 1)
	var x := 0.0
	for i in _parts.size():
		var last := i == _parts.size() - 1
		var width := size.x - x if last else maxf(4.0, usable * float(_parts[i][0]) / total)
		draw_style_box(_box(_parts[i][1], i == 0, last), Rect2(x, 0.0, width, size.y))
		x += width + GAP


func _box(color: Color, left: bool, right: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = RADIUS if left else 0
	box.corner_radius_bottom_left = RADIUS if left else 0
	box.corner_radius_top_right = RADIUS if right else 0
	box.corner_radius_bottom_right = RADIUS if right else 0
	box.anti_aliasing_size = 1.0
	return box
