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
## Lamaran kerja diterima (v1.5b): `offers` = tawaran yang menunggu keputusan pemain.
signal job_offers_received(offers: Array)
## Karier berubah lewat event (v1.5b langkah 2): kind "promoted" / "laid_off"; `title` = jabatan (key teks).
signal career_changed(kind: String, title: String)
## Lulus kuliah (v1.5b langkah 3): nama program (key teks), pendidikan baru, tambahan keahlian.
signal graduated(program: String, result: String, skill_gain: int)
## Tenggat impian terlewat; pemain memilih memperpanjang atau melepas.
signal dream_overdue(dream: Dictionary)
## Target bulanan selesai di tengah bulan (untuk notifikasi singkat).
signal target_completed(target: Dictionary)

## Versi slot save. Naik ke 2 di v1.5 (pasar harian); save lama ditolak, tanpa migrasi.
const SAVE_VERSION := 3
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
const INSURANCE_PATH := "res://data/insurance.json"
const JOBS_PATH := "res://data/jobs.json"
const EDUCATION_PATH := "res://data/education.json"
const RISK_PROFILE_PATH := "res://data/risk_profile.json"
const MAX_TRANSACTIONS := 200
const MAX_CAREER_LOG := 60

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
var salary: int = 0                # gaji bruto pekerjaan sekarang (0 = belum bekerja)
var health: int = 0                # 0..100
var happiness: int = 0             # 0..100
var xp: int = 0
var unpaid_months: int = 0         # sisa bulan cuti tanpa gaji (mis. sakit kritis), pekerjaan tetap
## Pekerjaan & karier (v1.5b). job = {} jika belum/tidak bekerja; {"id", "company", "since", "hired"}
## (since = mulai menjabat posisi ini, hired = mulai bekerja di perusahaan ini).
var job: Dictionary = {}
var performance := 0.0                   # kinerja 0-100 di pekerjaan berjenjang (v1.5b langkah 2)
var education := 0                       # indeks jobs.json education_levels (0 = SMA)
var skill := 0.0                         # keahlian 0-100
var experience: Dictionary = {}          # bidang -> bulan bekerja
var job_board: Array[Dictionary] = []    # lowongan bulan ini: [{job_id, company, salary, applied}]
var applications: Array[Dictionary] = [] # lamaran bulan ini (hasilnya awal bulan depan)
var job_offers: Array[Dictionary] = []   # lamaran yang diterima, menunggu keputusan pemain
var job_data: Dictionary = {}            # isi data/jobs.json
## Kuliah yang sedang diambil (v1.5b langkah 3), {} jika tidak kuliah:
## {"id", "months_left", "months_total", "since", "scholarship", "sponsor", "paid_month"}.
var study: Dictionary = {}
var education_data: Dictionary = {}      # isi data/education.json
## Perjalanan karier (v1.5b langkah 4), terlama di depan: [{month, kind, job_id?, company?, program?}].
## kind: hired | promoted | laid_off | resigned | graduated | dropped_out.
var career_log: Array[Dictionary] = []
var story_seen: Array[String] = []        # cerita/petunjuk per permainan yang sudah tampil
var food_id: String = ""
var housing_id: String = ""
var holdings: Dictionary = {}      # asset_id -> { "units": float, "cost": float, "locked_until": int }
var unlocked_stages: Array[int] = []
var market := Market.new()
var net_worth_history: Array[float] = []
var last_report: Dictionary = {}

var events := EventManager.new()
var pending_event: Dictionary = {}           # event yang menunggu keputusan pemain
var pending_vars: Dictionary = {}            # isian teks event itu ({job}, {salary}, ...), lihat _event_vars
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
var transaction_seq := 0                     # nomor urut transaksi terakhir (kunci di database)
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
var turn_fees := 0.0                         # fee + pajak transaksi manual giliran ini
## Pajak & biaya sejak laporan terakhir (v1.5a langkah 2), ditampilkan di laporan bulanan.
var month_costs: Dictionary = {}             # {"trade_fee", "trade_tax", "interest_tax"}
var turn_trades := 0
## Event Director (v1.5-0 langkah 4)
var event_queue: Array[String] = []          # event bulan ini yang menunggu giliran (setelah pending_event)
var chain_events: Array[Dictionary] = []     # event lanjutan terjadwal: [{id, due}]
var director: Dictionary = {}                # {"quiet_months": int, "last_bad": bool}
var dream_defs: Array = []                   # isi data/dreams.json
var insurance_data: Dictionary = {}          # isi data/insurance.json
## Asuransi (v1.5a langkah 3): kategori -> {"id": id produk, "since": bulan polis dimulai}
var policies: Dictionary = {}
## Stop loss & take profit (v1.5a langkah 4): asset_id -> {"stop_loss": harga, "take_profit": harga}
## (0 = tidak dipakai). Dicek setiap hari saat pasar bergerak; lihat _execute_orders().
var orders: Dictionary = {}
var _report_signals: Array[Callable] = []    # impian & kelulusan, dikirim setelah laporan
var _fast_forwarding := false
## Naik setiap game baru / dimuat (tidak disimpan). SaveManager memakainya untuk tahu apakah
## slot di database masih "permainan yang sama" sehingga cukup ditulis bagian barunya saja.
var run_id := 0
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
	insurance_data = DataLoader.load_json(INSURANCE_PATH)
	job_data = DataLoader.load_json(JOBS_PATH)
	education_data = DataLoader.load_json(EDUCATION_PATH)


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
	transaction_seq = 0
	run_id += 1
	background = _find_option(economy["backgrounds"], profile.get("background", economy["default_background"]))
	difficulty = _find_option(economy["difficulties"], profile.get("difficulty", economy["default_difficulty"]))

	month = 0
	cash = int(difficulty["start_cash"])
	salary = 0  # v1.5b: mulai tanpa pekerjaan, harus melamar
	job = {}
	education = education_index(background["education"])
	skill = float(background["skill"])
	experience.clear()
	job_board.clear()
	applications.clear()
	job_offers.clear()
	performance = 0.0
	study = {}
	career_log.clear()
	story_seen.clear()
	health = int(economy["start_health"])
	happiness = int(economy["start_happiness"])
	xp = 0
	unpaid_months = 0
	food_id = background["default_food"]
	housing_id = background["default_housing"]
	plan = default_plan()
	plan_applied_month = -1
	dreams.clear()
	dreams_asked = false
	policies.clear()
	orders.clear()
	event_queue.clear()
	chain_events.clear()
	director = _new_director()
	targets.clear()
	_report_signals.clear()
	holdings.clear()
	unlocked_stages.clear()
	pending_event = {}
	pending_vars = {}
	delayed_effects.clear()
	stats = _new_stats()
	month_costs = _new_month_costs()
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
	var level_before := price_level()
	var idle_money := maxf(cash, 0.0) + units_of(emergency_asset_id()) + dream_funds()
	var interest := _pay_interest() + _pay_dream_interest()
	var news := market.step(month + 1)
	var month_inflation := price_level() / level_before - 1.0
	var trade := _turn_trade_result(start_prices)  # transaksi manual, sebelum pesanan otomatis
	var executed := _execute_orders()
	var sold_value := 0.0
	for sale: Dictionary in executed:
		sold_value += float(sale["units"]) * float(sale["price"])
	var invest_change := investments_value() + sold_value - invest_before
	var daily_worth := _daily_worth_series(net_worth_before, executed)

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
		"trade_fee": month_costs["trade_fee"],
		"trade_tax": month_costs["trade_tax"],
		"orders": executed,
		"interest_tax": month_costs["interest_tax"],
		"inflation_month": month_inflation,
		"inflation_year": market.inflation,
		"erosion": idle_money * month_inflation,
	})
	_queue_overdue_dreams()
	_snapshot_turn()
	month_costs = _new_month_costs()  # pajak & biaya sudah masuk laporan ini
	changed.emit()
	if not _fast_forwarding:
		month_advanced.emit(last_report)
	_flush_report_signals()
	# Tawaran pekerjaan berjenjang didahului event wawancara (lihat _career_events).
	if not job_offers.is_empty() and _interview_offer_index() < 0 and not _fast_forwarding:
		job_offers_received.emit(job_offers)
	if _check_end():
		return
	_check_goals()
	_check_unlocks(true)
	_roll_events()
	state_committed.emit()


## Kekayaan bersih per tanggal (1-30) selama bulan yang baru disimulasikan, diawali
## `start_value`. Dipakai animasi grafik di laporan bulanan. Kas & jumlah unit tidak
## berubah di tengah bulan, jadi cukup menilai ulang portofolio dengan harga harian.
## Gaji & biaya hidup bulan baru TIDAK ikut digambar, agar lonjakannya tidak menenggelamkan
## pergerakan pasar; angka kekayaan di laporan tetap nilai setelahnya.
## `executed`: pesanan otomatis bulan ini. Sebelum tanggal terpicu, aset itu masih dipegang
## (dinilai dengan harga harian); sejak tanggal itu, uang hasil jualnya sudah di kas.
func _daily_worth_series(start_value: float, executed: Array[Dictionary] = []) -> Array[float]:
	var series: Array[float] = [start_value]
	for day in range(1, MarketAsset.DAYS_IN_MONTH + 1):
		var value := float(cash) + dream_funds()
		for asset_id: String in holdings:
			var asset := market.get_asset(asset_id)
			value += units_of(asset_id) * (asset.price if asset.is_interest() else asset.price_on_day(day))
		for sale: Dictionary in executed:
			if day < int(sale["day"]):
				var sold := market.get_asset(sale["asset_id"])
				value += float(sale["units"]) * sold.price_on_day(day) - float(sale["proceeds"])
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
		var gross: float = holdings[asset_id]["units"] * market.rate_for(asset) / 12.0
		var tax := gross * asset.interest_tax  # pajak final bunga (deposito 20%)
		holdings[asset_id]["units"] += gross - tax
		total += gross - tax
		_add_tax("interest_tax", tax)
	stats["total_interest"] += total
	return total


