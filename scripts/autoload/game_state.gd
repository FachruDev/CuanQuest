extends Node
## State global permainan (didaftarkan sebagai Autoload bernama "GameState").
## Analogi web: ini "store" (Redux/Pinia). UI tidak mengubah data langsung,
## melainkan memanggil fungsi di sini, lalu mendengarkan signal `changed` untuk re-render.

signal changed
signal month_advanced(report: Dictionary)
signal event_triggered(event: Dictionary)
signal stage_unlocked(stage: Dictionary)

const ASSETS_PATH := "res://data/assets.json"
const ECONOMY_PATH := "res://data/economy.json"
const MARKET_PATH := "res://data/market.json"
const NEWS_PATH := "res://data/news.json"
const UNLOCKS_PATH := "res://data/unlocks.json"
const EVENTS_PATH := "res://data/events.json"
const QUIZ_PATH := "res://data/quiz.json"

var economy: Dictionary = {}       # isi data/economy.json
var stage_defs: Array = []         # isi data/unlocks.json

var month: int = 0                 # 0 = Jan tahun 1
var cash: int = 0                  # Rupiah disimpan sebagai int (hindari error pembulatan float)
var salary: int = 0
var health: int = 0                # 0..100
var happiness: int = 0             # 0..100
var xp: int = 0
var unemployed_months: int = 0     # sisa bulan tanpa gaji (setelah PHK)
var food_id: String = ""
var housing_id: String = ""
var holdings: Dictionary = {}      # asset_id -> { "units": float, "cost": float, "locked_until": int }
var unlocked_stages: Array[int] = []
var market := Market.new()
var net_worth_history: Array[float] = []
var last_report: Dictionary = {}

var events := EventManager.new()
var pending_event: Dictionary = {}           # event yang menunggu keputusan pemain
var delayed_effects: Array[Dictionary] = []  # { due, effects, text, chance, fail_text }
var rng := RandomNumberGenerator.new()       # RNG event (terpisah dari RNG pasar)

## Kuis tidak di-reset saat game baru: jatahnya mengikuti minggu nyata.
var quiz := QuizManager.new()


func _ready() -> void:
	TranslationServer.set_locale("id")
	economy = DataLoader.load_json(ECONOMY_PATH)
	stage_defs = DataLoader.load_json(UNLOCKS_PATH).get("stages", [])
	quiz.setup(DataLoader.load_json(QUIZ_PATH).get("questions", []), economy["quiz"])
	new_game()


func new_game(seed_value: int = -1) -> void:
	if seed_value < 0:
		seed_value = randi()
	rng.seed = seed_value + 1
	month = 0
	cash = int(economy["start_cash"])
	salary = int(economy["salary"])
	health = int(economy["start_health"])
	happiness = int(economy["start_happiness"])
	xp = 0
	unemployed_months = 0
	food_id = economy["default_food"]
	housing_id = economy["default_housing"]
	holdings.clear()
	unlocked_stages.clear()
	pending_event = {}
	delayed_effects.clear()
	events.setup(DataLoader.load_json(EVENTS_PATH).get("events", []))
	market = Market.new()
	market.setup(
		DataLoader.load_json(ASSETS_PATH).get("assets", []),
		DataLoader.load_json(MARKET_PATH),
		DataLoader.load_json(NEWS_PATH).get("news", []),
		seed_value)
	_start_month()
	net_worth_history = [net_worth()]
	last_report = {}
	_check_unlocks(false)
	changed.emit()


## Tombol "Lanjut": tutup bulan ini (pasar bergerak), lalu buka bulan baru.
## Urutan signal: month_advanced (laporan) -> stage_unlocked -> event_triggered.
func advance_month() -> void:
	if has_pending_event():
		return  # event bulan ini harus diputuskan dulu
	var net_worth_before := net_worth()
	var invest_before := investments_value()
	var interest := _pay_interest()
	var news := market.step(month + 1)
	var invest_change := investments_value() - invest_before

	var from_month := month
	month += 1
	var start_report := _start_month()
	var delayed := _resolve_delayed()
	xp += int(economy["xp_per_month"])
	net_worth_history.append(net_worth())

	last_report = start_report.merged({
		"from_month": from_month,
		"to_month": month,
		"invest_change": invest_change,
		"interest": interest,
		"news": news,
		"delayed": delayed,
		"net_worth_before": net_worth_before,
		"net_worth_after": net_worth(),
		"cash_after": cash,
	})
	changed.emit()
	month_advanced.emit(last_report)
	_check_unlocks(true)
	_roll_event()


