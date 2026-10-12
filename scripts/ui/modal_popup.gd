class_name ModalPopup
extends Control
## Base class semua popup modal. Main memakai signal `closed` untuk menampilkan
## popup berikutnya di antrean (laporan -> unlock -> event).
## Catatan Godot 4: jika subclass meng-override _ready(), panggil super() di dalamnya.
##
## Saat tampil: latar memudar masuk dan node unik %Dialog (jika ada) sedikit "membal".

signal closed

const POP_TIME := 0.22


func _ready() -> void:
	hide()
	visibility_changed.connect(_on_visibility_changed)


func close() -> void:
	hide()
	closed.emit()


func _on_visibility_changed() -> void:
	if not visible:
		return
	modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, POP_TIME * 0.6)
	var dialog := get_node_or_null("%Dialog") as Control
	if dialog:
		await get_tree().process_frame  # tunggu container menata ukuran dialog dulu
		dialog.pivot_offset = dialog.size / 2.0
		dialog.scale = Vector2(0.94, 0.94)
		create_tween().tween_property(dialog, "scale", Vector2.ONE, POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
