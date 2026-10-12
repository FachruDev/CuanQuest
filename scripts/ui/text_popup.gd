extends ModalPopup
## Popup teks panjang yang bisa di-scroll (kebijakan privasi, syarat penggunaan).


func _ready() -> void:
	super()
	%CloseButton.pressed.connect(close)


func open(title: String, body: String) -> void:
	%TitleLabel.text = title
	%BodyLabel.text = body
	%Scroll.scroll_vertical = 0
	show()