## Awal bulan: gaji masuk (kecuali sedang menganggur), biaya hidup terpotong,
## kesehatan & kebahagiaan berubah. Hasil lamaran bulan lalu diumumkan & lowongan baru muncul.
## Januari: penyesuaian inflasi + kenaikan prestasi sesuai kinerja.
func _start_month() -> Dictionary:
	var food := food_option()
	var housing := housing_option()
	var health_before := health
	var happiness_before := happiness
	var new_year := month > 0 and month % 12 == 0
	var salary_raise := _index_salary() if new_year and is_employed() else 0.0
	var merit := _merit_raise() if new_year else {}
	var job_news := _resolve_applications()
	var working := is_employed() and unpaid_months == 0  # cuti tanpa gaji = tidak bekerja bulan ini
	var paid := _monthly_pay()
	var performance_before := performance
	_work_month(working)

	var food_cost := option_cost(food)
	var housing_cost := option_cost(housing)
	var salary_tax := income_tax(paid)
	cash += paid - salary_tax - food_cost - housing_cost
	month_income = paid - salary_tax  # gaji bersih: dasar rencana gaji
	stats["total_salary"] += paid
	stats["total_taxes"] += salary_tax
	stats["total_living"] += food_cost + housing_cost
	if food_id == "luxury" or housing_id == "apartment":
		stats["luxury_months"] += 1
	health = clampi(health + int(food["health"]) + int(housing["health"]) + _drift("health", health, working), 0, 100)
	happiness = clampi(happiness + int(food["happiness"]) + int(housing["happiness"])
		+ _drift("happiness", happiness, working), 0, 100)
	var insurance := _pay_premiums()
	var study_report := _study_month()
	energy_capacity = energy_max()  # setelah kuliah bulan ini diketahui (beban energi)
	energy = energy_capacity
	activity_counts.clear()
	# Rencana gaji baru berjalan setelah pemain menyimpannya pertama kali (lihat set_plan).
	var budget := _apply_budget(month_income) if plan.get("confirmed", false) else {}
	_check_dreams()
	targets = _new_targets()
	_refresh_job_board()

	return {
		"salary": paid,
		"income_tax": salary_tax,
		"unemployed": not is_employed(),
		"unpaid_leave": is_employed() and paid == 0,
		"applications_accepted": job_news["accepted"],
		"applications_rejected": job_news["rejected"],
		"food_cost": food_cost,
		"housing_cost": housing_cost,
		"health_delta": health - health_before,
		"happiness_delta": happiness - happiness_before,
		"salary_raise": salary_raise,
		"performance": roundi(performance) if working and is_career() else -1,
		"performance_delta": roundi(performance) - roundi(performance_before),
	}.merged(merit).merged(insurance).merged(study_report).merged(budget)


# --- Pekerjaan & karier (v1.5b) ------------------------------------------------------
# Permainan dimulai tanpa pekerjaan. Tiap awal bulan muncul lowongan (data/jobs.json);
# melamar memakai energi dan hasilnya diumumkan awal bulan berikutnya. Lamaran yang diterima
# menjadi tawaran: diambil = mulai bekerja (gaji pertama langsung dibayar jika belum ada gaji).

func is_employed() -> bool:
	return not job.is_empty()


func job_def(id: String) -> Dictionary:
	for def: Dictionary in job_data.get("jobs", []):
		if def["id"] == id:
			return def
	return {}


func track_def(id: String) -> Dictionary:
	for def: Dictionary in job_data.get("tracks", []):
		if def["id"] == id:
			return def
	return {}


func current_job_def() -> Dictionary:
	return job_def(job.get("id", ""))


## Kerja lepas: penghasilan naik-turun tiap bulan (0.3 = hingga 30%).
func income_volatility() -> float:
	return float(current_job_def().get("volatility", 0.0))


## "SMA" -> 0, "S1" -> 2. "" (tanpa syarat) -> -1.
func education_index(id: String) -> int:
	var levels: Array = job_data.get("education_levels", [])
	for i in levels.size():
		if levels[i]["id"] == id:
			return i
	return -1


func education_name(index: int) -> String:
	var levels: Array = job_data.get("education_levels", [])
	return levels[index]["name"] if index >= 0 and index < levels.size() else ""


func job_skill_requirement(def: Dictionary) -> float:
	if def.has("skill"):
		return float(def["skill"])
	return float(job_data["skill_by_level"][int(def["level"]) - 1])


## Pengalaman di bidang yang sama yang dibutuhkan pelamar dari luar (kerja lepas: tidak ada).
func job_experience_requirement(def: Dictionary) -> int:
	if def["track"] == "gig":
		return 0
	return int(job_data["experience_by_level"][int(def["level"]) - 1])


## Syarat lowongan untuk ditampilkan: [{type: education|skill|experience, need, have, met}]
func job_requirements(def: Dictionary) -> Array[Dictionary]:
	var reqs: Array[Dictionary] = []
	var need_education := education_index(def.get("education", ""))
	if need_education >= 0:
		reqs.append({"type": "education", "need": need_education, "have": education, "met": education >= need_education})
	var need_skill := job_skill_requirement(def)
	if need_skill > 0.0:
		reqs.append({"type": "skill", "need": need_skill, "have": skill, "met": skill + 0.001 >= need_skill})
	var need_experience := job_experience_requirement(def)
	if need_experience > 0:
		var have := int(experience.get(def["track"], 0))
		reqs.append({"type": "experience", "need": need_experience, "have": have, "met": have >= need_experience})
	return reqs


func meets_requirements(def: Dictionary) -> bool:
	return job_requirements(def).all(func(r: Dictionary) -> bool: return r["met"])


## Peluang diterima (0-1). 0 jika ada syarat yang belum terpenuhi.
func hire_chance(def: Dictionary) -> float:
	if not meets_requirements(def):
		return 0.0
	var cfg: Dictionary = job_data["chance"]
	if def["track"] == "gig":
		return float(cfg["gig"])
	var chance := float(cfg["base"]) + float(cfg["per_5_skill"]) * floorf((skill - job_skill_requirement(def)) / 5.0)
	if education > education_index(def.get("education", "")):
		chance += float(cfg["higher_education"])
	return clampf(chance, 0.0, float(cfg["max"]))


## "" jika lowongan ke-`index` bisa dilamar, atau key pesan alasannya.
func apply_block_reason(index: int) -> String:
	var opening: Dictionary = job_board[index]
	if opening.get("applied", false):
		return "ERR_JOB_APPLIED"
	if is_employed() and job["id"] == opening["job_id"] and job["company"] == opening["company"]:
		return "ERR_JOB_CURRENT"
	if is_over or has_pending_event():
		return "ERR_ACTIVITY_BUSY"
	if not meets_requirements(job_def(opening["job_id"])):
		return "ERR_JOB_REQUIREMENTS"
	if applications.size() >= int(job_data["applications_per_month"]):
		return "ERR_JOB_LIMIT"
	if energy < int(job_data["apply_energy"]):
		return "ERR_NO_ENERGY"
	return ""


## Melamar lowongan ke-`index` bulan ini (memakai energi). -> {ok, error}
func apply_job(index: int) -> Dictionary:
	var reason := apply_block_reason(index)
	if reason != "":
		return {"ok": false, "error": reason}
	var opening: Dictionary = job_board[index]
	energy -= int(job_data["apply_energy"])
	opening["applied"] = true
	applications.append({"job_id": opening["job_id"], "company": opening["company"],
		"salary": opening["salary"], "chance": hire_chance(job_def(opening["job_id"]))})
	stats["applications"] += 1
	changed.emit()
	state_committed.emit()
	return {"ok": true}


## Mengambil tawaran ke-`index`; tawaran lain otomatis ditolak. Jika bulan ini belum ada
## gaji (baru mulai bekerja), gaji pertama langsung dibayar agar modal tidak habis menunggu.
func accept_offer(index: int) -> void:
	var offer: Dictionary = job_offers[index]
	var first_salary := 0
	if not is_employed() and month_income == 0:
		first_salary = int(offer["salary"])
	job = {"id": offer["job_id"], "company": offer["company"], "since": month, "hired": month}
	_log_career("hired")
	_check_sponsor()
	salary = int(offer["salary"])
	unpaid_months = 0
	performance = float(job_data["performance"]["start"])
	job_offers.clear()
	stats["jobs_taken"] += 1
	if is_career():
		stats["top_level"] = maxi(int(stats["top_level"]), int(current_job_def()["level"]))
	if first_salary > 0:
		var tax := income_tax(first_salary)
		cash += first_salary - tax
		month_income = first_salary - tax
		stats["total_salary"] += first_salary
		stats["total_taxes"] += tax
	changed.emit()
	state_committed.emit()


func decline_offers() -> void:
	job_offers.clear()
	changed.emit()
	state_committed.emit()


## Hasil lamaran bulan lalu: diterima -> tawaran (job_offers), sisanya ditolak.
## Tawaran lama yang tidak diambil sudah kedaluwarsa.
func _resolve_applications() -> Dictionary:
	job_offers.clear()
	var accepted: Array[String] = []
	var rejected: Array[String] = []
	for application: Dictionary in applications:
		var title: String = job_def(application["job_id"])["title"]
		if rng.randf() < float(application["chance"]):
			job_offers.append(application)
			accepted.append("%s · %s" % [title, application["company"]])
		else:
			rejected.append("%s · %s" % [title, application["company"]])
	applications.clear()
	return {"accepted": accepted, "rejected": rejected}


## Gaji bulan ini: 0 jika belum bekerja atau sedang cuti tanpa gaji; kerja lepas naik-turun.
func _monthly_pay() -> int:
	if not is_employed():
		stats["months_unemployed"] += 1
		return 0
	if unpaid_months > 0:
		unpaid_months -= 1
		return 0
	var volatility := income_volatility()
	if volatility > 0.0:
		return roundi(salary * (1.0 + rng.randf_range(-volatility, volatility)) / 1000.0) * 1000
	return salary


## Bekerja sebulan: pengalaman di bidang ini +1 bulan, keahlian +1 tiap beberapa bulan,
## kinerja bergerak sebagian menuju targetnya (pekerjaan berjenjang saja, lihat performance_factors).
func _work_month(working: bool) -> void:
	if not working:
		return
	var track: String = current_job_def()["track"]
	experience[track] = int(experience.get(track, 0)) + 1
	var months_worked := months_at_company()
	if months_worked > 0 and months_worked % int(job_data["skill_every_months"]) == 0:
		_gain_skill(1.0)
	if is_career():
		var cfg: Dictionary = job_data["performance"]
		var noise := float(cfg["noise"])
		performance += (float(performance_factors()["target"]) - performance) * float(cfg["approach"]) \
			+ rng.randf_range(-noise, noise)
		performance = clampf(performance, 0.0, 100.0)


## Keahlian naik makin pelan saat sudah tinggi: tambahan x (1 - keahlian/100)^skill_curve
## (jobs.json), mis. kursus +3 menjadi +1,5 di keahlian 30 dan +0,3 di keahlian 70. Maks. 100.
func _gain_skill(amount: float) -> void:
	var factor := pow(maxf(1.0 - skill / 100.0, 0.0), float(job_data.get("skill_curve", 1.0)))
	skill = clampf(skill + amount * factor, 0.0, 100.0)


