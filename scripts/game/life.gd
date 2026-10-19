class_name Life
extends GameModule
## Siklus hidup (v2b). Langkah 1: bab kehidupan (Awal Karier, Membangun, Puncak, Pensiun) dengan
## ringkasan & titik simpan tiap bab, serta pensiun di usia 60 dengan Jaminan Hari Tua (JHT) dan
## Jaminan Pensiun (JP) ala BPJS Ketenagakerjaan. Permainan tidak lagi berhenti saat pensiun.
## Langkah 2: penuaan (energi, penurunan kesehatan alami, biaya berobat, peluang diterima kerja)
## dengan pemberitahuan setiap kali efek usia berubah. Langkah 3: status Kritis, masa senja, dan
## kematian yang selalu didahului peringatan (docs/PEDOMAN_KONTEN_SENSITIF.md). Data: data/life.json.
## Analogi web: seperti "milestone" akun (tahun pertama, tahun kelima) yang memicu email ringkasan,
## ditambah job terjadwal yang mencairkan dana pensiun.

const DATA_PATH := "res://data/life.json"
## Event yang dijadwalkan modul ini (bukan undian): perawatan saat status Kritis dimulai.
const SCHEDULED_EVENTS := ["critical_care"]

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
var critical := false  # status Kritis (kesehatan < critical_below), langkah 3
var critical_since := -1  # bulan status Kritis dimulai (peringatan tampil setelah laporan bulan itu)
var critical_count := 0  # berapa kali masuk status Kritis
var twilight_month := -1  # bulan pemberitahuan masa senja terakhir (usia 70+)
var twilight_since := -1  # bulan pemberitahuan masa senja pertama (undian mulai bulan berikutnya)
var death: Dictionary = {}  # {month, age, cause, payout} saat meninggal dunia
var rng := RandomNumberGenerator.new()  # undian peluang meninggal, terpisah dari RNG utama
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
	critical = false
	critical_since = -1
	critical_count = 0
	twilight_month = -1
	twilight_since = -1
	death = {}
	rng.seed = gs.rng.seed + int(data.get("mortality", {}).get("rng_offset", 5))  # GameState.rng sudah di-seed
	_legacy = false


func save_to(d: Dictionary) -> void:
	d.merge({"chapter": chapter, "chapter_log": chapter_log, "retired": retired, "retired_month": retired_month,
		"jht": jht, "jp_months": jp_months, "jp_real_wage": jp_real_wage, "jp_wage_sum": jp_wage_sum,
		"pension_real": pension_real, "retirement_info": retirement_info, "critical": critical,
		"critical_since": critical_since, "critical_count": critical_count, "twilight_month": twilight_month,
		"twilight_since": twilight_since,
		"death": death, "life_rng": [str(rng.seed), str(rng.state)]})


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
	critical = bool(d.get("critical", false))  # save sebelum langkah 3: belum ada status Kritis
	critical_since = int(d.get("critical_since", -1))
	critical_count = int(d.get("critical_count", 0))
	twilight_month = int(d.get("twilight_month", -1))
	twilight_since = int(d.get("twilight_since", twilight_month))  # save sebelum langkah 5: dari pemberitahuan terakhir
	death = d.get("death", {})
	if d.has("life_rng"):
		rng.seed = String(d["life_rng"][0]).to_int()
		rng.state = String(d["life_rng"][1]).to_int()


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
## Keadaan akhir bab dicatat sebelum pensiun, agar jabatan terakhir ikut tercatat.
## Mengembalikan bahan laporan ({} jika tidak ada apa-apa).
func month_start() -> Dictionary:
	var report := {}
	var id := chapter_for(gs.age())
	var end := _snapshot(id) if chapter != "" and id != chapter else {}
	if not retired and gs.age() >= int(data["retirement"]["age"]):
		report["retirement"] = retire()
	var aging_notice := gs.month > 0 and gs.month % 12 == 0 and gs.age() in aging_ages()  # ulang tahun ke-40, 45, ...
	var twilight := gs.age() >= int(data["mortality"]["twilight_age"]) and (gs.month % 12 == 0 or twilight_month < 0)
	if twilight:  # masa senja: pemberitahuan tahunan (atau saat save lama 70+ pertama dimuat), digabung dengan efek usia
		twilight_month = gs.month
		if twilight_since < 0:
			twilight_since = gs.month
		var info := {"age": gs.age(), "chance": annual_death_chance(), "aging": aging_notice}
		report["twilight"] = info
		gs.queue_after_report(func() -> void: gs.twilight_notice.emit(info))
		aging_notice = false
	if not end.is_empty():
		var summary := {"from": chapter, "to": id, "start": chapter_log[-1], "end": end, "aging": aging_notice}
		chapter = id
		chapter_log.append(summary["end"])
		gs.queue_after_report(func() -> void: gs.chapter_changed.emit(summary))
	elif aging_notice:  # efek usia ikut tampil di ringkasan bab; selain itu popup tersendiri
		var age := gs.age()
		gs.queue_after_report(func() -> void: gs.aging_changed.emit(age))
	return report


