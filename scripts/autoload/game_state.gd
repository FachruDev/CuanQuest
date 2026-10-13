extends Node
## State global permainan (didaftarkan sebagai Autoload bernama "GameState").
## Analogi web: ini "store" (Redux/Pinia). UI tidak mengubah data langsung,
## melainkan memanggil fungsi di sini, lalu mendengarkan signal `changed` untuk re-render.

signal changed
signal month_advanced(report: Dictionary)
signal event_triggered(event: Dictionary)
signal stage_unlocked(stage: Dictionary)
## Satu giliran selesai diproses (akhir bulan / event diputuskan) -> SaveManager menyimpan otomatis.
signal state_committed
## Data global pemain (kuis, tutorial, petunjuk) berubah -> SaveManager menyimpan player.json.
signal player_changed
## Permainan berakhir (kalah / pensiun / pemain memilih selesai setelah menang).
signal game_ended(result: Dictionary)
## Target kemenangan tercapai ("millionaire" / "freedom"); pemain boleh lanjut bermain.
signal goal_reached(goal: String)
## Impian terwujud (dana pos impian mencapai biayanya). `dream` = entri impian + "def".
signal dream_achieved(dream: Dictionary)
## Tenggat impian terlewat; pemain memilih memperpanjang atau melepas.
signal dream_overdue(dream: Dictionary)
## Target bulanan selesai di tengah bulan (untuk notifikasi singkat).
signal target_completed(target: Dictionary)

## Versi slot save. Naik ke 2 di v1.5 (pasar harian); save lama ditolak, tanpa migrasi.
const SAVE_VERSION := 2
## Versi data pemain (user://player.json): kuis, tutorial, riwayat. Tidak ikut naik
## agar progres kuis tidak hilang saat format slot save berubah.
const PLAYER_VERSION := 1
const MOVERS_SHOWN := 3
const ASSETS_PATH := "res://data/assets.json"
const ECONOMY_PATH := "res://data/economy.json"
const MARKET_PATH := "res://data/market.json"
const NEWS_PATH := "res://data/news.json"
const UNLOCKS_PATH := "res://data/unlocks.json"
const EVENTS_PATH := "res://data/events.json"
const QUIZ_PATH := "res://data/quiz.json"
const ACTIVITIES_PATH := "res://data/activities.json"
const DREAMS_PATH := "res://data/dreams.json"
const RISK_PROFILE_PATH := "res://data/risk_profile.json"
const MAX_TRANSACTIONS := 200

var economy: Dictionary = {}       # isi data/economy.json
var stage_defs: Array = []         # isi data/unlocks.json

## true setelah new_game() atau load_from_dict(); layar judul belum memulai game.
var is_active := false

# --- Profil (dipilih saat Game Baru) ---
var player_name := ""
var avatar := 0
var background: Dictionary = {}    # salah satu economy.backgrounds
var difficulty: Dictionary = {}    # salah satu economy.difficulties

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

# --- Kondisi akhir & statistik (M6) ---
var stats: Dictionary = {}                   # lihat _new_stats()
var negative_cash_months := 0                # berturut-turut; mencapai batas = bangkrut
var zero_health_months := 0
var zero_happiness_months := 0
var goals_reached: Array[String] = []
var is_over := false
var end_result: Dictionary = {}

# --- M6.5: energi, aktivitas, transaksi, profil risiko, lompat waktu ---
var activity_data: Dictionary = {}           # isi data/activities.json
var risk_data: Dictionary = {}               # isi data/risk_profile.json
var energy := 0
var energy_capacity := 0                     # energi maksimal bulan ini (dikunci di awal bulan)
var activity_counts: Dictionary = {}         # activity_id -> berapa kali bulan ini
var transactions: Array[Dictionary] = []     # riwayat transaksi, terbaru di depan
var risk_profile_id := "moderate"
## Rencana gaji (v1.5-0): porsi dalam persen gaji. Dijalankan otomatis tiap awal bulan.
## {"lifestyle": 0.05, "emergency": 0.1, "invest": {asset_id: 0.1}, "salary_seen": int, "confirmed": bool}
var plan: Dictionary = {}
var plan_applied_month := -1                 # bulan terakhir rencana dijalankan (cegah dobel)
var month_income := 0                        # penghasilan yang benar-benar diterima bulan ini
## Impian (v1.5-0 langkah 3): [{id, saved, start_month, deadline, status, achieved_month}]
## status: active | achieved | released
var dreams: Array[Dictionary] = []
var dreams_asked := false                    # pemain sudah ditawari memilih impian di awal permainan
## Target bulan berjalan: [{type, goal, param, progress, state: open|done|failed}]
var targets: Array[Dictionary] = []
# Transaksi manual selama giliran ini, untuk pembanding "kalau tidak bertransaksi" di laporan.
var turn_units: Dictionary = {}              # asset_id -> unit saat giliran dimulai
var turn_fees := 0.0
var turn_trades := 0
var dream_defs: Array = []                   # isi data/dreams.json
var _dream_signals: Array[Callable] = []     # impian terwujud/terlewat, dikirim setelah laporan
var _fast_forwarding := false
var _deferred: Array[Callable] = []          # signal yang ditunda selama lompat waktu

# --- Data global pemain (user://player.json), TIDAK di-reset saat game baru ---
## Kuis: jatahnya mengikuti minggu nyata, jadi tidak boleh ikut slot save.
var quiz := QuizManager.new()
var tutorial_done := false
var hints_seen: Array[String] = []
var history: Array[Dictionary] = []          # ringkasan permainan sebelumnya (maks 10)


func _ready() -> void:
	economy = DataLoader.load_json(ECONOMY_PATH)
	stage_defs = DataLoader.load_json(UNLOCKS_PATH).get("stages", [])
	quiz.setup(DataLoader.load_json(QUIZ_PATH).get("questions", []), economy["quiz"])
	activity_data = DataLoader.load_json(ACTIVITIES_PATH)
	risk_data = DataLoader.load_json(RISK_PROFILE_PATH)
	dream_defs = DataLoader.load_json(DREAMS_PATH).get("dreams", [])