## Bunga bulanan tabungan & deposito (setelah pajak) ditambahkan ke saldo. Mengembalikan totalnya.
func _pay_interest() -> float:
	var total := 0.0
	for asset_id: String in holdings:
		var asset := market.get_asset(asset_id)
		if not asset.is_interest():
			continue
		var monthly_rate := market.rate_for(asset) * (1.0 - asset.interest_tax) / 12.0
		var gain: float = holdings[asset_id]["units"] * monthly_rate
		holdings[asset_id]["units"] += gain
		total += gain
	return total


## Awal bulan: gaji masuk (kecuali sedang menganggur), biaya hidup terpotong,
## kesehatan & kebahagiaan berubah.
func _start_month() -> Dictionary:
	var food := food_option()
	var housing := housing_option()
	var health_before := health
	var happiness_before := happiness

	var paid := salary
	if unemployed_months > 0:
		paid = 0
		unemployed_months -= 1

	cash += paid - int(food["cost"]) - int(housing["cost"])
	health = clampi(health + int(food["health"]) + int(housing["health"]), 0, 100)
	happiness = clampi(happiness + int(food["happiness"]) + int(housing["happiness"]), 0, 100)

	return {
		"salary": paid,
		"unemployed": paid == 0,
		"food_cost": int(food["cost"]),
		"housing_cost": int(housing["cost"]),
		"health_delta": health - health_before,
		"happiness_delta": happiness - happiness_before,
	}


# --- Level & unlock -----------------------------------------------------------

func level() -> int:
	return floori(xp / float(economy["xp_per_level"])) + 1


## XP yang sudah dikumpulkan di level saat ini (untuk progress bar).
func xp_in_level() -> int:
	return xp % int(economy["xp_per_level"])


func stage_def(stage: int) -> Dictionary:
	for def: Dictionary in stage_defs:
		if int(def["stage"]) == stage:
			return def
	return {}


func is_stage_unlocked(stage: int) -> bool:
	return stage in unlocked_stages


func is_asset_unlocked(asset_id: String) -> bool:
	return is_stage_unlocked(market.get_asset(asset_id).stage)


## Kas + aset berisiko sangat rendah (tabungan, deposito, RD pasar uang).
func liquid_assets() -> float:
	var total := float(cash)
	for asset_id: String in holdings:
		if market.get_asset(asset_id).risk <= 1:
			total += holding_value(asset_id)
	return total


## Status satu syarat unlock: { "met": bool, "current": float, "target": float }
func requirement_status(req: Dictionary) -> Dictionary:
	var current := 0.0
	var target := 0.0
	match req["type"]:
		"emergency_fund":
			current = liquid_assets()
			target = monthly_expenses() * float(req["months"])
		"net_worth":
			current = net_worth()
			target = req["min"]
		"level":
			current = level()
			target = req["min"]
		"quiz_topic":
			current = quiz.correct_in_topic(req["topic"])
			target = req["correct"]
	return {"met": current >= target, "current": current, "target": target}


## Unlock bersifat permanen: sekali terbuka, tidak tertutup lagi walau syarat turun.
func _check_unlocks(notify: bool) -> void:
	var any := false
	for def: Dictionary in stage_defs:
		var stage := int(def["stage"])
		if is_stage_unlocked(stage):
			continue
		var all_met := true
		for req: Dictionary in def["requirements"]:
			if not requirement_status(req)["met"]:
				all_met = false
				break
		if all_met:
			unlocked_stages.append(stage)
			any = true
			if notify:
				stage_unlocked.emit(def)
	if any:
		changed.emit()


# --- Event hidup --------------------------------------------------------------

func has_pending_event() -> bool:
	return not pending_event.is_empty()


func _roll_event() -> void:
	var event := events.pick_guaranteed(self)
	if event.is_empty() and rng.randf() < float(economy["event_chance"]):
		event = events.pick_random(self, rng)
	if event.is_empty():
		return
	events.mark_shown(event, month)
	pending_event = event
	changed.emit()
	event_triggered.emit(event)