func _leave_job() -> void:
	job = {}
	salary = 0
	unpaid_months = 0
	_check_sponsor()


## Lowongan bulan ini: 1 kerja lepas, 1 yang paling tinggi jenjangnya di antara yang syaratnya
## terpenuhi, sisanya acak sampai jenjang berikutnya (sebagai motivasi). Gaji ikut inflasi.
func _refresh_job_board() -> void:
	var cfg: Dictionary = job_data["board"]
	var gigs: Array = job_data["jobs"].filter(func(def: Dictionary) -> bool: return def["track"] == "gig")
	var careers: Array = job_data["jobs"].filter(func(def: Dictionary) -> bool: return def["track"] != "gig")
	var count := rng.randi_range(int(cfg["min"]), int(cfg["max"]))
	var picked: Array = [gigs[rng.randi() % gigs.size()]]
	var qualified: Array = careers.filter(meets_requirements)
	var best_level := 1
	if not qualified.is_empty():
		best_level = qualified.map(func(def: Dictionary) -> int: return int(def["level"])).max()
		var best: Array = qualified.filter(func(def: Dictionary) -> bool: return int(def["level"]) == best_level)
		picked.append(best[rng.randi() % best.size()])
	var pool: Array = careers.filter(func(def: Dictionary) -> bool:
		return int(def["level"]) <= best_level + 1 and not def in picked)
	while picked.size() < count and not pool.is_empty():
		picked.append(pool.pop_at(rng.randi() % pool.size()))
	job_board.clear()
	var spread: Array = cfg["salary_spread"]
	for def: Dictionary in picked:
		var companies: Array = track_def(def["track"])["companies"]
		var base := float(def["salary"]) * float(difficulty["salary_mult"]) * rng.randf_range(float(spread[0]), float(spread[1]))
		job_board.append({"job_id": def["id"], "company": companies[rng.randi() % companies.size()],
			"salary": nominal(base), "applied": false})


# --- Karier: kinerja, kenaikan prestasi, promosi, PHK (v1.5b langkah 2) ----------------
# Hanya pekerjaan berjenjang (bukan kerja lepas). Kinerja bergerak tiap bulan menuju target
# (keahlian vs syarat jabatan + kesehatan & kebahagiaan) dan berubah lewat event kerja.
# Promosi & PHK datang sebagai event yang dijadwalkan di luar jatah event acak (_career_events).

func is_career() -> bool:
	return is_employed() and current_job_def().get("track", "gig") != "gig"


## Lama di jabatan sekarang (syarat promosi).
func months_in_role() -> int:
	return month - int(job.get("since", month))


## Lama di perusahaan ini (pesangon, kenaikan prestasi).
func months_at_company() -> int:
	return month - int(job.get("hired", job.get("since", month)))


## Target kinerja & penyusunnya (ditampilkan di kartu Pekerjaan):
## dasar + kecocokan keahlian dengan syarat jabatan + rata-rata kesehatan & kebahagiaan.
func performance_factors() -> Dictionary:
	var cfg: Dictionary = job_data["performance"]
	var skill_fit := clampf((skill - job_skill_requirement(current_job_def())) * float(cfg["per_skill"]),
		float(cfg["skill_min"]), float(cfg["skill_max"]))
	var wellbeing := clampf(((health + happiness) / 2.0 - float(cfg["wellbeing_from"])) * float(cfg["wellbeing_rate"]),
		float(cfg["wellbeing_min"]), float(cfg["wellbeing_max"]))
	return {"skill": skill_fit, "wellbeing": wellbeing,
		"target": clampf(float(cfg["base"]) + skill_fit + wellbeing, 0.0, 100.0)}


## Key teks predikat kinerja ("PERF_GOOD", ...).
func performance_label(value: float = performance) -> String:
	for row: Array in job_data["performance"]["labels"]:
		if roundi(value) >= int(row[0]):
			return row[1]
	return ""


## Kenaikan prestasi tahunan untuk kinerja `value` (0.015 = 1,5%).
func merit_raise_for(value: float) -> float:
	for row: Array in job_data["merit_raise"]["by_performance"]:
		if roundi(value) >= int(row[0]):
			return float(row[1])
	return 0.0


## Penilaian kinerja tahunan (Januari): kenaikan prestasi bagi yang sudah cukup lama bekerja.
func _merit_raise() -> Dictionary:
	if not is_career() or unpaid_months > 0 or months_at_company() < int(job_data["merit_raise"]["min_months"]):
		return {}
	var pct := merit_raise_for(performance)
	if pct > 0.0:
		_raise_salary(pct)
	return {"merit_raise": pct, "review_performance": roundi(performance)}


## Jabatan berikutnya di bidang yang sama ({} jika sudah jenjang tertinggi / kerja lepas).
func next_job_def() -> Dictionary:
	if not is_career():
		return {}
	var def := current_job_def()
	return _job_at(def["track"], int(def["level"]) + 1)


func _job_at(track: String, level: int) -> Dictionary:
	for def: Dictionary in job_data["jobs"]:
		if def["track"] == track and int(def["level"]) == level:
			return def
	return {}


## Gaji jabatan `def` saat promosi / dibajak: gaji pasarnya, minimal naik `min_raise` dari gaji sekarang.
func _raised_salary(def: Dictionary, min_raise: float) -> int:
	var market_pay := nominal(float(def["salary"]) * float(difficulty["salary_mult"]))
	return maxi(market_pay, roundi(salary * (1.0 + min_raise) / 1000.0) * 1000)


func promotion_salary() -> int:
	var next := next_job_def()
	return 0 if next.is_empty() else _raised_salary(next, float(job_data["promotion"]["min_raise"]))


## Syarat promosi ke jenjang berikutnya: [{type: tenure|performance|education|skill, need, have, met}].
## Promosi internal tidak butuh pengalaman bidang (itu syarat pelamar dari luar).
func promotion_requirements() -> Array[Dictionary]:
	var reqs: Array[Dictionary] = []
	var next := next_job_def()
	if next.is_empty():
		return reqs
	var cfg: Dictionary = job_data["promotion"]
	var min_months: Array = cfg["min_months"]
	var need_months := int(min_months[mini(int(current_job_def()["level"]) - 1, min_months.size() - 1)])
	reqs.append({"type": "tenure", "need": need_months, "have": months_in_role(), "met": months_in_role() >= need_months})
	reqs.append({"type": "performance", "need": int(cfg["performance"]), "have": roundi(performance),
		"met": roundi(performance) >= int(cfg["performance"])})
	for req: Dictionary in job_requirements(next):
		if req["type"] != "experience":
			reqs.append(req)
	return reqs


func promotion_ready() -> bool:
	var reqs := promotion_requirements()
	return not reqs.is_empty() and unpaid_months == 0 and reqs.all(func(r: Dictionary) -> bool: return r["met"])


## Peluang PHK bulan ini: dasar, dikali saat kinerja rendah dan saat pasar saham lesu (bear).
func layoff_chance() -> float:
	var cfg: Dictionary = job_data["layoff"]
	if not is_career() or unpaid_months > 0 or months_at_company() < int(cfg["min_months"]):
		return 0.0
	var chance := float(cfg["base"])
	if performance < float(cfg["low_performance"]):
		chance *= float(cfg["low_mult"])
	elif performance < float(cfg["mid_performance"]):
		chance *= float(cfg["mid_mult"])
	if market.regime_of("stock") == "bear":
		chance *= float(cfg["bear_mult"])
	return chance


## Pesangon PHK dalam bulan gaji: 1 bulan untuk tiap tahun masa kerja yang dimulai (maks. 9).
func severance_months() -> int:
	return clampi(floori(months_at_company() / 12.0) + 1, 1, int(job_data["layoff"]["severance_max"]))


## Berhenti sendiri: tanpa pesangon, gaji berhenti mulai bulan depan.
func resign() -> void:
	if not is_employed() or is_over or has_pending_event():
		return
	stats["resigns"] += 1
	_log_career("resigned")
	_leave_job()
	changed.emit()
	state_committed.emit()


func _promote() -> void:
	var next := next_job_def()
	if next.is_empty():
		return
	salary = int(pending_vars.get("salary", promotion_salary()))
	job["id"] = next["id"]
	job["since"] = month
	stats["promotions"] += 1
	stats["top_level"] = maxi(int(stats["top_level"]), int(next["level"]))
	_log_career("promoted")


func _lay_off() -> void:
	var severance := int(pending_vars.get("severance", severance_months() * salary))
	cash += severance
	stats["layoffs"] += 1
	stats["severance"] += severance
	_log_career("laid_off")
	_leave_job()


## Incaran headhunter: jenjang berikutnya di bidang yang sama jika pendidikan & keahlian cukup,
## selain itu jabatan setara. Gaji = gaji pasar jabatan itu + premium (tidak menumpuk dari gaji
## sekarang). {} jika kenaikannya kurang dari min_gain, sehingga event headhunter tidak muncul.
func headhunter_target() -> Dictionary:
	if not is_career():
		return {}
	var cfg: Dictionary = job_data["headhunter"]
	var target := next_job_def()
	if target.is_empty() or not job_requirements(target).all(func(r: Dictionary) -> bool:
			return r["met"] or r["type"] == "experience"):
		target = current_job_def()
	var offer := nominal(float(target["salary"]) * float(difficulty["salary_mult"]) * (1.0 + float(cfg["premium"])))
	if offer < salary * (1.0 + float(cfg["min_gain"])):
		return {}
	return {"def": target, "salary": offer}


func _headhunter_offer() -> Dictionary:
	var target := headhunter_target()
	if target.is_empty():
		return {}
	var def: Dictionary = target["def"]
	var companies: Array = track_def(def["track"])["companies"].filter(func(c: String) -> bool:
		return c != job["company"])
	return {"job_id": def["id"], "company": companies[rng.randi() % companies.size()],
		"salary": target["salary"], "chance": 1.0}


## Tawaran kerja berjenjang bergaji tertinggi bulan ini (dibahas di event wawancara), atau -1.
func _interview_offer_index() -> int:
	var best := -1
	for i in job_offers.size():
		if job_def(job_offers[i]["job_id"])["track"] == "gig":
			continue
		if best < 0 or job_offers[i]["salary"] > job_offers[best]["salary"]:
			best = i
	return best


## Hasil negosiasi gaji di event wawancara.
func _raise_offer(pct: float) -> void:
	var i := int(pending_vars.get("offer_index", -1))
	if i >= 0 and i < job_offers.size():
		job_offers[i]["salary"] = roundi(job_offers[i]["salary"] * (1.0 + pct) / 1000.0) * 1000


