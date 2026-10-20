class_name ArtThumb
extends PanelContainer
## Potongan ilustrasi adegan hunian (latar polos + satu lapisan rumah ATAU kendaraan) untuk kartu di menu
## Rumah & Kendaraan, showroom, dan daftar properti. Lapisan memakai kanvas 624 x 260 yang sama dengan
## HomeScene, jadi cukup dipotong di daerah objeknya (HomeScene.HOME_CROP / VEHICLE_CROP). Latar adegan
## lengkap terlalu ramai di ukuran kecil, jadi dipakai langit + rumput sederhana (thumb_bg.svg).

const ART_SIZE := Vector2(624.0, 260.0)
const THUMB_BG := "res://assets/illustrations/home/thumb_bg.svg"


## `layer_path`: ilustrasi rumah atau kendaraan; `crop`: daerah yang ditampilkan (koordinat kanvas 624 x 260).
func _init(layer_path: String, crop: Rect2, thumb_size := Vector2(200, 140)) -> void:
	theme_type_variation = &"ThumbFrame"
	custom_minimum_size = thumb_size
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()  # tumpukan lapisan (PanelContainer menata satu anak penuh)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	for path in [THUMB_BG, layer_path]:
		if not ResourceLoader.exists(path):
			continue
		var texture: Texture2D = load(path)
		var scale := texture.get_width() / ART_SIZE.x  # SVG diimpor skala 2
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(crop.position * scale, crop.size * scale)
		var rect := TextureRect.new()
		rect.texture = atlas
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(rect)
