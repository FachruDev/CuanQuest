class_name EventManager
extends RefCounted
## Katalog event hidup: memuat data/events/<kategori>.json, memeriksa syarat, dan memilih
## event berdasarkan bobot. Berapa event per bulan ditentukan LifeEvents (GameState.events);
## efek pilihan pemain dijalankan GameState.apply_effects() lewat modul pemiliknya.
## Cara menambah event: docs/PANDUAN_EVENT.md.

## Urutan kategori = urutan file dimuat. Kategori baru: tambah di sini + teks EVENT_CAT_<KATEGORI>.
const CATEGORIES := ["finance", "work", "education", "health", "social", "market", "scam", "property", "debt"]
const DATA_PATH := "res://data/events/%s.json"

var defs: Array = []
var counts: Dictionary = {}       # event_id -> berapa kali sudah muncul
var last_month: Dictionary = {}   # event_id -> bulan terakhir muncul


## Semua event dari file per kategori. Event yang `category`-nya tidak sama dengan nama file
## diberi peringatan agar mudah ditemukan saat menambah event.
static func load_defs() -> Array:
	var all: Array = []
	for category: String in CATEGORIES:
		for def: Dictionary in DataLoader.load_json(DATA_PATH % category).get("events", []):
			if def.get("category", "") != category:
				push_warning("Event %s ada di %s.json tapi kategorinya %s" % [def["id"], category, def.get("category")])
			all.append(def)
	return all


func setup(event_defs: Array) -> void:
	defs = event_defs
	counts.clear()
	last_month.clear()


## Event "guaranteed" (mis. THR) selalu muncul jika syaratnya terpenuhi.
func pick_guaranteed(state: Node) -> Dictionary:
	for def: Dictionary in defs:
		if def.get("guaranteed", false) and not def.get("chain_only", false) and _is_eligible(def, state):
			return def
	return {}


## `bad_mult` mengalikan bobot event yang ditandai "bad" (tingkat kesulitan & anti-sial beruntun).
## `context`: kondisi pemain yang aktif ({"cash_rich": true, ...}); bobot event dikali
## pengali di field "context" event tersebut. `exclude`: id event yang sudah terpilih bulan ini.
func pick_random(state: Node, rng: RandomNumberGenerator, bad_mult: float = 1.0,
		context: Dictionary = {}, exclude: Array = []) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var weights := PackedFloat32Array()
	for def: Dictionary in defs:
		if def.get("guaranteed", false) or def.get("chain_only", false) or def["id"] in exclude:
			continue
		if not _is_eligible(def, state):
			continue
		var weight: float = def.get("weight", 1.0) * (bad_mult if def.get("bad", false) else 1.0)
		var multipliers: Dictionary = def.get("context", {})
		for condition: String in multipliers:
			if context.get(condition, false):
				weight *= float(multipliers[condition])
		candidates.append(def)
		weights.append(weight)
	if candidates.is_empty():
		return {}
	return candidates[rng.rand_weighted(weights)]


func mark_shown(def: Dictionary, month: int) -> void:
	counts[def["id"]] = counts.get(def["id"], 0) + 1
	last_month[def["id"]] = month


func to_dict() -> Dictionary:
	return {"counts": counts, "last_month": last_month}


func from_dict(d: Dictionary) -> void:
	counts.clear()
	last_month.clear()
	for id: String in d.get("counts", {}):
		counts[id] = int(d["counts"][id])
	for id: String in d.get("last_month", {}):
		last_month[id] = int(d["last_month"][id])


## Cari definisi event berdasarkan id (dipakai saat memuat event yang tertunda).
func find(id: String) -> Dictionary:
	for def: Dictionary in defs:
		if def["id"] == id:
			return def
	return {}


## `state` adalah GameState (diakses secara duck-typing: state.month, state.holdings, ...).
func _is_eligible(def: Dictionary, state: Node) -> bool:
	var id: String = def["id"]
	if state.month < int(def.get("min_month", 0)):
		return false
	if counts.get(id, 0) >= int(def.get("max_times", 99)):
		return false
	if last_month.has(id) and state.month - last_month[id] < int(def.get("cooldown", 12)):
		return false
	if def.has("month_of_year") and state.month % 12 != int(def["month_of_year"]):
		return false
	return requires_met(def, state)


## Syarat "requires" event terhadap kondisi pemain saat ini. Juga dicek ulang saat event di
## antrean bulan ini mendapat giliran (kondisinya bisa berubah oleh event sebelumnya).
func requires_met(def: Dictionary, state: Node) -> bool:
	match def.get("requires", ""):
		"employed":
			return state.career.is_employed() and state.career.unpaid_months == 0
		"career":  # pekerjaan berjenjang (bukan kerja lepas), v1.5b langkah 2
			return state.career.is_career() and state.career.unpaid_months == 0
		"headhunter":  # pekerjaan berjenjang & ada incaran yang gajinya lebih tinggi
			return state.career.is_career() and state.career.unpaid_months == 0 and not state.career.headhunter_target().is_empty()
		"studying":  # sedang kuliah (sudah berjalan), v1.5b langkah 3
			return state.education.is_studying() and state.month >= int(state.education.study["since"])
		"sponsor_ready":  # syarat beasiswa kantor
			return not state.education.sponsor_program().is_empty()
		"unemployed":
			return not state.career.is_employed()
		"has_investments":
			return not state.portfolio.holdings.is_empty()
		"low_happiness":
			return state.happiness < 40
		"has_vehicle":
			return state.vehicles.has_any()
		"owns_house":  # punya rumah tapak (v1.5c langkah 4)
			return not state.properties.event_house().is_empty()
		"lives_in_own_home":
			return not state.properties.home().is_empty()
		"has_tenant":
			return not state.properties.tenant_entry().is_empty()
		"paylater_offer":  # tawaran kredit yang lolos semua syarat (skor, tunggakan, rasio cicilan)
			return not state.debt.offer("paylater").is_empty()
		"kta_offer":
			return not state.debt.offer("kta").is_empty()
	return true
