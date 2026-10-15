class_name Contracts
extends GameModule
## Proyek sampingan (v1.5d langkah 3). Setiap awal bulan papan proyek di tab Karier berisi 1-2
## tawaran sesuai bidang & reputasi pemain (desain logo UMKM, aplikasi kasir, audit koperasi, ...).
## Pemain memilih strategi saat menerima: teliti (energi lebih, peluang tinggi), cepat (hemat
## energi, rawan revisi), atau bersama rekan (ringan, bayaran dibagi). Proyek memakai energi setiap
## bulan sampai tenggat, lalu hasilnya diundi: memuaskan, selesai, revisi (+1 bulan), atau gagal.
## Hasilnya bayaran, pengalaman bidang, keahlian, dan reputasi (tawaran berikutnya lebih besar).
## Data: data/contracts.json.
##
## Memakai RNG sendiri, jadi permainan yang tidak mengambil proyek tetap sama persis. Analogi web:
## seperti marketplace freelance kecil dengan antrean job milik user.

const CONTRACTS_PATH := "res://data/contracts.json"

var data: Dictionary = {}  # isi data/contracts.json
## Tawaran bulan ini: [{uid, id, track, tier, months, client, pay, regime_mult}]
var board: Array[Dictionary] = []
## Proyek yang sedang dikerjakan: [{uid, id, track, tier, strategy, months_total, months_left, pay,
## client, chance, accepted, revision, short, price}]
var active: Array[Dictionary] = []
var reputation := 0
var month_energy := 0  # energi bulan ini yang dipakai proyek (untuk tampilan)
var seq := 0  # nomor urut tawaran
var rng := RandomNumberGenerator.new()


func load_data() -> void:
	data = DataLoader.load_json(CONTRACTS_PATH)


func reset() -> void:
	board.clear()
	active.clear()
	reputation = int(data["reputation"]["start"])
	month_energy = 0
	seq = 0
	rng.seed = gs.rng.seed + 3  # GameState.rng sudah di-seed sebelum modul di-reset/dimuat


func save_to(d: Dictionary) -> void:
	d.merge({"contract_board": board, "contracts": active, "contract_reputation": reputation,
		"contract_energy": month_energy, "contract_seq": seq, "contract_rng": [str(rng.seed), str(rng.state)]})


## Save sebelum v1.5d langkah 3: belum ada proyek; papan terisi di awal bulan berikutnya.
func load_from(d: Dictionary) -> void:
	reset()
	for saved: Dictionary in d.get("contract_board", []):
		board.append(_typed(saved))
	for saved: Dictionary in d.get("contracts", []):
		active.append(_typed(saved))
	reputation = int(d.get("contract_reputation", reputation))
	month_energy = int(d.get("contract_energy", 0))
	seq = int(d.get("contract_seq", 0))
	if d.has("contract_rng"):
		rng.seed = String(d["contract_rng"][0]).to_int()
		rng.state = String(d["contract_rng"][1]).to_int()


static func _typed(saved: Dictionary) -> Dictionary:
	var entry := saved.duplicate()
	for key: String in ["uid", "tier", "months", "pay", "months_total", "months_left", "accepted"]:
		if entry.has(key):
			entry[key] = int(entry[key])
	return entry


# --- Data -------------------------------------------------------------------------------------

func project_def(id: String) -> Dictionary:
	for def: Dictionary in data["projects"]:
		if def["id"] == id:
			return def
	return {}


func tier_def(tier: int) -> Dictionary:
	for def: Dictionary in data["tiers"]:
		if int(def["tier"]) == tier:
			return def
	return {}


func strategies() -> Array:
	return data["strategies"]


func strategy_def(id: String) -> Dictionary:
	for def: Dictionary in strategies():
		if def["id"] == id:
			return def
	return {}


## Tier tertinggi yang terbuka untuk reputasi sekarang.
func max_tier() -> int:
	var best := 1
	for def: Dictionary in data["tiers"]:
		if reputation >= int(def["reputation"]):
			best = maxi(best, int(def["tier"]))
	return best


## Tambahan bayaran dari reputasi (0.1 = +10%).
func reputation_bonus() -> float:
	return reputation * float(data["reputation"]["pay_per_point"])


## Peluang berhasil tawaran/proyek `entry` dengan strategi `strategy_id` (keahlian sekarang).
func chance_for(entry: Dictionary, strategy_id: String) -> float:
	var cfg: Dictionary = data["chance"]
	var chance := float(cfg["base"]) + (gs.career.skill - float(tier_def(int(entry["tier"]))["skill"])) * float(cfg["per_skill"])
	if entry["track"] != "general" and int(gs.career.experience.get(entry["track"], 0)) >= int(cfg["experience_months"]):
		chance += float(cfg["experience_bonus"])
	chance += float(strategy_def(strategy_id)["chance"])
	return clampf(chance, float(cfg["min"]), float(cfg["max"]))


