class_name Targets
extends GameModule
## Target bulanan ringan (v1.5-0 langkah 3): dipilih tiap awal bulan, berhadiah kecil, tanpa hukuman.

## Target bulan berjalan: [{type, goal, param, progress, state: open|done|failed}]
var items: Array[Dictionary] = []


func reset() -> void:
	items.clear()


func save_to(d: Dictionary) -> void:
	d["targets"] = items


func load_from(d: Dictionary) -> void:
	items.clear()
	for t: Dictionary in d.get("targets", []):
		items.append(t)


func config() -> Dictionary:
	return gs.economy["targets"]


## Memilih beberapa target ringan untuk bulan baru dari daftar yang masuk akal saat ini.
func roll() -> Array[Dictionary]:
	var cfg := config()
	var cap := int(cfg["stat_cap"])
	var bonus := int(cfg["stat_bonus"])
	var pool: Array[Dictionary] = [{"type": "invest", "goal": float(gs.nominal(cfg["invest_amount"], 50_000)), "param": ""}]
	var activities := gs.activities.defs().filter(func(def: Dictionary) -> bool:
		return int(def["energy"]) <= gs.activities.energy_capacity)
	if not activities.is_empty():
		var def: Dictionary = activities[gs.rng.randi() % activities.size()]
		pool.append({"type": "activity", "goal": 1.0, "param": def["id"]})
	pool.append({"type": "save", "goal": float(gs.monthly_expenses() * int(cfg["save_months"])), "param": ""})
	if gs.health < cap:
		pool.append({"type": "health", "goal": float(mini(cap, gs.health + bonus)), "param": ""})
	if gs.happiness < cap:
		pool.append({"type": "happiness", "goal": float(mini(cap, gs.happiness + bonus)), "param": ""})
	if gs.portfolio.investments_value() > 0.0:
		pool.append({"type": "no_loss", "goal": 0.0, "param": ""})
	if gs.quiz.free_left() > 0:
		pool.append({"type": "quiz", "goal": 1.0, "param": ""})
	if not gs.dreams.active().is_empty():
		pool.append({"type": "dream_deposit", "goal": float(gs.nominal(cfg["dream_deposit"], 50_000)), "param": ""})
	var picked: Array[Dictionary] = []
	for i in mini(int(cfg["per_month"]), pool.size()):
		var target: Dictionary = pool.pop_at(gs.rng.randi() % pool.size())
		target.merge({"progress": 0.0, "state": "open"})
		picked.append(target)
	return picked


func progress(type: String, amount: float, param: String = "") -> void:
	for target: Dictionary in items:
		if target["type"] != type or target["state"] != "open":
			continue
		if target["param"] != "" and target["param"] != param:
			continue
		target["progress"] += amount
		if target["progress"] >= target["goal"]:
			_complete(target, true)


func fail(type: String) -> void:
	for target: Dictionary in items:
		if target["type"] == type and target["state"] == "open":
			target["state"] = "failed"


func _complete(target: Dictionary, notify: bool) -> void:
	var cfg := config()
	target["state"] = "done"
	gs.happiness = clampi(gs.happiness + int(cfg["reward_happiness"]), 0, 100)
	gs.progress.xp += int(cfg["reward_xp"])
	gs.stats["targets_done"] += 1
	if notify:
		gs.target_completed.emit(target)


## Akhir bulan: target yang dinilai dari kondisi akhir dicek; sisanya yang belum selesai gagal.
## Mengembalikan salinan untuk laporan bulanan.
func finalize() -> Array:
	for target: Dictionary in items:
		if target["state"] != "open":
			continue
		var ok := false
		match target["type"]:
			"save":
				ok = gs.cash >= target["goal"]
			"health":
				ok = gs.health >= target["goal"]
			"happiness":
				ok = gs.happiness >= target["goal"]
			"no_loss":
				ok = true
		if ok:
			_complete(target, false)
		else:
			target["state"] = "failed"
	return items.duplicate(true)
