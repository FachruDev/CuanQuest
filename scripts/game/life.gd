class_name Life
extends GameModule
## Siklus hidup (v2b). Langkah 1: bab kehidupan (Awal Karier, Membangun, Puncak, Pensiun) dengan
## ringkasan & titik simpan tiap bab, serta pensiun di usia 60 dengan Jaminan Hari Tua (JHT) dan
## Jaminan Pensiun (JP) ala BPJS Ketenagakerjaan. Permainan tidak lagi berhenti saat pensiun.
## Data: data/life.json. Analogi web: seperti "milestone" akun (tahun pertama, tahun kelima) yang
## memicu email ringkasan, ditambah job terjadwal yang mencairkan dana pensiun.

const DATA_PATH := "res://data/life.json"

var data: Dictionary = {}  # isi data/life.json
var chapter := ""  # id bab sekarang ("" = belum dimulai, mis. tepat setelah memuat save lama)
## Keadaan di awal tiap bab: {id, month, age, worth, real_worth, dreams, level, job_id}
var chapter_log: Array[Dictionary] = []
var retired := false
var retired_month := -1
var jht := 0.0  # saldo Jaminan Hari Tua (nominal), cair saat pensiun
var jp_months := 0  # bulan iuran Jaminan Pensiun
var jp_real_wage := 0.0  # jumlah upah riil (dibatasi) selama iuran, untuk rata-rata JP bulanan
var jp_wage_sum := 0.0  # jumlah upah nominal (dibatasi), untuk JP sekaligus jika iuran < 15 tahun
var pension_real := 0.0  # JP bulanan dalam Rupiah awal permainan (dibayar ikut inflasi)
var retirement_info: Dictionary = {}  # {month, jht, jp_monthly, jp_lump, years} saat pensiun
var _legacy := false  # save sebelum v2b: perkiraan JHT/JP dibuat setelah pasar dimuat


func load_data() -> void:
	data = DataLoader.load_json(DATA_PATH)


func reset() -> void:
	chapter = ""
	chapter_log.clear()
	retired = false
	retired_month = -1
	jht = 0.0
	jp_months = 0
	jp_real_wage = 0.0
	jp_wage_sum = 0.0
	pension_real = 0.0
	retirement_info = {}
	_legacy = false


func save_to(d: Dictionary) -> void:
	d.merge({"chapter": chapter, "chapter_log": chapter_log, "retired": retired, "retired_month": retired_month,
		"jht": jht, "jp_months": jp_months, "jp_real_wage": jp_real_wage, "jp_wage_sum": jp_wage_sum,
		"pension_real": pension_real, "retirement_info": retirement_info})


func load_from(d: Dictionary) -> void:
	reset()
	if not d.has("chapter"):
		_legacy = true
		return
	chapter = d["chapter"]
	for entry: Dictionary in d.get("chapter_log", []):
		var copy := entry.duplicate()
		for key: String in ["month", "age", "dreams", "level"]:
			copy[key] = int(copy[key])
		chapter_log.append(copy)
	retired = bool(d.get("retired", false))
	retired_month = int(d.get("retired_month", -1))
	jht = float(d.get("jht", 0.0))
	jp_months = int(d.get("jp_months", 0))
	jp_real_wage = float(d.get("jp_real_wage", 0.0))
	jp_wage_sum = float(d.get("jp_wage_sum", 0.0))
	pension_real = float(d.get("pension_real", 0.0))
	retirement_info = d.get("retirement_info", {})


## Dipanggil setelah permainan baru dibuat atau save dimuat (pasar sudah siap): bab pertama dicatat.
## Save sebelum v2b: saldo JHT & masa iuran JP diperkirakan dari riwayat gaji & pengalaman kerja formal.
func begin() -> void:
	if _legacy:
		_legacy = false
		var cfg: Dictionary = data["retirement"]
		var total_salary := float(gs.stats["total_salary"])
		for track: String in gs.career.experience:
			if track != "gig":
				jp_months += int(gs.career.experience[track])
		jht = total_salary * float(cfg["jht_rate"]) * 1.15  # perkiraan imbal hasil yang sudah terkumpul
		jp_wage_sum = total_salary
		jp_real_wage = total_salary / gs.price_level()
	if chapter == "":
		chapter = chapter_for(gs.age())
		chapter_log.append(_snapshot(chapter))


static func chapter_ids() -> Array[String]:
	return ["early", "build", "peak", "retire"]


func chapter_for(age: int) -> String:
	var id := ""
	for def: Dictionary in data["chapters"]:
		if age >= int(def["from_age"]):
			id = def["id"]
	return id


