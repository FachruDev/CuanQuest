class_name ModalPopup
extends Control
## Base class semua popup modal. Main memakai signal `closed` untuk menampilkan
## popup berikutnya di antrean (laporan -> unlock -> event).
## Catatan Godot 4: jika subclass meng-override _ready(), panggil super() di dalamnya.

signal closed


func _ready() -> void:
	hide()


func close() -> void:
	hide()
	closed.emit()
