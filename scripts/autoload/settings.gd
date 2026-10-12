extends Node
## Pengaturan perangkat (Autoload "Settings"), disimpan di user://settings.cfg.
## Memakai ConfigFile (format INI) bawaan Godot, bukan JSON, karena ini konfigurasi
## sederhana dan formatnya mudah dibaca/diedit manual.

signal changed

const PATH := "user://settings.cfg"
const LANGUAGES := ["id", "en"]

var sfx_enabled := true
var vibration_enabled := true
var language := "id"
var compact_numbers := false


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		sfx_enabled = config.get_value("audio", "sfx", sfx_enabled)
		vibration_enabled = config.get_value("audio", "vibration", vibration_enabled)
		language = config.get_value("display", "language", language)
		compact_numbers = config.get_value("display", "compact_numbers", compact_numbers)
	_apply()


func set_sfx(enabled: bool) -> void:
	sfx_enabled = enabled
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


func _apply() -> void:
	TranslationServer.set_locale(language)
	Fmt.compact = compact_numbers


func _save() -> void:
	_apply()
	var config := ConfigFile.new()
	config.set_value("audio", "sfx", sfx_enabled)
	config.set_value("audio", "vibration", vibration_enabled)
	config.set_value("display", "language", language)
	config.set_value("display", "compact_numbers", compact_numbers)
	config.save(PATH)
	changed.emit()
