class_name Dreams
extends GameModule
## Impian (v1.5-0 langkah 3): tujuan menabung dengan tenggat, pos dana berbunga, perayaan saat
## terwujud, dan kendaraan yang dimiliki. Data: data/dreams.json.

const DREAMS_PATH := "res://data/dreams.json"

## Impian (v1.5-0 langkah 3): [{id, saved, start_month, deadline, status, achieved_month}]
## status: active | achieved | released
var entries: Array[Dictionary] = []
var asked := false  # pemain sudah ditawari memilih impian di awal permainan
var defs: Array = []  # isi data/dreams.json


func load_data() -> void:
	defs = DataLoader.load_json(DREAMS_PATH).get("dreams", [])


func reset() -> void:
	entries.clear()
	asked = false


func save_to(d: Dictionary) -> void:
	d.merge({"dreams": entries, "dreams_asked": asked})


func load_from(d: Dictionary) -> void:
	entries.clear()
	for entry: Dictionary in d.get("dreams", []):
		for key: String in ["start_month", "deadline", "achieved_month"]:
			entry[key] = int(entry.get(key, -1))
		entry["saved"] = float(entry["saved"])
		entries.append(entry)
	asked = d.get("dreams_asked", false)


## Kendaraan yang dimiliki dari impian yang sudah terwujud: "car", "motor", atau "".
func vehicle() -> String:
	for id: String in ["car", "motor"]:
		for entry: Dictionary in entries:
			if entry["id"] == id and entry["status"] == "achieved":
				return id
	return ""


## Harga kendaraan (harga awal permainan) untuk premi & biaya perbaikan.
func vehicle_base_value() -> float:
	var id := vehicle()
	return float(find_def(id)["cost"]) if id != "" else 0.0


func cost_of(def: Dictionary) -> int:
	return gs.nominal(def["cost"], 10_000)


func config() -> Dictionary:
	return gs.economy["dreams"]


func find_def(id: String) -> Dictionary:
	for def: Dictionary in defs:
		if def["id"] == id:
			return def
	return {}


func active() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if entry["status"] == "active":
			result.append(entry)
	return result


func funds() -> float:
	var total := 0.0
	for entry: Dictionary in active():
		total += float(entry["saved"])
	return total


func can_add() -> bool:
	return active().size() < int(config()["max_active"])


## Impian yang bisa dipilih: belum dipilih/terwujud, dan usia sudah cukup.
func available() -> Array:
	var taken := {}
	for entry: Dictionary in entries:
		if entry["status"] != "released":
			taken[entry["id"]] = true
	return defs.filter(func(def: Dictionary) -> bool:
		return not taken.has(def["id"]) and gs.age() >= int(def.get("min_age", 0)))


## Setoran per bulan yang dibutuhkan agar impian tercapai tepat waktu.
func needed_monthly(entry: Dictionary) -> int:
	var left := maxf(0.0, cost_of(find_def(entry["id"])) - entry["saved"])
	var months_left := maxi(1, int(entry["deadline"]) - gs.month)
	return ceili(left / months_left / 1000.0) * 1000


## Porsi gaji yang disarankan saat impian dipilih (dibulatkan ke atas per langkah, dibatasi share_cap).
func suggested_share(entry: Dictionary) -> float:
	var step := float(gs.budget.config()["step"])
	var share := ceilf(needed_monthly(entry) / float(maxi(gs.career.salary, 1)) / step) * step
	return clampf(share, step, float(config()["share_cap"]))


func pick(ids: Array) -> void:
	for id: String in ids:
		if not can_add() or find_def(id).is_empty():
			break
		var def := find_def(id)
		var entry := {"id": id, "saved": 0.0, "start_month": gs.month, "deadline": gs.month + int(def["months"]),
			"status": "active", "achieved_month": -1}
		entries.append(entry)
		# Porsi saran dibatasi sisa gaji di rencana saat ini, agar rencana tidak melebihi gaji.
		var step := float(gs.budget.config()["step"])
		var surplus := maxf(0.0, float(gs.budget.preview_for(gs.budget.plan, gs.career.salary)["surplus"]))
		var room := floorf(surplus / maxf(1.0, gs.career.salary) / step + 0.0001) * step
		gs.budget.plan["dreams"][id] = minf(suggested_share(entry), room)
	asked = true
	gs.changed.emit()
	gs.state_committed.emit()