## `profile`: { "name", "avatar", "background", "difficulty" } (semua opsional).
func new_game(profile: Dictionary = {}, seed_value: int = -1) -> void:
	if seed_value < 0:
		seed_value = randi()
	rng.seed = seed_value + 1
	player_name = profile.get("name", "")
	if player_name.strip_edges() == "":
		player_name = tr("DEFAULT_PLAYER_NAME")
	avatar = int(profile.get("avatar", 0))
	risk_profile_id = profile.get("risk_profile", "moderate")
	transactions.clear()
	background = _find_option(economy["backgrounds"], profile.get("background", economy["default_background"]))
	difficulty = _find_option(economy["difficulties"], profile.get("difficulty", economy["default_difficulty"]))

	month = 0
	cash = int(background["start_cash"])
	salary = roundi(background["salary"] * difficulty["salary_mult"] / 1000.0) * 1000
	health = int(economy["start_health"])
	happiness = int(economy["start_happiness"])
	xp = 0
	unemployed_months = 0
	food_id = background["default_food"]
	housing_id = background["default_housing"]
	plan = default_plan()
	plan_applied_month = -1
	dreams.clear()
	dreams_asked = false
	targets.clear()
	_dream_signals.clear()
	holdings.clear()
	unlocked_stages.clear()
	pending_event = {}
	delayed_effects.clear()
	stats = _new_stats()
	negative_cash_months = 0
	zero_health_months = 0
	zero_happiness_months = 0
	goals_reached.clear()
	is_over = false
	end_result = {}
	events.setup(DataLoader.load_json(EVENTS_PATH).get("events", []))
	market = Market.new()
	market.setup(
		DataLoader.load_json(ASSETS_PATH).get("assets", []),
		DataLoader.load_json(MARKET_PATH),
		DataLoader.load_json(NEWS_PATH).get("news", []),
		seed_value)
	_start_month()
	net_worth_history = [net_worth()]
	stats["peak_net_worth"] = net_worth()
	last_report = {}
	is_active = true
	_check_unlocks(false)
	_snapshot_turn()
	changed.emit()


func age() -> int:
	return int(background["start_age"]) + floori(month / 12.0)


## Tombol "Lanjut": tutup bulan ini (pasar bergerak), lalu buka bulan baru.
## Urutan signal: month_advanced (laporan) -> stage_unlocked -> event_triggered.
func advance_month() -> void:
	if has_pending_event() or is_over:
		return  # event bulan ini harus diputuskan dulu
	var finished_targets := _finalize_targets()
	var net_worth_before := net_worth()
	var invest_before := investments_value()
	var start_prices := _current_prices()
	var interest := _pay_interest() + _pay_dream_interest()
	var news := market.step(month + 1)
	var invest_change := investments_value() - invest_before
	var daily_worth := _daily_worth_series(net_worth_before)
	var trade := _turn_trade_result(start_prices)

	var from_month := month
	month += 1
	var start_report := _start_month()
	var delayed := _resolve_delayed()
	var forced_sales := _cover_negative_cash()
	var warnings := _update_danger_counters()
	xp += int(economy["xp_per_month"])
	var worth := net_worth()
	net_worth_history.append(worth)
	_track_monthly_stats(worth)

	last_report = start_report.merged({
		"from_month": from_month,
		"to_month": month,
		"invest_change": invest_change,
		"interest": interest,
		"news": news,
		"delayed": delayed,
		"forced_sales": forced_sales,
		"warnings": warnings,
		"net_worth_before": net_worth_before,
		"net_worth_after": net_worth(),
		"cash_after": cash,
		"daily_worth": daily_worth,
		"start_prices": start_prices,
		"movers": _movers_since(start_prices),
		"targets": finished_targets,
		"trade_edge": trade["edge"],
		"turn_trades": trade["trades"],
		"turn_fees": trade["fees"],
		"dreams_progress": _dreams_progress(),
	})
	_queue_overdue_dreams()
	_snapshot_turn()
	changed.emit()
	if not _fast_forwarding:
		month_advanced.emit(last_report)
	_flush_dream_signals()
	if _check_end():
		return
	_check_goals()
	_check_unlocks(true)
	_roll_event()
	state_committed.emit()


## Kekayaan bersih per tanggal (1-30) selama bulan yang baru disimulasikan, diawali
## `start_value`. Dipakai animasi grafik di laporan bulanan. Kas & jumlah unit tidak
## berubah di tengah bulan, jadi cukup menilai ulang portofolio dengan harga harian.
## Gaji & biaya hidup bulan baru TIDAK ikut digambar, agar lonjakannya tidak menenggelamkan
## pergerakan pasar; angka kekayaan di laporan tetap nilai setelahnya.
func _daily_worth_series(start_value: float) -> Array[float]:
	var series: Array[float] = [start_value]
	for day in range(1, MarketAsset.DAYS_IN_MONTH + 1):
		var value := float(cash) + dream_funds()
		for asset_id: String in holdings:
			var asset := market.get_asset(asset_id)
			value += units_of(asset_id) * (asset.price if asset.is_interest() else asset.price_on_day(day))
		series.append(value)
	return series


func _current_prices() -> Dictionary:
	var prices := {}
	for asset: MarketAsset in market.assets.values():
		prices[asset.id] = asset.price
	return prices


## Aset dengan pergerakan terbesar sejak `start_prices`, untuk kartu sorotan laporan.
## Aset yang dimiliki didahulukan; aset yang belum terbuka dilewati.
## -> [{"id": "BSNT", "name_key": ..., "change": 0.062, "owned": true}, ...]
func _movers_since(start_prices: Dictionary) -> Array:
	var candidates: Array = []
	for asset: MarketAsset in market.assets.values():
		if asset.is_interest() or not start_prices.has(asset.id):
			continue
		var owned := units_of(asset.id) > 0.0
		if not owned and not is_asset_unlocked(asset.id):
			continue
		candidates.append({"id": asset.id, "name_key": asset.name_key, "owned": owned,
			"change": asset.price / float(start_prices[asset.id]) - 1.0})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["owned"] != b["owned"]:
			return a["owned"]
		return absf(a["change"]) > absf(b["change"]))
	return candidates.slice(0, MOVERS_SHOWN)


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
	stats["total_interest"] += total
	return total


## Awal bulan: gaji masuk (kecuali sedang menganggur), biaya hidup terpotong,
## kesehatan & kebahagiaan berubah. Freelancer: penghasilan naik-turun tiap bulan.
func _start_month() -> Dictionary:
	var food := food_option()
	var housing := housing_option()
	var health_before := health
	var happiness_before := happiness

	var paid := salary
	var volatility := float(background["income_volatility"])
	if volatility > 0.0:
		paid = roundi(salary * (1.0 + rng.randf_range(-volatility, volatility)) / 1000.0) * 1000
	if unemployed_months > 0:
		paid = 0
		unemployed_months -= 1

	energy_capacity = energy_max()
	energy = energy_capacity
	activity_counts.clear()

	var food_cost := option_cost(food)
	var housing_cost := option_cost(housing)
	cash += paid - food_cost - housing_cost
	month_income = paid
	stats["total_salary"] += paid
	stats["total_living"] += food_cost + housing_cost
	if food_id == "luxury" or housing_id == "apartment":
		stats["luxury_months"] += 1
	health = clampi(health + int(food["health"]) + int(housing["health"]), 0, 100)
	happiness = clampi(happiness + int(food["happiness"]) + int(housing["happiness"]), 0, 100)
	# Rencana gaji baru berjalan setelah pemain menyimpannya pertama kali (lihat set_plan).
	var budget := _apply_budget(paid) if plan.get("confirmed", false) else {}
	_check_dreams()
	targets = _new_targets()

	return {
		"salary": paid,
		"unemployed": paid == 0,
		"food_cost": food_cost,
		"housing_cost": housing_cost,
		"health_delta": health - health_before,
		"happiness_delta": happiness - happiness_before,
	}.merged(budget)


