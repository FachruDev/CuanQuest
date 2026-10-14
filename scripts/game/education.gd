class_name Education
extends GameModule
## Pendidikan (v1.5b langkah 3): tingkat pendidikan, kuliah D3/S1/S2, uang kuliah, beasiswa,
## kelulusan, dan sertifikasi. Data: data/education.json (+ education_levels di data/jobs.json).

const EDUCATION_PATH := "res://data/education.json"

var level := 0  # indeks jobs.json education_levels (0 = SMA)
## Kuliah yang sedang diambil (v1.5b langkah 3), {} jika tidak kuliah:
## {"id", "months_left", "months_total", "since", "scholarship", "sponsor", "paid_month"}.
var study: Dictionary = {}
var data: Dictionary = {}  # isi data/education.json


func load_data() -> void:
	data = DataLoader.load_json(EDUCATION_PATH)


func reset() -> void:
	level = level_index(gs.background["education"])
	study = {}


func save_to(d: Dictionary) -> void:
	d.merge({"education": level, "study": study})


func load_from(d: Dictionary) -> void:
	level = int(d["education"])
	study = d.get("study", {}).duplicate()
	for key: String in ["months_left", "months_total", "since", "paid_month"]:
		if study.has(key):
			study[key] = int(study[key])


## Efek event pendidikan: beasiswa kampus, beasiswa kantor, kuliah mundur.
func apply_effects(e: Dictionary) -> void:
	if e.has("scholarship") and is_studying():
		study["scholarship"] = maxf(float(study["scholarship"]), float(e["scholarship"]))
		gs.stats["scholarships"] += 1
	if e.get("sponsored_study", false) and not is_studying() and gs.career.is_employed():
		var option := program_option(gs.events.pending_vars.get("program_id", ""))
		if not option.is_empty():
			_start_study(option, gs.career.job["company"])
	if e.has("study_delay") and is_studying():
		study["months_left"] = int(study["months_left"]) + int(e["study_delay"])
		study["months_total"] = int(study["months_total"]) + int(e["study_delay"])


## Isian teks event pendidikan ({company}, {program}, {cert}).
func event_vars(id: String) -> Dictionary:
	match id:
		"company_sponsor":
			var option := sponsor_program()
			if not option.is_empty():
				return {"company": gs.career.job["company"], "program_id": option["def"]["id"]}
		"course":
			return {"cert": certification_name()}
	return {}


## "SMA" -> 0, "S1" -> 2. "" (tanpa syarat) -> -1.
func level_index(id: String) -> int:
	var levels: Array = gs.career.data.get("education_levels", [])
	for i in levels.size():
		if levels[i]["id"] == id:
			return i
	return -1


func level_name(index: int) -> String:
	var levels: Array = gs.career.data.get("education_levels", [])
	return levels[index]["name"] if index >= 0 and index < levels.size() else ""


func is_studying() -> bool:
	return not study.is_empty()


## Id pendidikan sekarang ("SMA", "D3", ...).
func level_id() -> String:
	return gs.career.data["education_levels"][level]["id"]


func program_def(id: String) -> Dictionary:
	for def: Dictionary in data.get("programs", []):
		if def["id"] == id:
			return def
	return {}


## Program yang bisa diambil dengan pendidikan sekarang: [{def, months, fee}] (fee per bulan, harga hari ini).
func available_programs() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for def: Dictionary in data.get("programs", []):
		var months: Dictionary = def["months"]
		if months.has(level_id()):
			options.append({"def": def, "months": int(months[level_id()]), "fee": _program_fee(def, 0.0)})
	return options


func program_option(id: String) -> Dictionary:
	for option: Dictionary in available_programs():
		if option["def"]["id"] == id:
			return option
	return {}


func _program_fee(def: Dictionary, covered: float) -> int:
	return gs.nominal(float(def["cost"]) * float(gs.difficulty["expense_mult"]) * (1.0 - covered))


## Uang kuliah per bulan (harga hari ini) setelah beasiswa; 0 jika ditanggung kantor.
func tuition_fee() -> int:
	if not is_studying() or study_sponsored():
		return 0
	return _program_fee(program_def(study["id"]), float(study["scholarship"]))


func study_sponsored() -> bool:
	return is_studying() and study["sponsor"] != "" and gs.career.is_employed() and gs.career.job["company"] == study["sponsor"]


## Bulan kelulusan jika tidak ada cuti kuliah.
func graduation_month() -> int:
	var next := maxi(int(study["since"]), gs.month + 1)
	return next + int(study["months_left"])


