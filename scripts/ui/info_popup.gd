extends ModalPopup
## Popup informasi: judul, isi, tombol Oke, dan tombol kedua opsional
## (mis. "Selesaikan permainan" saat target kemenangan tercapai).

var _on_secondary := Callable()


func _ready() -> void:
	super()
	%OkButton.pressed.connect(close)
	%SecondaryButton.pressed.connect(_on_secondary_pressed)


func open(title: String, body: String, secondary_text: String = "", on_secondary: Callable = Callable()) -> void:
	%TitleLabel.text = title
	%BodyLabel.text = body
	_on_secondary = on_secondary
	%SecondaryButton.visible = secondary_text != ""
	%SecondaryButton.text = secondary_text
	show()
	Sfx.play("success")


## Callback dijalankan SEBELUM close(), karena close() langsung memicu popup berikutnya di antrean.
func _on_secondary_pressed() -> void:
	if _on_secondary.is_valid():
		_on_secondary.call()
	close()
