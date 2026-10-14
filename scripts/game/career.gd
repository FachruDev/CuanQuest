class_name Career
extends GameModule
## Pekerjaan & karier (v1.5b): lowongan, lamaran, tawaran, gaji, kinerja, kenaikan prestasi,
## promosi, PHK, berhenti, keahlian, pengalaman, dan perjalanan karier. Data: data/jobs.json.

const JOBS_PATH := "res://data/jobs.json"
const MAX_CAREER_LOG := 60
## Event karier yang dijadwalkan sistem (bukan acak), lihat scheduled_events().
const SCHEDULED_EVENTS := ["interview", "layoff", "promotion"]

var salary: int = 0  # gaji bruto pekerjaan sekarang (0 = belum bekerja)
var unpaid_months: int = 0  # sisa bulan cuti tanpa gaji (mis. sakit kritis), pekerjaan tetap
## Pekerjaan & karier (v1.5b). job = {} jika belum/tidak bekerja; {"id", "company", "since", "hired"}
## (since = mulai menjabat posisi ini, hired = mulai bekerja di perusahaan ini).
var job: Dictionary = {}
var performance := 0.0  # kinerja 0-100 di pekerjaan berjenjang (v1.5b langkah 2)
var skill := 0.0  # keahlian 0-100
var experience: Dictionary = {}  # bidang -> bulan bekerja
var job_board: Array[Dictionary] = []  # lowongan bulan ini: [{job_id, company, salary, applied}]
var applications: Array[Dictionary] = [] # lamaran bulan ini (hasilnya awal bulan depan)
var job_offers: Array[Dictionary] = []  # lamaran yang diterima, menunggu keputusan pemain
var data: Dictionary = {}  # isi data/jobs.json
## Perjalanan karier (v1.5b langkah 4), terlama di depan: [{month, kind, job_id?, company?, program?}].
## kind: hired | promoted | laid_off | resigned | graduated | dropped_out.
var history: Array[Dictionary] = []


func load_data() -> void:
	data = DataLoader.load_json(JOBS_PATH)


func reset() -> void:
	salary = 0  # v1.5b: mulai tanpa pekerjaan, harus melamar
	job = {}
	skill = float(gs.background["skill"])
	experience.clear()
	job_board.clear()
	applications.clear()
	job_offers.clear()
	performance = 0.0
	history.clear()
	unpaid_months = 0


func save_to(d: Dictionary) -> void:
	d.merge({"salary": salary, "unpaid_months": unpaid_months, "job": job, "performance": performance,
		"skill": skill, "experience": experience, "job_board": job_board, "applications": applications,
		"job_offers": job_offers, "career_log": history})


func load_from(d: Dictionary) -> void:
	salary = int(d["salary"])
	unpaid_months = int(d["unpaid_months"])
	job = {}
	if not d["job"].is_empty():
		job = {"id": d["job"]["id"], "company": d["job"]["company"], "since": int(d["job"]["since"]),
			"hired": int(d["job"].get("hired", d["job"]["since"]))}
	performance = float(d.get("performance", data["performance"]["start"] if not job.is_empty() else 0.0))
	skill = float(d["skill"])
	experience.clear()
	for track: String in d["experience"]:
		experience[track] = int(d["experience"][track])
	for list: Array in [[job_board, d["job_board"]], [applications, d["applications"]], [job_offers, d["job_offers"]]]:
		var target: Array[Dictionary] = list[0]
		target.clear()
		for entry: Dictionary in list[1]:
			var copy := entry.duplicate()
			copy["salary"] = int(entry["salary"])
			target.append(copy)
	history.clear()
	for entry: Dictionary in d.get("career_log", []):
		var copy := entry.duplicate()
		copy["month"] = int(copy["month"])
		history.append(copy)


## Efek event karier: gaji, cuti tanpa gaji, keahlian, kehilangan kerja, kinerja, promosi, PHK,
## negosiasi tawaran, tawaran headhunter.
func apply_effects(e: Dictionary) -> void:
	if e.has("salary_pct"):
		salary = roundi(salary * (1.0 + float(e["salary_pct"])) / 1000.0) * 1000
	if is_employed():  # cuti tanpa gaji hanya berarti jika sedang bekerja
		unpaid_months += int(e.get("unpaid_months", 0))
	if e.has("skill"):
		gain_skill(float(e["skill"]))
	if e.get("lose_job", false):
		_leave_job()
	if is_career():
		performance = clampf(performance + float(e.get("performance", 0)), 0.0, 100.0)
	if e.get("promote", false):
		_promote()
	if e.get("layoff", false):
		_lay_off()
	if e.has("offer_raise"):
		_raise_offer(float(e["offer_raise"]))
	if e.get("headhunter", false) and gs.events.pending_vars.has("offer"):
		job_offers.append(gs.events.pending_vars["offer"].duplicate())


