extends CenterContainer
## Layar sementara untuk tab yang belum dibuat.

@export var message_key := ""


func _ready() -> void:
	$Label.text = tr(message_key)