## Biaya sebuah pilihan makan/tempat tinggal setelah dikali pengali tingkat kesulitan.
func option_cost(option: Dictionary) -> int:
	return roundi(option["cost"] * difficulty["expense_mult"] / 1000.0) * 1000


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
		"tutorial":
			current = 1.0 if tutorial_done else 0.0
			target = 1.0
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
				_emit_later(stage_unlocked, def)
	if any:
		changed.emit()


# --- Event hidup --------------------------------------------------------------

func has_pending_event() -> bool:
	return not pending_event.is_empty()


func _roll_event() -> void:
	var event := events.pick_guaranteed(self)
	var chance := float(difficulty["event_chance"])
	if _fast_forwarding:
		chance *= float(economy.get("fast_forward_event_mult", 1.0))  # lompat waktu tetap bermakna
	if event.is_empty() and rng.randf() < chance:
		event = events.pick_random(self, rng, float(difficulty["bad_event_mult"]))
	if event.is_empty():
		return
	events.mark_shown(event, month)
	pending_event = event
	changed.emit()
	_emit_later(event_triggered, event)


## Pilihan dengan biaya di muka hanya bisa dipilih jika kas cukup.
## Pilihan gratis selalu bisa dipilih, termasuk saat kas minus, agar game tidak macet.
func can_choose(choice: Dictionary) -> bool:
	var cost := int(choice.get("cost", 0))
	return cost == 0 or cost <= cash


## Menjalankan pilihan pemain. Mengembalikan { "result": teks, "changes": perubahan }.
func resolve_event(choice_index: int) -> Dictionary:
	var event := pending_event
	var choice: Dictionary = event["choices"][choice_index]
	var before := _snapshot()
	var had_unaffordable := false
	for c: Dictionary in event["choices"]:
		if not can_choose(c):
			had_unaffordable = true
	cash -= int(choice.get("cost", 0))
	var outcome := choice
	if choice.has("outcomes"):
		outcome = _pick_outcome(choice["outcomes"])
	_apply_effects(outcome.get("effects", {}))
	pending_event = {}
	var result := {"result": outcome.get("result", ""), "changes": _diff(before)}
	var cash_change: float = result["changes"].get("cash", 0.0)
	stats["events"] += 1
	if had_unaffordable:
		stats["unaffordable_choices"] += 1
	if event["category"] == "scam" and cash_change < 0:
		stats["scam_loss"] += -cash_change
	_record_extreme("best_event", "worst_event", cash_change, {"title": event["title"]})
	changed.emit()
	_check_unlocks(true)
	state_committed.emit()
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
		stats["panic_sell"] = true
		for asset_id: String in holdings.keys():
			sell(asset_id, ceili(holding_value(asset_id)), "panic")


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
	player_changed.emit()
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
	player_changed.emit()


## Mengembalikan { "correct": bool, "reward": int, "xp": int }
func answer_quiz(question: Dictionary, option_index: int) -> Dictionary:
	var cfg: Dictionary = economy["quiz"]
	var is_correct := quiz.answer(question, option_index)
	var reward := int(cfg["reward_correct"]) if is_correct else 0
	var gained := int(cfg["xp_correct"]) if is_correct else int(cfg["xp_wrong"])
	cash += reward
	xp += gained
	if is_correct:
		_progress_target("quiz", 1.0)
	changed.emit()
	player_changed.emit()
	_check_unlocks(true)
	return {"correct": is_correct, "reward": reward, "xp": gained}


# --- Biaya hidup --------------------------------------------------------------

func food_option() -> Dictionary:
	return _find_option(economy["food"], food_id)


func housing_option() -> Dictionary:
	return _find_option(economy["housing"], housing_id)


func monthly_expenses() -> int:
	return option_cost(food_option()) + option_cost(housing_option())


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
	return cash + investments_value() + dream_funds()


## Beli aset senilai `amount` Rupiah (sudah termasuk fee).
## Mengembalikan { ok, error, units, fee } supaya UI bisa menampilkan pesan.
## `kind`: buy (manual) | auto (autodebet dari rencana gaji).
func buy(asset_id: String, amount: int, kind: String = "buy") -> Dictionary:
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
	stats["total_fees"] += fee
	_log_transaction(kind, asset, amount, units, fee, 0.0)
	if kind == "buy":  # autodebet tidak dihitung sebagai transaksi manual
		turn_fees += fee
		turn_trades += 1
		_progress_target("invest", amount)

	changed.emit()
	return {"ok": true, "units": units, "fee": fee}


## Jual aset senilai `amount` Rupiah (berdasarkan harga pasar sebelum fee).
## `kind`: sell (manual) | forced (jual paksa saat kas minus) | panic (event panik jual).
func sell(asset_id: String, amount: int, kind: String = "sell") -> Dictionary:
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
	var cost_sold: float = h["cost"] * (units / held)
	h["cost"] -= cost_sold  # kurangi modal secara proporsional
	h["units"] -= units
	if h["units"] <= 0.0:
		holdings.erase(asset_id)
	cash += proceeds
	stats["total_fees"] += fee
	_record_extreme("best_trade", "worst_trade", proceeds - cost_sold, {"asset_key": asset.name_key})
	_log_transaction(kind, asset, proceeds, units, fee, proceeds - cost_sold)
	if kind in ["sell", "panic"]:
		turn_fees += fee
		turn_trades += 1
		if proceeds - cost_sold < 0.0:
			_fail_target("no_loss")

	changed.emit()
	return {"ok": true, "units": units, "fee": fee, "proceeds": proceeds, "penalty": penalty}


## Deposito yang belum jatuh tempo kena penalti jika dicairkan.
func is_locked(asset_id: String) -> bool:
	return holdings.get(asset_id, {}).get("locked_until", 0) > month


func locked_until(asset_id: String) -> int:
	return holdings.get(asset_id, {}).get("locked_until", 0)


# --- Tutorial & petunjuk (data global pemain) ----------------------------------

func mark_tutorial_done() -> void:
	tutorial_done = true
	player_changed.emit()
	if is_active:
		_check_unlocks(true)
		changed.emit()


## Mengembalikan true jika petunjuk ini BARU pertama kali dilihat.
func consume_hint(key: String) -> bool:
	if key in hints_seen:
		return false
	hints_seen.append(key)
	player_changed.emit()
	return true


func player_to_dict() -> Dictionary:
	return {"version": PLAYER_VERSION, "quiz": quiz.to_dict(),
		"tutorial_done": tutorial_done, "hints_seen": hints_seen, "history": history}


func player_from_dict(d: Dictionary) -> void:
	quiz.from_dict(d.get("quiz", {}))
	tutorial_done = d.get("tutorial_done", false)
	hints_seen.assign(d.get("hints_seen", []))
	history.assign(d.get("history", []))