## Bahan teks event bertema usia: investasi & penarikan aman per bulan menurut aturan 4% (dibulatkan,
## karena teksnya menyebut "sekitar").
func event_vars(id: String) -> Dictionary:
	if id == "retirement_withdrawal":
		var invest := gs.portfolio.investments_value()
		var withdraw := invest * float(gs.economy["end"]["freedom_rate"]) / 12.0
		return {"invest": snappedi(roundi(invest), 1_000_000 if invest >= 10_000_000.0 else 10_000),
			"withdraw": snappedi(roundi(withdraw), 1_000)}
	return {}


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


## Perkiraan dana masa pensiun (v2b langkah 5): berapa bulan kas + investasi menutup selisih pengeluaran
## rutin dengan JP & sewa bersih (tanpa imbal hasil & inflasi, yang kira-kira saling menutup). months = -1
## jika pendapatan pensiun & sewa sudah menutup pengeluaran; low = habis sebelum usia runway_warn_age.
func runway_info() -> Dictionary:
	var gap := float(gs.monthly_spending()) - pension_payment() - gs.properties.rent_income()
	if gap <= 0.0:
		return {"months": -1, "until_age": -1, "low": false}
	var months := floori((maxf(gs.cash, 0.0) + gs.portfolio.investments_value()) / gap)
	var until_age := gs.age() + floori(months / 12.0)
	return {"months": months, "until_age": until_age, "low": until_age < int(data["retirement"]["runway_warn_age"])}


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


# --- Penuaan (langkah 2) ----------------------------------------------------------------------

## Baris tabel usia yang berlaku: baris terakhir yang usia mulainya <= `age` ([] jika belum ada).
static func band(table: Array, age: int) -> Array:
	var row: Array = []
	for r: Array in table:
		if age >= int(r[0]):
			row = r
	return row


func _aging_row(key: String) -> Array:
	return band(data.get("aging", {}).get(key, []), gs.age())


## Perubahan energi maksimal bulanan karena usia (0, -1, -2).
func energy_change() -> int:
	var row := _aging_row("energy")
	return int(row[1]) if not row.is_empty() else 0


## Penurunan kesehatan alami bulan ini (poin): berlaku tiap N bulan sesuai kelompok usia.
func health_decline() -> int:
	var row := _aging_row("health_decline")
	if row.is_empty() or gs.month % int(row[2]) != 0:
		return 0
	return int(row[1])


## Pengali biaya berobat (pilihan event "claim": "medical").
func medical_mult() -> float:
	var row := _aging_row("medical_cost")
	return float(row[1]) if not row.is_empty() else 1.0


## Pengali peluang diterima pekerjaan berjenjang.
func hire_mult() -> float:
	var row := _aging_row("hire_chance")
	return float(row[1]) if not row.is_empty() else 1.0


