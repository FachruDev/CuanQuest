class_name Research
extends GameModule
## Rumor pasar & riset (v1.5d langkah 2). Sesekali beredar rumor tentang saham/kripto yang sudah
## terbuka ("Kabarnya NUSA akan mendapat kontrak pemerintah"): harganya langsung bergerak, lalu
## bulan berikutnya rumor itu terbukti (harga lanjut searah) atau ternyata jebakan yang sudah
## "digoreng" (harga berbalik). Pemain bisa meriset rumor yang sedang beredar: riset dasar
## (keyakinan 55%) atau riset mendalam (75%). Penilaian riset diundi terhadap hasil sebenarnya saat
## rumor muncul, jadi riset membantu tetapi tidak pasti, dan tidak bisa diulang untuk "menebak ulang".
## Data: data/rumors.json.
##
## Rumor memakai RNG sendiri dan menggerakkan harga lewat guncangan tambahan di Market.step(), sehingga
## urutan acak pasar tidak berubah. Analogi web: seperti layanan terpisah yang menyuntikkan
## "feature flag" ke pipeline harga tanpa mengubah kode pipeline-nya.

const RUMORS_PATH := "res://data/rumors.json"
const LEVELS := ["basic", "deep"]

var data: Dictionary = {}  # isi data/rumors.json
## Rumor yang sedang beredar (kosong jika tidak ada). Kunci: id, asset, direction, month, day, is_true,
## pump, outcome, resolve_day, verdicts {level: bool "kemungkinan benar"}, researched [level], units.
var rumor: Dictionary = {}
## Rekam jejak: jumlah rumor & yang terbukti, serta riset per tingkat [dilakukan, tepat], biaya total.
var record: Dictionary = {}
var last_resolved := -99  # bulan rumor terakhir terjawab (jeda sebelum rumor berikutnya)
var rng := RandomNumberGenerator.new()
var _resolving: Dictionary = {}  # rumor yang terjawab di bulan yang sedang disimulasikan


func load_data() -> void:
	data = DataLoader.load_json(RUMORS_PATH)


func reset() -> void:
	rumor = {}
	_resolving = {}
	record = new_record()
	last_resolved = -99
	rng.seed = gs.rng.seed + 2  # GameState.rng sudah di-seed sebelum modul di-reset/dimuat


func save_to(d: Dictionary) -> void:
	d.merge({"rumor": rumor, "research_record": record, "rumor_last": last_resolved,
		"research_rng": [str(rng.seed), str(rng.state)]})


## Save sebelum v1.5d langkah 2: belum ada rumor, rekam jejak kosong.
func load_from(d: Dictionary) -> void:
	reset()
	if not d.get("rumor", {}).is_empty():
		rumor = d["rumor"].duplicate(true)
		for key: String in ["month", "day", "resolve_day"]:
			rumor[key] = int(rumor[key])
		rumor["researched"] = Array(rumor["researched"]).map(func(level: Variant) -> String: return str(level))
	for key: String in d.get("research_record", {}):
		var value: Variant = d["research_record"][key]
		record[key] = [int(value[0]), int(value[1])] if value is Array else int(value)
	last_resolved = int(d.get("rumor_last", -99))
	if d.has("research_rng"):
		rng.seed = String(d["research_rng"][0]).to_int()
		rng.state = String(d["research_rng"][1]).to_int()


static func new_record() -> Dictionary:
	return {"rumors": 0, "true": 0, "basic": [0, 0], "deep": [0, 0], "costs": 0}


# --- Alur bulanan (dipanggil GameState.advance_month) ----------------------------------------

## Sebelum pasar bergerak ke bulan `month`: rumor yang beredar dijawab (terbukti / hoaks), lalu
## mungkin muncul rumor baru. Mengembalikan guncangan & berita untuk Market.step().
func market_input(month: int) -> Dictionary:
	var shocks := {}
	var news: Array[Dictionary] = []
	_resolving = {}
	if not rumor.is_empty():
		_resolving = rumor
		_resolving["close"] = gs.market.get_asset(rumor["asset"]).price  # harga penutupan bulan rumor
		_resolving["position"] = _position(rumor)
		rumor = {}
		last_resolved = month
		var suffix := "_TRUE" if _resolving["is_true"] else "_FALSE"
		_add(shocks, _resolving["asset"], int(_resolving["resolve_day"]), float(_resolving["outcome"]))
		news.append(_news(month, _resolving, suffix, int(_resolving["resolve_day"]), float(_resolving["outcome"])))
	elif month - last_resolved >= int(data.get("cooldown_months", 1)) and rng.randf() < float(data.get("chance", 0.0)):
		rumor = _new_rumor(month)
		if not rumor.is_empty():
			_add(shocks, rumor["asset"], int(rumor["day"]), float(rumor["pump"]))
			news.append(_news(month, rumor, "", int(rumor["day"]), float(rumor["pump"])))
	return {"shocks": shocks, "news": news}


## Setelah pasar bergerak (dan pesanan otomatis dijalankan). Mengembalikan hasil rumor yang terjawab
## bulan ini untuk laporan (kosong jika tidak ada); posisi awal rumor baru dicatat.
func after_market() -> Dictionary:
	if not rumor.is_empty() and int(rumor["month"]) == gs.month + 1:
		rumor["units"] = gs.portfolio.units_of(rumor["asset"])
	if _resolving.is_empty():
		return {}
	var r := _resolving
	_resolving = {}
	var asset := gs.market.get_asset(r["asset"])
	record["rumors"] += 1
	if r["is_true"]:
		record["true"] += 1
	var research := []
	for level: String in r["researched"]:
		var verdict: bool = r["verdicts"][level]
		var correct := verdict == bool(r["is_true"])
		record[level][0] += 1
		if correct:
			record[level][1] += 1
		research.append({"level": level, "verdict": verdict, "correct": correct})
	return {"id": r["id"], "asset": r["asset"], "direction": r["direction"], "is_true": r["is_true"],
		"change": asset.price / float(r["close"]) - 1.0, "research": research, "position": r["position"]}