# --- Simpan / muat (format JSON, lihat SaveManager) ----------------------------

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"profile": {"name": player_name, "avatar": avatar,
			"background": background["id"], "difficulty": difficulty["id"]},
		"month": month, "cash": cash, "salary": salary, "health": health,
		"happiness": happiness, "xp": xp, "unemployed_months": unemployed_months,
		"food_id": food_id, "housing_id": housing_id,
		"holdings": holdings, "unlocked_stages": unlocked_stages,
		"net_worth_history": net_worth_history, "last_report": last_report,
		"pending_event_id": pending_event.get("id", ""),
		"delayed_effects": delayed_effects,
		"events": events.to_dict(),
		"rng_seed": str(rng.seed), "rng_state": str(rng.state),
		"market": market.to_dict(),
		"stats": stats,
		"danger": [negative_cash_months, zero_health_months, zero_happiness_months],
		"goals_reached": goals_reached,
		"energy": energy, "energy_capacity": energy_capacity, "activity_counts": activity_counts,
		"transactions": transactions, "risk_profile": risk_profile_id,
		"plan": plan, "plan_applied_month": plan_applied_month, "month_income": month_income,
		"dreams": dreams, "dreams_asked": dreams_asked, "targets": targets,
		"turn_units": turn_units, "turn_fees": turn_fees, "turn_trades": turn_trades,
	}


## JSON mengubah semua angka menjadi float, jadi field int dikonversi ulang dengan int().
## Mengembalikan false jika data tidak valid / versinya tidak dikenal.
func load_from_dict(d: Dictionary) -> bool:
	if int(d.get("version", 0)) != SAVE_VERSION:
		push_warning("Versi save tidak dikenal: %s" % d.get("version"))
		return false
	var profile: Dictionary = d["profile"]
	player_name = profile["name"]
	avatar = int(profile["avatar"])
	background = _find_option(economy["backgrounds"], profile["background"])
	difficulty = _find_option(economy["difficulties"], profile["difficulty"])

	month = int(d["month"])
	cash = int(d["cash"])
	salary = int(d["salary"])
	health = int(d["health"])
	happiness = int(d["happiness"])
	xp = int(d["xp"])
	unemployed_months = int(d["unemployed_months"])
	food_id = d["food_id"]
	housing_id = d["housing_id"]
	holdings.clear()
	for asset_id: String in d["holdings"]:
		var h: Dictionary = d["holdings"][asset_id]
		holdings[asset_id] = {"units": float(h["units"]), "cost": float(h["cost"]),
			"locked_until": int(h.get("locked_until", 0))}
	unlocked_stages.clear()
	for stage in d["unlocked_stages"]:
		unlocked_stages.append(int(stage))
	net_worth_history.assign(d["net_worth_history"])
	last_report = d["last_report"]

	events.setup(DataLoader.load_json(EVENTS_PATH).get("events", []))
	events.from_dict(d["events"])
	pending_event = events.find(d["pending_event_id"]) if d["pending_event_id"] != "" else {}
	delayed_effects.clear()
	for effect: Dictionary in d["delayed_effects"]:
		effect["due"] = int(effect["due"])
		delayed_effects.append(effect)
	rng.seed = String(d["rng_seed"]).to_int()
	rng.state = String(d["rng_state"]).to_int()
	stats = _new_stats().merged(d.get("stats", {}), true)  # save lama (M5) belum punya stats
	var danger: Array = d.get("danger", [0, 0, 0])
	negative_cash_months = int(danger[0])
	zero_health_months = int(danger[1])
	zero_happiness_months = int(danger[2])
	goals_reached.assign(d.get("goals_reached", []))
	energy_capacity = int(d.get("energy_capacity", energy_max()))
	energy = int(d.get("energy", energy_capacity))
	activity_counts.clear()
	for id: String in d.get("activity_counts", {}):
		activity_counts[id] = int(d["activity_counts"][id])
	transactions.clear()
	for t: Dictionary in d.get("transactions", []):
		t["month"] = int(t["month"])
		transactions.append(t)
	risk_profile_id = d.get("risk_profile", "moderate")
	plan = default_plan().merged(d.get("plan", {}), true)
	plan["salary_seen"] = int(plan["salary_seen"])
	plan_applied_month = int(d.get("plan_applied_month", -1))
	month_income = int(d.get("month_income", salary))
	dreams.clear()
	for entry: Dictionary in d.get("dreams", []):
		for key: String in ["start_month", "deadline", "achieved_month"]:
			entry[key] = int(entry.get(key, -1))
		entry["saved"] = float(entry["saved"])
		dreams.append(entry)
	dreams_asked = d.get("dreams_asked", false)
	targets.clear()
	for t: Dictionary in d.get("targets", []):
		targets.append(t)
	turn_units = d.get("turn_units", {})
	turn_fees = float(d.get("turn_fees", 0.0))
	turn_trades = int(d.get("turn_trades", 0))
	_dream_signals.clear()
	is_over = false
	end_result = {}

	market = Market.new()
	market.load_state(
		DataLoader.load_json(ASSETS_PATH).get("assets", []),
		DataLoader.load_json(MARKET_PATH),
		DataLoader.load_json(NEWS_PATH).get("news", []),
		d["market"])
	is_active = true
	changed.emit()
	return true


# --- Kondisi menang/kalah & statistik (M6, GDD 5.11) ---------------------------

func _new_stats() -> Dictionary:
	return {
		"total_salary": 0, "total_living": 0, "total_interest": 0.0, "total_fees": 0.0,
		"peak_net_worth": 0.0, "events": 0, "scam_loss": 0, "forced_sales": 0,
		"unaffordable_choices": 0, "luxury_months": 0, "cash_heavy_months": 0,
		"panic_sell": false, "total_lifestyle": 0, "total_autodebet": 0, "dreams_achieved": 0,
		"targets_done": 0,
		"best_trade": {}, "worst_trade": {}, "best_event": {}, "worst_event": {},
	}


## Simpan nilai terbaik/terburuk (mis. transaksi paling untung & paling rugi).
func _record_extreme(best_key: String, worst_key: String, value: float, info: Dictionary) -> void:
	var record := info.merged({"value": value, "month": month})
	if value > 0 and (stats[best_key].is_empty() or value > stats[best_key]["value"]):
		stats[best_key] = record
	elif value < 0 and (stats[worst_key].is_empty() or value < stats[worst_key]["value"]):
		stats[worst_key] = record


func _track_monthly_stats(worth: float) -> void:
	stats["peak_net_worth"] = maxf(stats["peak_net_worth"], worth)
	if worth > 10_000_000 and cash / worth > 0.7:
		stats["cash_heavy_months"] += 1


