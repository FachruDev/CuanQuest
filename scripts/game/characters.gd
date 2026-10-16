class_name Characters
extends GameModule
## Tokoh berulang (v1.5d): sahabat, ibu, mentor, tetangga, serta atasan & rekan kerja yang berganti
## mengikuti perusahaan. Tiap tokoh punya kedekatan 0-100 yang diubah pilihan di event (efek "rel")
## dan membuka atau menutup lanjutan cerita ("min_rel"/"max_rel" di data event). Kedekatan dengan
## atasan & rekan kerja sedikit memengaruhi karier. Data: data/characters.json.
##
## Analogi web: seperti tabel "relationships" milik user; event membaca dan menulis barisnya.

const CHARACTERS_PATH := "res://data/characters.json"

var data: Dictionary = {}  # isi data/characters.json
var rel: Dictionary = {}  # id tokoh -> kedekatan 0-100
var met: Array[String] = []  # tokoh yang sudah dikenal (tampil di Profil)
## Perusahaan tempat atasan & rekan kerja sekarang. Diperbarui saat bekerja di perusahaan baru (kedekatan
## dengan tokoh kantor kembali ke awal) dan tetap diingat saat berhenti bekerja (nama "mantan" rekan).
var work_company := ""


func load_data() -> void:
	data = DataLoader.load_json(CHARACTERS_PATH)


func reset() -> void:
	rel.clear()
	met.clear()
	work_company = ""
	for d: Dictionary in defs():
		rel[d["id"]] = int(d["start"])
		if d.get("known", false):
			met.append(d["id"])


func save_to(d: Dictionary) -> void:
	d.merge({"relationships": rel, "people_met": met, "work_company": work_company})


## Save sebelum v1.5d: kedekatan awal, tokoh bawaan sudah dikenal.
func load_from(d: Dictionary) -> void:
	reset()
	for id: String in d.get("relationships", {}):
		if rel.has(id):
			rel[id] = int(d["relationships"][id])
	if d.has("people_met"):
		met.assign(d["people_met"])
	work_company = d.get("work_company", "")


## Efek event "rel": {"bima": 5, "boss": -3} mengubah kedekatan (0-100) dan membuat tokohnya dikenal.
func apply_effects(e: Dictionary) -> void:
	for id: String in e.get("rel", {}):
		add_rel(id, int(e["rel"][id]))


func event_vars(id: String) -> Dictionary:
	if id == "wulan_checkup":
		return {"advice": advice_text()}
	return {}


# --- Data tokoh ------------------------------------------------------------------------------

func defs() -> Array:
	return data.get("characters", [])


func def(id: String) -> Dictionary:
	for d: Dictionary in defs():
		if d["id"] == id:
			return d
	return {}


func is_work(id: String) -> bool:
	return def(id).get("work", false)


## Atasan & rekan kerja hanya ada saat bekerja di pekerjaan berjenjang.
func available(id: String) -> bool:
	return not def(id).is_empty() and (not is_work(id) or gs.career.is_career())


## Tokoh masih muncul di cerita: "until_player_age" = event tokoh berhenti saat pemain mencapai usia
## itu, tanpa diceritakan alasannya (pedoman konten sensitif: tokoh berulang tidak meninggal).
func in_story(id: String) -> bool:
	return gs.age() < int(def(id).get("until_player_age", 999))


func is_known(id: String) -> bool:
	return id in met


## Nama tokoh. Tokoh kantor diambil dari daftar nama sesuai perusahaan (tetap sama selama di
## perusahaan itu); sebelum pernah bekerja kantoran memakai nama perannya.
func name_of(id: String) -> String:
	var d := def(id)
	if not d.get("work", false):
		return d.get("name", "")
	_sync_work()
	if work_company == "":
		return tr(d["role"])
	var names: Array = d["names"]
	return names[posmod(hash(work_company + ":" + id), names.size())]


func rel_of(id: String) -> int:
	_sync_work()
	return int(rel.get(id, 50))


