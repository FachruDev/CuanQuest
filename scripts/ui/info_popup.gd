extends ModalPopup
## Popup informasi sederhana: judul, isi, tombol Oke (dipakai untuk notifikasi unlock).


func _ready() -> void:
	super()
	%OkButton.pressed.connect(close)


func open(title: String, body: String) -> void:
	%TitleLabel.text = title
	%BodyLabel.text = body
	show()