## Kas minus di awal bulan: aset dijual paksa, mulai dari risiko paling rendah
## (GDD 5.8: "pemain terpaksa menjual aset, mungkin saat rugi").
func _cover_negative_cash() -> Array[Dictionary]:
	var sales: Array[Dictionary] = []
	if cash >= 0:
		return sales
	var ids: Array = holdings.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return market.get_asset(a).risk < market.get_asset(b).risk)
	for asset_id: String in ids:
		if cash >= 0:
			break
		var asset := market.get_asset(asset_id)
		var fee_rate := asset.sell_fee + (asset.early_penalty if is_locked(asset_id) else 0.0)
		var needed := ceili(-cash / (1.0 - fee_rate)) + 1000
		var result := sell(asset_id, mini(needed, ceili(holding_value(asset_id))), "forced")
		if result["ok"]:
			sales.append({"asset_key": asset.name_key, "proceeds": result["proceeds"]})
	for entry: Dictionary in active_dreams():  # terakhir: dana pos impian terpaksa dipakai
		if cash >= 0:
			break
		var taken := minf(float(entry["saved"]), -cash)
		if taken <= 0.0:
			continue
		entry["saved"] -= taken
		cash += roundi(taken)
		sales.append({"asset_key": dream_def(entry["id"])["name"], "proceeds": roundi(taken)})
	stats["forced_sales"] += sales.size()
	return sales


## Hitung bulan berturut-turut dalam kondisi bahaya. Mengembalikan teks peringatan untuk laporan.
func _update_danger_counters() -> Array[String]:
	var limit := int(economy["end"]["danger_months"])
	negative_cash_months = negative_cash_months + 1 if cash < 0 else 0
	zero_health_months = zero_health_months + 1 if health <= 0 else 0
	zero_happiness_months = zero_happiness_months + 1 if happiness <= 0 else 0
	var warnings: Array[String] = []
	if negative_cash_months > 0:
		warnings.append(tr("WARN_BANKRUPT") % [negative_cash_months, limit])
	if zero_health_months > 0:
		warnings.append(tr("WARN_HEALTH") % [zero_health_months, limit])
	if zero_happiness_months > 0:
		warnings.append(tr("WARN_HAPPINESS") % [zero_happiness_months, limit])
	return warnings


func _check_end() -> bool:
	var limit := int(economy["end"]["danger_months"])
	if negative_cash_months >= limit:
		finish_game("lose", "bankrupt")
	elif zero_health_months >= limit:
		finish_game("lose", "health")
	elif zero_happiness_months >= limit:
		finish_game("lose", "happiness")
	elif age() >= int(economy["end"]["retirement_age"]):
		finish_game("retired", "retired")
	return is_over


func _check_goals() -> void:
	if net_worth() >= float(economy["end"]["win_net_worth"]) and not "millionaire" in goals_reached:
		goals_reached.append("millionaire")
		_emit_later(goal_reached, "millionaire")
	if is_financially_free() and not "freedom" in goals_reached:
		goals_reached.append("freedom")
		_emit_later(goal_reached, "freedom")


## Aturan 4%: investasi bisa "menggaji" pemain sebesar 4% per tahun tanpa habis.
func passive_income() -> float:
	return investments_value() * float(economy["end"]["freedom_rate"]) / 12.0


func is_financially_free() -> bool:
	return investments_value() > 0 and passive_income() >= monthly_expenses()


## Skor warisan: kekayaan (per Rp1 juta) + kesehatan + kebahagiaan + level x 10.
func legacy_score() -> int:
	return floori(net_worth() / 1_000_000.0) + health + happiness + level() * 10


## Mengakhiri permainan. `result_type`: win | lose | retired.
func finish_game(result_type: String, reason: String) -> void:
	is_over = true
	pending_event = {}
	end_result = {
		"type": result_type, "reason": reason, "month": month, "age": age(),
		"net_worth": net_worth(), "peak": stats["peak_net_worth"], "score": legacy_score(),
	}
	history.push_front({
		"name": player_name, "avatar": avatar, "background": background["id"],
		"difficulty": difficulty["id"], "type": result_type, "reason": reason,
		"months": month, "net_worth": net_worth(), "date": int(Time.get_unix_time_from_system()),
	})
	history.resize(mini(history.size(), 10))
	player_changed.emit()
	changed.emit()
	_emit_later(game_ended, end_result)


# --- Energi & aktivitas bulanan (M6.5, GDD 4.2) --------------------------------

func energy_max() -> int:
	var value := int(activity_data.get("base_energy", 3))
	if health >= int(activity_data.get("health_bonus_at", 70)):
		value += 1
	if health < int(activity_data.get("health_penalty_below", 30)):
		value -= 1
	return maxi(value, 1)


func activity_defs() -> Array:
	return activity_data.get("activities", [])


## "" jika aktivitas bisa dilakukan, atau key pesan error.
func activity_block_reason(def: Dictionary) -> String:
	if is_over or has_pending_event():
		return "ERR_ACTIVITY_BUSY"
	if energy < int(def["energy"]):
		return "ERR_NO_ENERGY"
	if activity_counts.get(def["id"], 0) >= int(def.get("max_per_month", 1)):
		return "ERR_ACTIVITY_LIMIT"
	if int(def.get("cost", 0)) > cash:
		return "ERR_NOT_ENOUGH_CASH"
	return ""


## Mengembalikan { "ok", "error", "changes" }.
func do_activity(activity_id: String) -> Dictionary:
	var def: Dictionary = {}
	for d: Dictionary in activity_defs():
		if d["id"] == activity_id:
			def = d
	var reason := activity_block_reason(def)
	if reason != "":
		return {"ok": false, "error": reason}
	var before := _snapshot()
	energy -= int(def["energy"])
	activity_counts[activity_id] = activity_counts.get(activity_id, 0) + 1
	cash -= int(def.get("cost", 0))
	_apply_effects(def["effects"])
	stats["activities"] = stats.get("activities", 0) + 1
	_progress_target("activity", 1.0, activity_id)
	changed.emit()
	_check_unlocks(true)
	return {"ok": true, "changes": _diff(before)}


# --- Lompat waktu (M6.5) ---------------------------------------------------------

## Maju beberapa bulan sekaligus. Berhenti lebih awal jika ada event, peringatan,
## penjualan paksa, instrumen baru, target tercapai, atau game berakhir.
## Laporan bulanan digabung menjadi satu; signal lain ditunda agar popup tampil
## SETELAH laporan gabungan (urutan sama seperti saat maju satu bulan).
func fast_forward(months: int) -> void:
	if has_pending_event() or is_over:
		return
	_fast_forwarding = true
	var reports: Array[Dictionary] = []
	for i in months:
		var goals_before := goals_reached.size()
		var stages_before := unlocked_stages.size()
		advance_month()
		reports.append(last_report)
		var interrupted: bool = is_over or has_pending_event() \
				or goals_reached.size() != goals_before or unlocked_stages.size() != stages_before \
				or not last_report["warnings"].is_empty() or not last_report["forced_sales"].is_empty()
		if interrupted:
			break
	_fast_forwarding = false
	last_report = _merge_reports(reports)
	month_advanced.emit(last_report)
	var pending := _deferred.duplicate()
	_deferred.clear()
	for emit_later: Callable in pending:
		emit_later.call()


func _emit_later(sig: Signal, arg: Variant) -> void:
	if _fast_forwarding:
		_deferred.append(func() -> void: sig.emit(arg))
	else:
		sig.emit(arg)


