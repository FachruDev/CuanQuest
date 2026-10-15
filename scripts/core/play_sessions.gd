class_name PlaySessions
extends RefCounted
## Statistik sesi bermain untuk playtest (penutup v1.5): kapan mulai, berapa lama, dan berapa bulan
## yang dimainkan per sesi. Kriteria v1.5-0: penguji rata-rata memainkan minimal 10 bulan per sesi.
## Sesi baru dimulai saat bulan pertama dimainkan setelah jeda >= NEW_AFTER_SECONDS (mis. aplikasi
## ditutup atau ditinggal). Disimpan di data pemain (lokal), tidak dikirim ke mana pun.
##
## Analogi web: seperti "session" di analitik, tetapi hanya disimpan di perangkat.

const MAX_SESSIONS := 20
const NEW_AFTER_SECONDS := 15 * 60

## Terbaru di belakang: [{start, end, months}] (waktu nyata, detik unix).
var sessions: Array[Dictionary] = []


## Dipanggil setiap kali satu bulan permainan selesai dimainkan.
func record_month(now: int) -> void:
	if sessions.is_empty() or now - int(sessions[-1]["end"]) >= NEW_AFTER_SECONDS:
		sessions.append({"start": now, "end": now, "months": 0})
		if sessions.size() > MAX_SESSIONS:
			sessions.pop_front()
	var current: Dictionary = sessions[-1]
	current["months"] = int(current["months"]) + 1
	current["end"] = now


## Rata-rata bulan per sesi dari `count` sesi terakhir (0 jika belum ada).
func average_months(count: int = 10) -> float:
	var recent := sessions.slice(-count)
	if recent.is_empty():
		return 0.0
	var total := 0
	for s: Dictionary in recent:
		total += int(s["months"])
	return float(total) / recent.size()


static func minutes(session: Dictionary) -> int:
	return roundi((int(session["end"]) - int(session["start"])) / 60.0)


func to_dict() -> Dictionary:
	return {"sessions": sessions}


func from_dict(d: Dictionary) -> void:
	sessions.clear()
	for s: Dictionary in d.get("sessions", []):
		sessions.append({"start": int(s["start"]), "end": int(s["end"]), "months": int(s["months"])})