## Isian teks event karier ({job}, {company}, {salary}, {months}, {severance}, {raise}).
func event_vars(id: String) -> Dictionary:
	match id:
		"interview":
			var i := interview_offer_index()
			if i >= 0:
				var offer: Dictionary = job_offers[i]
				return {"offer_index": i, "job_id": offer["job_id"], "company": offer["company"], "salary": offer["salary"]}
		"promotion":
			return {"job_id": next_job_def()["id"], "salary": promotion_salary(), "months": months_in_role()}
		"layoff":
			var months := severance_months()
			return {"job_id": job["id"], "company": job["company"], "months": months, "severance": months * salary}
		"headhunter":
			var offer := _headhunter_offer()
			if not offer.is_empty():
				return {"offer": offer, "job_id": offer["job_id"], "company": offer["company"],
					"salary": offer["salary"], "raise": float(offer["salary"]) / maxf(salary, 1.0) - 1.0}
	return {}


## Event karier terjadwal masih relevan saat gilirannya tiba? (mis. promosi batal setelah PHK)
func scheduled_event_valid(id: String) -> bool:
	match id:
		"interview":
			return interview_offer_index() >= 0
		"promotion":
			return promotion_ready()
	return is_career()  # layoff


func is_employed() -> bool:
	return not job.is_empty()


func job_def(id: String) -> Dictionary:
	for def: Dictionary in data.get("jobs", []):
		if def["id"] == id:
			return def
	return {}


func track_def(id: String) -> Dictionary:
	for def: Dictionary in data.get("tracks", []):
		if def["id"] == id:
			return def
	return {}


func current_job_def() -> Dictionary:
	return job_def(job.get("id", ""))


## Kerja lepas: penghasilan naik-turun tiap bulan (0.3 = hingga 30%).
func income_volatility() -> float:
	return float(current_job_def().get("volatility", 0.0))


func skill_requirement(def: Dictionary) -> float:
	if def.has("skill"):
		return float(def["skill"])
	return float(data["skill_by_level"][int(def["level"]) - 1])


## Pengalaman di bidang yang sama yang dibutuhkan pelamar dari luar (kerja lepas: tidak ada).
func experience_requirement(def: Dictionary) -> int:
	if def["track"] == "gig":
		return 0
	return int(data["experience_by_level"][int(def["level"]) - 1])


## Syarat lowongan untuk ditampilkan: [{type: education|skill|experience, need, have, met}]
func requirements(def: Dictionary) -> Array[Dictionary]:
	var reqs: Array[Dictionary] = []
	var need_education := gs.education.level_index(def.get("education", ""))
	if need_education >= 0:
		reqs.append({"type": "education", "need": need_education, "have": gs.education.level, "met": gs.education.level >= need_education})
	var need_skill := skill_requirement(def)
	if need_skill > 0.0:
		reqs.append({"type": "skill", "need": need_skill, "have": skill, "met": skill + 0.001 >= need_skill})
	var need_experience := experience_requirement(def)
	if need_experience > 0:
		var have := int(experience.get(def["track"], 0))
		reqs.append({"type": "experience", "need": need_experience, "have": have, "met": have >= need_experience})
	return reqs


func meets_requirements(def: Dictionary) -> bool:
	return requirements(def).all(func(r: Dictionary) -> bool: return r["met"])


## Peluang diterima (0-1). 0 jika ada syarat yang belum terpenuhi.
func hire_chance(def: Dictionary) -> float:
	if not meets_requirements(def):
		return 0.0
	var cfg: Dictionary = data["chance"]
	if def["track"] == "gig":
		return float(cfg["gig"])
	var chance := float(cfg["base"]) + float(cfg["per_5_skill"]) * floorf((skill - skill_requirement(def)) / 5.0)
	if gs.education.level > gs.education.level_index(def.get("education", "")):
		chance += float(cfg["higher_education"])
	return clampf(chance, 0.0, float(cfg["max"]))