## Efek usia sekarang untuk UI: {energy, health, every, medical, hire}; nilai netral = tanpa efek.
func aging_effects() -> Dictionary:
	var decline := _aging_row("health_decline")
	return {"energy": energy_change(), "health": int(decline[1]) if not decline.is_empty() else 0,
		"every": int(decline[2]) if not decline.is_empty() else 0, "medical": medical_mult(), "hire": hire_mult()}


## Usia saat efek penuaan berubah (awal kelompok usia di semua tabel), urut naik.
func aging_ages() -> Array[int]:
	var ages: Array[int] = []
	for table: Array in data.get("aging", {}).values():
		for row: Array in table:
			if not int(row[0]) in ages:
				ages.append(int(row[0]))
	ages.sort()
	return ages


# --- Kesehatan Kritis & kematian (langkah 3) -----------------------------------------------------

## Peluang meninggal dalam setahun menurut usia & kesehatan sekarang (tabel `mortality`).
func annual_death_chance(health := -1) -> float:
	var cfg: Dictionary = data["mortality"]
	var base := band(cfg["base"], gs.age())
	var mult := band(cfg["health_mult"], gs.health if health < 0 else health)
	return (float(base[1]) if not base.is_empty() else 0.0) * (float(mult[1]) if not mult.is_empty() else 1.0)


## Undian bulan ini hanya berlaku setelah peringatan (pedoman konten sensitif): status Kritis yang
## sudah diumumkan bulan lalu dan kesehatan masih rendah, atau pemberitahuan masa senja.
func is_warned() -> bool:
	var cfg: Dictionary = data["mortality"]
	if critical and critical_since < gs.month and gs.health < int(cfg["critical_exit"]):
		return true
	# Masa senja: mulai bulan setelah pemberitahuan PERTAMA. Pemberitahuan tahunan berikutnya tidak menunda
	# undian (langkah 5), agar peluang sungguhan sama dengan peluang per tahun yang ditampilkan.
	return gs.age() >= int(cfg["twilight_age"]) and twilight_since >= 0 and twilight_since < gs.month


func monthly_death_chance() -> float:
	return annual_death_chance() / 12.0 if is_warned() else 0.0


## Dipanggil GameState.advance_month setelah kondisi bulan ini dihitung: undian peluang meninggal
## (hanya setelah peringatan), lalu status Kritis dimulai/berakhir. Mengembalikan bahan laporan.
func check_health() -> Dictionary:
	var cfg: Dictionary = data["mortality"]
	var report := {}
	var chance := monthly_death_chance()
	if chance > 0.0 and rng.randf() < chance:
		die("critical" if critical else "old_age")
		return report
	if not critical and gs.health < int(cfg["critical_below"]):
		critical = true
		critical_since = gs.month
		critical_count += 1
		var info := {"health": gs.health, "age": gs.age(), "chance": annual_death_chance()}
		report["critical_started"] = info
		gs.queue_after_report(func() -> void: gs.critical_started.emit(info))
	elif critical and gs.health >= int(cfg["critical_exit"]):
		critical = false
		report["critical_ended"] = true
	if critical:
		report["critical"] = {"health": gs.health, "chance": annual_death_chance()}
	return report


## Meninggal dunia: uang pertanggungan asuransi jiwa (jika polis aktif) masuk ke warisan.
## `cause`: old_age | critical | illness. GameState._check_end lalu mengakhiri permainan.
func die(cause: String) -> void:
	if not death.is_empty():
		return
	var payout := gs.insurance.death_payout()
	gs.cash += payout
	gs.stats["life_insurance_payout"] = payout
	death = {"month": gs.month, "age": gs.age(), "cause": cause, "payout": payout}


## Perawatan kritis dijadwalkan di bulan status Kritis dimulai (di luar jatah event acak).
func scheduled_events() -> Array[Dictionary]:
	var picked: Array[Dictionary] = []
	if scheduled_event_valid("critical_care"):
		var def := gs.events.catalog.find("critical_care")
		if not def.is_empty():
			picked.append(def)
	return picked


func scheduled_event_valid(id: String) -> bool:
	return id == "critical_care" and critical and critical_since == gs.month and death.is_empty()
