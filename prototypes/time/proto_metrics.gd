extends RefCounted
## Pengukur uji prototipe. Disimpan terpisah dari state game, sehingga tetap ada walau
## penguji menekan "Mulai ulang". Penguji menyalin laporannya lewat tombol "Salin laporan".
## Dipakai prototipe A (per jam) dan B (hari cepat), masing-masing dengan file sendiri.

const BASE_KEYS := ["first_run", "sessions", "real_seconds", "seconds_by_speed", "seconds_by_scale",
	"manual_pauses", "auto_pauses", "trade", "queued", "cancel", "sleep", "pass_out",
	"skip_payday", "skip_month_end", "event", "day"]

var path := "user://prototype/metrics.json"
var title := "LAPORAN UJI PROTOTIPE A (WAKTU PER JAM)"
var scale_unit := "dtk/jam"
var data := {}


func load_or_create() -> void:
	data = {
		"first_run": Time.get_datetime_string_from_system(), "sessions": 0, "real_seconds": 0.0,
		"seconds_by_speed": {"jeda": 0.0, "1x": 0.0, "2x": 0.0, "4x": 0.0},
		"seconds_by_scale": {},
		"manual_pauses": 0, "auto_pauses": {"popup": 0, "idle": 0, "background": 0},
		"trade": 0, "queued": 0, "cancel": 0, "sleep": 0, "pass_out": 0,
		"skip_payday": 0, "skip_month_end": 0, "event": 0, "day": 0,
	}
	if FileAccess.file_exists(path):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if saved is Dictionary:
			data.merge(saved, true)
	data["sessions"] = int(data["sessions"]) + 1


func save() -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


func reset() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	load_or_create()


func add_time(delta: float, speed_key: String, scale_key: String) -> void:
	data["real_seconds"] += delta
	data["seconds_by_speed"][speed_key] = data["seconds_by_speed"].get(speed_key, 0.0) + delta
	data["seconds_by_scale"][scale_key] = data["seconds_by_scale"].get(scale_key, 0.0) + delta


func count(key: String) -> void:
	data[key] = int(data.get(key, 0)) + 1


func count_auto_pause(reason: String) -> void:
	data["auto_pauses"][reason] = int(data["auto_pauses"].get(reason, 0)) + 1


func report_text() -> String:
	var total := maxf(float(data["real_seconds"]), 1.0)
	var speeds: Array[String] = []
	for key: String in ["jeda", "1x", "2x", "4x"]:
		speeds.append("%s %d%%" % [key, roundi(100.0 * data["seconds_by_speed"].get(key, 0.0) / total)])
	var scales: Array[String] = []
	for key: String in data["seconds_by_scale"]:
		scales.append("%s %s %d mnt" % [key, scale_unit, roundi(data["seconds_by_scale"][key] / 60.0)])
	var others: Array[String] = []  # penghitung khusus prototipe tertentu
	for key: String in data:
		if not BASE_KEYS.has(key):
			others.append("%s %d" % [key, int(data[key])])
	var auto: Dictionary = data["auto_pauses"]
	var days := maxi(int(data["day"]), 1)
	return "\n".join([
		title,
		"Mulai uji: %s | Sesi: %d" % [data["first_run"], int(data["sessions"])],
		"Waktu main nyata: %d menit (rata-rata %d menit/sesi)" % [
			roundi(total / 60.0), roundi(total / 60.0 / maxi(int(data["sessions"]), 1))],
		"Kecepatan: " + ", ".join(speeds),
		"Skala: " + (", ".join(scales) if not scales.is_empty() else "-"),
		"Hari game berlalu: %d (%.1f detik nyata per hari game)" % [int(data["day"]), total / days],
		"Jeda manual: %d | Jeda otomatis: popup %d, diam %d, latar %d" % [
			int(data["manual_pauses"]), int(auto["popup"]), int(auto["idle"]), int(auto["background"])],
		"Transaksi: %d (antre %d, batal %d)" % [int(data["trade"]), int(data["queued"]), int(data["cancel"])],
		"Tidur: %d | Pingsan: %d" % [int(data["sleep"]), int(data["pass_out"])],
		"Lompat ke gajian: %d | Lompat ke akhir bulan: %d" % [int(data["skip_payday"]), int(data["skip_month_end"])],
		"Event muncul: %d" % int(data["event"]),
		"Lainnya: " + (", ".join(others) if not others.is_empty() else "-"),
	])