## "" jika lowongan ke-`index` bisa dilamar, atau key pesan alasannya.
func apply_block_reason(index: int) -> String:
	var opening: Dictionary = job_board[index]
	if opening.get("applied", false):
		return "ERR_JOB_APPLIED"
	if is_employed() and job["id"] == opening["job_id"] and job["company"] == opening["company"]:
		return "ERR_JOB_CURRENT"
	if gs.is_over or gs.events.has_pending():
		return "ERR_ACTIVITY_BUSY"
	if not meets_requirements(job_def(opening["job_id"])):
		return "ERR_JOB_REQUIREMENTS"
	if applications.size() >= int(data["applications_per_month"]):
		return "ERR_JOB_LIMIT"
	if gs.activities.energy < int(data["apply_energy"]):
		return "ERR_NO_ENERGY"
	return ""


## Melamar lowongan ke-`index` bulan ini (memakai energi). -> {ok, error}
func apply_job(index: int) -> Dictionary:
	var reason := apply_block_reason(index)
	if reason != "":
		return {"ok": false, "error": reason}
	var opening: Dictionary = job_board[index]
	gs.activities.energy -= int(data["apply_energy"])
	opening["applied"] = true
	applications.append({"job_id": opening["job_id"], "company": opening["company"],
		"salary": opening["salary"], "chance": hire_chance(job_def(opening["job_id"]))})
	gs.stats["applications"] += 1
	gs.changed.emit()
	gs.state_committed.emit()
	return {"ok": true}


## Mengambil tawaran ke-`index`; tawaran lain otomatis ditolak. Jika bulan ini belum ada
## gaji (baru mulai bekerja), gaji pertama langsung dibayar agar modal tidak habis menunggu.
func accept_offer(index: int) -> void:
	var offer: Dictionary = job_offers[index]
	var first_salary := 0
	if not is_employed() and gs.budget.month_income == 0:
		first_salary = int(offer["salary"])
	job = {"id": offer["job_id"], "company": offer["company"], "since": gs.month, "hired": gs.month}
	record("hired")
	gs.education.check_sponsor()
	salary = int(offer["salary"])
	unpaid_months = 0
	performance = float(data["performance"]["start"])
	job_offers.clear()
	gs.stats["jobs_taken"] += 1
	if is_career():
		gs.stats["top_level"] = maxi(int(gs.stats["top_level"]), int(current_job_def()["level"]))
	if first_salary > 0:
		var tax := gs.income_tax(first_salary)
		gs.cash += first_salary - tax
		gs.budget.month_income = first_salary - tax
		gs.stats["total_salary"] += first_salary
		gs.stats["total_taxes"] += tax
	gs.changed.emit()
	gs.state_committed.emit()


func decline_offers() -> void:
	job_offers.clear()
	gs.changed.emit()
	gs.state_committed.emit()


## Hasil lamaran bulan lalu: diterima -> tawaran (job_offers), sisanya ditolak.
## Tawaran lama yang tidak diambil sudah kedaluwarsa.
func resolve_applications() -> Dictionary:
	job_offers.clear()
	var accepted: Array[String] = []
	var rejected: Array[String] = []
	for application: Dictionary in applications:
		var title: String = job_def(application["job_id"])["title"]
		if gs.rng.randf() < float(application["chance"]):
			job_offers.append(application)
			accepted.append("%s · %s" % [title, application["company"]])
		else:
			rejected.append("%s · %s" % [title, application["company"]])
	applications.clear()
	return {"accepted": accepted, "rejected": rejected}


## Gaji bulan ini: 0 jika belum bekerja atau sedang cuti tanpa gaji; kerja lepas naik-turun.
func monthly_pay() -> int:
	if not is_employed():
		gs.stats["months_unemployed"] += 1
		return 0
	if unpaid_months > 0:
		unpaid_months -= 1
		return 0
	var volatility := income_volatility()
	if volatility > 0.0:
		return roundi(salary * (1.0 + gs.rng.randf_range(-volatility, volatility)) / 1000.0) * 1000
	return salary


## Bekerja sebulan: pengalaman di bidang ini +1 bulan, keahlian +1 tiap beberapa bulan,
## kinerja bergerak sebagian menuju targetnya (pekerjaan berjenjang saja, lihat performance_factors).
func work_month(working: bool) -> void:
	if not working:
		return
	var track: String = current_job_def()["track"]
	experience[track] = int(experience.get(track, 0)) + 1
	var months_worked := months_at_company()
	if months_worked > 0 and months_worked % int(data["skill_every_months"]) == 0:
		gain_skill(1.0)
	if is_career():
		var cfg: Dictionary = data["performance"]
		var noise := float(cfg["noise"])
		performance += (float(performance_factors()["target"]) - performance) * float(cfg["approach"]) \
			+ gs.rng.randf_range(-noise, noise)
		performance = clampf(performance, 0.0, 100.0)