## Event karier bulan ini, di luar jatah event acak: wawancara jika ada tawaran kerja berjenjang;
## selain itu PHK atau tawaran promosi (diundi tiap bulan).
func _career_events() -> Array[Dictionary]:
	var picked: Array[Dictionary] = []
	var id := ""
	if _interview_offer_index() >= 0:
		id = "interview"  # sedang mempertimbangkan pindah kerja: PHK & promosi ditunda
	elif rng.randf() < layoff_chance():
		id = "layoff"
	elif promotion_ready() and _event_off_cooldown("promotion") \
			and rng.randf() < float(job_data["promotion"]["chance"]):
		id = "promotion"
	var def := events.find(id)
	if not def.is_empty():
		picked.append(def)
	return picked


func _event_off_cooldown(id: String) -> bool:
	var def := events.find(id)
	return not events.last_month.has(id) or month - int(events.last_month[id]) >= int(def.get("cooldown", 12))


## Isian teks event yang bergantung kondisi pemain. Dihitung saat event mulai tampil dan
## ikut disimpan, agar teks, efek, dan hasilnya konsisten (mis. gaji promosi, pesangon).
func _event_vars(def: Dictionary) -> Dictionary:
	match def.get("id", ""):
		"interview":
			var i := _interview_offer_index()
			if i >= 0:
				var offer: Dictionary = job_offers[i]
				return {"offer_index": i, "job_id": offer["job_id"], "company": offer["company"], "salary": offer["salary"]}
		"promotion":
			return {"job_id": next_job_def()["id"], "salary": promotion_salary(), "months": months_in_role()}
		"layoff":
			var months := severance_months()
			return {"job_id": job["id"], "company": job["company"], "months": months, "severance": months * salary}
		"headhunter":
			var offer := _headhunter_offer()
			if not offer.is_empty():
				return {"offer": offer, "job_id": offer["job_id"], "company": offer["company"],
					"salary": offer["salary"], "raise": float(offer["salary"]) / maxf(salary, 1.0) - 1.0}
		"company_sponsor":
			var option := sponsor_program()
			if not option.is_empty():
				return {"company": job["company"], "program_id": option["def"]["id"]}
		"course":
			return {"cert": certification_name()}
	return {}


## Event di antrean masih relevan saat gilirannya tiba? (mis. event kerja batal setelah PHK)
func _event_still_valid(def: Dictionary) -> bool:
	match def.get("id", ""):
		"interview":
			return _interview_offer_index() >= 0
		"promotion":
			return promotion_ready()
		"layoff":
			return is_career()
	return events.requires_met(def, self)


# --- Pendidikan: kuliah, beasiswa, sertifikasi (v1.5b langkah 3) --------------------------
# Kuliah berjalan tiap awal bulan mulai bulan setelah mendaftar, sambil bekerja atau tidak.
# Lulus = pendidikan naik + keahlian. Beasiswa kampus memotong uang kuliah; beasiswa kantor
# menanggung penuh selama pemain masih bekerja di perusahaan pemberinya.

func is_studying() -> bool:
	return not study.is_empty()


## Id pendidikan sekarang ("SMA", "D3", ...).
func education_id() -> String:
	return job_data["education_levels"][education]["id"]


func program_def(id: String) -> Dictionary:
	for def: Dictionary in education_data.get("programs", []):
		if def["id"] == id:
			return def
	return {}


## Program yang bisa diambil dengan pendidikan sekarang: [{def, months, fee}] (fee per bulan, harga hari ini).
func available_programs() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for def: Dictionary in education_data.get("programs", []):
		var months: Dictionary = def["months"]
		if months.has(education_id()):
			options.append({"def": def, "months": int(months[education_id()]), "fee": _program_fee(def, 0.0)})
	return options


func program_option(id: String) -> Dictionary:
	for option: Dictionary in available_programs():
		if option["def"]["id"] == id:
			return option
	return {}


func _program_fee(def: Dictionary, covered: float) -> int:
	return nominal(float(def["cost"]) * float(difficulty["expense_mult"]) * (1.0 - covered))


## Uang kuliah per bulan (harga hari ini) setelah beasiswa; 0 jika ditanggung kantor.
func tuition_fee() -> int:
	if not is_studying() or study_sponsored():
		return 0
	return _program_fee(program_def(study["id"]), float(study["scholarship"]))


func study_sponsored() -> bool:
	return is_studying() and study["sponsor"] != "" and is_employed() and job["company"] == study["sponsor"]


## Bulan kelulusan jika tidak ada cuti kuliah.
func graduation_month() -> int:
	var next := maxi(int(study["since"]), month + 1)
	return next + int(study["months_left"])


## "" jika program bisa didaftar, atau key pesan alasannya.
func enroll_block_reason(program_id: String) -> String:
	if is_over or has_pending_event():
		return "ERR_ACTIVITY_BUSY"
	if is_studying():
		return "ERR_STUDY_ACTIVE"
	var option := program_option(program_id)
	if option.is_empty():
		return "ERR_STUDY_UNAVAILABLE"
	if cash < int(option["fee"]):
		return "ERR_NOT_ENOUGH_CASH"
	return ""


## Mendaftar kuliah; mulai berjalan (dan dibayar) awal bulan depan. -> {ok, error}
func enroll(program_id: String) -> Dictionary:
	var reason := enroll_block_reason(program_id)
	if reason != "":
		return {"ok": false, "error": reason}
	_start_study(program_option(program_id), "")
	changed.emit()
	state_committed.emit()
	return {"ok": true}


func _start_study(option: Dictionary, sponsor: String) -> void:
	study = {"id": option["def"]["id"], "months_left": option["months"], "months_total": option["months"],
		"since": month + 1, "scholarship": 0.0, "sponsor": sponsor, "paid_month": -1}
	stats["enrollments"] += 1


## Berhenti kuliah: biaya yang sudah dibayar hangus, pendidikan tidak berubah.
func quit_study() -> void:
	if not is_studying() or is_over or has_pending_event():
		return
	_log_career("dropped_out", {"program": study["id"]})
	study = {}
	stats["dropouts"] += 1
	changed.emit()
	state_committed.emit()


## Catat peristiwa karier untuk Profil & layar akhir. Pekerjaan sekarang ikut dicatat.
func _log_career(kind: String, extra: Dictionary = {}) -> void:
	var entry := {"month": month, "kind": kind}
	if is_employed():
		entry.merge({"job_id": job["id"], "company": job["company"]})
	career_log.append(entry.merged(extra, true))
	if career_log.size() > MAX_CAREER_LOG:
		career_log.pop_front()


## Kas + tabungan dana darurat cukup untuk berapa bulan biaya hidup, premi, dan uang kuliah
## (ditampilkan di Beranda saat menganggur).
func runway_months() -> int:
	var monthly := maxi(monthly_expenses() + premiums_total() + tuition_fee(), 1)
	return floori((maxf(cash, 0.0) + emergency_balance()) / monthly)


## Cerita/petunjuk sekali per permainan (mis. cerita hari pertama). true jika baru pertama kali.
func mark_story(key: String) -> bool:
	if key in story_seen:
		return false
	story_seen.append(key)
	return true


## Beasiswa kantor berakhir jika pemain tidak lagi bekerja di perusahaan pemberinya.
func _check_sponsor() -> void:
	if is_studying() and study["sponsor"] != "" and job.get("company", "") != study["sponsor"]:
		study["sponsor"] = ""


## Awal bulan: lulus jika semua bulan sudah dijalani; selain itu bayar uang kuliah (kas, lalu
## tabungan dana darurat) dan jalani sebulan kuliah. Uang tidak cukup = cuti kuliah bulan ini.
func _study_month() -> Dictionary:
	if not is_studying() or month < int(study["since"]):
		return {}
	var def := program_def(study["id"])
	if int(study["months_left"]) <= 0:
		return _graduate()
	var fee := tuition_fee()
	_draw_savings(fee)
	if cash < fee:
		return {"study_paused": def["name"]}
	cash -= fee
	stats["tuition"] += fee
	study["months_left"] = int(study["months_left"]) - 1
	study["paid_month"] = month
	happiness = clampi(happiness + int(education_data["load"]["happiness"]), 0, 100)
	return {"study_fee": fee, "study_program": def["name"],
		"study_done": int(study["months_total"]) - int(study["months_left"]), "study_total": study["months_total"]}


func _graduate() -> Dictionary:
	var def := program_def(study["id"])
	var before := floori(skill)
	education = maxi(education, education_index(def["result"]))
	_gain_skill(float(def["skill"]))
	_log_career("graduated", {"program": def["id"]})
	study = {}
	stats["graduations"] += 1
	var gain := floori(skill) - before
	_report_signals.append(func() -> void: graduated.emit(def["name"], def["result"], gain))
	return {"graduated": def["name"], "graduated_education": def["result"], "graduated_skill": gain}


## Program yang ditawarkan beasiswa kantor (event company_sponsor): program pertama yang tersedia,
## jika pemain sudah cukup lama di perusahaan, kinerjanya baik, dan sedang tidak kuliah. {} jika tidak.
func sponsor_program() -> Dictionary:
	var cfg: Dictionary = education_data["sponsor"]
	if not is_career() or is_studying() or months_at_company() < int(cfg["min_months"]) \
			or performance < float(cfg["performance"]):
		return {}
	var options := available_programs()
	return {} if options.is_empty() else options[0]


## Nama sertifikasi di event "course": sesuai bidang pekerjaan sekarang, atau bidang dengan
## pengalaman terbanyak, atau sertifikasi umum (key teks).
func certification_name() -> String:
	var track_id: String = current_job_def().get("track", "")
	if track_id == "" or track_id == "gig":
		var best := 0
		for id: String in experience:
			if id != "gig" and int(experience[id]) > best:
				best = int(experience[id])
				track_id = id
	return track_def(track_id).get("certification", job_data["default_certification"])


## Jika kas kurang dari `amount`, kekurangannya diambil dari tabungan dana darurat (autodebet).
func _draw_savings(amount: int) -> void:
	var savings := emergency_asset_id()
	if cash < amount and units_of(savings) >= amount - cash:
		sell(savings, ceili(amount - cash), "forced")


# --- Asuransi (v1.5a langkah 3) ---------------------------------------------------
# Premi dibayar otomatis tiap awal bulan (sebelum rencana gaji). Polis berlaku setelah masa
# tunggu dan berhenti jika kas tidak cukup. Klaim terjadi otomatis saat event: pilihan
# bertanda "claim" (medical/vehicle) dan event "critical" (asuransi jiwa).

