class_name ChunkyButton
extends Button
## Tombol "tebal" ala game. Bibir bawahnya adalah border bawah StyleBoxFlat; saat
## ditekan, style "pressed" menipiskan bibir itu dan isi tombol (anak pertama,
## anchor penuh) ikut turun, jadi terasa seperti tombol fisik yang ditekan.

@export var press_depth := 6.0

var _content: Control
var _base_top := 0.0
var _base_bottom := 0.0


func _ready() -> void:
	if get_child_count() > 0 and get_child(0) is Control:
		_content = get_child(0)
		_base_top = _content.offset_top
		_base_bottom = _content.offset_bottom
	button_down.connect(_set_sunk.bind(true))
	button_up.connect(_set_sunk.bind(false))


func _set_sunk(sunk: bool) -> void:
	if _content == null:
		return
	var shift := press_depth if sunk else 0.0
	_content.offset_top = _base_top + shift
	_content.offset_bottom = _base_bottom + shift
