class_name Activities
extends GameModule
## Energi & aktivitas bulanan (M6.5, GDD 4.2): kursus, olahraga, istirahat, kerja sampingan, dst.
## Data: data/activities.json.

const ACTIVITIES_PATH := "res://data/activities.json"

var data: Dictionary = {}  # isi data/activities.json
var energy := 0
var energy_capacity := 0  # energi maksimal bulan ini (dikunci di awal bulan)
var counts: Dictionary = {}  # activity_id -> berapa kali bulan ini


func load_data() -> void:
	data = DataLoader.load_json(ACTIVITIES_PATH)


func save_to(d: Dictionary) -> void:
	d.merge({"energy": energy, "energy_capacity": energy_capacity, "activity_counts": counts})


func load_from(d: Dictionary) -> void:
	energy_capacity = int(d.get("energy_capacity", energy_max()))
	energy = int(d.get("energy", energy_capacity))
	counts.clear()
	for id: String in d.get("activity_counts", {}):
		counts[id] = int(d["activity_counts"][id])


func cost(def: Dictionary) -> int:
	return gs.nominal(def.get("cost", 0))


func energy_max() -> int:
	var value := int(data.get("base_energy", 3))
	if gs.health >= int(data.get("health_bonus_at", 70)):
		value += 1
	if gs.health < int(data.get("health_penalty_below", 30)):
		value -= 1
	if not gs.education.study.is_empty() and int(gs.education.study["paid_month"]) == gs.month:  # kuliah bulan ini
		value -= int(gs.education.data["load"]["energy"])
	value += gs.life.energy_change()  # usia 60+ (v2b)
	value += gs.mental.energy_change()  # Depresi (v2b langkah 4)
	value -= gs.fund.energy_cost()  # mengelola dana investor (v2c)
	return maxi(value, 1)


func defs() -> Array:
	return data.get("activities", [])


## Aktivitas yang sedang ditampilkan: "show_when": "low_mood" (mis. Konseling) hanya saat suasana hati
## rendah atau Depresi (v2b langkah 4).
func is_shown(def: Dictionary) -> bool:
	return def.get("show_when", "") != "low_mood" or gs.mental.help_visible()


## "" jika aktivitas bisa dilakukan, atau key pesan error.
func block_reason(def: Dictionary) -> String:
	if gs.is_over or gs.events.has_pending():
		return "ERR_ACTIVITY_BUSY"
	if not is_shown(def):
		return "ERR_ACTIVITY_HIDDEN"
	if gs.mental.activity_blocked(def["id"]):
		return "ERR_ACTIVITY_MOOD"
	if energy < int(def["energy"]):
		return "ERR_NO_ENERGY"
	if counts.get(def["id"], 0) >= int(def.get("max_per_month", 1)):
		return "ERR_ACTIVITY_LIMIT"
	if def.has("max_total") and total(def["id"]) >= int(def["max_total"]):
		return "ERR_ACTIVITY_MAXED"
	if cooldown_left(def) > 0:
		return "ERR_ACTIVITY_COOLDOWN"
	if cost(def) > gs.cash:
		return "ERR_NOT_ENOUGH_CASH"
	return ""


## Sisa bulan sebelum aktivitas berjeda ("cooldown_months", mis. kursus) bisa diambil lagi.
func cooldown_left(def: Dictionary) -> int:
	var last: Dictionary = gs.stats["activity_last"]
	if not def.has("cooldown_months") or not last.has(def["id"]):
		return 0
	return maxi(int(last[def["id"]]) + int(def["cooldown_months"]) - gs.month, 0)


## Berapa kali aktivitas ini sudah dilakukan sepanjang permainan (untuk batas "max_total").
func total(activity_id: String) -> int:
	return int(gs.stats["activity_totals"].get(activity_id, 0))


## Mengembalikan { "ok", "error", "changes" }.
func perform(activity_id: String) -> Dictionary:
	var def: Dictionary = {}
	for d: Dictionary in defs():
		if d["id"] == activity_id:
			def = d
	var reason := block_reason(def)
	if reason != "":
		return {"ok": false, "error": reason}
	var before := gs.snapshot()
	energy -= int(def["energy"])
	counts[activity_id] = counts.get(activity_id, 0) + 1
	gs.stats["activity_totals"][activity_id] = total(activity_id) + 1
	gs.stats["activity_last"][activity_id] = gs.month
	gs.cash -= cost(def)
	gs.apply_effects(def["effects"])
	gs.stats["activities"] = gs.stats.get("activities", 0) + 1
	gs.targets.progress("activity", 1.0, activity_id)
	gs.changed.emit()
	gs.progress.check_unlocks(true)
	return {"ok": true, "changes": gs.diff(before)}