## Rentang usia bab, mis. [30, 44] (akhir -1 = tanpa batas).
func chapter_ages(id: String) -> Array[int]:
	var chapters: Array = data["chapters"]
	for i in chapters.size():
		if chapters[i]["id"] == id:
			var start := maxi(int(chapters[i]["from_age"]), int(gs.background["start_age"]))
			var end := int(chapters[i + 1]["from_age"]) - 1 if i + 1 < chapters.size() else -1
			return [start, end]
	return [0, -1]


func _snapshot(id: String) -> Dictionary:
	var worth := gs.net_worth()
	return {"id": id, "month": gs.month, "age": gs.age(), "worth": worth, "real_worth": gs.real_value(worth),
		"dreams": int(gs.stats["dreams_achieved"]), "level": int(gs.career.current_job_def().get("level", 0)),
		"job_id": gs.career.job.get("id", "")}


# --- Alur bulanan (dipanggil GameState._start_month, sebelum gaji) --------------------------------

## Usia pensiun tercapai: pensiun dulu (bulan ini tanpa gaji). Lalu jika usia melewati batas bab,
## bab lama ditutup dan ringkasannya dikirim setelah laporan bulanan (signal chapter_changed).
## Mengembalikan bahan laporan ({} jika tidak ada apa-apa).
func month_start() -> Dictionary:
	var report := {}
	if not retired and gs.age() >= int(data["retirement"]["age"]):
		report["retirement"] = retire()
	var id := chapter_for(gs.age())
	if chapter != "" and id != chapter:
		var summary := {"from": chapter, "to": id, "start": chapter_log[-1], "end": _snapshot(id)}
		chapter = id
		chapter_log.append(summary["end"])
		gs.queue_after_report(func() -> void: gs.chapter_changed.emit(summary))
	return report


## Iuran BPJS Ketenagakerjaan bulan ini: saldo JHT tumbuh, lalu pekerjaan formal (berjenjang) yang
## membayar gaji menambah JHT 3,7% gaji serta masa iuran & upah JP (dibatasi batas upah, ikut inflasi).
func accrue(paid: int) -> void:
	var cfg: Dictionary = data["retirement"]
	jht *= 1.0 + float(cfg["jht_return"]) / 12.0
	if paid <= 0 or not gs.career.is_career():
		return
	jht += paid * float(cfg["jht_rate"])
	var wage := minf(paid, gs.nominal(float(cfg["jp_wage_cap"])))
	jp_months += 1
	jp_wage_sum += wage
	jp_real_wage += wage / gs.price_level()


## JP yang dibayar bulan ini (nominal, ikut inflasi). 0 sebelum pensiun atau jika JP dibayar sekaligus.
func pension_payment() -> int:
	return roundi(pension_real * gs.price_level()) if retired else 0


## Perkiraan JP bulanan jika pensiun dengan masa iuran sekarang (Rupiah hari ini), untuk kartu karier.
func projected_pension() -> int:
	var cfg: Dictionary = data["retirement"]
	var years := jp_months / 12.0
	if years < float(cfg["jp_min_years"]):
		return 0
	return roundi(float(cfg["jp_rate_per_year"]) * years * jp_real_wage / maxf(jp_months, 1.0) * gs.price_level())


## Pensiun: pekerjaan berakhir (bukan PHK), JHT cair sekaligus, JP mulai dibayar bulanan (atau sekaligus
## jika masa iuran kurang dari 15 tahun). Popup dikirim setelah laporan (signal retirement_started).
func retire() -> Dictionary:
	var cfg: Dictionary = data["retirement"]
	retired = true
	retired_month = gs.month
	if gs.career.is_employed():
		gs.career.retire()
	var payout := roundi(jht)
	jht = 0.0
	var years := jp_months / 12.0
	var jp_lump := 0
	if years >= float(cfg["jp_min_years"]):
		pension_real = float(cfg["jp_rate_per_year"]) * years * jp_real_wage / maxf(jp_months, 1.0)
	elif jp_months > 0:
		jp_lump = roundi(jp_wage_sum * float(cfg["jp_lump_rate"]))
	gs.cash += payout + jp_lump
	gs.stats["retirement_payout"] = payout + jp_lump
	retirement_info = {"month": gs.month, "jht": payout, "jp_monthly": pension_payment(), "jp_lump": jp_lump,
		"years": snappedf(years, 0.1)}
	var info := retirement_info.duplicate()
	gs.queue_after_report(func() -> void: gs.retirement_started.emit(info))
	return info