func insurance_products(category: String) -> Array:
	return insurance_data.get("products", []).filter(func(p: Dictionary) -> bool:
		return p["category"] == category)


func insurance_product(id: String) -> Dictionary:
	for p: Dictionary in insurance_data.get("products", []):
		if p["id"] == id:
			return p
	return {}


## Produk polis di kategori ini ({} jika tidak punya).
func policy_product(category: String) -> Dictionary:
	return insurance_product(policies.get(category, {}).get("id", ""))


## Produk polis yang sudah melewati masa tunggu ({} jika belum/ tidak ada).
func active_policy(category: String) -> Dictionary:
	if not policies.has(category):
		return {}
	if month - int(policies[category]["since"]) < int(insurance_data.get("waiting_months", 1)):
		return {}
	return policy_product(category)


## Premi sebulan (harga hari ini). Kendaraan: persen per tahun dari harga kendaraan.
func premium(product: Dictionary) -> int:
	if product.has("premium_rate"):
		return nominal(vehicle_base_value() * float(product["premium_rate"]) / 12.0)
	return nominal(product["premium"])


func premiums_total() -> int:
	var total := 0
	for category: String in policies:
		var product := policy_product(category)
		if not product.is_empty():
			total += premium(product)
	return total


## Pilihan dari popup Perlindungan: {kategori: id produk atau ""}. Polis baru/ganti produk
## memulai masa tunggu dari bulan ini; premi pertama dibayar awal bulan depan.
func set_insurance(choices: Dictionary) -> void:
	for category: String in choices:
		var id: String = choices[category]
		if id == "":
			policies.erase(category)
		elif policies.get(category, {}).get("id", "") != id:
			policies[category] = {"id": id, "since": month}
	changed.emit()
	state_committed.emit()


## Bagian biaya pilihan event yang ditanggung asuransi aktif (0 jika tidak ada).
func insurance_cover(choice: Dictionary) -> int:
	var category := _claim_category(choice)
	if category == "":
		return 0
	var product := active_policy(category)
	if product.is_empty():
		return 0
	var cost := float(choice_cost(choice)) - nominal(product.get("deductible", 0))
	return maxi(0, roundi(cost * float(product.get("coverage", 0.0))))


func _claim_category(choice: Dictionary) -> String:
	match choice.get("claim", ""):
		"medical":
			return "health"
		"vehicle":
			return "vehicle"
	return ""


## Kendaraan yang dimiliki dari impian yang sudah terwujud: "car", "motor", atau "".
func vehicle() -> String:
	for id: String in ["car", "motor"]:
		for entry: Dictionary in dreams:
			if entry["id"] == id and entry["status"] == "achieved":
				return id
	return ""


## Harga kendaraan (harga awal permainan) untuk premi & biaya perbaikan.
func vehicle_base_value() -> float:
	var id := vehicle()
	return float(dream_def(id)["cost"]) if id != "" else 0.0


## Premi semua polis di awal bulan. Jika kas kurang, kekurangannya diambil dari tabungan dana
## darurat; jika masih tidak cukup, polis berhenti (lapse).
func _pay_premiums() -> Dictionary:
	var paid := 0
	var lapsed: Array[String] = []
	for category: String in policies.keys():
		var product := policy_product(category)
		if product.is_empty() or (category == "vehicle" and vehicle() == ""):
			policies.erase(category)
			continue
		var amount := premium(product)
		_draw_savings(amount)
		if cash < amount:
			policies.erase(category)
			lapsed.append(product["name"])
			continue
		cash -= amount
		paid += amount
	stats["insurance_premiums"] += paid
	return {"insurance_premium": paid, "insurance_lapsed": lapsed}


# --- Pajak (v1.5a langkah 2) -------------------------------------------------------

## PPh 21 sebulan untuk penghasilan bruto sebulan `monthly`: disetahunkan, dikurangi PTKP,
## lalu tarif bertingkat per lapisan (economy.json "income_tax"). PTKP & batas lapisan
## ikut indeks harga, jadi beban pajak tidak naik hanya karena inflasi.
func income_tax(monthly: int) -> int:
	var cfg: Dictionary = economy["income_tax"]
	var taxable := monthly * 12.0 - nominal(cfg["ptkp"])
	var tax := 0.0
	var lower := 0.0
	for bracket: Array in cfg["brackets"]:
		if taxable <= lower:
			break
		var upper := INF if bracket[0] == null else float(nominal(bracket[0]))
		tax += (minf(taxable, upper) - lower) * float(bracket[1])
		lower = upper
	return roundi(tax / 12.0)


## Gaji yang diterima setelah PPh 21 (dasar rencana gaji di popup & Beranda).
func net_salary() -> int:
	return salary - income_tax(salary)


func _new_month_costs() -> Dictionary:
	return {"trade_fee": 0.0, "trade_tax": 0.0, "interest_tax": 0.0}


func _add_tax(key: String, amount: float) -> void:
	month_costs[key] += amount
	stats["total_taxes"] += amount


## Perubahan kesehatan & kebahagiaan per bulan dari pekerjaan: beban kerja jabatan (jobs.json
## "workload"), stres mencari kerja saat menganggur (economy.json "monthly_drift"), atau nol saat
## cuti tanpa gaji. Di bawah ambang, tubuh & pikiran pulih alami agar pemain pasif tidak terus merosot.
func _drift(stat: String, value: int, working: bool) -> int:
	var drift: Dictionary = economy.get("monthly_drift", {})
	var change := 0
	if working:
		change = int(current_job_def().get("workload", {}).get(stat, 0))
	elif not is_employed():
		change = int(drift.get("unemployed", {}).get(stat, 0))
	if value < int(drift.get("recover_below", 0)):
		change += int(drift.get("recover", 0))
	return change


## Penyesuaian gaji tahunan (setiap Januari) sebesar inflasi 12 bulan terakhir, agar gaji
## tidak tergerus inflasi. Kenaikan "nyata" datang dari prestasi & promosi (v1.5b langkah 2).
## Mengembalikan persentase kenaikannya (0.035 = 3,5%).
func _index_salary() -> float:
	var raise := snappedf(market.realized_inflation(12), 0.001)
	if raise <= 0.0:
		return 0.0
	_raise_salary(raise)
	return raise


## Kenaikan gaji rutin. Rencana gaji dalam persen, jadi tidak perlu ditinjau ulang.
func _raise_salary(pct: float) -> void:
	var old_salary := salary
	salary = roundi(salary * (1.0 + pct) / 1000.0) * 1000
	if int(plan.get("salary_seen", -1)) == old_salary:
		plan["salary_seen"] = salary


## Biaya sebuah pilihan makan/tempat tinggal: harga hari ini x pengali tingkat kesulitan.
func option_cost(option: Dictionary) -> int:
	return nominal(option["cost"] * difficulty["expense_mult"])


# --- Inflasi & daya beli (v1.5a langkah 1) -----------------------------------------
# Semua harga di file data (makanan, sewa, biaya event & aktivitas, impian, hadiah kuis)
# adalah harga AWAL permainan. nominal() mengubahnya ke harga hari ini.

## Indeks harga: 1.0 = harga di awal permainan, 1.25 = harga-harga sudah naik 25%.
func price_level() -> float:
	return market.price_level if market != null else 1.0


## Harga awal permainan -> harga hari ini, dibulatkan ke `step` Rupiah.
func nominal(amount: float, step: int = 1000) -> int:
	return roundi(amount * price_level() / step) * step


## Nilai `amount` Rupiah hari ini dalam harga awal permainan (nilai riil).
func real_value(amount: float) -> float:
	return amount / price_level()


## Biaya pilihan event (harga hari ini). "cost_vehicle" = persen dari harga kendaraan pemain.
func choice_cost(choice: Dictionary) -> int:
	if choice.has("cost_vehicle"):
		return nominal(vehicle_base_value() * float(choice["cost_vehicle"]))
	return nominal(choice.get("cost", 0))


func activity_cost(def: Dictionary) -> int:
	return nominal(def.get("cost", 0))


func dream_cost(def: Dictionary) -> int:
	return nominal(def["cost"], 10_000)


## Bunga tabungan per tahun setelah pajak, untuk dibandingkan dengan inflasi.
func savings_rate() -> float:
	var asset := market.get_asset(emergency_asset_id())
	return market.rate_for(asset) * (1.0 - asset.interest_tax)


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


# --- Event Director (v1.5-0 langkah 4) ------------------------------------------------
# Setiap bulan: event wajib (mis. THR) + event lanjutan yang jatuh tempo + 0-3 event acak.
# Event diputuskan satu per satu; tombol Lanjut terkunci sampai semuanya selesai.

func _new_director() -> Dictionary:
	return {"quiet_months": 0, "last_bad": false}


func _roll_events() -> void:
	var cfg: Dictionary = economy["event_director"]
	var queue: Array[Dictionary] = []
	var guaranteed := events.pick_guaranteed(self)  # event kalender, di luar jatah acak
	if not guaranteed.is_empty():
		queue.append(guaranteed)
	for chained: Dictionary in chain_events.duplicate():  # rantai event, juga di luar jatah
		if int(chained["due"]) > month:
			continue
		chain_events.erase(chained)
		var def := events.find(chained["id"])
		if not def.is_empty():
			queue.append(def)
	queue.append_array(_career_events())  # wawancara / PHK / promosi, juga di luar jatah

	var context := event_context()
	var picked := 0
	for i in _roll_event_count():
		# Anti-sial beruntun: setelah event buruk, event buruk berikutnya lebih jarang.
		var bad_mult := float(difficulty["bad_event_mult"])
		if director["last_bad"]:
			bad_mult *= float(cfg["bad_after_bad"])
		var taken := queue.map(func(e: Dictionary) -> String: return e["id"])
		var event := events.pick_random(self, rng, bad_mult, context, taken)
		if event.is_empty():
			break
		queue.append(event)
		director["last_bad"] = event.get("bad", false)
		picked += 1
	director["quiet_months"] = int(director["quiet_months"]) + 1 if picked == 0 else 0
	stats["events_rolled"] = int(stats.get("events_rolled", 0)) + picked

	if queue.is_empty():
		return
	for event: Dictionary in queue:
		events.mark_shown(event, month)
	pending_event = queue[0]
	pending_vars = _event_vars(pending_event)
	event_queue.clear()
	for event: Dictionary in queue.slice(1):
		event_queue.append(event["id"])
	changed.emit()
	_emit_later(event_triggered, pending_event)


