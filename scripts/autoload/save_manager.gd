extends Node
## Simpan/muat game ke file JSON di user:// (Autoload "SaveManager").
## Analogi web: user:// mirip localStorage, tapi berupa folder file di perangkat.
## Lokasinya di PC: %APPDATA%/Godot/app_userdata/Cuan Quest/
##
## - saves/auto.json   : simpan otomatis tiap akhir bulan / event diputuskan / app di-pause
## - saves/slot_N.json : slot manual (Profil -> Simpan)
## - player.json       : data global pemain (kuis, tutorial, petunjuk), tidak terikat slot

const SAVE_DIR := "user://saves/"
const PLAYER_PATH := "user://player.json"
const AUTO_SLOT := "auto"
const MANUAL_SLOTS: Array[String] = ["slot_1", "slot_2", "slot_3"]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_load_player()
	GameState.state_committed.connect(func() -> void: save_slot(AUTO_SLOT))
	GameState.player_changed.connect(_save_player)
	# Game over: hapus simpanan otomatis (slot manual tetap ada untuk "mengulang").
	GameState.game_ended.connect(func(_result: Dictionary) -> void: delete_slot(AUTO_SLOT))


## Android bisa mematikan app kapan saja saat di background, jadi simpan saat di-pause/ditutup.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if GameState.is_active and not GameState.is_over:
			save_slot(AUTO_SLOT)
		_save_player()


func save_slot(slot: String) -> bool:
	if not GameState.is_active or GameState.is_over:
		return false
	var data := {
		"meta": {
			"saved_at": int(Time.get_unix_time_from_system()),
			"player_name": GameState.player_name,
			"avatar": GameState.avatar,
			"month": GameState.month,
			"net_worth": GameState.net_worth(),
		},
		"state": GameState.to_dict(),
	}
	return _write_json(_slot_path(slot), data)


func load_slot(slot: String) -> bool:
	var data := _read_json(_slot_path(slot))
	if not data.has("state"):
		return false
	return GameState.load_from_dict(data["state"])


## true jika slot berisi simpanan dari versi game lama (tidak bisa dimuat, tanpa migrasi).
func is_outdated(slot: String) -> bool:
	var state: Dictionary = _read_json(_slot_path(slot)).get("state", {})
	return not state.is_empty() and int(state.get("version", 0)) != GameState.SAVE_VERSION


## Pesan gagal muat yang sesuai penyebabnya.
func load_error_text(slot: String) -> String:
	return tr("SAVE_OUTDATED") if is_outdated(slot) else tr("SAVE_LOAD_FAILED")


func delete_slot(slot: String) -> void:
	if has_slot(slot):
		DirAccess.remove_absolute(_slot_path(slot))


## Hapus SEMUA simpanan dan data pemain (Pengaturan -> Reset Data). Pengaturan tidak ikut dihapus.
func reset_all() -> void:
	delete_slot(AUTO_SLOT)
	for slot: String in MANUAL_SLOTS:
		delete_slot(slot)
	if FileAccess.file_exists(PLAYER_PATH):
		DirAccess.remove_absolute(PLAYER_PATH)
	GameState.player_from_dict({})
	GameState.is_active = false


func has_slot(slot: String) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


## Ringkasan slot untuk ditampilkan di daftar ({} jika kosong).
func slot_meta(slot: String) -> Dictionary:
	if not has_slot(slot):
		return {}
	return _read_json(_slot_path(slot)).get("meta", {})


## "Budi | Maret Tahun 2 | Rp12.345.678 | 12/10/2026 10:30"
func slot_summary(slot: String) -> String:
	var meta := slot_meta(slot)
	if meta.is_empty():
		return tr("SAVE_EMPTY")
	return "%s | %s | %s | %s" % [
		meta["player_name"], Fmt.game_date(int(meta["month"])), Fmt.rupiah(meta["net_worth"]),
		saved_at_text(meta)]


## Waktu simpan (jam lokal HP): "12/10/2026 10:30"
func saved_at_text(meta: Dictionary) -> String:
	var bias_minutes: int = Time.get_time_zone_from_system()["bias"]
	var dt := Time.get_datetime_dict_from_unix_time(int(meta["saved_at"]) + bias_minutes * 60)
	return "%02d/%02d/%d %02d:%02d" % [dt["day"], dt["month"], dt["year"], dt["hour"], dt["minute"]]


func _slot_path(slot: String) -> String:
	return SAVE_DIR + slot + ".json"


func _save_player() -> void:
	_write_json(PLAYER_PATH, GameState.player_to_dict())


func _load_player() -> void:
	var data := _read_json(PLAYER_PATH)
	if not data.is_empty():
		GameState.player_from_dict(data)


## Tulis ke file sementara dulu lalu rename, agar file lama tidak rusak
## jika app mati di tengah penulisan.
func _write_json(path: String, data: Dictionary) -> bool:
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("Gagal menulis %s: %s" % [tmp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return DirAccess.rename_absolute(tmp_path, path) == OK


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