## Bayaran yang diterima pemain jika proyek selesai dengan strategi ini (sebelum bonus).
func pay_for(entry: Dictionary, strategy_id: String) -> int:
	return roundi(float(entry["pay"]) * float(strategy_def(strategy_id)["pay_share"]) / 1000.0) * 1000


## Energi bulan ini yang masih dibutuhkan proyek aktif bulan depan dst. (untuk tampilan).
func monthly_energy() -> int:
	var total := 0
	for c: Dictionary in active:
		total += int(strategy_def(c["strategy"])["energy"])
	return total


## Penurunan target kinerja kantor karena terlalu banyak proyek (dipakai Career.performance_factors).
func performance_penalty() -> float:
	return float(data["performance_penalty"]) * maxi(active.size() - 1, 0)


# --- Menerima proyek ---------------------------------------------------------------------------

## "" jika tawaran `index` bisa diterima dengan strategi ini, atau key pesan error.
func accept_block_reason(index: int, strategy_id: String) -> String:
	if gs.is_over or gs.events.has_pending():
		return "ERR_ACTIVITY_BUSY"
	if index < 0 or index >= board.size():
		return "ERR_CONTRACT_GONE"
	if active.size() >= int(data["max_active"]):
		return "ERR_CONTRACT_MAX"
	if gs.activities.energy < int(strategy_def(strategy_id)["energy"]):
		return "ERR_NO_ENERGY"
	return ""


## Terima tawaran `index` dengan strategi `strategy_id`: energi bulan ini langsung terpakai.
func accept(index: int, strategy_id: String) -> Dictionary:
	var reason := accept_block_reason(index, strategy_id)
	if reason != "":
		return {"ok": false, "error": reason}
	var offer: Dictionary = board.pop_at(index)
	var energy := int(strategy_def(strategy_id)["energy"])
	gs.activities.energy -= energy
	month_energy += energy
	var entry := offer.duplicate()
	entry.merge({"strategy": strategy_id, "months_total": int(offer["months"]), "months_left": int(offer["months"]),
		"chance": chance_for(offer, strategy_id), "accepted": gs.month, "revision": false, "short": false})
	var def := project_def(offer["id"])
	if def.has("pay_asset") and gs.market.get_asset(def["pay_asset"]) != null:
		entry["price"] = gs.market.get_asset(def["pay_asset"]).price
	active.append(entry)
	gs.changed.emit()
	return {"ok": true, "contract": entry}


# --- Alur bulanan (dipanggil GameState._start_month setelah energi diisi ulang) --------------------

## Proyek aktif sudah dikerjakan sebulan: kondisi berubah, yang tenggatnya tiba diundi hasilnya,
## sisanya memakai energi bulan ini. Lalu papan berisi tawaran baru. Mengembalikan hasil untuk laporan.
func month_step() -> Dictionary:
	var results: Array[Dictionary] = []
	var reputation_before := reputation
	if active.size() > 1:  # beberapa proyek sekaligus: kelelahan
		var overload: Dictionary = data.get("overload", {})
		gs.health = clampi(gs.health + int(overload.get("health", 0)) * (active.size() - 1), 0, 100)
		gs.happiness = clampi(gs.happiness + int(overload.get("happiness", 0)) * (active.size() - 1), 0, 100)
	for c: Dictionary in active.duplicate():
		var strategy := strategy_def(c["strategy"])
		gs.health = clampi(gs.health + int(strategy.get("health", 0)), 0, 100)
		gs.happiness = clampi(gs.happiness + int(strategy.get("happiness", 0)), 0, 100)
		c["months_left"] = int(c["months_left"]) - 1
		if int(c["months_left"]) <= 0:
			results.append(_resolve(c))
	month_energy = 0
	for c: Dictionary in active:
		var need := int(strategy_def(c["strategy"])["energy"])
		if gs.activities.energy < need:
			c["short"] = true  # kelelahan: proyek dikerjakan seadanya bulan ini
		var used := mini(need, gs.activities.energy)
		gs.activities.energy -= used
		month_energy += used
	refresh_board()
	if results.is_empty():
		return {}
	return {"contracts_done": results, "reputation_before": reputation_before, "reputation_after": reputation}