func add_rel(id: String, delta: int) -> void:
	if not rel.has(id):
		return
	_sync_work()
	rel[id] = clampi(int(rel[id]) + delta, 0, 100)
	meet(id)


func meet(id: String) -> void:
	if rel.has(id) and not id in met:
		met.append(id)


## Tokoh yang sudah dikenal dan ada sekarang (kartu Orang Terdekat di Profil), sesuai urutan data.
func known() -> Array[String]:
	_sync_work()
	var result: Array[String] = []
	for d: Dictionary in defs():
		if d["id"] in met and available(d["id"]):
			result.append(d["id"])
	return result


## Kunci teks tingkat kedekatan ("REL_CLOSE", ...).
func level_key(value: int) -> String:
	for level: Dictionary in data.get("levels", []):
		if value >= int(level["min"]):
			return level["key"]
	return ""


## Pindah ke perusahaan baru: atasan & rekan kerja baru, kedekatannya kembali ke awal. Dipanggil
## saat dibaca (tanpa undian), sehingga tidak mengubah urutan acak permainan.
func _sync_work() -> void:
	if not gs.career.is_career():
		return
	var company: String = gs.career.job.get("company", "")
	if company == work_company:
		return
	work_company = company
	for d: Dictionary in defs():
		if d.get("work", false):
			rel[d["id"]] = int(d["start"])
			meet(d["id"])


# --- Dampak ke karier ----------------------------------------------------------------------

## Pengali peluang promosi: atasan yang dekat lebih sering merekomendasikanmu.
func promotion_mult() -> float:
	var cfg: Dictionary = data["work_effects"]
	return float(cfg["promotion_mult"]) if rel_of("boss") >= int(cfg["boss_close"]) else 1.0


## Pengali peluang PHK: hubungan yang renggang dengan atasan membuatmu lebih rentan.
func layoff_mult() -> float:
	var cfg: Dictionary = data["work_effects"]
	return float(cfg["layoff_mult"]) if rel_of("boss") <= int(cfg["boss_distant"]) else 1.0


## Tambahan target kinerja: rekan kerja yang dekat saling membantu.
func performance_bonus() -> float:
	var cfg: Dictionary = data["work_effects"]
	return float(cfg["performance_bonus"]) if rel_of("coworker") >= int(cfg["coworker_close"]) else 0.0


# --- Saran Kak Wulan --------------------------------------------------------------------------

## Saran "cek kesehatan keuangan" sesuai kondisi pemain (maksimal 3 butir).
func advice_text() -> String:
	var tips: Array[String] = []
	var expenses := float(maxi(gs.monthly_expenses(), 1))
	var emergency_months := gs.budget.emergency_balance() / expenses
	if emergency_months < 1.0:
		tips.append(tr("ADVICE_NO_EMERGENCY"))
	elif emergency_months < 3.0:
		tips.append(tr("ADVICE_EMERGENCY") % floori(emergency_months))
	if gs.insurance.policy_product("health").is_empty():
		tips.append(tr("ADVICE_HEALTH"))
	var dsr := gs.debt.dsr_with(0)
	if dsr > 0.3:
		tips.append(tr("ADVICE_DEBT") % roundi(dsr * 100.0))
	if float(gs.budget.plan.get("lifestyle", 0.0)) > 0.2:
		tips.append(tr("ADVICE_LIFESTYLE") % roundi(float(gs.budget.plan["lifestyle"]) * 100.0))
	if gs.portfolio.investments_value() - gs.budget.emergency_balance() < expenses:
		tips.append(tr("ADVICE_INVEST"))
	var share := EndAnalysis.largest_holding_share(gs)
	if share > 0.7 and gs.portfolio.investments_value() > expenses * 6.0:
		tips.append(tr("ADVICE_DIVERSIFY") % roundi(share * 100.0))
	if tips.is_empty():
		tips.append(tr("ADVICE_HEALTHY"))
	return "\n".join(PackedStringArray(tips.slice(0, 3).map(func(t: String) -> String: return "• " + t)))
