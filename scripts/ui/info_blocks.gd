class_name InfoBlocks
extends RefCounted
## Isi popup info bertingkat (Popup v2): pengantar singkat di tengah, lalu blok rata kiri. Satu blok =
## Dictionary dengan salah satu kunci berikut:
##   {"lead": teks}                         pengantar (tengah)
##   {"text": teks}                         paragraf rata kiri
##   {"caps": teks}                         judul kecil berhuruf kapital
##   {"bullets": [teks...], "dot": Color}   daftar berpoin (titik berwarna)
##   {"rows": [[label, nilai, warna?]...]}  kartu baris angka
##   {"tiles": [[judul, nilai, keterangan, positif?]...]}  ubin 2 kolom
##   {"tip": teks}                          kartu tip kuning berikon lampu
##   {"warn": teks}                         kartu peringatan merah
##   {"meter": {title, value, ratio, low, left, right, note}}  meteran (mis. dana pensiun)
##   {"help": true}                         kartu bantuan kesehatan jiwa (pedoman konten sensitif)
##   {"note": teks, "icon": path}           catatan kecil berikon
## Analogi web: seperti renderer "rich text" sederhana berbasis JSON, agar teks panjang tidak menjadi
## satu dinding paragraf rata tengah.

const LIGHTBULB := preload("res://assets/icons/lightbulb.svg")
const WARNING := preload("res://assets/icons/warning_small.svg")
const HEART := preload("res://assets/icons/heart.svg")
const LEAD_MAX := 170  # paragraf pertama sependek ini menjadi pengantar di tengah


## Teks biasa (paragraf dipisah baris kosong, baris "• " = poin) menjadi blok. Dipakai InfoPopup.open()
## sehingga semua popup lama ikut rata kiri & berpoin tanpa mengubah teksnya.
static func from_text(text: String) -> Array:
	var blocks: Array = []
	var paragraphs := text.strip_edges().split("\n\n", false)
	for i in paragraphs.size():
		var para := paragraphs[i].strip_edges(false, true)
		var lines := para.split("\n", false)
		var plain: PackedStringArray = []
		var bullets: Array = []
		for line in lines:
			var trimmed := line.strip_edges()
			if trimmed.begins_with("• ") or trimmed.begins_with("- "):
				if not plain.is_empty():
					blocks.append({"text": "\n".join(plain)})
					plain.clear()
				bullets.append(trimmed.substr(2))
			elif not bullets.is_empty() and line.begins_with("  "):  # lanjutan poin (mis. kekurangan margin)
				bullets[-1] += "\n" + trimmed
			else:
				if not bullets.is_empty():
					blocks.append({"bullets": bullets})
					bullets = []
				plain.append(trimmed)
		if not bullets.is_empty():
			blocks.append({"bullets": bullets})
		if not plain.is_empty():
			var joined := "\n".join(plain)
			if i == 0 and blocks.is_empty() and joined.length() <= LEAD_MAX:
				blocks.append({"lead": joined})
			else:
				blocks.append({"text": joined})
	return blocks


static func build(box: VBoxContainer, blocks: Array) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	for block: Dictionary in blocks:
		var node := _block(block)
		if node != null:
			box.add_child(node)


static func _block(b: Dictionary) -> Control:
	if b.has("lead"):
		var lead := _wrap(b["lead"], &"PopupBodyLabel")
		lead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return lead
	if b.has("text"):
		return _wrap(b["text"], &"InfoLabel")
	if b.has("caps"):
		var caps := _wrap(str(b["caps"]).to_upper(), &"TileCapsLabel")
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_child(caps)
		return margin
	if b.has("bullets"):
		return _bullets(b["bullets"], b.get("dot", Palette.GOLD))
	if b.has("rows"):
		return _rows(b["rows"])
	if b.has("tiles"):
		return _tiles(b["tiles"])
	if b.has("tip"):
		return _banner(&"TipBanner", LIGHTBULB, b["tip"], Color("#5e3f08"))
	if b.has("warn"):
		return _banner(&"AlertCard", WARNING, b["warn"], Color("#8a3b26"))
	if b.has("meter"):
		return _meter(b["meter"])
	if b.has("help"):
		return _help()
	if b.has("note"):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		if b.has("icon"):
			row.add_child(_icon(load(b["icon"]), Vector2(20, 20)))
		var label := _wrap(b["note"], &"SmallMutedLabel")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		return row
	return null