## Keahlian naik makin pelan saat sudah tinggi: tambahan x (1 - keahlian/100)^skill_curve
## (jobs.json), mis. kursus +3 menjadi +1,5 di keahlian 30 dan +0,3 di keahlian 70. Maks. 100.
func gain_skill(amount: float) -> void:
	var factor := pow(maxf(1.0 - skill / 100.0, 0.0), float(data.get("skill_curve", 1.0)))
	skill = clampf(skill + amount * factor, 0.0, 100.0)


func _leave_job() -> void:
	job = {}
	salary = 0
	unpaid_months = 0
	gs.education.check_sponsor()


## Lowongan bulan ini: 1 kerja lepas, 1 yang paling tinggi jenjangnya di antara yang syaratnya
## terpenuhi, sisanya acak sampai jenjang berikutnya (sebagai motivasi). Gaji ikut inflasi.
func refresh_board() -> void:
	var cfg: Dictionary = data["board"]
	var gigs: Array = data["jobs"].filter(func(def: Dictionary) -> bool: return def["track"] == "gig")
	var careers: Array = data["jobs"].filter(func(def: Dictionary) -> bool: return def["track"] != "gig")
	var count := gs.rng.randi_range(int(cfg["min"]), int(cfg["max"]))
	var picked: Array = [gigs[gs.rng.randi() % gigs.size()]]
	var qualified: Array = careers.filter(meets_requirements)
	var best_level := 1
	if not qualified.is_empty():
		best_level = qualified.map(func(def: Dictionary) -> int: return int(def["level"])).max()
		var best: Array = qualified.filter(func(def: Dictionary) -> bool: return int(def["level"]) == best_level)
		picked.append(best[gs.rng.randi() % best.size()])
	var pool: Array = careers.filter(func(def: Dictionary) -> bool:
		return int(def["level"]) <= best_level + 1 and not def in picked)
	while picked.size() < count and not pool.is_empty():
		picked.append(pool.pop_at(gs.rng.randi() % pool.size()))
	job_board.clear()
	var spread: Array = cfg["salary_spread"]
	for def: Dictionary in picked:
		var companies: Array = track_def(def["track"])["companies"]
		var base := float(def["salary"]) * float(gs.difficulty["salary_mult"]) * gs.rng.randf_range(float(spread[0]), float(spread[1]))
		job_board.append({"job_id": def["id"], "company": companies[gs.rng.randi() % companies.size()],
			"salary": gs.nominal(base), "applied": false})


func is_career() -> bool:
	return is_employed() and current_job_def().get("track", "gig") != "gig"


## Lama di jabatan sekarang (syarat promosi).
func months_in_role() -> int:
	return gs.month - int(job.get("since", gs.month))


## Lama di perusahaan ini (pesangon, kenaikan prestasi).
func months_at_company() -> int:
	return gs.month - int(job.get("hired", job.get("since", gs.month)))


## Target kinerja & penyusunnya (ditampilkan di kartu Pekerjaan):
## dasar + kecocokan keahlian dengan syarat jabatan + rata-rata kesehatan & kebahagiaan.
func performance_factors() -> Dictionary:
	var cfg: Dictionary = data["performance"]
	var skill_fit := clampf((skill - skill_requirement(current_job_def())) * float(cfg["per_skill"]),
		float(cfg["skill_min"]), float(cfg["skill_max"]))
	var wellbeing := clampf(((gs.health + gs.happiness) / 2.0 - float(cfg["wellbeing_from"])) * float(cfg["wellbeing_rate"]),
		float(cfg["wellbeing_min"]), float(cfg["wellbeing_max"]))
	return {"skill": skill_fit, "wellbeing": wellbeing,
		"target": clampf(float(cfg["base"]) + skill_fit + wellbeing, 0.0, 100.0)}


## Key teks predikat kinerja ("PERF_GOOD", ...).
func performance_label(value: float = performance) -> String:
	for row: Array in data["performance"]["labels"]:
		if roundi(value) >= int(row[0]):
			return row[1]
	return ""


## Kenaikan prestasi tahunan untuk kinerja `value` (0.015 = 1,5%).
func merit_raise_for(value: float) -> float:
	for row: Array in data["merit_raise"]["by_performance"]:
		if roundi(value) >= int(row[0]):
			return float(row[1])
	return 0.0


