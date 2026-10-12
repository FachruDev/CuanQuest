@tool
class_name AvatarView
extends Control
## Avatar sederhana: lingkaran berwarna dengan inisial nama. Digambar lewat _draw()
## sehingga tidak butuh file gambar. @tool membuatnya tampil juga di editor.

const COLORS: Array[Color] = [
	Color("#2e86de"), Color("#27ae60"), Color("#e67e22"),
	Color("#8e44ad"), Color("#e74c3c"), Color("#16a085"),
]

@export var avatar_index := 0:
	set(value):
		avatar_index = value
		queue_redraw()
@export var display_name := "":
	set(value):
		display_name = value
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var radius := minf(size.x, size.y) / 2.0
	var center := size / 2.0
	draw_circle(center, radius, COLORS[avatar_index % COLORS.size()])
	var initial := display_name.strip_edges().left(1).to_upper()
	if initial == "":
		initial = "?"
	var font := get_theme_default_font()
	var font_size := int(radius)
	var text_size := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center + Vector2(-text_size.x / 2.0, font_size * 0.35), initial,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
