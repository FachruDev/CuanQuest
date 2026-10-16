extends ModalPopup
## Popup informasi: judul, isi, tombol Oke, dan tombol kedua opsional
## (mis. "Selesaikan permainan" saat target kemenangan tercapai).

var _on_secondary := Callable()
var _mark: Label  # tanda "!" pada lencana mode peringatan (v2a), dibuat saat pertama dipakai


func _ready() -> void:
	super()
	%OkButton.pressed.connect(close)
	%SecondaryButton.pressed.connect(_on_secondary_pressed)


## `ok_text`: label tombol utama (default "Oke"), mis. "Batal" untuk popup konfirmasi.
func open(title: String, body: String, secondary_text: String = "", on_secondary: Callable = Callable(),
		ok_text: String = "") -> void:
	_set_warning(false)
	_fill(title, body, secondary_text, on_secondary, ok_text)
	Sfx.play("success")


## Varian peringatan (v2a): lencana "!" merah, judul merah, bunyi peringatan. Untuk peringatan risiko
## leverage dan margin call, agar tidak terlihat seperti perayaan.
func open_warning(title: String, body: String, secondary_text: String = "", on_secondary: Callable = Callable(),
		ok_text: String = "") -> void:
	_set_warning(true)
	_fill(title, body, secondary_text, on_secondary, ok_text)
	Sfx.play("alert")


func _set_warning(on: bool) -> void:
	var badge: PanelContainer = $Center/Dialog/BadgeHolder/Badge
	badge.theme_type_variation = &"WarningBadgePanel" if on else &"BadgeGoldPanel"
	badge.get_node("Icon").visible = not on
	if on and _mark == null:
		_mark = Label.new()
		_mark.theme_type_variation = &"PopupBadgeLabel"
		_mark.text = "!"
		_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(_mark)
	if _mark != null:
		_mark.visible = on
	if on:
		%TitleLabel.add_theme_color_override("font_color", Palette.LOSS)
	else:
		%TitleLabel.remove_theme_color_override("font_color")


func _fill(title: String, body: String, secondary_text: String, on_secondary: Callable, ok_text: String) -> void:
	%TitleLabel.text = title
	%BodyLabel.text = body
	%OkButton.get_child(0).text = ok_text if ok_text != "" else tr("BTN_OK")
	_on_secondary = on_secondary
	%SecondaryButton.visible = secondary_text != ""
	%SecondaryButton.get_child(0).text = secondary_text
	show()


## Callback dijalankan SEBELUM close(), karena close() langsung memicu popup berikutnya di antrean.
func _on_secondary_pressed() -> void:
	if _on_secondary.is_valid():
		_on_secondary.call()
	close()