## Penilaian kinerja tahunan (Januari): kenaikan prestasi bagi yang sudah cukup lama bekerja.
func merit_raise() -> Dictionary:
	if not is_career() or unpaid_months > 0 or months_at_company() < int(data["merit_raise"]["min_months"]):
		return {}
	var pct := merit_raise_for(performance)
	if pct > 0.0:
		raise_salary(pct)
	return {"merit_raise": pct, "review_performance": roundi(performance)}


## Jabatan berikutnya di bidang yang sama ({} jika sudah jenjang tertinggi / kerja lepas).
func next_job_def() -> Dictionary:
	if not is_career():
		return {}
	var def := current_job_def()
	return _job_at(def["track"], int(def["level"]) + 1)


func _job_at(track: String, level: int) -> Dictionary:
	for def: Dictionary in data["jobs"]:
		if def["track"] == track and int(def["level"]) == level:
			return def
	return {}


## Gaji jabatan `def` saat promosi / dibajak: gaji pasarnya, minimal naik `min_raise` dari gaji sekarang.
func _raised_salary(def: Dictionary, min_raise: float) -> int:
	var market_pay := gs.nominal(float(def["salary"]) * float(gs.difficulty["salary_mult"]))
	return maxi(market_pay, roundi(salary * (1.0 + min_raise) / 1000.0) * 1000)


func promotion_salary() -> int:
	var next := next_job_def()
	return 0 if next.is_empty() else _raised_salary(next, float(data["promotion"]["min_raise"]))


## Syarat promosi ke jenjang berikutnya: [{type: tenure|performance|education|skill, need, have, met}].
## Promosi internal tidak butuh pengalaman bidang (itu syarat pelamar dari luar).
func promotion_requirements() -> Array[Dictionary]:
	var reqs: Array[Dictionary] = []
	var next := next_job_def()
	if next.is_empty():
		return reqs
	var cfg: Dictionary = data["promotion"]
	var min_months: Array = cfg["min_months"]
	var need_months := int(min_months[mini(int(current_job_def()["level"]) - 1, min_months.size() - 1)])
	reqs.append({"type": "tenure", "need": need_months, "have": months_in_role(), "met": months_in_role() >= need_months})
	reqs.append({"type": "performance", "need": int(cfg["performance"]), "have": roundi(performance),
		"met": roundi(performance) >= int(cfg["performance"])})
	for req: Dictionary in requirements(next):
		if req["type"] != "experience":
			reqs.append(req)
	return reqs


func promotion_ready() -> bool:
	var reqs := promotion_requirements()
	return not reqs.is_empty() and unpaid_months == 0 and reqs.all(func(r: Dictionary) -> bool: return r["met"])


## Peluang PHK bulan ini: dasar, dikali saat kinerja rendah dan saat pasar saham lesu (bear).
func layoff_chance() -> float:
	var cfg: Dictionary = data["layoff"]
	if not is_career() or unpaid_months > 0 or months_at_company() < int(cfg["min_months"]):
		return 0.0
	var chance := float(cfg["base"])
	if performance < float(cfg["low_performance"]):
		chance *= float(cfg["low_mult"])
	elif performance < float(cfg["mid_performance"]):
		chance *= float(cfg["mid_mult"])
	if gs.market.regime_of("stock") == "bear":
		chance *= float(cfg["bear_mult"])
	return chance


## Pesangon PHK dalam bulan gaji: 1 bulan untuk tiap tahun masa kerja yang dimulai (maks. 9).
func severance_months() -> int:
	return clampi(floori(months_at_company() / 12.0) + 1, 1, int(data["layoff"]["severance_max"]))


## Berhenti sendiri: tanpa pesangon, gaji berhenti mulai bulan depan.
func resign() -> void:
	if not is_employed() or gs.is_over or gs.events.has_pending():
		return
	gs.stats["resigns"] += 1
	record("resigned")
	_leave_job()
	gs.changed.emit()
	gs.state_committed.emit()


func _promote() -> void:
	var next := next_job_def()
	if next.is_empty():
		return
	salary = int(gs.events.pending_vars.get("salary", promotion_salary()))
	job["id"] = next["id"]
	job["since"] = gs.month
	gs.stats["promotions"] += 1
	gs.stats["top_level"] = maxi(int(gs.stats["top_level"]), int(next["level"]))
	record("promoted")


func _lay_off() -> void:
	var severance := int(gs.events.pending_vars.get("severance", severance_months() * salary))
	gs.cash += severance
	gs.stats["layoffs"] += 1
	gs.stats["severance"] += severance
	record("laid_off")
	_leave_job()


