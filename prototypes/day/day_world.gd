extends RefCounted
## Dunia prototipe B "Hari Cepat": satu hari game berlalu sekitar 1 detik nyata, dan waktu
## berhenti otomatis saat ada hal yang perlu diputuskan pemain (event, gajian, laporan,
## rencana bulan, harga bergerak besar).
##
## Agar pemain tidak sekadar menunggu, selama bulan berjalan ada hal yang bisa dikerjakan:
## aktivitas berdurasi beberapa hari (memakai energi bulanan), 3 misi bulanan, serta
## kesehatan & kebahagiaan yang perlahan turun bila tidak dijaga.
##
## Tidak tahu apa-apa soal UI (bisa dites headless). Popup yang menunggu ada di `pending`.

signal logged(text: String)
signal counted(key: String)
signal toast(text: String)

const GameClock := preload("res://prototypes/time/game_clock.gd")
const ProtoDirector := preload("res://prototypes/time/proto_director.gd")
const DayMarket := preload("res://prototypes/day/day_market.gd")
const VERSION := 1
const MISSION_TYPES := ["invest", "activity", "save", "health", "no_loss"]

var cfg: Dictionary
var activity_defs: Array = []
var clock := GameClock.new()
var market := DayMarket.new()
var director := ProtoDirector.new()
var rng := RandomNumberGenerator.new()   # khusus misi

var cash := 0.0
var salary := 0.0
var health := 0.0
var happiness := 0.0
var xp := 0
var energy := 0
var holdings := {}          # id -> unit
var avg_cost := {}          # id -> biaya rata-rata per unit (termasuk fee)
var activity := {}          # aktivitas berjalan: {id, days_left, days}; kosong jika tidak ada
var activity_counts := {}   # id -> berapa kali dimulai bulan ini
var missions: Array = []    # [{type, text, target, state: open|done|failed, activity_id}]
var month_buys := 0.0
var month_start_worth := 0.0
var move_cooldown := {}     # id -> hari terakhir popup gerakan besar
var warned := {}            # "health"/"happiness" -> true saat peringatan sudah tampil
var pending: Array = []


func setup(config: Dictionary, asset_defs: Array, event_defs: Array, activities: Array, seed_value: int) -> void:
	cfg = config
	var clock_cfg: Dictionary = cfg["clock"].duplicate()
	clock_cfg["seconds_per_hour"] = float(cfg["clock"]["seconds_per_day"]) / 24.0
	clock.setup(clock_cfg, cfg["calendar"])
	market.setup(cfg["market"], asset_defs, seed_value)
	director.setup(cfg["events"], event_defs, seed_value + 1)
	rng.seed = seed_value + 2
	activity_defs = activities
	for inst in market.instruments:
		holdings[inst.id] = 0.0
		avg_cost[inst.id] = 0.0


func new_game() -> void:
	cash = cfg["money"]["start_cash"]
	salary = cfg["money"]["salary"]
	health = cfg["stats"]["start_health"]
	happiness = cfg["stats"]["start_happiness"]
	_start_month(true)


# --- Waktu -------------------------------------------------------------------------------

## Dipanggil UI setiap frame. Berhenti lebih awal bila ada popup baru (UI akan menjeda jam).
func advance(real_delta: float) -> int:
	var steps := clock.consume(real_delta)
	for i in steps:
		_step()
		if not pending.is_empty():
			return i + 1
	return steps


func seconds_per_day() -> float:
	return clock.seconds_per_hour * 24.0


func set_seconds_per_day(seconds: float) -> void:
	clock.seconds_per_hour = seconds / 24.0


## Fase hari untuk suasana: langkah waktu = 6 jam (06 pagi, 12 siang, 18 sore, 00 malam).
func phase() -> String:
	match clock.hour():
		6, 7, 8, 9, 10, 11:
			return "Pagi"
		12, 13, 14, 15, 16, 17:
			return "Siang"
		18, 19, 20, 21, 22, 23:
			return "Sore"
	return "Malam"


func _step() -> void:
	clock.minutes += clock.step_minutes
	var cal: Dictionary = cfg["calendar"]
	if clock.hour() == 0:
		_on_new_day()
	if clock.day_of_month() == int(cal["report_day"]) and clock.hour() == int(cal["report_hour"]):
		pending.append(_month_report())
	if director.is_due(clock.minutes):
		var event := director.pop_event()
		pending.append({"kind": "event", "event_id": event["id"]})
		counted.emit("event")