## Pilihan dengan biaya di muka hanya bisa dipilih jika kas cukup.
## Pilihan gratis selalu bisa dipilih, termasuk saat kas minus, agar game tidak macet.
func can_choose(choice: Dictionary) -> bool:
	var cost := int(choice.get("cost", 0))
	return cost == 0 or cost <= cash


## Menjalankan pilihan pemain. Mengembalikan { "result": teks, "changes": perubahan }.
func resolve_event(choice_index: int) -> Dictionary:
	var choice: Dictionary = pending_event["choices"][choice_index]
	var before := _snapshot()
	cash -= int(choice.get("cost", 0))
	var outcome := choice
	if choice.has("outcomes"):
		outcome = _pick_outcome(choice["outcomes"])
	_apply_effects(outcome.get("effects", {}))
	pending_event = {}
	var result := {"result": outcome.get("result", ""), "changes": _diff(before)}
	changed.emit()
	_check_unlocks(true)
	return result


func _pick_outcome(outcomes: Array) -> Dictionary:
	var weights := PackedFloat32Array()
	for o: Dictionary in outcomes:
		weights.append(o["chance"])
	return outcomes[rng.rand_weighted(weights)]


func _apply_effects(e: Dictionary) -> void:
	cash += int(e.get("cash", 0)) + roundi(salary * float(e.get("cash_salary", 0.0)))
	health = clampi(health + int(e.get("health", 0)), 0, 100)
	happiness = clampi(happiness + int(e.get("happiness", 0)), 0, 100)
	xp += int(e.get("xp", 0))
	if e.has("salary_pct"):
		salary = roundi(salary * (1.0 + float(e["salary_pct"])) / 1000.0) * 1000
	unemployed_months += int(e.get("unemployed_months", 0))
	if e.has("delayed"):
		var d: Dictionary = e["delayed"].duplicate(true)
		d["due"] = month + int(d["months"])
		delayed_effects.append(d)
	if e.get("sell_all", false):
		for asset_id: String in holdings.keys():
			sell(asset_id, ceili(holding_value(asset_id)))


## Efek tertunda yang jatuh tempo bulan ini. Mengembalikan teks-teksnya untuk laporan.
func _resolve_delayed() -> Array[String]:
	var texts: Array[String] = []
	for d: Dictionary in delayed_effects.duplicate():
		if d["due"] > month:
			continue
		delayed_effects.erase(d)
		if rng.randf() < float(d.get("chance", 1.0)):
			_apply_effects(d["effects"])
			texts.append(d["text"])
		elif d.has("fail_text"):
			texts.append(d["fail_text"])
	return texts


func _snapshot() -> Dictionary:
	return {"cash": cash, "health": health, "happiness": happiness, "xp": xp,
		"salary": salary, "investments": investments_value()}


func _diff(before: Dictionary) -> Dictionary:
	var after := _snapshot()
	var changes := {}
	for key: String in before:
		var delta: float = after[key] - before[key]
		if absf(delta) > 0.5:
			changes[key] = delta
	return changes


# --- Kuis ---------------------------------------------------------------------

## Memakai satu jatah kuis. Mengembalikan soal, atau {} jika jatah habis.
func start_quiz() -> Dictionary:
	var question := quiz.start(_needed_quiz_topics())
	changed.emit()
	return question


## Topik kuis yang dibutuhkan untuk tahap terkunci TERDEKAT (fokus satu tahap dulu).
func _needed_quiz_topics() -> Array:
	for def: Dictionary in stage_defs:
		if is_stage_unlocked(int(def["stage"])):
			continue
		var topics := []
		for req: Dictionary in def["requirements"]:
			if req["type"] == "quiz_topic" and not requirement_status(req)["met"]:
				topics.append(req["topic"])
		if not topics.is_empty():
			return topics
	return []


func grant_quiz_credit() -> void:
	quiz.add_bonus_credit()
	changed.emit()


## Mengembalikan { "correct": bool, "reward": int, "xp": int }
func answer_quiz(question: Dictionary, option_index: int) -> Dictionary:
	var cfg: Dictionary = economy["quiz"]
	var is_correct := quiz.answer(question, option_index)
	var reward := int(cfg["reward_correct"]) if is_correct else 0
	var gained := int(cfg["xp_correct"]) if is_correct else int(cfg["xp_wrong"])
	cash += reward
	xp += gained
	changed.emit()
	_check_unlocks(true)
	return {"correct": is_correct, "reward": reward, "xp": gained}