## Incaran headhunter: jenjang berikutnya di bidang yang sama jika pendidikan & keahlian cukup,
## selain itu jabatan setara. Gaji = gaji pasar jabatan itu + premium (tidak menumpuk dari gaji
## sekarang). {} jika kenaikannya kurang dari min_gain, sehingga event headhunter tidak muncul.
func headhunter_target() -> Dictionary:
	if not is_career():
		return {}
	var cfg: Dictionary = data["headhunter"]
	var target := next_job_def()
	if target.is_empty() or not requirements(target).all(func(r: Dictionary) -> bool:
			return r["met"] or r["type"] == "experience"):
		target = current_job_def()
	var offer := gs.nominal(float(target["salary"]) * float(gs.difficulty["salary_mult"]) * (1.0 + float(cfg["premium"])))
	if offer < salary * (1.0 + float(cfg["min_gain"])):
		return {}
	return {"def": target, "salary": offer}


func _headhunter_offer() -> Dictionary:
	var target := headhunter_target()
	if target.is_empty():
		return {}
	var def: Dictionary = target["def"]
	var companies: Array = track_def(def["track"])["companies"].filter(func(c: String) -> bool:
		return c != job["company"])
	return {"job_id": def["id"], "company": companies[gs.rng.randi() % companies.size()],
		"salary": target["salary"], "chance": 1.0}


## Tawaran kerja berjenjang bergaji tertinggi bulan ini (dibahas di event wawancara), atau -1.
func interview_offer_index() -> int:
	var best := -1
	for i in job_offers.size():
		if job_def(job_offers[i]["job_id"])["track"] == "gig":
			continue
		if best < 0 or job_offers[i]["salary"] > job_offers[best]["salary"]:
			best = i
	return best


## Hasil negosiasi gaji di event wawancara.
func _raise_offer(pct: float) -> void:
	var i := int(gs.events.pending_vars.get("offer_index", -1))
	if i >= 0 and i < job_offers.size():
		job_offers[i]["salary"] = roundi(job_offers[i]["salary"] * (1.0 + pct) / 1000.0) * 1000


## Event karier bulan ini, di luar jatah event acak: wawancara jika ada tawaran kerja berjenjang;
## selain itu PHK atau tawaran promosi (diundi tiap bulan).
func scheduled_events() -> Array[Dictionary]:
	var picked: Array[Dictionary] = []
	var id := ""
	if interview_offer_index() >= 0:
		id = "interview"  # sedang mempertimbangkan pindah kerja: PHK & promosi ditunda
	elif gs.rng.randf() < layoff_chance():
		id = "layoff"
	elif promotion_ready() and gs.events.off_cooldown("promotion") \
			and gs.rng.randf() < float(data["promotion"]["chance"]):
		id = "promotion"
	var def := gs.events.catalog.find(id)
	if not def.is_empty():
		picked.append(def)
	return picked


## Catat peristiwa karier untuk Profil & layar akhir. Pekerjaan sekarang ikut dicatat.
func record(kind: String, extra: Dictionary = {}) -> void:
	var entry := {"month": gs.month, "kind": kind}
	if is_employed():
		entry.merge({"job_id": job["id"], "company": job["company"]})
	history.append(entry.merged(extra, true))
	if history.size() > MAX_CAREER_LOG:
		history.pop_front()


## Gaji yang diterima setelah PPh 21 (dasar rencana gaji di popup & Beranda).
func net_salary() -> int:
	return salary - gs.income_tax(salary)


## Penyesuaian gaji tahunan (setiap Januari) sebesar inflasi 12 bulan terakhir, agar gaji
## tidak tergerus inflasi. Kenaikan "nyata" datang dari prestasi & promosi (v1.5b langkah 2).
## Mengembalikan persentase kenaikannya (0.035 = 3,5%).
func index_salary() -> float:
	var raise := snappedf(gs.market.realized_inflation(12), 0.001)
	if raise <= 0.0:
		return 0.0
	raise_salary(raise)
	return raise


## Kenaikan gaji rutin. Rencana gaji dalam persen, jadi tidak perlu ditinjau ulang.
func raise_salary(pct: float) -> void:
	var old_salary := salary
	salary = roundi(salary * (1.0 + pct) / 1000.0) * 1000
	if int(gs.budget.plan.get("salary_seen", -1)) == old_salary:
		gs.budget.plan["salary_seen"] = salary
