@tool
class_name AvatarView
extends Control
## Avatar pemain: ilustrasi anime dari assets/illustrations/avatar_<index>.svg (lingkaran).
## Jika file gambarnya tidak ada, jatuh kembali ke lingkaran berwarna + inisial nama.
## @tool membuatnya tampil juga di editor.

const COUNT := 10  # 0-4 pria, 5-9 wanita
const MALE_COUNT := 5
## Nama saran per avatar: dipakai jika kolom nama di Buat Karakter dikosongkan.
const NAMES: Array[String] = ["Raka", "Dimas", "Bayu", "Arif", "Kenzo", "Sinta", "Ayu", "Nadia", "Laras", "Citra"]
const TEXTURE_PATH := "res://assets/illustrations/avatar_%d.svg"
const COLORS: Array[Color] = [
	Color("#2e86de"), Color("#27ae60"), Color("#e67e22"),
	Color("#8e44ad"), Color("#e74c3c"), Color("#16a085"),
]

@export var avatar_index := 0:
	set(value):
		avatar_index = value
		_texture = _load_texture(value)
		queue_redraw()
@export var display_name := "":
	set(value):
		display_name = value
		queue_redraw()

var _texture: Texture2D


func _ready() -> void:
	_texture = _load_texture(avatar_index)
	resized.connect(queue_redraw)


## Teks deskripsi avatar (kunci terjemahan AVATAR_DESC_<index>).
static func description(index: int) -> String:
	return TranslationServer.translate("AVATAR_DESC_%d" % index)


static func _load_texture(index: int) -> Texture2D:
	var path := TEXTURE_PATH % posmod(index, COUNT)
	return load(path) if ResourceLoader.exists(path) else null


func _draw() -> void:
	var radius := minf(size.x, size.y) / 2.0
	var center := size / 2.0
	if _texture:
		draw_texture_rect(_texture, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false)
		return
	draw_circle(center, radius, COLORS[avatar_index % COLORS.size()])
	var initial := display_name.strip_edges().left(1).to_upper()
	if initial == "":
		initial = "?"
	var font := get_theme_default_font()
	var font_size := int(radius)
	var text_size := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center + Vector2(-text_size.x / 2.0, font_size * 0.35), initial,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