func _on_new_day() -> void:
	counted.emit("day")
	var ended_day := clock.day() - 1
	var result := market.on_day(ended_day % 7 < 5)
	for text: String in result["news"]:
		logged.emit("Kabar: " + text)

	var stats: Dictionary = cfg["stats"]
	_add_stat("health", float(stats["health_per_day"]))
	_add_stat("happiness", float(stats["happiness_per_day"]))
	_progress_activity()

	var cal: Dictionary = cfg["calendar"]
	var dom := clock.day_of_month()
	if dom == 1:
		_start_month(false)
	if dom == int(cal["payday"]):
		cash += salary
		counted.emit("payday")
		logged.emit("Gaji masuk: %s" % Fmt.signed_rupiah(salary))
		pending.append({"kind": "payday"})
	_check_big_moves(result["changes"])


func _start_month(first: bool) -> void:
	energy = int(cfg["energy_per_month"])
	activity_counts.clear()
	month_buys = 0.0
	if not first:
		cash -= float(cfg["money"]["monthly_bills"])
		logged.emit("Tagihan bulanan dibayar: %s" % Fmt.signed_rupiah(-float(cfg["money"]["monthly_bills"])))
	month_start_worth = net_worth()
	director.plan_month(clock.day(), clock.days_per_month, clock.minutes)
	missions = _make_missions()
	var lines: Array[String] = []
	for mission: Dictionary in missions:
		lines.append("- " + mission["text"])
	var month_name := TranslationServer.translate("MONTH_%d" % clock.month_of_year())
	pending.append(_info("Rencana %s" % month_name,
		"Energi bulan ini: %d\nGaji masuk tanggal %d.\n\nMisi bulan ini:\n%s" % [
			energy, int(cfg["calendar"]["payday"]), "\n".join(lines)]))


# --- Kesehatan & kebahagiaan ------------------------------------------------------------

func _add_stat(stat: String, amount: float) -> void:
	var value := clampf(float(get(stat)) + amount, 0.0, 100.0)
	set(stat, value)
	var warn_below := float(cfg["stats"]["warn_below"])
	if value < warn_below and not warned.has(stat):
		warned[stat] = true
		var label := "Kesehatan" if stat == "health" else "Kebahagiaan"
		pending.append(_info("%s menurun" % label,
			"%s kamu tinggal %d. Coba aktivitas seperti Olahraga, Istirahat Total, atau Nongkrong dengan Teman." % [label, roundi(value)]))
	elif value >= warn_below + 10.0:
		warned.erase(stat)


# --- Aktivitas -----------------------------------------------------------------------------

func activity_def(id: String) -> Dictionary:
	for def: Dictionary in activity_defs:
		if def["id"] == id:
			return def
	return {}


func activity_days(id: String) -> int:
	return int(cfg["activity_days"].get(id, 1))


## "" jika aktivitas bisa dimulai, selain itu alasannya.
func activity_block_reason(id: String) -> String:
	var def := activity_def(id)
	if not activity.is_empty():
		return "Sedang ada aktivitas"
	if int(def["energy"]) > energy:
		return "Energi kurang"
	if float(def.get("cost", 0)) > cash:
		return "Kas kurang"
	if int(activity_counts.get(id, 0)) >= int(def.get("max_per_month", 1)):
		return "Maksimal bulan ini"
	return ""


func start_activity(id: String) -> bool:
	if activity_block_reason(id) != "":
		return false
	var def := activity_def(id)
	energy -= int(def["energy"])
	cash -= float(def.get("cost", 0))
	activity_counts[id] = int(activity_counts.get(id, 0)) + 1
	activity = {"id": id, "days_left": activity_days(id), "days": activity_days(id)}
	counted.emit("activity")
	logged.emit("Mulai %s (%d hari)." % [def["name"], activity_days(id)])
	return true


func _progress_activity() -> void:
	if activity.is_empty():
		return
	activity["days_left"] = int(activity["days_left"]) - 1
	if int(activity["days_left"]) > 0:
		return
	var def := activity_def(activity["id"])
	var effects: Dictionary = def.get("effects", {})
	var changes := {}
	if effects.has("cash_salary"):
		changes["cash"] = salary * float(effects["cash_salary"])
	if effects.has("salary_pct"):
		changes["salary"] = salary * float(effects["salary_pct"])
	for key: String in ["health", "happiness", "xp"]:
		if effects.has(key):
			changes[key] = effects[key]
	_apply_changes(changes)
	var finished_id: String = activity["id"]
	activity = {}
	toast.emit("%s selesai: %s" % [def["name"], changes_text(changes)])
	logged.emit("%s selesai: %s" % [def["name"], changes_text(changes)])
	for mission: Dictionary in missions:
		if mission["type"] == "activity" and mission["state"] == "open" and mission["activity_id"] == finished_id:
			_complete_mission(mission)


func _apply_changes(changes: Dictionary) -> void:
	cash += float(changes.get("cash", 0.0))
	salary += float(changes.get("salary", 0.0))
	xp += int(changes.get("xp", 0))
	if changes.has("health"):
		_add_stat("health", float(changes["health"]))
	if changes.has("happiness"):
		_add_stat("happiness", float(changes["happiness"]))