## "" jika program bisa didaftar, atau key pesan alasannya.
func enroll_block_reason(program_id: String) -> String:
	if gs.is_over or gs.events.has_pending():
		return "ERR_ACTIVITY_BUSY"
	if is_studying():
		return "ERR_STUDY_ACTIVE"
	var option := program_option(program_id)
	if option.is_empty():
		return "ERR_STUDY_UNAVAILABLE"
	if gs.cash < int(option["fee"]):
		return "ERR_NOT_ENOUGH_CASH"
	return ""


## Mendaftar kuliah; mulai berjalan (dan dibayar) awal bulan depan. -> {ok, error}
func enroll(program_id: String) -> Dictionary:
	var reason := enroll_block_reason(program_id)
	if reason != "":
		return {"ok": false, "error": reason}
	_start_study(program_option(program_id), "")
	gs.changed.emit()
	gs.state_committed.emit()
	return {"ok": true}


func _start_study(option: Dictionary, sponsor: String) -> void:
	study = {"id": option["def"]["id"], "months_left": option["months"], "months_total": option["months"],
		"since": gs.month + 1, "scholarship": 0.0, "sponsor": sponsor, "paid_month": -1}
	gs.stats["enrollments"] += 1


## Berhenti kuliah: biaya yang sudah dibayar hangus, pendidikan tidak berubah.
func quit_study() -> void:
	if not is_studying() or gs.is_over or gs.events.has_pending():
		return
	gs.career.record("dropped_out", {"program": study["id"]})
	study = {}
	gs.stats["dropouts"] += 1
	gs.changed.emit()
	gs.state_committed.emit()


## Beasiswa kantor berakhir jika pemain tidak lagi bekerja di perusahaan pemberinya.
func check_sponsor() -> void:
	if is_studying() and study["sponsor"] != "" and gs.career.job.get("company", "") != study["sponsor"]:
		study["sponsor"] = ""


## Awal bulan: lulus jika semua bulan sudah dijalani; selain itu bayar uang kuliah (kas, lalu
## tabungan dana darurat) dan jalani sebulan kuliah. Uang tidak cukup = cuti kuliah bulan ini.
func study_month() -> Dictionary:
	if not is_studying() or gs.month < int(study["since"]):
		return {}
	var def := program_def(study["id"])
	if int(study["months_left"]) <= 0:
		return _graduate()
	var fee := tuition_fee()
	gs.budget.draw_emergency(fee)
	if gs.cash < fee:
		return {"study_paused": def["name"]}
	gs.cash -= fee
	gs.stats["tuition"] += fee
	study["months_left"] = int(study["months_left"]) - 1
	study["paid_month"] = gs.month
	gs.happiness = clampi(gs.happiness + int(data["load"]["happiness"]), 0, 100)
	return {"study_fee": fee, "study_program": def["name"],
		"study_done": int(study["months_total"]) - int(study["months_left"]), "study_total": study["months_total"]}


func _graduate() -> Dictionary:
	var def := program_def(study["id"])
	var before := floori(gs.career.skill)
	level = maxi(level, level_index(def["result"]))
	gs.career.gain_skill(float(def["skill"]))
	gs.career.record("graduated", {"program": def["id"]})
	study = {}
	gs.stats["graduations"] += 1
	var gain := floori(gs.career.skill) - before
	gs.queue_after_report(func() -> void: gs.graduated.emit(def["name"], def["result"], gain))
	return {"graduated": def["name"], "graduated_education": def["result"], "graduated_skill": gain}


## Program yang ditawarkan beasiswa kantor (event company_sponsor): program pertama yang tersedia,
## jika pemain sudah cukup lama di perusahaan, kinerjanya baik, dan sedang tidak kuliah. {} jika tidak.
func sponsor_program() -> Dictionary:
	var cfg: Dictionary = data["sponsor"]
	if not gs.career.is_career() or is_studying() or gs.career.months_at_company() < int(cfg["min_months"]) \
			or gs.career.performance < float(cfg["performance"]):
		return {}
	var options := available_programs()
	return {} if options.is_empty() else options[0]


## Nama sertifikasi di event "course": sesuai bidang pekerjaan sekarang, atau bidang dengan
## pengalaman terbanyak, atau sertifikasi umum (key teks).
func certification_name() -> String:
	var track_id: String = gs.career.current_job_def().get("track", "")
	if track_id == "" or track_id == "gig":
		var best := 0
		for id: String in gs.career.experience:
			if id != "gig" and int(gs.career.experience[id]) > best:
				best = int(gs.career.experience[id])
				track_id = id
	return gs.career.track_def(track_id).get("certification", gs.career.data["default_certification"])