## Undian hasil proyek yang tenggatnya tiba.
func _resolve(c: Dictionary) -> Dictionary:
	var cfg: Dictionary = data["chance"]
	var strategy := strategy_def(c["strategy"])
	var chance := float(c["chance"])
	if c["revision"]:
		chance += float(cfg["revision_bonus"])
	if c["short"]:
		chance += float(cfg["short_energy"])
	chance = clampf(chance, float(cfg["min"]), float(cfg["max"]))
	var roll := rng.randf()
	var result := {"id": c["id"], "track": c["track"], "client": c["client"], "strategy": c["strategy"],
		"short": c["short"], "pay": 0, "rep": 0}
	var rep: Dictionary = data["reputation"]
	if roll < chance:
		var excellent := roll < chance * float(strategy["excellent"])
		var pay := float(c["pay"]) * float(strategy["pay_share"]) * _asset_ratio(c)
		if excellent:
			pay *= 1.0 + float(data["excellent_bonus"])
		result["result"] = "excellent" if excellent else "success"
		result["pay"] = roundi(pay / 1000.0) * 1000
		result["rep"] = int(rep["excellent" if excellent else "success"])
		_reward(c, strategy)
		gs.stats["projects_done"] = int(gs.stats.get("projects_done", 0)) + 1
		if excellent:
			gs.stats["projects_excellent"] = int(gs.stats.get("projects_excellent", 0)) + 1
		active.erase(c)
	elif not c["revision"]:
		c["revision"] = true
		c["months_left"] = 1
		result["result"] = "revision"
		result["rep"] = int(rep["revision"])
		gs.stats["projects_revised"] = int(gs.stats.get("projects_revised", 0)) + 1
	else:
		result["result"] = "failed"
		result["pay"] = roundi(float(c["pay"]) * float(strategy["pay_share"]) * float(data["failed_pay"]) / 1000.0) * 1000
		result["rep"] = int(rep["failed"])
		gs.happiness = clampi(gs.happiness + int(data["failed_happiness"]), 0, 100)
		gs.stats["projects_failed"] = int(gs.stats.get("projects_failed", 0)) + 1
		active.erase(c)
	if c.has("price"):
		result["asset_change"] = _asset_ratio(c) - 1.0
	gs.cash += int(result["pay"])
	gs.stats["project_income"] = int(gs.stats.get("project_income", 0)) + int(result["pay"])
	reputation = clampi(reputation + int(result["rep"]), 0, 100)
	return result


## Proyek berhasil: pengalaman bidang, keahlian, XP, dan kedekatan dengan rekan kerja (strategi tim).
func _reward(c: Dictionary, strategy: Dictionary) -> void:
	var tier := tier_def(int(c["tier"]))
	if c["track"] != "general":
		gs.career.experience[c["track"]] = int(gs.career.experience.get(c["track"], 0)) \
			+ floori(int(c["months_total"]) * float(data["experience_ratio"]))
	gs.career.gain_skill(float(tier["skill_gain"]))
	gs.progress.xp += int(tier["xp"]) * int(c["months_total"])
	if strategy.has("coworker_rel") and gs.career.is_career():
		gs.characters.add_rel("coworker", int(strategy["coworker_rel"]))


## Bayaran token: nilainya ikut harga aset dari saat diterima sampai dibayar.
func _asset_ratio(c: Dictionary) -> float:
	if not c.has("price"):
		return 1.0
	var asset := gs.market.get_asset(project_def(c["id"]).get("pay_asset", ""))
	return asset.price / float(c["price"]) if asset != null and float(c["price"]) > 0.0 else 1.0


## Tawaran bulan ini: proyek di bidang yang pernah/sedang ditekuni lebih sering muncul, begitu juga
## tier tertinggi yang terbuka untuk reputasi sekarang. Bayaran ikut inflasi, tingkat kesulitan,
## reputasi, dan (untuk sebagian proyek) kondisi pasar.
func refresh_board() -> void:
	board.clear()
	var top := max_tier()
	var own_track: String = gs.career.current_job_def().get("track", "") if gs.career.is_employed() else ""
	var candidates: Array[Dictionary] = []
	var weights := PackedFloat32Array()
	for def: Dictionary in data["projects"]:
		if int(def["tier"]) > top:
			continue
		var weight := float(def.get("weight", 1.0))
		if def["track"] == own_track or int(gs.career.experience.get(def["track"], 0)) > 0:
			weight *= 3.0
		if int(def["tier"]) == top:
			weight *= 2.0
		candidates.append(def)
		weights.append(weight)
	var count := rng.randi_range(int(data["offers"][0]), int(data["offers"][1]))
	while board.size() < count and not candidates.is_empty():
		var i := rng.rand_weighted(weights)
		var def: Dictionary = candidates.pop_at(i)
		weights.remove_at(i)
		board.append(_offer(def))


func _offer(def: Dictionary) -> Dictionary:
	var tier := tier_def(int(def["tier"]))
	var months := rng.randi_range(int(def["months"][0]), int(def["months"][1]))
	var clients: Array = data["clients"][str(int(def["tier"]))]  # angka JSON terbaca float (1.0)
	var regime_mult := 1.0
	if def.get("regime", false):
		regime_mult = float(data["regime_pay"].get(gs.market.regime_of("stock"), 1.0))
	var spread: Array = data["pay_spread"]
	var base := float(tier["pay"]) * months * float(gs.difficulty["salary_mult"]) * regime_mult \
		* rng.randf_range(float(spread[0]), float(spread[1])) * (1.0 + reputation_bonus())
	seq += 1
	return {"uid": seq, "id": def["id"], "track": def["track"], "tier": int(def["tier"]), "months": months,
		"client": clients[rng.randi() % clients.size()], "pay": gs.nominal(base), "regime_mult": regime_mult}