func mark_asked() -> void:
	asked = true
	gs.state_committed.emit()


## Setoran manual ke pos impian.
func deposit(id: String, amount: int) -> bool:
	var entry := find_entry(id)
	if entry.is_empty() or entry["status"] != "active" or amount <= 0 or amount > gs.cash:
		return false
	var left := ceili(maxf(0.0, cost_of(find_def(id)) - entry["saved"]))
	amount = mini(amount, left)
	gs.cash -= amount
	entry["saved"] += amount
	gs.targets.progress("dream_deposit", amount)
	check()
	gs.changed.emit()
	gs.state_committed.emit()
	gs.flush_report_signals()
	return true


## Melepas impian: dana kembali ke kas, kebahagiaan turun sedikit.
func release(id: String) -> void:
	var entry := find_entry(id)
	if entry.is_empty() or entry["status"] != "active":
		return
	gs.cash += roundi(entry["saved"])
	entry["saved"] = 0.0
	entry["status"] = "released"
	gs.budget.plan["dreams"].erase(id)
	gs.happiness = clampi(gs.happiness + int(config()["release_happiness"]), 0, 100)
	gs.changed.emit()
	gs.state_committed.emit()


## Memperpanjang tenggat impian yang terlewat.
func extend(id: String) -> void:
	var entry := find_entry(id)
	if entry.is_empty() or entry["status"] != "active":
		return
	entry["deadline"] = gs.month + int(config()["extend_months"])
	gs.happiness = clampi(gs.happiness + int(config()["extend_happiness"]), 0, 100)
	gs.changed.emit()
	gs.state_committed.emit()


## Impian aktif yang tenggatnya sudah lewat (menunggu keputusan pemain).
func overdue() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in active():
		if gs.month > int(entry["deadline"]):
			result.append(entry)
	return result


## Data impian siap tampil: entri + definisi + persentase terkumpul.
func view_of(entry: Dictionary) -> Dictionary:
	var def := find_def(entry["id"])
	var cost := cost_of(def)
	return entry.merged({"def": def, "cost": cost, "ratio": clampf(entry["saved"] / float(cost), 0.0, 1.0)})


## Entri impian AKTIF dengan id tersebut ({} jika tidak ada / sudah terwujud / dilepas).
func get_active(id: String) -> Dictionary:
	return find_entry(id)


func find_entry(id: String) -> Dictionary:
	for entry: Dictionary in entries:
		if entry["id"] == id and entry["status"] == "active":
			return entry
	return {}


## Impian yang dananya sudah cukup langsung terwujud (dana dipakai, kelebihannya kembali ke kas).
func check() -> void:
	for entry: Dictionary in active():
		var def := find_def(entry["id"])
		var cost := cost_of(def)
		if entry["saved"] + 0.5 < float(cost):
			continue
		gs.cash += roundi(entry["saved"] - float(cost))
		entry["saved"] = float(cost)
		entry["status"] = "achieved"
		entry["achieved_month"] = gs.month
		gs.budget.plan["dreams"].erase(entry["id"])
		gs.happiness = clampi(gs.happiness + int(def["happiness"]), 0, 100)
		gs.progress.xp += int(def["xp"])
		gs.stats["dreams_achieved"] += 1
		var view := view_of(entry)
		gs.queue_after_report(func() -> void: gs.dream_achieved.emit(view))


func queue_overdue() -> void:
	for entry: Dictionary in overdue():
		var view := view_of(entry)
		gs.queue_after_report(func() -> void: gs.dream_overdue.emit(view))


## Pos impian berbunga seperti tabungan (setelah pajak). Mengembalikan totalnya.
func pay_interest() -> float:
	var asset := gs.market.get_asset(config()["interest_asset"])
	var rate := gs.market.rate_for(asset) / 12.0
	var total := 0.0
	for entry: Dictionary in active():
		var gross: float = entry["saved"] * rate
		var tax := gross * asset.interest_tax
		entry["saved"] += gross - tax
		total += gross - tax
		gs.portfolio.add_tax("interest_tax", tax)
	return total


func progress_report() -> Array:
	var result: Array = []
	for entry: Dictionary in active():
		var view := view_of(entry)
		result.append({"name": view["def"]["name"], "ratio": view["ratio"]})
	return result
