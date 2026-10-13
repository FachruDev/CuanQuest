extends Control
## Popup serbaguna prototipe (event, laporan, peringatan, form transaksi).
## Dibangun lewat kode memakai variasi tema Senja Cuan. Selama terlihat, layar prototipe
## menjeda jam (alasan "popup").

signal closed

var _title := Label.new()
var _body := Label.new()
var _buttons := VBoxContainer.new()


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	var dim := ColorRect.new()
	dim.color = Palette.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DialogPanel"
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	_title.theme_type_variation = &"PopupTitleLabel"
	_body.theme_type_variation = &"PopupBodyLabel"
	for label in [_title, _body]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
	_buttons.add_theme_constant_override("separation", 10)
	box.add_child(_buttons)


func open(title: String, body: String) -> void:
	_title.text = title
	_body.text = body
	_body.visible = body != ""
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	show()


## Tombol pilihan. `callback` dijalankan lalu popup TIDAK ditutup otomatis,
## sehingga callback bisa membuka isi berikutnya (mis. hasil event).
func add_button(text: String, callback: Callable, variation := &"ChoiceCardButton", disabled := false) -> Button:
	var button := Button.new()
	button.theme_type_variation = variation
	button.text = text
	button.custom_minimum_size = Vector2(0, 76)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.disabled = disabled
	button.pressed.connect(callback)
	_buttons.add_child(button)
	return button


## Tombol utama tebal (emas), mis. "Oke".
func add_primary(text: String, callback: Callable) -> Button:
	var button := chunky(text, &"PrimaryButton", &"PrimaryButtonLabel", 84.0, 30)
	button.pressed.connect(callback)
	_buttons.add_child(button)
	return button


## Beberapa tombol kecil sebaris (mis. nominal transaksi). `callback` menerima item["value"].
func add_button_row(items: Array, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for item: Dictionary in items:
		var button := Button.new()
		button.theme_type_variation = &"PeriodButton"
		button.add_theme_font_size_override("font_size", 22)
		button.text = item["text"]
		button.custom_minimum_size = Vector2(0, 72)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = item.get("disabled", false)
		var value: Variant = item["value"]
		button.pressed.connect(func() -> void: callback.call(value))
		row.add_child(button)
	_buttons.add_child(row)


## Tombol tebal gaya Senja Cuan: Button + Label "Content" sebagai anak (lihat ChunkyButton).
static func chunky(text: String, variation: StringName, label_variation: StringName,
		height := 76.0, font_size := 0) -> Button:
	var button := ChunkyButton.new()
	button.theme_type_variation = variation
	button.custom_minimum_size = Vector2(0, height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.name = "Content"
	label.theme_type_variation = label_variation
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_bottom = -8.0  # sisakan bibir bawah tombol
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	button.add_child(label)
	return button


func close() -> void:
	hide()
	closed.emit()
