class_name ChapterTrack
extends Control
## Garis waktu 4 bab kehidupan (Profil > Ringkasan): bulatan per bab (selesai = centang teal, sekarang =
## emas berisi usia, belum = putih), garis penghubung yang terisi sampai bab sekarang, nama & rentang usia.

const DOT := 48.0
const LINE := 6.0
const TRACK := Color("#f4eadb")
const CHECK := preload("res://assets/icons/req_ok.svg")

var _columns: HBoxContainer
var _done := 0  # jumlah bab yang sudah dilewati (garis terisi sampai bab sekarang)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_columns = HBoxContainer.new()
	_columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_columns.add_theme_constant_override("separation", 0)
	_columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_columns)
	_columns.minimum_size_changed.connect(func() -> void: custom_minimum_size.y = _columns.get_combined_minimum_size().y)


## `chapters`: [{id, name, ages, state: "done" | "now" | "todo"}] urut dari bab pertama.
func set_chapters(chapters: Array, age: int) -> void:
	for child in _columns.get_children():
		_columns.remove_child(child)
		child.queue_free()
	_done = 0
	for c: Dictionary in chapters:
		if c["state"] == "done":
			_done += 1
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 4)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dot := PanelContainer.new()
		dot.custom_minimum_size = Vector2(DOT, DOT)
		dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(int(DOT / 2.0))
		style.set_border_width_all(3)
		style.anti_aliasing_size = 1.0
		match c["state"]:
			"done":
				style.bg_color = Palette.TEAL
				style.border_color = Palette.INK
				var icon := TextureRect.new()
				icon.texture = CHECK
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.custom_minimum_size = Vector2(26, 26)
				icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				dot.add_child(icon)
			"now":
				style.bg_color = Palette.GOLD
				style.border_color = Palette.INK
				style.shadow_color = Color("#fff1be")
				style.shadow_size = 5
				var label := _label(str(age), &"TileValueLabel")
				label.add_theme_font_size_override("font_size", 18)
				dot.add_child(label)
			_:
				style.bg_color = Color.WHITE
				style.border_color = Color("#d9c3a0")
		dot.add_theme_stylebox_override("panel", style)
		column.add_child(dot)
		var name_label := _label(c["name"], &"RowValueLabel" if c["state"] == "now" else &"RowLabel")
		name_label.add_theme_font_size_override("font_size", 16)
		if c["state"] == "todo":
			name_label.add_theme_color_override("font_color", Palette.MUTED)
		column.add_child(name_label)
		var ages := _label(c["ages"], &"SmallMutedLabel")
		ages.add_theme_font_size_override("font_size", 14)
		column.add_child(ages)
		_columns.add_child(column)
	queue_redraw()


func _draw() -> void:
	var count := _columns.get_child_count()
	if count < 2:
		return
	var step := size.x / count
	var y := DOT / 2.0 - LINE / 2.0
	var start := step / 2.0
	var end := size.x - step / 2.0
	draw_style_box(_bar(TRACK), Rect2(start, y, end - start, LINE))
	if _done > 0:
		draw_style_box(_bar(Palette.TEAL), Rect2(start, y, step * mini(_done, count - 1), LINE))


func _bar(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(LINE / 2.0))
	return box


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