# --- Riset -------------------------------------------------------------------------------------

func level_def(level: String) -> Dictionary:
	return data["research"][level]


func cost(level: String) -> int:
	return gs.nominal(float(level_def(level).get("cost", 0)))


func accuracy(level: String) -> float:
	return float(level_def(level)["accuracy"])


func has_rumor() -> bool:
	return not rumor.is_empty()


func is_researched(level: String) -> bool:
	return has_rumor() and level in rumor["researched"]


## Penilaian riset yang sudah dilakukan: true = "kemungkinan benar", false = "kemungkinan hoaks".
func verdict(level: String) -> bool:
	return rumor["verdicts"][level]


## "" jika riset bisa dilakukan, atau key pesan error.
func block_reason(level: String) -> String:
	if not has_rumor():
		return "ERR_NO_RUMOR"
	if is_researched(level):
		return "ERR_RESEARCH_DONE"
	if gs.is_over or gs.events.has_pending():
		return "ERR_ACTIVITY_BUSY"
	if gs.activities.energy < int(level_def(level)["energy"]):
		return "ERR_NO_ENERGY"
	if cost(level) > gs.cash:
		return "ERR_NOT_ENOUGH_CASH"
	return ""


## Riset rumor yang sedang beredar. Mengembalikan { "ok", "error" } atau { "ok", "verdict" }.
func research(level: String) -> Dictionary:
	var reason := block_reason(level)
	if reason != "":
		return {"ok": false, "error": reason}
	var price := cost(level)
	gs.activities.energy -= int(level_def(level)["energy"])
	gs.cash -= price
	record["costs"] += price
	rumor["researched"].append(level)
	gs.changed.emit()
	return {"ok": true, "verdict": verdict(level)}


## Akurasi nyata riset per tingkat (-1 jika belum pernah ada riset yang terjawab).
func realized_accuracy(level: String) -> float:
	var done: Array = record[level]
	return float(done[1]) / float(done[0]) if int(done[0]) > 0 else -1.0


# --- Internal ----------------------------------------------------------------------------------

func _new_rumor(month: int) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var weights := PackedFloat32Array()
	for def: Dictionary in data.get("rumors", []):
		if not _targets(def).is_empty():
			candidates.append(def)
			weights.append(float(def["weight"]))
	if candidates.is_empty():
		return {}  # belum ada saham/kripto yang terbuka
	var def: Dictionary = candidates[rng.rand_weighted(weights)]
	var targets := _targets(def)
	var asset_id: String = targets[rng.randi() % targets.size()]
	var dir: Dictionary = data["directions"][def["direction"]]
	var scale := float(data["class_scale"].get(gs.market.get_asset(asset_id).asset_class, 1.0))
	var is_true := rng.randf() < float(dir["true_chance"])
	var move: Array = dir["true_move"] if is_true else dir["trap_move"]
	var verdicts := {}
	for level: String in LEVELS:
		verdicts[level] = is_true if rng.randf() < accuracy(level) else not is_true
	return {
		"id": def["id"], "asset": asset_id, "direction": def["direction"], "month": month,
		"day": rng.randi_range(int(data["pump_days"][0]), int(data["pump_days"][1])),
		"is_true": is_true,
		"pump": rng.randf_range(float(dir["pump"][0]), float(dir["pump"][1])) * scale,
		"outcome": rng.randf_range(float(move[0]), float(move[1])) * scale,
		"resolve_day": rng.randi_range(int(data["resolve_days"][0]), int(data["resolve_days"][1])),
		"verdicts": verdicts, "researched": [], "units": 0.0,
	}


## Aset sasaran rumor yang sudah terbuka untuk pemain (urutan sesuai assets.json).
func _targets(def: Dictionary) -> Array[String]:
	var target: String = def["target"]
	var ids: Array[String] = []
	if target.begins_with("asset:"):
		ids.append(target.trim_prefix("asset:"))
	else:
		var asset_class := "stock" if target == "random_stock" else "crypto"
		for asset: MarketAsset in gs.market.assets.values():
			if asset.asset_class == asset_class:
				ids.append(asset.id)
	var open: Array[String] = []
	for id: String in ids:
		if gs.market.get_asset(id) != null and gs.progress.is_asset_unlocked(id):
			open.append(id)
	return open


## Apa yang pemain lakukan dengan aset itu selama rumor beredar.
func _position(r: Dictionary) -> String:
	var before := float(r.get("units", 0.0))
	var now := gs.portfolio.units_of(r["asset"])
	if now > before * 1.0001 + 1e-9:
		return "bought"
	if now < before * 0.9999 - 1e-9:
		return "sold"
	return "held" if now > 0.0 else "none"


func _news(month: int, r: Dictionary, suffix: String, day: int, shock: float) -> Dictionary:
	return {"month": month, "day": day, "key": "RUMOR_%s%s" % [str(r["id"]).to_upper(), suffix],
		"asset_key": gs.market.get_asset(r["asset"]).name_key, "shock": shock,
		"rumor": "new" if suffix == "" else suffix.trim_prefix("_").to_lower()}


static func _add(shocks: Dictionary, asset_id: String, day: int, shock: float) -> void:
	var by_day: Dictionary = shocks.get_or_add(asset_id, {})
	by_day[day] = by_day.get(day, 0.0) + shock
