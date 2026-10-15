class_name CharacterPortrait
extends Control
## Potret tokoh berulang (v1.5d): assets/illustrations/characters/<id>.svg jika ada, selain itu
## lingkaran berwarna (warna dari data/characters.json) dengan inisial nama tokoh.

const TEXTURE_PATH := "res://assets/illustrations/characters/%s.svg"

var character_id := "":
	set(value):
		character_id = value
		var path := TEXTURE_PATH % value
		_texture = load(path) if value != "" and ResourceLoader.exists(path) else null
		queue_redraw()

var _texture: Texture2D


func _init(size_px: float = 64.0) -> void:
	custom_minimum_size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var radius := minf(size.x, size.y) / 2.0
	var center := size / 2.0
	if _texture:
		draw_texture_rect(_texture, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false)
		return
	draw_circle(center, radius, Palette.INK)  # garis tinta seperti ilustrasi lain
	draw_circle(center, radius - 3.0, Color(GameState.characters.def(character_id).get("color", "#B5A089")))
	var words := GameState.characters.name_of(character_id).split(" ", false)
	var initial := words[-1].left(1).to_upper() if not words.is_empty() else "?"  # "Kak Wulan" -> W
	var font := get_theme_default_font()
	var font_size := int(radius * 1.15)
	var text_size := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center + Vector2(-text_size.x / 2.0, font_size * 0.35), initial,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