## {"cash": 1500000, "health": -2} -> "Kas +Rp1.500.000, Kesehatan -2"
static func changes_text(changes: Dictionary) -> String:
	var parts: Array[String] = []
	if changes.has("cash"):
		parts.append("Kas " + Fmt.signed_rupiah(changes["cash"]))
	if changes.has("salary"):
		parts.append("Gaji " + Fmt.signed_rupiah(changes["salary"]))
	if changes.has("health"):
		parts.append("Kesehatan %+d" % int(changes["health"]))
	if changes.has("happiness"):
		parts.append("Kebahagiaan %+d" % int(changes["happiness"]))
	if changes.has("xp"):
		parts.append("XP %+d" % int(changes["xp"]))
	return ", ".join(parts) if not parts.is_empty() else "tidak ada perubahan"


# --- Misi bulanan --------------------------------------------------------------------------

func _make_missions() -> Array:
	var m: Dictionary = cfg["missions"]
	var types := MISSION_TYPES.duplicate()
	for i in range(types.size() - 1, 0, -1):  # acak dengan RNG ber-seed (bukan shuffle global)
		var j := rng.randi_range(0, i)
		var tmp: String = types[i]
		types[i] = types[j]
		types[j] = tmp
	var result: Array = []
	for type: String in types.slice(0, int(m["per_month"])):
		var mission := {"type": type, "state": "open", "target": 0.0, "activity_id": ""}
		match type:
			"invest":
				mission["target"] = float(m["invest_target"])
				mission["text"] = "Investasikan minimal %s bulan ini" % Fmt.rupiah(m["invest_target"])
			"activity":
				var def: Dictionary = activity_defs[rng.randi() % activity_defs.size()]
				mission["activity_id"] = def["id"]
				mission["text"] = "Selesaikan aktivitas %s" % def["name"]
			"save":
				mission["target"] = float(m["save_target"])
				mission["text"] = "Akhiri bulan dengan kas minimal %s" % Fmt.rupiah(m["save_target"])
			"health":
				mission["target"] = float(m["health_target"])
				mission["text"] = "Jaga kesehatan minimal %d sampai akhir bulan" % int(m["health_target"])
			"no_loss":
				mission["text"] = "Jangan menjual aset dalam kondisi rugi bulan ini"
		result.append(mission)
	return result


func _complete_mission(mission: Dictionary) -> void:
	mission["state"] = "done"
	var m: Dictionary = cfg["missions"]
	_apply_changes({"happiness": float(m["reward_happiness"]), "xp": int(m["reward_xp"])})
	counted.emit("mission_done")
	toast.emit("Misi selesai! Kebahagiaan +%d, XP +%d" % [int(m["reward_happiness"]), int(m["reward_xp"])])


## Misi yang baru bisa dinilai di akhir bulan.
func _finalize_missions() -> void:
	for mission: Dictionary in missions:
		if mission["state"] != "open":
			continue
		var ok := false
		match mission["type"]:
			"save":
				ok = cash >= float(mission["target"])
			"health":
				ok = health >= float(mission["target"])
			"no_loss":
				ok = true
		if ok:
			_complete_mission(mission)
		else:
			mission["state"] = "failed"
			counted.emit("mission_failed")


# --- Transaksi -----------------------------------------------------------------------------
# Tanpa antrean: harga berubah sekali sehari, jadi transaksi selalu memakai harga terakhir.

func holding_value(id: String) -> float:
	return holdings[id] * market.find(id).price


func net_worth() -> float:
	var total := cash
	for inst in market.instruments:
		total += holding_value(inst.id)
	return total


func buy(id: String, rupiah: float) -> bool:
	if rupiah <= 0.0 or rupiah > cash + 0.5:
		return false
	rupiah = minf(rupiah, cash)
	var inst := market.find(id)
	var units := rupiah * (1.0 - inst.buy_fee) / inst.price
	avg_cost[id] = (avg_cost[id] * holdings[id] + rupiah) / (holdings[id] + units)
	holdings[id] += units
	cash -= rupiah
	month_buys += rupiah
	counted.emit("trade")
	logged.emit("Beli %s unit %s di %s." % [Fmt.units(units), id, Fmt.rupiah(inst.price)])
	for mission: Dictionary in missions:
		if mission["type"] == "invest" and mission["state"] == "open" and month_buys >= float(mission["target"]):
			_complete_mission(mission)
	return true