static func _bullets(items: Array, dot: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	for item in items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var mark := Control.new()
		mark.custom_minimum_size = Vector2(12, 26)
		mark.draw.connect(func() -> void:
			mark.draw_circle(Vector2(6, 13), 6.0, Palette.INK)
			mark.draw_circle(Vector2(6, 13), 4.0, dot))
		row.add_child(mark)
		var label := _wrap(str(item), &"InfoLabel")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		box.add_child(row)
	return box


static func _rows(rows: Array) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"HomeCard"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	for i in rows.size():
		var r: Array = rows[i]
		if i > 0:
			var line := Panel.new()
			line.theme_type_variation = &"Divider"
			line.custom_minimum_size = Vector2(0, 2)
			box.add_child(line)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name := _wrap(str(r[0]), &"RowLabel")
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var value := _label(str(r[1]), &"RowValueLabel")
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if r.size() > 2 and r[2] is Color:
			value.add_theme_color_override("font_color", r[2])
		row.add_child(value)
		box.add_child(row)
	card.add_child(box)
	return card


static func _tiles(tiles: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for t: Array in tiles:
		var tile := PanelContainer.new()
		tile.theme_type_variation = &"StatTilePositive" if t.size() > 3 and t[3] else &"StatTile"
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		box.add_child(_wrap(str(t[0]), &"TileCapsLabel"))
		box.add_child(_wrap(str(t[1]), &"TileValueLabel"))
		if t.size() > 2 and str(t[2]) != "":
			box.add_child(_wrap(str(t[2]), &"SmallMutedLabel"))
		tile.add_child(box)
		grid.add_child(tile)
	return grid


static func _banner(variation: StringName, icon: Texture2D, text: String, color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = variation
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var image := _icon(icon, Vector2(24, 24))
	image.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(image)
	var label := _wrap(text, &"InfoLabel")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", color)
	row.add_child(label)
	card.add_child(row)
	return card


## Meteran: judul & nilai, bar (merah bila `low`), label kiri/kanan, keterangan.
static func _meter(m: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"HomeCard"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	var title := _wrap(m["title"], &"AssetNameLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var value := _label(m.get("value", ""), &"RowValueLabel")
	value.add_theme_color_override("font_color", Palette.LOSS if m.get("low", false) else Palette.GAIN)
	head.add_child(value)
	box.add_child(head)
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"HealthBar" if m.get("low", false) else &"XpBar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = clampf(float(m.get("ratio", 0.0)), 0.0, 1.0)
	box.add_child(bar)
	if m.has("left"):
		var scale := HBoxContainer.new()
		var left := _label(m["left"], &"SmallMutedLabel")
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scale.add_child(left)
		scale.add_child(_label(m.get("right", ""), &"SmallMutedLabel"))
		box.add_child(scale)
	if m.has("note"):
		box.add_child(_wrap(m["note"], &"SmallMutedLabel"))
	card.add_child(box)
	return card


## Kartu bantuan (pedoman konten sensitif, bagian 2): ikon hati, judul, pesan dukungan resmi (SUPPORT_MESSAGE,
## teks tidak diubah karena diperiksa test_policy).
static func _help() -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#e3f4f1")
	style.border_color = Palette.TEAL
	style.set_border_width_all(3)
	style.set_corner_radius_all(22)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.anti_aliasing_size = 1.0
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var tile := UiText.icon_tile("res://assets/icons/heart.svg", &"IconTileTeal", 44.0)
	head.add_child(tile)
	var title := _wrap(TranslationServer.translate("SUPPORT_CARD_TITLE"), &"AssetNameLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_theme_color_override("font_color", Color("#145a50"))
	head.add_child(title)
	box.add_child(head)
	var body := _wrap(TranslationServer.translate("SUPPORT_MESSAGE"), &"InfoLabel")
	body.add_theme_color_override("font_color", Color("#1d4f48"))
	box.add_child(body)
	card.add_child(box)
	return card


static func _icon(texture: Texture2D, size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


static func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label


static func _wrap(text: String, variation: StringName) -> Label:
	var label := _label(text, variation)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1
	return label
