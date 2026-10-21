extends Node
## Pengaturan perangkat (Autoload "Settings"), disimpan di user://settings.cfg.
## Memakai ConfigFile (format INI) bawaan Godot, bukan JSON, karena ini konfigurasi
## sederhana dan formatnya mudah dibaca/diedit manual.
##
## Hemat baterai (penutup v1.5): mode hemat prosesor dinyalakan sejak awal, jadi layar hanya
## digambar ulang saat ada yang berubah (animasi, scroll, sentuhan). Saat pemain diam, mesin game
## hampir tidak bekerja. Analogi web: seperti halaman yang hanya re-render saat state berubah.

signal changed

const PATH := "user://settings.cfg"
const LANGUAGES := ["id", "en"]
## Batas FPS: cukup untuk animasi mulus; HP berlayar 90/120 Hz tidak perlu menggambar lebih cepat.
const MAX_FPS := 60

const MUSIC_LEVELS := [0.4, 0.7, 1.0]  # pilihan volume musik: pelan, sedang, keras

var sfx_enabled := true
var music_enabled := true
var music_volume := 0.7
var vibration_enabled := true
var language := "id"
var compact_numbers := false
var perf_overlay := false  # info performa untuk uji di HP (PerfOverlay)

var _overlay: PerfOverlay


func _ready() -> void:
	OS.low_processor_usage_mode = true
	Engine.max_fps = MAX_FPS
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		sfx_enabled = config.get_value("audio", "sfx", sfx_enabled)
		vibration_enabled = config.get_value("audio", "vibration", vibration_enabled)
		music_enabled = config.get_value("audio", "music", music_enabled)
		music_volume = config.get_value("audio", "music_volume", music_volume)
		language = config.get_value("display", "language", language)
		compact_numbers = config.get_value("display", "compact_numbers", compact_numbers)
		perf_overlay = config.get_value("display", "perf_overlay", perf_overlay)
	_apply()


func set_sfx(enabled: bool) -> void:
	sfx_enabled = enabled
	_save()


func set_music(enabled: bool) -> void:
	music_enabled = enabled
	_save()


func set_music_volume(volume: float) -> void:
	music_volume = volume
	_save()


func set_vibration(enabled: bool) -> void:
	vibration_enabled = enabled
	_save()


## Ganti bahasa. Layar yang sedang tampil perlu di-reload agar semua teks ikut berubah.
func set_language(code: String) -> void:
	language = code
	_save()


func set_compact_numbers(enabled: bool) -> void:
	compact_numbers = enabled
	_save()


func set_perf_overlay(enabled: bool) -> void:
	perf_overlay = enabled
	_save()


func _apply() -> void:
	TranslationServer.set_locale(language)
	Fmt.compact = compact_numbers
	if perf_overlay and _overlay == null:
		_overlay = PerfOverlay.new()
		add_child(_overlay)
	elif not perf_overlay and _overlay != null:
		_overlay.queue_free()
		_overlay = null


func _save() -> void:
	_apply()
	var config := ConfigFile.new()
	config.set_value("audio", "sfx", sfx_enabled)
	config.set_value("audio", "vibration", vibration_enabled)
	config.set_value("audio", "music", music_enabled)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("display", "language", language)
	config.set_value("display", "compact_numbers", compact_numbers)
	config.set_value("display", "perf_overlay", perf_overlay)
	config.save(PATH)
	changed.emit()