## Jumlah event acak bulan ini (bobot sesuai tingkat kesulitan). Setelah beberapa bulan
## tenang, bulan berikutnya pasti ada event (quiet_counts).
func _roll_event_count() -> int:
	var cfg: Dictionary = economy["event_director"]
	var weights: Array = difficulty["event_counts"]
	if int(director["quiet_months"]) >= int(cfg["quiet_months"]):
		weights = cfg["quiet_counts"]
	var floats := PackedFloat32Array()
	for w in weights:
		floats.append(float(w))
	var count := rng.rand_weighted(floats)
	if _fast_forwarding and rng.randf() >= float(economy.get("fast_forward_event_mult", 1.0)):
		count = 0  # lompat waktu (masa pensiun nanti) tetap bermakna, tidak terus terpotong
	return count


## Kondisi pemain untuk tag "context" di events.json.
func event_context() -> Dictionary:
	var cfg: Dictionary = economy["event_director"]
	var expenses := float(maxi(monthly_expenses(), 1))
	var risky := false
	var crypto := false
	for asset_id: String in holdings:
		var asset_class := market.get_asset(asset_id).asset_class
		risky = risky or asset_class in ["stock", "crypto"]
		crypto = crypto or asset_class == "crypto"
	return {
		"cash_rich": cash >= expenses * float(cfg["cash_rich_months"]),
		"cash_poor": cash < expenses * float(cfg["cash_poor_months"]),
		"low_happiness": happiness < int(cfg["low_happiness"]),
		"low_health": health < int(cfg["low_health"]),
		"holds_risky": risky,
		"holds_crypto": crypto,
		"unemployed": not is_employed(),
	}


## Event berikutnya di antrean bulan ini (setelah event sebelumnya diputuskan).
func _next_queued_event() -> void:
	while not event_queue.is_empty():
		var def := events.find(event_queue.pop_front())
		if def.is_empty() or not _event_still_valid(def):
			continue
		pending_event = def
		pending_vars = _event_vars(def)
		changed.emit()
		event_triggered.emit(def)
		return


## Pilihan dengan biaya di muka hanya bisa dipilih jika kas cukup.
## Pilihan gratis selalu bisa dipilih, termasuk saat kas minus, agar game tidak macet.
func can_choose(choice: Dictionary) -> bool:
	var cost := choice_cost(choice) - insurance_cover(choice)  # yang ditanggung asuransi tidak perlu dibayar
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
	var cost := choice_cost(choice)
	var covered := insurance_cover(choice)
	cash -= cost - covered
	var claims: Array[Dictionary] = []
	if covered > 0:
		claims.append({"category": _claim_category(choice), "amount": covered})
	elif choice.get("claim", "") == "medical":
		stats["uninsured_medical"] += cost
	if event.get("critical", false):  # asuransi jiwa: uang pertanggungan penyakit kritis
		var life := active_policy("life")
		if not life.is_empty():
			var payout := nominal(life["critical_payout"])
			cash += payout
			claims.append({"category": "life", "amount": payout})
	for claim: Dictionary in claims:
		stats["insurance_claims"] += claim["amount"]
	var outcome := choice
	if choice.has("outcomes"):
		outcome = _pick_outcome(choice["outcomes"])
	var effects: Dictionary = outcome.get("effects", {})
	var offers_before := job_offers.size()
	var title_before: String = current_job_def().get("title", "")
	_apply_effects(effects)
	var vars := pending_vars
	pending_event = {}
	pending_vars = {}
	var result := {"result": outcome.get("result", ""), "changes": _diff(before), "claims": claims, "vars": vars}
	var cash_change: float = result["changes"].get("cash", 0.0)
	stats["events"] += 1
	if had_unaffordable:
		stats["unaffordable_choices"] += 1
	if event["category"] == "scam" and cash_change < 0:
		stats["scam_loss"] += -cash_change
	_record_extreme("best_event", "worst_event", cash_change, {"title": event["title"]})
	changed.emit()
	_check_unlocks(true)
	if effects.get("promote", false):
		career_changed.emit("promoted", current_job_def()["title"])
	if effects.get("layoff", false):
		career_changed.emit("laid_off", title_before)
	# Tawaran kerja (setelah wawancara / dari headhunter) tampil sebelum event berikutnya.
	if not job_offers.is_empty() and (event["id"] == "interview" or job_offers.size() > offers_before):
		job_offers_received.emit(job_offers)
	_next_queued_event()  # sebelum autosave, agar event yang tersisa ikut tersimpan sebagai pending
	state_committed.emit()
	return result


func _pick_outcome(outcomes: Array) -> Dictionary:
	var weights := PackedFloat32Array()
	for o: Dictionary in outcomes:
		weights.append(o["chance"])
	return outcomes[rng.rand_weighted(weights)]


func _apply_effects(e: Dictionary) -> void:
	cash += nominal(e.get("cash", 0)) + roundi(salary * float(e.get("cash_salary", 0.0)))
	health = clampi(health + int(e.get("health", 0)), 0, 100)
	happiness = clampi(happiness + int(e.get("happiness", 0)), 0, 100)
	xp += int(e.get("xp", 0))
	if e.has("salary_pct"):
		salary = roundi(salary * (1.0 + float(e["salary_pct"])) / 1000.0) * 1000
	if is_employed():  # cuti tanpa gaji hanya berarti jika sedang bekerja
		unpaid_months += int(e.get("unpaid_months", 0))
	if e.has("skill"):
		_gain_skill(float(e["skill"]))
	if e.get("lose_job", false):
		_leave_job()
	if is_career():
		performance = clampf(performance + float(e.get("performance", 0)), 0.0, 100.0)
	if e.get("promote", false):
		_promote()
	if e.get("layoff", false):
		_lay_off()
	if e.has("offer_raise"):
		_raise_offer(float(e["offer_raise"]))
	if e.get("headhunter", false) and pending_vars.has("offer"):
		job_offers.append(pending_vars["offer"].duplicate())
	if e.has("scholarship") and is_studying():
		study["scholarship"] = maxf(float(study["scholarship"]), float(e["scholarship"]))
		stats["scholarships"] += 1
	if e.get("sponsored_study", false) and not is_studying() and is_employed():
		var option := program_option(pending_vars.get("program_id", ""))
		if not option.is_empty():
			_start_study(option, job["company"])
	if e.has("study_delay") and is_studying():
		study["months_left"] = int(study["months_left"]) + int(e["study_delay"])
		study["months_total"] = int(study["months_total"]) + int(e["study_delay"])
	if e.has("delayed"):
		var d: Dictionary = e["delayed"].duplicate(true)
		d["due"] = month + int(d["months"])
		delayed_effects.append(d)
	if e.has("chain"):  # rantai event: jadwalkan event lanjutan beberapa bulan lagi
		var months: Array = e["chain"]["months"]
		chain_events.append({"id": e["chain"]["event"], "due": month + rng.randi_range(int(months[0]), int(months[1]))})
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
		"salary": salary, "investments": investments_value(), "skill": floori(skill),
		"performance": roundi(performance)}


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


## Mengembalikan { "correct": bool, "reward": int, "xp": int }
func answer_quiz(question: Dictionary, option_index: int) -> Dictionary:
	var cfg: Dictionary = economy["quiz"]
	var is_correct := quiz.answer(question, option_index)
	var reward := nominal(cfg["reward_correct"]) if is_correct else 0
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


# --- Transaksi: rincian fee & pajak (v1.5a langkah 2) -----------------------------

## Rincian satu transaksi SEBELUM dijalankan. Satu sumber hitungan untuk layar konfirmasi,
## buy(), dan sell() (mirip fungsi hitung total checkout yang dipakai UI dan backend).
## Beli: `amount` = uang yang dibayar (fee & pajak diambil dari situ).
## Jual: `amount` = nilai pasar aset yang dijual (fee, pajak, & penalti dipotong dari situ).
## `at_price` > 0: harga per unit tertentu (mis. harga hari stop loss terpicu), bukan harga sekarang.
## -> {ok, error, buy, asset_id, amount, units, fee, tax, penalty, net, pnl, warnings}
##    net: beli = yang benar-benar masuk ke investasi; jual = uang yang diterima.
func trade_quote(asset_id: String, is_buy: bool, amount: int, at_price: float = 0.0) -> Dictionary:
	var asset := market.get_asset(asset_id)
	var price := at_price if at_price > 0.0 else asset.price
	var q := {"ok": false, "error": "", "buy": is_buy, "asset_id": asset_id, "amount": amount,
		"units": 0.0, "fee": 0.0, "tax": 0.0, "penalty": 0.0, "net": 0.0, "pnl": 0.0, "warnings": []}
	if is_buy and not is_asset_unlocked(asset_id):
		q["error"] = "ERR_LOCKED"
	elif amount <= 0:
		q["error"] = "ERR_AMOUNT_INVALID"
	elif is_buy and amount > cash:
		q["error"] = "ERR_NOT_ENOUGH_CASH"
	if q["error"] != "":
		return q
	if is_buy:
		q["fee"] = amount * asset.buy_fee
		q["tax"] = amount * asset.buy_tax
		q["net"] = amount - q["fee"] - q["tax"]
		q["units"] = q["net"] / price
	else:
		var held := units_of(asset_id)
		var units := amount / price
		if held <= 0.0 or units > held * 1.0001:
			q["error"] = "ERR_NOT_ENOUGH_UNITS"
			return q
		if units >= held * 0.999:
			units = held  # jual semua, hindari sisa "debu" 0.0001 unit
		var gross := units * price
		q["units"] = units
		q["fee"] = gross * asset.sell_fee
		q["tax"] = gross * asset.sell_tax
		q["penalty"] = gross * asset.early_penalty if is_locked(asset_id) else 0.0
		q["net"] = floorf(gross - q["fee"] - q["tax"] - q["penalty"])
		q["pnl"] = q["net"] - cost_of(asset_id) * (units / held)
	q["ok"] = true
	q["warnings"] = _trade_warnings(asset, q)
	return q