func _merge_reports(reports: Array[Dictionary]) -> Dictionary:
	var merged: Dictionary = reports[-1].duplicate(true)
	if reports.size() == 1:
		return merged
	for key: String in ["salary", "food_cost", "housing_cost", "invest_change", "interest",
			"health_delta", "happiness_delta", "lifestyle_cost", "emergency_saved"]:
		var total := 0.0
		for r: Dictionary in reports:
			total += float(r.get(key, 0))
		merged[key] = total
	var news: Array = []
	var delayed: Array = []
	var forced: Array = []
	for r: Dictionary in reports:
		news.append_array(r.get("news", []))
		delayed.append_array(r.get("delayed", []))
		forced.append_array(r.get("forced_sales", []))
	merged["news"] = news.slice(-5)  # cukup 5 berita terakhir agar laporan tidak terlalu panjang
	merged["delayed"] = delayed
	merged["forced_sales"] = forced
	merged["from_month"] = reports[0]["from_month"]
	merged["net_worth_before"] = reports[0]["net_worth_before"]
	merged["unemployed"] = merged["salary"] == 0
	merged["months"] = reports.size()
	var daily: Array = reports[0].get("daily_worth", []).duplicate()
	for r: Dictionary in reports.slice(1):
		daily.append_array(r.get("daily_worth", []).slice(1))  # titik awal = titik akhir bulan sebelumnya
	merged["daily_worth"] = daily
	merged["start_prices"] = reports[0]["start_prices"]
	merged["movers"] = _movers_since(reports[0]["start_prices"])
	return merged


# --- Riwayat transaksi (M6.5) ----------------------------------------------------

## `kind`: buy | sell | forced | panic. `pnl` = untung/rugi terealisasi (khusus jual).
func _log_transaction(kind: String, asset: MarketAsset, amount: float, units: float,
		fee: float, pnl: float) -> void:
	transactions.push_front({"month": month, "kind": kind, "asset_key": asset.name_key,
		"amount": amount, "units": units, "fee": fee, "pnl": pnl})
	if transactions.size() > MAX_TRANSACTIONS:
		transactions.resize(MAX_TRANSACTIONS)


# --- Rencana gaji & autodebet (v1.5-0 langkah 2) ----------------------------------

func budget_config() -> Dictionary:
	return economy["budget"]


func default_plan() -> Dictionary:
	var cfg := budget_config()
	return {"lifestyle": float(cfg["default_lifestyle"]), "emergency": float(cfg["default_emergency"]),
		"invest": {}, "dreams": {}, "salary_seen": salary, "confirmed": false}


## Rencana perlu dicek pemain: belum pernah disimpan, atau gaji pokok berubah sejak terakhir dicek.
func plan_needs_review() -> bool:
	return not plan.get("confirmed", false) or int(plan.get("salary_seen", 0)) != salary


## Menyimpan rencana dari popup. Saat pertama kali disimpan, rencana langsung dijalankan
## untuk bulan ini (gaji bulan ini sudah masuk). Mengembalikan ringkasan yang dijalankan ({} jika tidak).
func set_plan(new_plan: Dictionary) -> Dictionary:
	var first: bool = not plan.get("confirmed", false)
	plan = new_plan.duplicate(true)
	plan["confirmed"] = true
	plan["salary_seen"] = salary
	var applied := {}
	if first and plan_applied_month != month:
		applied = _apply_budget(month_income)
		_check_dreams()
		_snapshot_turn()  # autodebet pertama bukan transaksi manual
	changed.emit()
	state_committed.emit()
	_flush_dream_signals()
	return applied


## Popup rencana ditutup tanpa disimpan: perubahan gaji dianggap sudah dilihat.
func acknowledge_plan_review() -> void:
	plan["salary_seen"] = salary


## Aset yang bisa diikutkan autodebet: sudah terbuka dan bukan tabungan/deposito.
func autodebet_assets() -> Array[MarketAsset]:
	var result: Array[MarketAsset] = []
	for asset: MarketAsset in market.assets.values():
		if not asset.is_interest() and is_asset_unlocked(asset.id):
			result.append(asset)
	return result


func emergency_asset_id() -> String:
	return budget_config()["emergency_asset"]


func emergency_balance() -> float:
	return holding_value(emergency_asset_id())


## Target dana darurat: N x pengeluaran pokok bulanan (makan + tempat tinggal).
func emergency_target() -> float:
	return float(monthly_expenses() * int(budget_config()["emergency_target_months"]))


## Efek kebahagiaan per bulan dari porsi gaya hidup (lihat economy.json budget.lifestyle_happiness).
func lifestyle_happiness(share: float) -> int:
	var effect := 0
	for row: Array in budget_config()["lifestyle_happiness"]:
		if share + 0.0001 >= float(row[0]):
			effect = int(row[1])
	return effect


## Rincian rupiah sebuah rencana untuk penghasilan `income`. Satu sumber hitungan untuk
## popup rencana, kartu Beranda, dan eksekusi di awal bulan.
func plan_preview(p: Dictionary, income: int) -> Dictionary:
	var basic := monthly_expenses()
	var lifestyle := _round_thousand(income * float(p["lifestyle"]))
	var room := maxf(0.0, emergency_target() - emergency_balance())
	var emergency := mini(_round_thousand(income * float(p["emergency"])), _round_thousand(room))
	var invest: Array[Dictionary] = []
	var invest_total := 0
	for asset: MarketAsset in autodebet_assets():
		var share := float(p["invest"].get(asset.id, 0.0))
		if share <= 0.0:
			continue
		var amount := _round_thousand(income * share)
		invest.append({"id": asset.id, "name_key": asset.name_key, "share": share, "amount": amount})
		invest_total += amount
	var dream_items: Array[Dictionary] = []
	var dreams_total := 0
	for entry: Dictionary in active_dreams():
		var share := float(p.get("dreams", {}).get(entry["id"], 0.0))
		if share <= 0.0:
			continue
		var needed := ceili(maxf(0.0, dream_def(entry["id"])["cost"] - entry["saved"]) / 1000.0) * 1000
		var amount := mini(_round_thousand(income * share), needed)  # jangan menabung melebihi biayanya
		dream_items.append({"id": entry["id"], "name": dream_def(entry["id"])["name"], "share": share, "amount": amount})
		dreams_total += amount
	return {"income": income, "basic": basic, "lifestyle": lifestyle, "emergency": emergency,
		"emergency_room": room, "invest": invest, "invest_total": invest_total,
		"dreams": dream_items, "dreams_total": dreams_total,
		"surplus": income - basic - lifestyle - emergency - invest_total - dreams_total}


