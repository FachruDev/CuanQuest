extends Node
## Layanan iklan rewarded (didaftarkan sebagai Autoload "AdService").
##
## SAAT INI STUB: hanya menampilkan layar hitung mundur "iklan simulasi".
## Menjelang rilis, isi fungsi ini diganti dengan plugin AdMob, tanpa mengubah
## kode pemanggilnya, karena interface-nya tetap:
##     AdService.show_rewarded(func(): ...hadiah...)

const STUB_SECONDS := 3

var _showing := false


func is_available() -> bool:
	return not _showing


## Tampilkan iklan; `on_reward` dipanggil hanya jika iklan ditonton sampai selesai.
func show_rewarded(on_reward: Callable) -> void:
	if _showing:
		return
	_showing = true

	var layer := CanvasLayer.new()
	layer.layer = 100  # di atas semua UI
	var background := ColorRect.new()
	background.color = Color(Palette.INK, 0.96)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP  # blok klik selama iklan
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 48
	label.offset_right = -48
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("#fff8ec"))  # tema default berteks gelap
	label.add_theme_font_size_override("font_size", 28)
	background.add_child(label)
	layer.add_child(background)
	add_child(layer)

	for seconds_left in range(STUB_SECONDS, 0, -1):
		label.text = tr("AD_STUB") % seconds_left
		await get_tree().create_timer(1.0).timeout

	layer.queue_free()
	_showing = false
	on_reward.call()
