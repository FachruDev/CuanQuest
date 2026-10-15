class_name Achievements
extends RefCounted
## Pencapaian & kosmetik (v1.5d langkah 4). Berlaku LINTAS permainan: tersimpan di data pemain
## (seperti kuis & petunjuk), bukan di slot save, sehingga pencapaian dari permainan lama tetap ada.
## Pencapaian membuka kosmetik tanpa aset baru: bingkai avatar (warna) dan gelar di bawah nama.
## Tidak mengubah keadaan permainan (tanpa uang/XP/undian), jadi aman bagi simulasi.
## Data: data/achievements.json.
##
## Analogi web: seperti tabel "badges" milik akun, terpisah dari data tiap sesi permainan.

const ACHIEVEMENTS_PATH := "res://data/achievements.json"
const ICON_PATH := "res://assets/icons/achievements/%s.svg"
const INVEST_CLASSES := ["mutual_fund", "stock", "crypto", "commodity"]  # termasuk emas & komoditas (v2a)

var gs: GameStore
var data: Dictionary = {}  # isi data/achievements.json
## id -> {"date": waktu nyata (unix), "name": nama pemain saat terbuka}
var unlocked: Dictionary = {}
var frame := ""  # bingkai avatar terpilih ("" = bawaan)
var title := ""  # id pencapaian yang gelarnya dipakai ("" = tanpa gelar)


func _init(state: GameStore) -> void:
	gs = state


func load_data() -> void:
	data = DataLoader.load_json(ACHIEVEMENTS_PATH)


func to_dict() -> Dictionary:
	return {"unlocked": unlocked, "frame": frame, "title": title}


func from_dict(d: Dictionary) -> void:
	unlocked.clear()
	for id: String in d.get("unlocked", {}):
		unlocked[id] = d["unlocked"][id]
	frame = d.get("frame", "")
	title = d.get("title", "")


func defs() -> Array:
	return data.get("achievements", [])


func def(id: String) -> Dictionary:
	for d: Dictionary in defs():
		if d["id"] == id:
			return d
	return {}


func is_unlocked(id: String) -> bool:
	return unlocked.has(id)


## Jumlah pencapaian terbuka yang masih ada di data (id lama yang sudah diganti tidak dihitung).
func unlocked_count() -> int:
	return defs().filter(func(d: Dictionary) -> bool: return unlocked.has(d["id"])).size()


func icon(id: String) -> String:
	var path := ICON_PATH % id
	return path if ResourceLoader.exists(path) else ""


# --- Syarat -------------------------------------------------------------------------------------

func target(d: Dictionary) -> float:
	return float(d.get("min", 1))


## Nilai sekarang untuk syarat pencapaian (dibandingkan dengan target). Permainan yang sedang
## berjalan; kuis memakai data lintas permainan.
func value(d: Dictionary) -> float:
	match d["type"]:
		"stat":
			return float(gs.stats.get(d["key"], 0))
		"invested":
			var total := 0.0
			for id: String in gs.portfolio.holdings:
				if gs.market.get_asset(id).asset_class in INVEST_CLASSES:
					total += gs.portfolio.holding_value(id)
			return total
		"emergency_months":  # dibulatkan: autodebet berhenti tepat di target, inflasi membuatnya 5,99
			return snappedf(gs.budget.emergency_balance() / maxf(gs.monthly_expenses(), 1.0), 0.1)
		"net_worth":
			return gs.net_worth()
		"freedom":
			return 1.0 if gs.is_financially_free() else 0.0
		"own_home":
			return 1.0 if not gs.properties.home().is_empty() else 0.0
		"quiz_correct":
			return float(gs.quiz.correct_ids.size())
		"job_level":
			return float(gs.career.current_job_def()["level"]) if gs.career.is_career() else 0.0
		"credit_score":
			return float(gs.debt.credit_score)
		"research_correct":
			var record := gs.research.record
			return float(record["basic"][1]) + float(record["deep"][1])
		"relationship":
			var best := 0
			for id: String in gs.characters.known():
				best = maxi(best, gs.characters.rel_of(id))
			return float(best)
		"months":
			return float(gs.month)
		"bear_hold":
			return 0.0 if gs.stats["panic_sell"] else float(gs.stats.get("bear_months_held", 0))
	return 0.0


## Periksa semua pencapaian yang belum terbuka. Mengembalikan id yang baru terbuka.
func check() -> Array[String]:
	var fresh: Array[String] = []
	if not gs.is_active:
		return fresh
	for d: Dictionary in defs():
		if not unlocked.has(d["id"]) and value(d) >= target(d):
			unlocked[d["id"]] = {"date": int(Time.get_unix_time_from_system()), "name": gs.player_name}
			fresh.append(d["id"])
	return fresh


# --- Kosmetik ------------------------------------------------------------------------------------

func frames() -> Array:
	return data.get("frames", [])


func frame_def(id: String) -> Dictionary:
	for f: Dictionary in frames():
		if f["id"] == id:
			return f
	return frames()[0]


## Bingkai bawaan (yang pertama) selalu tersedia; sisanya dibuka pencapaian.
func frame_unlocked(id: String) -> bool:
	if id == frames()[0]["id"]:
		return true
	for d: Dictionary in defs():
		if d.get("frame", "") == id and unlocked.has(d["id"]):
			return true
	return false


## Pencapaian yang membuka bingkai `id` (untuk keterangan di Profil).
func frame_source(id: String) -> String:
	for d: Dictionary in defs():
		if d.get("frame", "") == id:
			return d["id"]
	return ""


func current_frame() -> Dictionary:
	return frame_def(frame if frame != "" and frame_unlocked(frame) else frames()[0]["id"])


## Gelar terpilih (teks sudah diterjemahkan) atau "" jika tanpa gelar.
func current_title() -> String:
	if title == "" or not unlocked.has(title):
		return ""
	return TranslationServer.translate("TITLE_" + title.to_upper())


func titles_unlocked() -> Array[String]:
	var ids: Array[String] = []
	for d: Dictionary in defs():
		if d.get("title", false) and unlocked.has(d["id"]):
			ids.append(d["id"])
	return ids


func set_frame(id: String) -> void:
	if frame_unlocked(id):
		frame = id
		gs.player_changed.emit()
		gs.changed.emit()


## "" = tanpa gelar.
func set_title(id: String) -> void:
	if id == "" or (unlocked.has(id) and def(id).get("title", false)):
		title = id
		gs.player_changed.emit()
		gs.changed.emit()