## Menjalankan rencana setelah gaji masuk: belanja gaya hidup, setor dana darurat, lalu
## autodebet. Pos yang kasnya tidak cukup dilewati dan dicatat di laporan.
func _apply_budget(income: int) -> Dictionary:
	var result := {"lifestyle_cost": 0, "emergency_saved": 0, "autodebet": [], "autodebet_skipped": [],
		"dream_saved": []}
	plan_applied_month = month
	if income <= 0:
		return result  # menganggur: tidak ada gaji untuk dibagi
	var preview := plan_preview(plan, income)

	var lifestyle := mini(int(preview["lifestyle"]), maxi(cash, 0))
	cash -= lifestyle
	stats["total_lifestyle"] += lifestyle
	happiness = clampi(happiness + lifestyle_happiness(float(lifestyle) / income), 0, 100)
	result["lifestyle_cost"] = lifestyle

	var emergency: int = preview["emergency"]
	if emergency >= 1000 and emergency <= cash:
		if buy(emergency_asset_id(), emergency, "auto")["ok"]:
			result["emergency_saved"] = emergency

	for item: Dictionary in preview["dreams"]:  # pos impian sebelum autodebet
		var saved: int = item["amount"]
		if saved >= 1000 and saved <= cash:
			cash -= saved
			_find_dream(item["id"])["saved"] += saved
			result["dream_saved"].append({"name": item["name"], "amount": saved})
		elif saved >= 1000:
			result["autodebet_skipped"].append(item["name"])

	for item: Dictionary in preview["invest"]:
		var amount: int = item["amount"]
		if amount >= 1000 and amount <= cash and buy(item["id"], amount, "auto")["ok"]:
			stats["total_autodebet"] += amount
			result["autodebet"].append({"asset_key": item["name_key"], "amount": amount})
		else:
			result["autodebet_skipped"].append(item["name_key"])
	return result


func _round_thousand(value: float) -> int:
	return maxi(0, floori(value / 1000.0) * 1000)


# --- Impian (v1.5-0 langkah 3) -----------------------------------------------------

func dreams_config() -> Dictionary:
	return economy["dreams"]


func dream_def(id: String) -> Dictionary:
	for def: Dictionary in dream_defs:
		if def["id"] == id:
			return def
	return {}


func active_dreams() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in dreams:
		if entry["status"] == "active":
			result.append(entry)
	return result


func dream_funds() -> float:
	var total := 0.0
	for entry: Dictionary in active_dreams():
		total += float(entry["saved"])
	return total


func can_add_dream() -> bool:
	return active_dreams().size() < int(dreams_config()["max_active"])


## Impian yang bisa dipilih: belum dipilih/terwujud, dan usia sudah cukup.
func available_dreams() -> Array:
	var taken := {}
	for entry: Dictionary in dreams:
		if entry["status"] != "released":
			taken[entry["id"]] = true
	return dream_defs.filter(func(def: Dictionary) -> bool:
		return not taken.has(def["id"]) and age() >= int(def.get("min_age", 0)))


## Setoran per bulan yang dibutuhkan agar impian tercapai tepat waktu.
func dream_needed_monthly(entry: Dictionary) -> int:
	var left := maxf(0.0, dream_def(entry["id"])["cost"] - entry["saved"])
	var months_left := maxi(1, int(entry["deadline"]) - month)
	return ceili(left / months_left / 1000.0) * 1000


## Porsi gaji yang disarankan saat impian dipilih (dibulatkan ke atas per langkah, dibatasi share_cap).
func suggested_dream_share(entry: Dictionary) -> float:
	var step := float(budget_config()["step"])
	var share := ceilf(dream_needed_monthly(entry) / float(maxi(salary, 1)) / step) * step
	return clampf(share, step, float(dreams_config()["share_cap"]))


func pick_dreams(ids: Array) -> void:
	for id: String in ids:
		if not can_add_dream() or dream_def(id).is_empty():
			break
		var def := dream_def(id)
		var entry := {"id": id, "saved": 0.0, "start_month": month, "deadline": month + int(def["months"]),
			"status": "active", "achieved_month": -1}
		dreams.append(entry)
		# Porsi saran dibatasi sisa gaji di rencana saat ini, agar rencana tidak melebihi gaji.
		var step := float(budget_config()["step"])
		var surplus := maxf(0.0, float(plan_preview(plan, salary)["surplus"]))
		var room := floorf(surplus / maxf(1.0, salary) / step + 0.0001) * step
		plan["dreams"][id] = minf(suggested_dream_share(entry), room)
	dreams_asked = true
	changed.emit()
	state_committed.emit()


func mark_dreams_asked() -> void:
	dreams_asked = true
	state_committed.emit()


## Setoran manual ke pos impian.
func deposit_dream(id: String, amount: int) -> bool:
	var entry := _find_dream(id)
	if entry.is_empty() or entry["status"] != "active" or amount <= 0 or amount > cash:
		return false
	var left := ceili(maxf(0.0, dream_def(id)["cost"] - entry["saved"]))
	amount = mini(amount, left)
	cash -= amount
	entry["saved"] += amount
	_progress_target("dream_deposit", amount)
	_check_dreams()
	changed.emit()
	state_committed.emit()
	_flush_dream_signals()
	return true


## Melepas impian: dana kembali ke kas, kebahagiaan turun sedikit.
func release_dream(id: String) -> void:
	var entry := _find_dream(id)
	if entry.is_empty() or entry["status"] != "active":
		return
	cash += roundi(entry["saved"])
	entry["saved"] = 0.0
	entry["status"] = "released"
	plan["dreams"].erase(id)
	happiness = clampi(happiness + int(dreams_config()["release_happiness"]), 0, 100)
	changed.emit()
	state_committed.emit()


## Memperpanjang tenggat impian yang terlewat.
func extend_dream(id: String) -> void:
	var entry := _find_dream(id)
	if entry.is_empty() or entry["status"] != "active":
		return
	entry["deadline"] = month + int(dreams_config()["extend_months"])
	happiness = clampi(happiness + int(dreams_config()["extend_happiness"]), 0, 100)
	changed.emit()
	state_committed.emit()


## Impian aktif yang tenggatnya sudah lewat (menunggu keputusan pemain).
func overdue_dreams() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in active_dreams():
		if month > int(entry["deadline"]):
			result.append(entry)
	return result


## Data impian siap tampil: entri + definisi + persentase terkumpul.
func dream_view(entry: Dictionary) -> Dictionary:
	var def := dream_def(entry["id"])
	return entry.merged({"def": def, "ratio": clampf(entry["saved"] / float(def["cost"]), 0.0, 1.0)})


## Entri impian AKTIF dengan id tersebut ({} jika tidak ada / sudah terwujud / dilepas).
func active_dream(id: String) -> Dictionary:
	return _find_dream(id)


func _find_dream(id: String) -> Dictionary:
	for entry: Dictionary in dreams:
		if entry["id"] == id and entry["status"] == "active":
			return entry
	return {}


## Impian yang dananya sudah cukup langsung terwujud (dana dipakai, kelebihannya kembali ke kas).
func _check_dreams() -> void:
	for entry: Dictionary in active_dreams():
		var def := dream_def(entry["id"])
		if entry["saved"] + 0.5 < float(def["cost"]):
			continue
		cash += roundi(entry["saved"] - float(def["cost"]))
		entry["saved"] = float(def["cost"])
		entry["status"] = "achieved"
		entry["achieved_month"] = month
		plan["dreams"].erase(entry["id"])
		happiness = clampi(happiness + int(def["happiness"]), 0, 100)
		xp += int(def["xp"])
		stats["dreams_achieved"] += 1
		var view := dream_view(entry)
		_dream_signals.append(func() -> void: dream_achieved.emit(view))