## Peringatan untuk layar konfirmasi: [{"id": risk|concentration|emergency|low_cash|penalty|loss, "args": [...]}]
func _trade_warnings(asset: MarketAsset, q: Dictionary) -> Array[Dictionary]:
	var cfg: Dictionary = economy["trade_warnings"]
	var warnings: Array[Dictionary] = []
	if q["buy"]:
		var risky := asset.risk >= int(cfg["risky_from"])
		if exceeds_risk_profile(asset):
			warnings.append({"id": "risk", "args": [risk_profile()["name"]]})
		var invest_after: float = investments_value() + q["net"]
		var share: float = (holding_value(asset.id) + q["net"]) / maxf(invest_after, 1.0)
		if risky and invest_after >= nominal(cfg["concentration_min"]) and share > float(cfg["concentration"]):
			warnings.append({"id": "concentration", "args": [share]})
		if risky and emergency_balance() < emergency_target():
			warnings.append({"id": "emergency", "args": [emergency_balance(), emergency_target()]})
		if asset.asset_class != "savings" and cash - int(q["amount"]) < monthly_expenses():
			warnings.append({"id": "low_cash", "args": [monthly_expenses()]})
	else:
		if q["penalty"] > 0.0:
			warnings.append({"id": "penalty", "args": [locked_until(asset.id)]})
		if q["pnl"] < 0.0:
			warnings.append({"id": "loss", "args": [-q["pnl"]]})
	return warnings


func _add_trade_costs(fee: float, tax: float) -> void:
	month_costs["trade_fee"] += fee
	stats["total_fees"] += fee
	_add_tax("trade_tax", tax)


## Beli aset senilai `amount` Rupiah (sudah termasuk fee & pajak, lihat trade_quote).
## Mengembalikan { ok, error, units, fee, tax } supaya UI bisa menampilkan pesan.
## `kind`: buy (manual) | auto (autodebet dari rencana gaji).
func buy(asset_id: String, amount: int, kind: String = "buy") -> Dictionary:
	var q := trade_quote(asset_id, true, amount)
	if not q["ok"]:
		return {"ok": false, "error": q["error"]}
	var asset := market.get_asset(asset_id)
	var fee: float = q["fee"]
	var tax: float = q["tax"]
	var units: float = q["units"]

	var h: Dictionary = holdings.get(asset_id, {"units": 0.0, "cost": 0.0, "locked_until": 0})
	h["units"] += units
	h["cost"] += amount
	if asset.lock_months > 0:
		h["locked_until"] = month + asset.lock_months  # setoran baru memperpanjang tenor
	holdings[asset_id] = h
	cash -= amount
	_add_trade_costs(fee, tax)
	_log_transaction(kind, asset, amount, units, fee, tax, 0.0)
	if kind == "buy":  # autodebet tidak dihitung sebagai transaksi manual
		turn_fees += fee + tax
		turn_trades += 1
		_progress_target("invest", amount)

	changed.emit()
	return {"ok": true, "units": units, "fee": fee, "tax": tax}


## Jual aset senilai `amount` Rupiah (berdasarkan harga pasar sebelum fee).
## `kind`: sell (manual) | forced (jual paksa saat kas minus) | panic (event panik jual)
##         | stop_loss | take_profit (pesanan otomatis, dijual di `at_price`).
func sell(asset_id: String, amount: int, kind: String = "sell", at_price: float = 0.0) -> Dictionary:
	var q := trade_quote(asset_id, false, amount, at_price)
	if not q["ok"]:
		return {"ok": false, "error": q["error"]}
	var asset := market.get_asset(asset_id)
	var held := units_of(asset_id)
	var units: float = q["units"]
	var fee: float = q["fee"] + q["penalty"]  # penalti pencairan dini dicatat bersama fee
	var tax: float = q["tax"]
	var proceeds := int(q["net"])

	var h: Dictionary = holdings[asset_id]
	var cost_sold: float = h["cost"] * (units / held)
	h["cost"] -= cost_sold  # kurangi modal secara proporsional
	h["units"] -= units
	if h["units"] <= 0.0:
		holdings.erase(asset_id)
		orders.erase(asset_id)  # tidak ada lagi yang dijaga pesanan otomatis
	cash += proceeds
	_add_trade_costs(fee, tax)
	_record_extreme("best_trade", "worst_trade", proceeds - cost_sold, {"asset_key": asset.name_key})
	_log_transaction(kind, asset, proceeds, units, fee, tax, proceeds - cost_sold)
	if kind in ["sell", "panic"]:
		turn_fees += fee + tax
		turn_trades += 1
		if proceeds - cost_sold < 0.0:
			_fail_target("no_loss")

	changed.emit()
	return {"ok": true, "units": units, "fee": fee, "tax": tax, "proceeds": proceeds,
		"pnl": proceeds - cost_sold, "penalty": q["penalty"] > 0.0}


# --- Stop loss & take profit (v1.5a langkah 4) ----------------------------------------

func orders_config() -> Dictionary:
	return economy["orders"]


## Pesanan bisa dipasang pada aset berharga harian yang sedang dimiliki (bukan tabungan/deposito).
func can_have_order(asset_id: String) -> bool:
	return holdings.has(asset_id) and not market.get_asset(asset_id).is_interest()


## {"stop_loss": harga, "take_profit": harga} atau {} jika tidak ada pesanan.
func order_of(asset_id: String) -> Dictionary:
	return orders.get(asset_id, {})


## Pasang/ubah pesanan (harga batas per unit). Keduanya 0 = hapus pesanan.
func set_order(asset_id: String, stop_loss: float, take_profit: float) -> void:
	if stop_loss <= 0.0 and take_profit <= 0.0:
		orders.erase(asset_id)
	elif can_have_order(asset_id):
		orders[asset_id] = {"stop_loss": maxf(stop_loss, 0.0), "take_profit": maxf(take_profit, 0.0)}
	changed.emit()
	state_committed.emit()


## Dicek hari demi hari pada harga bulan yang baru disimulasikan. Pesanan yang tersentuh
## menjual SEMUA unit aset itu di harga hari tersebut, lalu selesai. Mengembalikan daftar
## yang terpicu untuk laporan: [{asset_id, asset_key, kind, day, price, end_price, units, proceeds, pnl}]
func _execute_orders() -> Array[Dictionary]:
	var executed: Array[Dictionary] = []
	var ids: Array = orders.keys()
	ids.sort()  # urutan tetap agar hasil simulasi sama setelah simpan/muat
	for asset_id: String in ids:
		if not can_have_order(asset_id):
			orders.erase(asset_id)
			continue
		var asset := market.get_asset(asset_id)
		var order: Dictionary = orders[asset_id]
		var steps := asset.days_per_month()
		for i in steps:
			var price: float = asset.history[asset.history.size() - steps + i]
			var kind := ""
			if float(order["stop_loss"]) > 0.0 and price <= float(order["stop_loss"]):
				kind = "stop_loss"
			elif float(order["take_profit"]) > 0.0 and price >= float(order["take_profit"]):
				kind = "take_profit"
			if kind == "":
				continue
			var units := units_of(asset_id)
			var result := sell(asset_id, ceili(units * price), kind, price)
			if result["ok"]:
				executed.append({"asset_id": asset_id, "asset_key": asset.name_key, "kind": kind,
					"day": floori(i * MarketAsset.DAYS_IN_MONTH / float(steps)) + 1,  # tanggal pertama langkah ke-i
					"price": price, "end_price": asset.price, "units": units,
					"proceeds": result["proceeds"], "pnl": result["pnl"]})
				stats["orders_executed"] += 1
			orders.erase(asset_id)
			break
	return executed


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


# --- Simpan / muat (SaveManager memetakannya ke tabel SQLite) -------------------

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"profile": {"name": player_name, "avatar": avatar,
			"background": background["id"], "difficulty": difficulty["id"]},
		"month": month, "cash": cash, "salary": salary, "health": health,
		"happiness": happiness, "xp": xp, "unpaid_months": unpaid_months,
		"food_id": food_id, "housing_id": housing_id,
		"holdings": holdings, "unlocked_stages": unlocked_stages,
		"net_worth_history": net_worth_history, "last_report": last_report,
		"pending_event_id": pending_event.get("id", ""), "pending_vars": pending_vars,
		"delayed_effects": delayed_effects,
		"events": events.to_dict(),
		"rng_seed": str(rng.seed), "rng_state": str(rng.state),
		"market": market.to_dict(),
		"stats": stats,
		"danger": [negative_cash_months, zero_health_months, zero_happiness_months],
		"goals_reached": goals_reached,
		"energy": energy, "energy_capacity": energy_capacity, "activity_counts": activity_counts,
		"transactions": transactions, "transaction_seq": transaction_seq, "risk_profile": risk_profile_id,
		"plan": plan, "plan_applied_month": plan_applied_month, "month_income": month_income,
		"dreams": dreams, "dreams_asked": dreams_asked, "targets": targets, "policies": policies, "orders": orders,
		"job": job, "performance": performance, "education": education, "skill": skill, "experience": experience,
		"job_board": job_board, "applications": applications, "job_offers": job_offers, "study": study,
		"career_log": career_log, "story_seen": story_seen,
		"turn_units": turn_units, "turn_fees": turn_fees, "turn_trades": turn_trades, "month_costs": month_costs,
		"event_queue": event_queue, "chain_events": chain_events, "director": director,
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
	unpaid_months = int(d["unpaid_months"])
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
	pending_vars = d.get("pending_vars", {}).duplicate(true)
	for key: String in ["offer_index", "salary", "months", "severance"]:
		if pending_vars.has(key):
			pending_vars[key] = int(pending_vars[key])
	if pending_vars.has("offer"):
		pending_vars["offer"]["salary"] = int(pending_vars["offer"]["salary"])
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
	var saved_transactions: Array = d.get("transactions", [])
	for i in saved_transactions.size():
		var t: Dictionary = saved_transactions[i]
		t["month"] = int(t["month"])
		t["seq"] = int(t.get("seq", saved_transactions.size() - i))  # terbaru di depan
		t["tax"] = float(t.get("tax", 0.0))
		transactions.append(t)
	transaction_seq = int(d.get("transaction_seq", transactions[0]["seq"] if not transactions.is_empty() else 0))
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
	policies.clear()
	for category: String in d.get("policies", {}):
		var saved_policy: Dictionary = d["policies"][category]
		policies[category] = {"id": saved_policy["id"], "since": int(saved_policy["since"])}
	job = {}
	if not d["job"].is_empty():
		job = {"id": d["job"]["id"], "company": d["job"]["company"], "since": int(d["job"]["since"]),
			"hired": int(d["job"].get("hired", d["job"]["since"]))}
	performance = float(d.get("performance", job_data["performance"]["start"] if not job.is_empty() else 0.0))
	education = int(d["education"])
	study = d.get("study", {}).duplicate()
	career_log.clear()
	for entry: Dictionary in d.get("career_log", []):
		var copy := entry.duplicate()
		copy["month"] = int(copy["month"])
		career_log.append(copy)
	story_seen.assign(d.get("story_seen", ["start"]))  # save lama: cerita hari pertama sudah lewat
	for key: String in ["months_left", "months_total", "since", "paid_month"]:
		if study.has(key):
			study[key] = int(study[key])
	skill = float(d["skill"])
	experience.clear()
	for track: String in d["experience"]:
		experience[track] = int(d["experience"][track])
	for list: Array in [[job_board, d["job_board"]], [applications, d["applications"]], [job_offers, d["job_offers"]]]:
		var target: Array[Dictionary] = list[0]
		target.clear()
		for entry: Dictionary in list[1]:
			var copy := entry.duplicate()
			copy["salary"] = int(entry["salary"])
			target.append(copy)
	orders.clear()
	for asset_id: String in d.get("orders", {}):
		var saved_order: Dictionary = d["orders"][asset_id]
		orders[asset_id] = {"stop_loss": float(saved_order["stop_loss"]), "take_profit": float(saved_order["take_profit"])}
	targets.clear()
	for t: Dictionary in d.get("targets", []):
		targets.append(t)
	turn_units = d.get("turn_units", {})
	turn_fees = float(d.get("turn_fees", 0.0))
	month_costs = _new_month_costs().merged(d.get("month_costs", {}), true)
	turn_trades = int(d.get("turn_trades", 0))
	_report_signals.clear()
	event_queue.assign(d.get("event_queue", []))
	chain_events.clear()
	for chained: Dictionary in d.get("chain_events", []):
		chain_events.append({"id": chained["id"], "due": int(chained["due"])})
	director = _new_director().merged(d.get("director", {}), true)
	director["quiet_months"] = int(director["quiet_months"])
	if pending_event.is_empty() and not event_queue.is_empty():  # jaga-jaga: antrean tanpa pending
		pending_event = events.find(event_queue.pop_front())
	is_over = false
	end_result = {}

	market = Market.new()
	market.load_state(
		DataLoader.load_json(ASSETS_PATH).get("assets", []),
		DataLoader.load_json(MARKET_PATH),
		DataLoader.load_json(NEWS_PATH).get("news", []),
		d["market"])
	if not pending_event.is_empty() and pending_vars.is_empty():
		pending_vars = _event_vars(pending_event)  # save langkah 1 / antrean tanpa pending: hitung setelah pasar dimuat
	run_id += 1
	is_active = true
	changed.emit()
	return true