func sell(id: String, units: float) -> bool:
	units = minf(units, holdings[id])
	if units <= 0.0:
		return false
	var inst := market.find(id)
	var proceeds := units * inst.price * (1.0 - inst.sell_fee)
	var profit: float = proceeds - units * avg_cost[id]
	holdings[id] -= units
	if holdings[id] < 1e-9:
		holdings[id] = 0.0
		avg_cost[id] = 0.0
	cash += proceeds
	counted.emit("trade")
	logged.emit("Jual %s unit %s di %s (untung/rugi %s)." % [Fmt.units(units), id, Fmt.rupiah(inst.price), Fmt.signed_rupiah(profit)])
	if profit < 0.0:
		counted.emit("loss_sell")
		for mission: Dictionary in missions:
			if mission["type"] == "no_loss" and mission["state"] == "open":
				mission["state"] = "failed"
				toast.emit("Misi gagal: menjual dalam kondisi rugi")
	return true


## Untung/rugi belum terealisasi (persen) untuk satu aset.
func unrealized_ratio(id: String) -> float:
	if holdings[id] <= 0.0 or avg_cost[id] <= 0.0:
		return 0.0
	return market.find(id).price / avg_cost[id] - 1.0


func _check_big_moves(changes: Dictionary) -> void:
	var m: Dictionary = cfg["market"]
	for inst in market.instruments:  # urutan tetap
		if not changes.has(inst.id):
			continue
		var change: float = changes[inst.id]
		if absf(change) < float(m["big_move_sigma"]) * market.daily_sigma(inst):
			continue
		if clock.day() - int(move_cooldown.get(inst.id, -9999)) < int(m["big_move_cooldown_days"]):
			continue
		move_cooldown[inst.id] = clock.day()
		counted.emit("big_move")
		pending.append({"kind": "move", "id": inst.id, "change": change})


# --- Popup ---------------------------------------------------------------------------------

func _info(title: String, body: String) -> Dictionary:
	return {"kind": "info", "title": title, "body": body}


func _month_report() -> Dictionary:
	_finalize_missions()
	var worth := net_worth()
	var lines: Array[String] = []
	for mission: Dictionary in missions:
		lines.append("%s %s" % ["[v]" if mission["state"] == "done" else "[x]", mission["text"]])
	var month_name := TranslationServer.translate("MONTH_%d" % clock.month_of_year())
	return _info("Laporan %s" % month_name,
		"Kekayaan: %s (%s)\nKas: %s | Investasi: %s\nKesehatan %d | Kebahagiaan %d\n\nMisi:\n%s" % [
			Fmt.rupiah(worth), Fmt.signed_rupiah(worth - month_start_worth), Fmt.rupiah(cash),
			Fmt.rupiah(worth - cash), roundi(health), roundi(happiness), "\n".join(lines)])


func resolve_event(event: Dictionary, choice_index: int) -> Dictionary:
	var outcome := director.resolve(event, choice_index)
	cash += outcome["cash"]
	var effects: Dictionary = outcome["effects"]
	for key: String in ["health", "happiness"]:
		if effects.has(key):
			_add_stat(key, float(effects[key]))
	return outcome


func can_afford(choice: Dictionary) -> bool:
	var cost := float(choice.get("cost", 0))
	return cost == 0.0 or cost <= cash


# --- Simpan / muat -------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"version": VERSION, "clock": clock.to_dict(), "market": market.to_dict(),
		"director": director.to_dict(), "rng_seed": str(rng.seed), "rng_state": str(rng.state),
		"cash": cash, "salary": salary, "health": health, "happiness": happiness, "xp": xp,
		"energy": energy, "holdings": holdings, "avg_cost": avg_cost, "activity": activity,
		"activity_counts": activity_counts, "missions": missions, "month_buys": month_buys,
		"month_start_worth": month_start_worth, "move_cooldown": move_cooldown, "warned": warned,
		"pending": pending}


func load_state(d: Dictionary) -> bool:
	if int(d.get("version", 0)) != VERSION:
		return false
	clock.load_state(d["clock"])
	market.load_state(d["market"])
	director.load_state(d["director"])
	rng.seed = str(d["rng_seed"]).to_int()
	rng.state = str(d["rng_state"]).to_int()
	cash = d["cash"]
	salary = d["salary"]
	health = d["health"]
	happiness = d["happiness"]
	xp = int(d["xp"])
	energy = int(d["energy"])
	for inst in market.instruments:
		holdings[inst.id] = float(d["holdings"][inst.id])
		avg_cost[inst.id] = float(d["avg_cost"][inst.id])
	activity = d["activity"]
	if not activity.is_empty():
		activity["days_left"] = int(activity["days_left"])
		activity["days"] = int(activity["days"])
	activity_counts = d["activity_counts"]
	missions = d["missions"]
	month_buys = d["month_buys"]
	month_start_worth = d["month_start_worth"]
	move_cooldown = d["move_cooldown"]
	warned = d["warned"]
	pending = d["pending"]
	return true