func _queue_overdue_dreams() -> void:
	for entry: Dictionary in overdue_dreams():
		var view := dream_view(entry)
		_dream_signals.append(func() -> void: dream_overdue.emit(view))


## Sinyal impian dikirim SETELAH laporan bulanan, agar urutan popup: laporan -> perayaan.
func _flush_dream_signals() -> void:
	var pending := _dream_signals.duplicate()
	_dream_signals.clear()
	for send: Callable in pending:
		if _fast_forwarding:
			_deferred.append(send)
		else:
			send.call()


## Pos impian berbunga seperti tabungan (setelah pajak). Mengembalikan totalnya.
func _pay_dream_interest() -> float:
	var asset := market.get_asset(dreams_config()["interest_asset"])
	var rate := market.rate_for(asset) * (1.0 - asset.interest_tax) / 12.0
	var total := 0.0
	for entry: Dictionary in active_dreams():
		var gain: float = entry["saved"] * rate
		entry["saved"] += gain
		total += gain
	return total


func _dreams_progress() -> Array:
	var result: Array = []
	for entry: Dictionary in active_dreams():
		var view := dream_view(entry)
		result.append({"name": view["def"]["name"], "ratio": view["ratio"]})
	return result


# --- Target bulanan (v1.5-0 langkah 3) ------------------------------------------------

func targets_config() -> Dictionary:
	return economy["targets"]


## Memilih beberapa target ringan untuk bulan baru dari daftar yang masuk akal saat ini.
func _new_targets() -> Array[Dictionary]:
	var cfg := targets_config()
	var cap := int(cfg["stat_cap"])
	var bonus := int(cfg["stat_bonus"])
	var pool: Array[Dictionary] = [{"type": "invest", "goal": float(cfg["invest_amount"]), "param": ""}]
	var activities := activity_defs().filter(func(def: Dictionary) -> bool:
		return int(def["energy"]) <= energy_capacity)
	if not activities.is_empty():
		var def: Dictionary = activities[rng.randi() % activities.size()]
		pool.append({"type": "activity", "goal": 1.0, "param": def["id"]})
	pool.append({"type": "save", "goal": float(monthly_expenses() * int(cfg["save_months"])), "param": ""})
	if health < cap:
		pool.append({"type": "health", "goal": float(mini(cap, health + bonus)), "param": ""})
	if happiness < cap:
		pool.append({"type": "happiness", "goal": float(mini(cap, happiness + bonus)), "param": ""})
	if investments_value() > 0.0:
		pool.append({"type": "no_loss", "goal": 0.0, "param": ""})
	if quiz.free_left() > 0:
		pool.append({"type": "quiz", "goal": 1.0, "param": ""})
	if not active_dreams().is_empty():
		pool.append({"type": "dream_deposit", "goal": float(cfg["dream_deposit"]), "param": ""})
	var picked: Array[Dictionary] = []
	for i in mini(int(cfg["per_month"]), pool.size()):
		var target: Dictionary = pool.pop_at(rng.randi() % pool.size())
		target.merge({"progress": 0.0, "state": "open"})
		picked.append(target)
	return picked


func _progress_target(type: String, amount: float, param: String = "") -> void:
	for target: Dictionary in targets:
		if target["type"] != type or target["state"] != "open":
			continue
		if target["param"] != "" and target["param"] != param:
			continue
		target["progress"] += amount
		if target["progress"] >= target["goal"]:
			_complete_target(target, true)


func _fail_target(type: String) -> void:
	for target: Dictionary in targets:
		if target["type"] == type and target["state"] == "open":
			target["state"] = "failed"


func _complete_target(target: Dictionary, notify: bool) -> void:
	var cfg := targets_config()
	target["state"] = "done"
	happiness = clampi(happiness + int(cfg["reward_happiness"]), 0, 100)
	xp += int(cfg["reward_xp"])
	stats["targets_done"] += 1
	if notify:
		target_completed.emit(target)


## Akhir bulan: target yang dinilai dari kondisi akhir dicek; sisanya yang belum selesai gagal.
## Mengembalikan salinan untuk laporan bulanan.
func _finalize_targets() -> Array:
	for target: Dictionary in targets:
		if target["state"] != "open":
			continue
		var ok := false
		match target["type"]:
			"save":
				ok = cash >= target["goal"]
			"health":
				ok = health >= target["goal"]
			"happiness":
				ok = happiness >= target["goal"]
			"no_loss":
				ok = true
		if ok:
			_complete_target(target, false)
		else:
			target["state"] = "failed"
	return targets.duplicate(true)


# --- Pembanding "kalau tidak bertransaksi" ---------------------------------------------

## Mencatat portofolio di awal giliran, agar transaksi manual bulan ini bisa dibandingkan.
func _snapshot_turn() -> void:
	turn_units.clear()
	for asset_id: String in holdings:
		turn_units[asset_id] = units_of(asset_id)
	turn_fees = 0.0
	turn_trades = 0


## Selisih hasil transaksi manual bulan ini dibanding kalau portofolio awal giliran ditahan:
## (perubahan unit x pergerakan harga bulan ini) - fee. Transaksi terjadi di harga awal bulan.
func _turn_trade_result(start_prices: Dictionary) -> Dictionary:
	if turn_trades == 0:
		return {"edge": 0.0, "trades": 0, "fees": 0.0}
	var ids := turn_units.keys()
	for asset_id: String in holdings:
		if asset_id not in ids:
			ids.append(asset_id)
	var edge := -turn_fees
	for asset_id: String in ids:
		var asset := market.get_asset(asset_id)
		var delta := units_of(asset_id) - float(turn_units.get(asset_id, 0.0))
		edge += delta * (asset.price - float(start_prices.get(asset_id, asset.price)))
	return {"edge": edge, "trades": turn_trades, "fees": turn_fees}


# --- Profil risiko (M6.5, GDD 5.8) -------------------------------------------------

func risk_questions() -> Array:
	return risk_data.get("questions", [])


func risk_profiles() -> Array:
	return risk_data.get("profiles", [])


## Skor total kuesioner -> id profil (profil pertama dengan max_score >= skor).
func profile_from_score(score: int) -> String:
	for p: Dictionary in risk_profiles():
		if score <= int(p["max_score"]):
			return p["id"]
	return risk_profiles()[-1]["id"]


func risk_profile() -> Dictionary:
	return _find_option(risk_profiles(), risk_profile_id)


func set_risk_profile(id: String) -> void:
	risk_profile_id = id
	changed.emit()


## true jika risiko aset melebihi profil risiko pemain.
func exceeds_risk_profile(asset: MarketAsset) -> bool:
	return asset.risk > int(risk_profile()["max_asset_risk"])
