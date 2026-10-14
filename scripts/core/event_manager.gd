class_name EventManager
extends RefCounted
## Memilih event hidup yang memenuhi syarat, berdasarkan bobot.
## Efek dari pilihan pemain diterapkan oleh GameState (karena menyentuh kas, gaji, dll).
## Berapa event per bulan ditentukan Event Director di GameState (_roll_events).

var defs: Array = []
var counts: Dictionary = {}       # event_id -> berapa kali sudah muncul
var last_month: Dictionary = {}   # event_id -> bulan terakhir muncul


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
	match def.get("requires", ""):
		"employed":
			return state.unemployed_months == 0
		"has_investments":
			return not state.holdings.is_empty()
		"low_happiness":
			return state.happiness < 40
		"has_vehicle":
			return state.vehicle() != ""
	return true