# --- Biaya hidup --------------------------------------------------------------

func food_option() -> Dictionary:
	return _find_option(economy["food"], food_id)


func housing_option() -> Dictionary:
	return _find_option(economy["housing"], housing_id)


func monthly_expenses() -> int:
	return int(food_option()["cost"]) + int(housing_option()["cost"])


## Pilihan baru berlaku saat awal bulan berikutnya.
func set_food(id: String) -> void:
	food_id = id
	changed.emit()


func set_housing(id: String) -> void:
	housing_id = id
	changed.emit()


func _find_option(options: Array, id: String) -> Dictionary:
	for option: Dictionary in options:
		if option["id"] == id:
			return option
	push_error("Opsi tidak ditemukan: %s" % id)
	return options[0]


# --- Portofolio ---------------------------------------------------------------

func units_of(asset_id: String) -> float:
	return holdings.get(asset_id, {}).get("units", 0.0)


func cost_of(asset_id: String) -> float:
	return holdings.get(asset_id, {}).get("cost", 0.0)


func holding_value(asset_id: String) -> float:
	return units_of(asset_id) * market.get_asset(asset_id).price


func investments_value() -> float:
	var total := 0.0
	for asset_id: String in holdings:
		total += holding_value(asset_id)
	return total


func total_cost() -> float:
	var total := 0.0
	for asset_id: String in holdings:
		total += cost_of(asset_id)
	return total


func net_worth() -> float:
	return cash + investments_value()


## Beli aset senilai `amount` Rupiah (sudah termasuk fee).
## Mengembalikan { ok, error, units, fee } supaya UI bisa menampilkan pesan.
func buy(asset_id: String, amount: int) -> Dictionary:
	if not is_asset_unlocked(asset_id):
		return {"ok": false, "error": "ERR_LOCKED"}
	if amount <= 0:
		return {"ok": false, "error": "ERR_AMOUNT_INVALID"}
	if amount > cash:
		return {"ok": false, "error": "ERR_NOT_ENOUGH_CASH"}

	var asset := market.get_asset(asset_id)
	var fee := amount * asset.buy_fee
	var units := (amount - fee) / asset.price

	var h: Dictionary = holdings.get(asset_id, {"units": 0.0, "cost": 0.0, "locked_until": 0})
	h["units"] += units
	h["cost"] += amount
	if asset.lock_months > 0:
		h["locked_until"] = month + asset.lock_months  # setoran baru memperpanjang tenor
	holdings[asset_id] = h
	cash -= amount

	changed.emit()
	return {"ok": true, "units": units, "fee": fee}


## Jual aset senilai `amount` Rupiah (berdasarkan harga pasar sebelum fee).
func sell(asset_id: String, amount: int) -> Dictionary:
	var held := units_of(asset_id)
	if amount <= 0:
		return {"ok": false, "error": "ERR_AMOUNT_INVALID"}
	if held <= 0.0:
		return {"ok": false, "error": "ERR_NOT_ENOUGH_UNITS"}

	var asset := market.get_asset(asset_id)
	var units := amount / asset.price
	if units > held * 1.0001:
		return {"ok": false, "error": "ERR_NOT_ENOUGH_UNITS"}
	if units >= held * 0.999:
		units = held  # jual semua, hindari sisa "debu" 0.0001 unit

	var penalty := is_locked(asset_id)
	var gross := units * asset.price
	var fee := gross * (asset.sell_fee + (asset.early_penalty if penalty else 0.0))
	var proceeds := floori(gross - fee)

	var h: Dictionary = holdings[asset_id]
	h["cost"] -= h["cost"] * (units / held)  # kurangi modal secara proporsional
	h["units"] -= units
	if h["units"] <= 0.0:
		holdings.erase(asset_id)
	cash += proceeds

	changed.emit()
	return {"ok": true, "units": units, "fee": fee, "proceeds": proceeds, "penalty": penalty}


## Deposito yang belum jatuh tempo kena penalti jika dicairkan.
func is_locked(asset_id: String) -> bool:
	return holdings.get(asset_id, {}).get("locked_until", 0) > month


func locked_until(asset_id: String) -> int:
	return holdings.get(asset_id, {}).get("locked_until", 0)
