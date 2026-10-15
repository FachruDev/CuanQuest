class_name PerfOverlay
extends CanvasLayer
## Info performa untuk uji di HP (penutup v1.5): FPS, waktu proses per frame, memori, jumlah node.
## Diperbarui dua kali per detik lewat Timer (bukan _process) agar tidak ikut menguras baterai.
## Dinyalakan dari Profil > Pengaturan > Info performa (Settings.perf_overlay).
##
## Catatan membaca angka: dengan mode hemat prosesor, layar hanya digambar ulang saat ada perubahan,
## jadi FPS rendah saat diam itu BAGUS (hemat baterai). Saat animasi atau scroll, FPS sebaiknya ~60.

const UPDATE_SECONDS := 0.5

var _label: Label


func _init() -> void:
	layer = 120  # di atas semua layar & popup
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.169, 0.129, 0.278, 0.78)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_top = -255  # tepat di atas tombol Lanjut
	panel.offset_bottom = -225
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label = Label.new()
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_font_size_override("font_size", 18)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_label)
	add_child(panel)
	var timer := Timer.new()
	timer.wait_time = UPDATE_SECONDS
	timer.autostart = true
	timer.timeout.connect(_update)
	add_child(timer)


func _ready() -> void:
	_update()


func _update() -> void:
	var fps := int(Performance.get_monitor(Performance.TIME_FPS))
	var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var memory_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_label.text = tr("PERF_OVERLAY") % [fps, Fmt.number(process_ms, 1), roundi(memory_mb), nodes]