# --- Kondisi menang/kalah & statistik (M6, GDD 5.11) ---------------------------

func _new_stats() -> Dictionary:
	return {
		"total_salary": 0, "total_living": 0, "total_interest": 0.0, "total_fees": 0.0, "total_taxes": 0.0,
		"peak_net_worth": 0.0, "events": 0, "scam_loss": 0, "forced_sales": 0,
		"unaffordable_choices": 0, "luxury_months": 0, "cash_heavy_months": 0,
		"panic_sell": false, "total_lifestyle": 0, "total_autodebet": 0, "dreams_achieved": 0,
		"targets_done": 0, "insurance_premiums": 0, "insurance_claims": 0, "uninsured_medical": 0, "orders_executed": 0,
		"activity_totals": {}, "activity_last": {}, "months_unemployed": 0, "applications": 0, "jobs_taken": 0,
		"promotions": 0, "layoffs": 0, "resigns": 0, "severance": 0, "top_level": 0,
		"tuition": 0, "enrollments": 0, "graduations": 0, "dropouts": 0, "scholarships": 0,
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
		var fee_rate := asset.sell_fee + asset.sell_tax + (asset.early_penalty if is_locked(asset_id) else 0.0)
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
	if not study.is_empty() and int(study["paid_month"]) == month:  # kuliah bulan ini
		value -= int(education_data["load"]["energy"])
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
	if def.has("max_total") and activity_total(def["id"]) >= int(def["max_total"]):
		return "ERR_ACTIVITY_MAXED"
	if activity_cooldown_left(def) > 0:
		return "ERR_ACTIVITY_COOLDOWN"
	if activity_cost(def) > cash:
		return "ERR_NOT_ENOUGH_CASH"
	return ""


## Sisa bulan sebelum aktivitas berjeda ("cooldown_months", mis. kursus) bisa diambil lagi.
func activity_cooldown_left(def: Dictionary) -> int:
	var last: Dictionary = stats["activity_last"]
	if not def.has("cooldown_months") or not last.has(def["id"]):
		return 0
	return maxi(int(last[def["id"]]) + int(def["cooldown_months"]) - month, 0)


## Berapa kali aktivitas ini sudah dilakukan sepanjang permainan (untuk batas "max_total").
func activity_total(activity_id: String) -> int:
	return int(stats["activity_totals"].get(activity_id, 0))


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
	stats["activity_totals"][activity_id] = activity_total(activity_id) + 1
	stats["activity_last"][activity_id] = month
	cash -= activity_cost(def)
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
			"health_delta", "happiness_delta", "lifestyle_cost", "emergency_saved",
			"income_tax", "trade_fee", "trade_tax", "interest_tax", "insurance_premium"]:
		var total := 0.0
		for r: Dictionary in reports:
			total += float(r.get(key, 0))
		merged[key] = total
	var news: Array = []
	var delayed: Array = []
	var forced: Array = []
	var executed_orders: Array = []
	for r: Dictionary in reports:
		news.append_array(r.get("news", []))
		delayed.append_array(r.get("delayed", []))
		forced.append_array(r.get("forced_sales", []))
		executed_orders.append_array(r.get("orders", []))
	merged["news"] = news.slice(-5)  # cukup 5 berita terakhir agar laporan tidak terlalu panjang
	merged["delayed"] = delayed
	merged["forced_sales"] = forced
	merged["orders"] = executed_orders
	merged["from_month"] = reports[0]["from_month"]
	merged["net_worth_before"] = reports[0]["net_worth_before"]
	merged["unemployed"] = merged["salary"] == 0
	var inflation_total := 1.0
	var erosion := 0.0
	var salary_raise := 0.0
	for r: Dictionary in reports:
		inflation_total *= 1.0 + float(r.get("inflation_month", 0.0))
		erosion += float(r.get("erosion", 0.0))
		salary_raise = maxf(salary_raise, float(r.get("salary_raise", 0.0)))
	merged["inflation_month"] = inflation_total - 1.0
	merged["erosion"] = erosion
	merged["salary_raise"] = salary_raise
	merged["months"] = reports.size()
	var daily: Array = reports[0].get("daily_worth", []).duplicate()
	for r: Dictionary in reports.slice(1):
		daily.append_array(r.get("daily_worth", []).slice(1))  # titik awal = titik akhir bulan sebelumnya
	merged["daily_worth"] = daily
	merged["start_prices"] = reports[0]["start_prices"]
	merged["movers"] = _movers_since(reports[0]["start_prices"])
	return merged


# --- Riwayat transaksi (M6.5) ----------------------------------------------------

## `kind`: buy | auto | sell | forced | panic. `pnl` = untung/rugi terealisasi (khusus jual).
func _log_transaction(kind: String, asset: MarketAsset, amount: float, units: float,
		fee: float, tax: float, pnl: float) -> void:
	transaction_seq += 1
	transactions.push_front({"seq": transaction_seq, "month": month, "kind": kind, "asset_key": asset.name_key,
		"amount": amount, "units": units, "fee": fee, "tax": tax, "pnl": pnl})
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
	if not is_employed():
		return false  # belum ada gaji untuk dibagi; popup muncul setelah diterima kerja
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
	_flush_report_signals()
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
		var needed := ceili(maxf(0.0, dream_cost(dream_def(entry["id"])) - entry["saved"]) / 1000.0) * 1000
		var amount := mini(_round_thousand(income * share), needed)  # jangan menabung melebihi biayanya
		dream_items.append({"id": entry["id"], "name": dream_def(entry["id"])["name"], "share": share, "amount": amount})
		dreams_total += amount
	var insurance := premiums_total()
	var tuition := tuition_fee()
	return {"income": income, "basic": basic, "insurance": insurance, "tuition": tuition, "lifestyle": lifestyle,
		"emergency": emergency, "emergency_room": room, "invest": invest, "invest_total": invest_total,
		"dreams": dream_items, "dreams_total": dreams_total,
		"surplus": income - basic - insurance - tuition - lifestyle - emergency - invest_total - dreams_total}


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
	var left := maxf(0.0, dream_cost(dream_def(entry["id"])) - entry["saved"])
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
	var left := ceili(maxf(0.0, dream_cost(dream_def(id)) - entry["saved"]))
	amount = mini(amount, left)
	cash -= amount
	entry["saved"] += amount
	_progress_target("dream_deposit", amount)
	_check_dreams()
	changed.emit()
	state_committed.emit()
	_flush_report_signals()
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
	var cost := dream_cost(def)
	return entry.merged({"def": def, "cost": cost, "ratio": clampf(entry["saved"] / float(cost), 0.0, 1.0)})


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
		var cost := dream_cost(def)
		if entry["saved"] + 0.5 < float(cost):
			continue
		cash += roundi(entry["saved"] - float(cost))
		entry["saved"] = float(cost)
		entry["status"] = "achieved"
		entry["achieved_month"] = month
		plan["dreams"].erase(entry["id"])
		happiness = clampi(happiness + int(def["happiness"]), 0, 100)
		xp += int(def["xp"])
		stats["dreams_achieved"] += 1
		var view := dream_view(entry)
		_report_signals.append(func() -> void: dream_achieved.emit(view))


func _queue_overdue_dreams() -> void:
	for entry: Dictionary in overdue_dreams():
		var view := dream_view(entry)
		_report_signals.append(func() -> void: dream_overdue.emit(view))


## Sinyal impian dikirim SETELAH laporan bulanan, agar urutan popup: laporan -> perayaan.
func _flush_report_signals() -> void:
	var pending := _report_signals.duplicate()
	_report_signals.clear()
	for send: Callable in pending:
		if _fast_forwarding:
			_deferred.append(send)
		else:
			send.call()


## Pos impian berbunga seperti tabungan (setelah pajak). Mengembalikan totalnya.
func _pay_dream_interest() -> float:
	var asset := market.get_asset(dreams_config()["interest_asset"])
	var rate := market.rate_for(asset) / 12.0
	var total := 0.0
	for entry: Dictionary in active_dreams():
		var gross: float = entry["saved"] * rate
		var tax := gross * asset.interest_tax
		entry["saved"] += gross - tax
		total += gross - tax
		_add_tax("interest_tax", tax)
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
	var pool: Array[Dictionary] = [{"type": "invest", "goal": float(nominal(cfg["invest_amount"], 50_000)), "param": ""}]
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
		pool.append({"type": "dream_deposit", "goal": float(nominal(cfg["dream_deposit"], 50_000)), "param": ""})
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
