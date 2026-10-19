class_name GameStore
extends Node
## State global permainan (Autoload bernama "GameState"; tipe skripnya GameStore).
##
## Analogi web: ini root "store" (Redux/Pinia). Logika tiap domain ada di modul terpisah di
## scripts/game/ (seperti slice/store per fitur): career, characters, education, insurance, debt,
## portfolio, research, contracts, budget, dreams, vehicles, properties, targets, events, activities,
## progress, annual (laporan tahunan). Pencapaian (`achievements`) adalah data pemain lintas permainan.
## File ini hanya memegang data bersama (profil, bulan, kas, kondisi, statistik, pasar, RNG), mengatur
## alur tiap bulan, menjalankan efek event, menyimpan/memuat, dan memeriksa akhir permainan.
##
## UI tidak mengubah data langsung: panggil fungsi di sini atau di modul
## (mis. GameState.career.apply_job(i)), lalu dengarkan signal `changed` untuk re-render.

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
## Pencapaian baru terbuka (v1.5d langkah 4): id pencapaian, berlaku lintas permainan.
signal achievements_unlocked(ids: Array[String])
## Januari: laporan tahun lalu sudah ditutup (v1.5d langkah 4), dikirim setelah laporan bulanan.
signal year_closed(report: Dictionary)
## Bab kehidupan berganti (v2b): {from, to, start, end} keadaan di awal & akhir bab yang selesai,
## aging = true jika efek penuaan juga berubah di ulang tahun ini (ditampilkan di popup yang sama).
signal chapter_changed(summary: Dictionary)
## Pensiun dimulai (v2b): {month, jht, jp_monthly, jp_lump, years}.
signal retirement_started(info: Dictionary)
## Efek penuaan berubah di ulang tahun ini (v2b langkah 2), di luar pergantian bab. Dikirim setelah laporan bulanan.
signal aging_changed(age: int)
## Status Kritis dimulai (v2b langkah 3): {health, age, chance}. Peringatan wajib sebelum peluang meninggal berlaku.
signal critical_started(info: Dictionary)
## Pemberitahuan masa senja tahunan mulai usia 70 (v2b langkah 3): {age, chance, aging}.
signal twilight_notice(info: Dictionary)
## Status Depresi dimulai (v2b langkah 4): {first, happiness}; first = pesan dukungan tampil pertama kali.
signal depression_started(info: Dictionary)

## Versi slot save. Naik ke 2 di v1.5 (pasar harian); save lama ditolak, tanpa migrasi.
const SAVE_VERSION := 3
## Versi data pemain (user://player.json): kuis, tutorial, riwayat. Tidak ikut naik
## agar progres kuis tidak hilang saat format slot save berubah.
const PLAYER_VERSION := 1
const ASSETS_PATH := "res://data/assets.json"
const ECONOMY_PATH := "res://data/economy.json"
const MARKET_PATH := "res://data/market.json"
const NEWS_PATH := "res://data/news.json"
const QUIZ_PATH := "res://data/quiz.json"

var economy: Dictionary = {}  # isi data/economy.json
## true setelah new_game() atau load_from_dict(); layar judul belum memulai game.
var is_active := false

# --- Profil & kondisi pemain ---
var player_name := ""
var avatar := 0
var background: Dictionary = {}  # salah satu economy.backgrounds
var difficulty: Dictionary = {}  # salah satu economy.difficulties
var month: int = 0  # 0 = Jan tahun 1
var cash: int = 0  # Rupiah disimpan sebagai int (hindari error pembulatan float)
var health: int = 0  # 0..100
var happiness: int = 0  # 0..100
var food_id: String = ""
var housing_id: String = ""
var story_seen: Array[String] = [] # cerita/petunjuk per permainan yang sudah tampil
var market := Market.new()
var net_worth_history: Array[float] = []
var last_report: Dictionary = {}
var rng := RandomNumberGenerator.new()  # RNG event & karier (terpisah dari RNG pasar)

# --- Kondisi akhir & statistik ---
var stats: Dictionary = {}  # lihat _new_stats()
var negative_cash_months := 0  # berturut-turut; mencapai batas = bangkrut
var zero_health_months := 0
var zero_happiness_months := 0
var goals_reached: Array[String] = []
var is_over := false
var end_result: Dictionary = {}

# --- Modul per domain (scripts/game/) ---
var progress := Progress.new(self)
var career := Career.new(self)
var characters := Characters.new(self)
var education := Education.new(self)
var insurance := Insurance.new(self)
var debt := Debt.new(self)
var events := LifeEvents.new(self)
var portfolio := Portfolio.new(self)
var research := Research.new(self)
var leverage := Leverage.new(self)
var contracts := Contracts.new(self)
var annual := Annual.new(self)
var budget := Budget.new(self)
var dreams := Dreams.new(self)
var vehicles := Vehicles.new(self)
var properties := Properties.new(self)
var targets := Targets.new(self)
var activities := Activities.new(self)
var life := Life.new(self)
var mental := Mental.new(self)
## Urutan dipakai untuk reset, simpan/muat, dan efek event. Karier sebelum rencana gaji
## (rencana awal memakai gaji); pendidikan sebelum aktivitas (energi memakai beban kuliah);
## impian sebelum kendaraan (save lama: impian kendaraan yang terwujud menjadi kendaraan). Riset (rumor
## pasar) dan proyek sampingan memakai RNG sendiri, jadi urutannya tidak memengaruhi undian modul lain.
## Leverage (v2a) tidak memakai angka acak sama sekali.
var modules: Array[GameModule] = [progress, career, characters, education, insurance, debt, events, portfolio,
	research, leverage, contracts, budget, dreams, vehicles, properties, targets, activities, annual, life, mental]

var fast_forwarding := false
var _advancing := false  # di tengah advance_month(): pencapaian diperiksa sekali di akhirnya
## Naik setiap game baru / dimuat (tidak disimpan). SaveManager memakainya untuk tahu apakah
## slot di database masih "permainan yang sama" sehingga cukup ditulis bagian barunya saja.
var run_id := 0
var _deferred: Array[Callable] = []  # signal yang ditunda selama lompat waktu
var _report_signals: Array[Callable] = []  # impian & kelulusan, dikirim setelah laporan

# --- Data global pemain (user://player.json), TIDAK di-reset saat game baru ---
## Kuis: jatahnya mengikuti minggu nyata, jadi tidak boleh ikut slot save.
var quiz := QuizManager.new()
## Pencapaian & kosmetik (bingkai avatar, gelar), berlaku lintas permainan (v1.5d).
var achievements := Achievements.new(self)
## Statistik sesi bermain untuk playtest (penutup v1.5), hanya disimpan di perangkat.
var sessions := PlaySessions.new()
var tutorial_done := false
var hints_seen: Array[String] = []
var history: Array[Dictionary] = []  # ringkasan permainan sebelumnya (maks 10)


func _ready() -> void:
	economy = DataLoader.load_json(ECONOMY_PATH)
	var quiz_data := DataLoader.load_json(QUIZ_PATH)
	quiz.setup(quiz_data.get("questions", []), economy["quiz"], quiz_data.get("topics", []))
	for module: GameModule in modules:
		module.load_data()
	achievements.load_data()
	changed.connect(_on_changed)


# --- Alur permainan -------------------------------------------------------------------

## `profile`: { "name", "avatar", "background", "difficulty", "risk_profile" } (semua opsional).
func new_game(profile: Dictionary = {}, seed_value: int = -1) -> void:
	if seed_value < 0:
		seed_value = randi()
	rng.seed = seed_value + 1
	player_name = profile.get("name", "")
	if player_name.strip_edges() == "":
		player_name = tr("DEFAULT_PLAYER_NAME")
	avatar = int(profile.get("avatar", 0))
	run_id += 1
	background = find_option(economy["backgrounds"], profile.get("background", economy["default_background"]))
	difficulty = find_option(economy["difficulties"], profile.get("difficulty", economy["default_difficulty"]))

	month = 0
	cash = int(difficulty["start_cash"])
	health = int(economy["start_health"])
	happiness = int(economy["start_happiness"])
	food_id = background["default_food"]
	housing_id = background["default_housing"]
	story_seen.clear()
	stats = _new_stats()
	for module: GameModule in modules:
		module.reset()
	portfolio.risk_profile_id = profile.get("risk_profile", "moderate")
	_report_signals.clear()
	negative_cash_months = 0
	zero_health_months = 0
	zero_happiness_months = 0
	goals_reached.clear()
	is_over = false
	end_result = {}
	market = Market.new()
	market.setup(
		DataLoader.load_json(ASSETS_PATH).get("assets", []),
		DataLoader.load_json(MARKET_PATH),
		DataLoader.load_json(NEWS_PATH).get("news", []),
		seed_value)
	_start_month()
	net_worth_history = [net_worth()]
	stats["peak_net_worth"] = net_worth()
	annual.begin_year()
	life.begin()  # bab pertama (v2b)
	last_report = {}
	is_active = true
	progress.check_unlocks(false)
	portfolio.snapshot_turn()
	changed.emit()


func age() -> int:
	return age_at(month)


## Usia pemain pada bulan permainan `m` (mis. saat polis asuransi dibeli).
func age_at(m: int) -> int:
	return int(background["start_age"]) + floori(m / 12.0)


## Tombol "Lanjut": tutup bulan ini (pasar bergerak), lalu buka bulan baru.
## Urutan signal: month_advanced (laporan) -> stage_unlocked -> event_triggered.
func advance_month() -> void:
	if events.has_pending() or is_over:
		return  # event bulan ini harus diputuskan dulu
	_advancing = true
	var finished_targets := targets.finalize()
	var net_worth_before := net_worth()
	var invest_before := portfolio.investments_value()
	var start_prices := portfolio.current_prices()
	var level_before := price_level()
	var idle_money := maxf(cash, 0.0) + portfolio.units_of(budget.emergency_asset_id()) + dreams.funds()
	var interest := portfolio.pay_interest() + dreams.pay_interest()
	var news := market.step(month + 1, research.market_input(month + 1))  # rumor ikut menggerakkan harga
	var month_inflation := price_level() / level_before - 1.0
	var trade := portfolio.turn_trade_result(start_prices)  # transaksi manual, sebelum pesanan otomatis
	var executed := portfolio.execute_orders()
	var rumor_result := research.after_market()
	var leverage_result := leverage.check_month()  # biaya inap, margin call & likuidasi harian (v2a)
	var sold_value := 0.0
	for sale: Dictionary in executed:
		sold_value += float(sale["units"]) * float(sale["price"])
	var invest_change := portfolio.investments_value() + sold_value - invest_before
	var daily_worth := portfolio.daily_worth_series(net_worth_before, executed)

	var from_month := month
	month += 1
	var start_report := _start_month()
	var delayed := events.resolve_delayed()
	var forced_sales := portfolio.cover_negative_cash()
	var warnings := _update_danger_counters()
	var health_report := life.check_health()  # v2b: undian peluang meninggal (setelah peringatan) & status Kritis
	var mental_report := mental.month_check() if life.death.is_empty() else {}  # v2b: status Depresi & pemulihan
	progress.xp += int(economy["xp_per_month"])
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
		"movers": portfolio.movers_since(start_prices),
		"targets": finished_targets,
		"trade_edge": trade["edge"],
		"turn_trades": trade["trades"],
		"turn_fees": trade["fees"],
		"dreams_progress": dreams.progress_report(),
		"trade_fee": portfolio.month_costs["trade_fee"],
		"trade_tax": portfolio.month_costs["trade_tax"],
		"orders": executed,
		"interest_tax": portfolio.month_costs["interest_tax"],
		"inflation_month": month_inflation,
		"inflation_year": market.inflation,
		"vehicle_depreciation": vehicles.depreciation_since(from_month, level_before),
		"erosion": idle_money * month_inflation,
	})
	last_report.merge(health_report)
	last_report.merge(mental_report)
	if not rumor_result.is_empty():
		last_report["rumors"] = [rumor_result]
	if not leverage_result.is_empty():
		last_report["leverage"] = leverage_result
	annual.add_month(last_report)
	if month % 12 == 0:  # Januari: laporan tahun lalu (v1.5d), tampil setelah laporan bulanan
		var year_report := annual.close_year(floori(month / 12.0))
		queue_after_report(func() -> void: year_closed.emit(year_report))
	dreams.queue_overdue()
	portfolio.snapshot_turn()
	portfolio.month_costs = portfolio.new_month_costs()  # pajak & biaya sudah masuk laporan ini
	changed.emit()
	if not fast_forwarding:
		month_advanced.emit(last_report)
	flush_report_signals()
	_advancing = false
	check_achievements()
	sessions.record_month(int(Time.get_unix_time_from_system()))
	# Tawaran pekerjaan berjenjang didahului event wawancara (lihat Career.scheduled_events).
	if not career.job_offers.is_empty() and career.interview_offer_index() < 0 and not fast_forwarding:
		job_offers_received.emit(career.job_offers)
	if _check_end():
		return
	_check_goals()
	progress.check_unlocks(true)
	events.roll()
	state_committed.emit()


## Awal bulan: properti diproses (harga, sewa, biaya, penjualan), hasil lamaran diumumkan, gaji masuk
## (kecuali menganggur/cuti), biaya hidup & biaya kendaraan terpotong, kesehatan & kebahagiaan berubah, cicilan utang lalu premi & uang kuliah dibayar,
## proyek sampingan diproses (hasil & energi bulan ini), rencana gaji dijalankan, target, lowongan & tawaran proyek
## baru muncul. Januari: penyesuaian inflasi + kenaikan prestasi.
func _start_month() -> Dictionary:
	var life_report := life.month_start()  # v2b: pensiun di usia 60 (sebelum gaji), bab baru
	var property_report := properties.month_step()  # sebelum biaya hidup: rumah yang laku = kembali menyewa
	var food := food_option()
	var housing := housing_option()
	var health_before := health
	var happiness_before := happiness
	var new_year := month > 0 and month % 12 == 0
	var salary_raise := career.index_salary() if new_year and career.is_employed() else 0.0
	var merit := career.merit_raise() if new_year else {}
	var job_news := career.resolve_applications()
	var working := career.is_employed() and career.unpaid_months == 0  # cuti tanpa gaji = tidak bekerja bulan ini
	var paid := career.monthly_pay()
	life.accrue(paid)  # iuran JHT & JP (v2b)
	var pension := life.pension_payment()  # Jaminan Pensiun bulanan setelah pensiun
	if pension > 0:
		stats["total_pension"] = int(stats.get("total_pension", 0)) + pension
	var performance_before := career.performance
	career.work_month(working)

	var food_cost := option_cost(food)
	var housing_cost := option_cost(housing)
	var vehicle_cost := vehicles.running_cost()
	var salary_tax := income_tax(paid)
	cash += paid + pension - salary_tax - food_cost - housing_cost - vehicle_cost
	budget.month_income = paid - salary_tax  # gaji bersih: dasar rencana gaji
	stats["total_salary"] += paid
	stats["total_taxes"] += salary_tax
	stats["total_living"] += food_cost + housing_cost
	stats["vehicle_costs"] += vehicle_cost
	if food_id == "luxury" or housing["id"] == "apartment":
		stats["luxury_months"] += 1
	var aging_health := life.health_decline()  # penurunan kesehatan alami karena usia (v2b)
	var mental_drain := mental.health_drain()  # Depresi: kesehatan turun perlahan, berhenti di batas aman (v2b)
	health = clampi(health + int(food["health"]) + int(housing["health"]) + _drift("health", health, working) - aging_health
		- mental_drain, 0, 100)
	happiness = clampi(happiness + int(food["happiness"]) + int(housing["happiness"]) + vehicles.happiness()
		+ _drift("happiness", happiness, working), 0, 100)
	var debt_report := debt.pay_installments()  # kewajiban utang sebelum premi, kuliah, dan rencana gaji
	var premiums := insurance.pay_premiums()
	var study_report := education.study_month()
	activities.energy_capacity = activities.energy_max()  # setelah kuliah bulan ini diketahui (beban energi)
	activities.energy = activities.energy_capacity
	activities.counts.clear()
	var contract_report := contracts.month_step()  # proyek sampingan: hasil, lalu energi bulan ini
	# Rencana gaji baru berjalan setelah pemain menyimpannya pertama kali (lihat Budget.set_plan).
	var budget_report := budget.apply(budget.month_income) if budget.plan.get("confirmed", false) else {}
	dreams.check()
	targets.items = targets.roll()
	career.refresh_board()

	return {
		"salary": paid,
		"income_tax": salary_tax,
		"unemployed": not career.is_employed() and not life.retired,
		"retired": life.retired,
		"pension": pension,
		"unpaid_leave": career.is_employed() and paid == 0,
		"applications_accepted": job_news["accepted"],
		"applications_rejected": job_news["rejected"],
		"food_cost": food_cost,
		"housing_cost": housing_cost,
		"vehicle_cost": vehicle_cost,
		"health_delta": health - health_before,
		"aging_health": aging_health,
		"happiness_delta": happiness - happiness_before,
		"salary_raise": salary_raise,
		"performance": roundi(career.performance) if working and career.is_career() else -1,
		"performance_delta": roundi(career.performance) - roundi(performance_before),
	}.merged(merit).merged(life_report).merged(property_report).merged(debt_report).merged(premiums).merged(study_report) \
		.merged(budget_report).merged(contract_report)


## Perubahan kesehatan & kebahagiaan per bulan dari pekerjaan: beban kerja jabatan (jobs.json
## "workload"), stres mencari kerja saat menganggur (economy.json "monthly_drift"), atau nol saat
## cuti tanpa gaji. Di bawah ambang, tubuh & pikiran pulih alami (lebih cepat saat sangat rendah)
## agar pemain pasif tidak terus merosot.
func _drift(stat: String, value: int, working: bool) -> int:
	var drift: Dictionary = economy.get("monthly_drift", {})
	var change := 0
	if working:
		change = int(career.current_job_def().get("workload", {}).get(stat, 0))
	elif not career.is_employed():  # pensiun (v2b) tanpa stres mencari kerja
		change = int(drift.get("retired" if life.retired else "unemployed", {}).get(stat, 0))
	if value < int(drift.get("deep_below", -1)):
		change += int(drift.get("deep_recover", 0))
	elif value < int(drift.get("recover_below", 0)):
		change += int(drift.get("recover", 0))
	return change


# --- Efek event & aktivitas -----------------------------------------------------------

## Efek dari pilihan event, efek tertunda, dan aktivitas (format "effects" di data/events/*.json).
## Kas, kesehatan, dan kebahagiaan ditangani di sini; kunci lain oleh modul pemiliknya
## (lihat apply_effects() di tiap modul), dengan urutan sesuai `modules`.
func apply_effects(e: Dictionary) -> void:
	cash += nominal(e.get("cash", 0)) + roundi(career.salary * float(e.get("cash_salary", 0.0)))
	health = clampi(health + int(e.get("health", 0)), 0, 100)
	happiness = clampi(happiness + int(e.get("happiness", 0)), 0, 100)
	for module: GameModule in modules:
		module.apply_effects(e)


## Angka yang ditampilkan sebagai "perubahan" setelah event/aktivitas (lihat diff()).
func snapshot() -> Dictionary:
	return {"cash": cash, "health": health, "happiness": happiness, "xp": progress.xp,
		"salary": career.salary, "investments": portfolio.investments_value(), "skill": floori(career.skill),
		"performance": roundi(career.performance), "debt": debt.outstanding(), "credit": debt.credit_score}.merged(
		_rel_snapshot())


## Kedekatan tiap tokoh untuk diff() ("rel_bima": 60, ...), tanpa menyentuh state.
func _rel_snapshot() -> Dictionary:
	var result := {}
	for id: String in characters.rel:
		result["rel_" + id] = int(characters.rel[id])
	return result


func diff(before: Dictionary) -> Dictionary:
	var after := snapshot()
	var changes := {}
	for key: String in before:
		var delta: float = after[key] - before[key]
		if absf(delta) > 0.5:
			changes[key] = delta
	return changes


## Signal yang dikirim SETELAH laporan bulanan (impian terwujud, kelulusan), agar urutan
## popup: laporan -> perayaan.
func queue_after_report(send: Callable) -> void:
	_report_signals.append(send)


func flush_report_signals() -> void:
	var pending := _report_signals.duplicate()
	_report_signals.clear()
	for send: Callable in pending:
		if fast_forwarding:
			_deferred.append(send)
		else:
			send.call()


func emit_later(sig: Signal, arg: Variant) -> void:
	if fast_forwarding:
		_deferred.append(func() -> void: sig.emit(arg))
	else:
		sig.emit(arg)


# --- Biaya hidup, pajak, inflasi ------------------------------------------------------

func food_option() -> Dictionary:
	return find_option(economy["food"], food_id)


## Tempat tinggal bulan ini: rumah sendiri yang dihuni (tanpa sewa), atau pilihan sewa housing_id.
func housing_option() -> Dictionary:
	var home := properties.home()
	if not home.is_empty():
		return properties.home_option(home)
	return find_option(economy["housing"], housing_id)


func monthly_expenses() -> int:
	return option_cost(food_option()) + option_cost(housing_option())


## Pilihan baru berlaku saat awal bulan berikutnya.
func set_food(id: String) -> void:
	food_id = id
	changed.emit()


## Memilih tempat tinggal sewaan. Jika sedang menghuni rumah sendiri, rumahnya menjadi kosong.
func set_housing(id: String) -> void:
	housing_id = id
	properties.move_out()
	changed.emit()


func find_option(options: Array, id: String) -> Dictionary:
	for option: Dictionary in options:
		if option["id"] == id:
			return option
	push_error("Opsi tidak ditemukan: %s" % id)
	return options[0]


## Biaya sebuah pilihan makan/tempat tinggal: harga hari ini x pengali tingkat kesulitan.
func option_cost(option: Dictionary) -> int:
	return nominal(option["cost"] * difficulty["expense_mult"])


## Kas + tabungan dana darurat cukup untuk berapa bulan biaya hidup, biaya kendaraan, cicilan,
## premi, dan uang kuliah (ditampilkan di Beranda saat menganggur).
func runway_months() -> int:
	var monthly := maxi(monthly_expenses() + vehicles.running_cost() + properties.running_cost()
		+ debt.installments_total() + insurance.premiums_total() + education.tuition_fee(), 1)
	return floori((maxf(cash, 0.0) + budget.emergency_balance()) / monthly)


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


## Indeks harga: 1.0 = harga di awal permainan, 1.25 = harga-harga sudah naik 25%.
func price_level() -> float:
	return market.price_level if market != null else 1.0


## Harga awal permainan -> harga hari ini, dibulatkan ke `step` Rupiah. Semua harga di file
## data (makanan, sewa, biaya event & aktivitas, impian, hadiah kuis) adalah harga AWAL permainan.
func nominal(amount: float, step: int = 1000) -> int:
	return roundi(amount * price_level() / step) * step


## Nilai `amount` Rupiah hari ini dalam harga awal permainan (nilai riil).
func real_value(amount: float) -> float:
	return amount / price_level()


## Bunga tabungan per tahun setelah pajak, untuk dibandingkan dengan inflasi.
func savings_rate() -> float:
	var asset := market.get_asset(budget.emergency_asset_id())
	return market.rate_for(asset) * (1.0 - asset.interest_tax)


func round_thousand(value: float) -> int:
	return maxi(0, floori(value / 1000.0) * 1000)


## Kekayaan bersih = semua aset (termasuk kendaraan & properti) dikurangi utang (sisa pokok + tunggakan).
func net_worth() -> float:
	return cash + portfolio.investments_value() + dreams.funds() + vehicles.total_value() + properties.total_value() \
		- debt.outstanding() + leverage.total_equity()


## Neraca (v1.5c langkah 4) untuk tab Portofolio & layar akhir: rincian yang sama dengan net_worth().
## -> {assets: [{key, value}], debts: [{name, value}], total_assets, total_debt, net_worth}
func balance_sheet() -> Dictionary:
	var emergency := budget.emergency_balance()
	var assets: Array[Dictionary] = [
		{"key": "LBL_CASH", "value": cash},
		{"key": "SHEET_EMERGENCY", "value": emergency},
		{"key": "SHEET_INVESTMENTS", "value": portfolio.investments_value() - emergency},
		{"key": "SHEET_DREAMS", "value": dreams.funds()},
		{"key": "SHEET_VEHICLES", "value": vehicles.total_value()},
		{"key": "SHEET_PROPERTIES", "value": properties.total_value()},
	]
	if not leverage.positions.is_empty():  # ekuitas posisi leverage (v2a)
		assets.append({"key": "SHEET_LEVERAGE", "value": leverage.total_equity()})
	var debts: Array[Dictionary] = []
	for loan: Dictionary in debt.loans:
		debts.append({"name": debt.product(loan["product"])["name"], "value": float(loan["balance"]) + int(loan["arrears"])})
	var total_assets := 0.0
	for item: Dictionary in assets:
		total_assets += float(item["value"])
	return {"assets": assets, "debts": debts, "total_assets": total_assets, "total_debt": debt.outstanding(),
		"net_worth": net_worth()}


# --- Data global pemain: tutorial, petunjuk, cerita ----------------------------------

func mark_tutorial_done() -> void:
	tutorial_done = true
	player_changed.emit()
	if is_active:
		progress.check_unlocks(true)
		changed.emit()


## Mengembalikan true jika petunjuk ini BARU pertama kali dilihat (berlaku semua permainan).
func consume_hint(key: String) -> bool:
	if key in hints_seen:
		return false
	hints_seen.append(key)
	player_changed.emit()
	return true


## Cerita/petunjuk sekali per permainan (mis. cerita hari pertama). true jika baru pertama kali.
func mark_story(key: String) -> bool:
	if key in story_seen:
		return false
	story_seen.append(key)
	return true


## Periksa pencapaian setelah data berubah (aksi pemain) dan sekali di akhir advance_month().
## Pencapaian baru dicatat di laporan tahunan, disimpan ke data pemain, lalu diumumkan.
func check_achievements() -> void:
	var fresh := achievements.check()
	if fresh.is_empty():
		return
	annual.note_achievements(fresh)
	player_changed.emit()
	emit_later(achievements_unlocked, fresh)


func _on_changed() -> void:
	if is_active and not _advancing:
		check_achievements()


func player_to_dict() -> Dictionary:
	return {"version": PLAYER_VERSION, "quiz": quiz.to_dict(), "achievements": achievements.to_dict(),
		"sessions": sessions.to_dict(), "tutorial_done": tutorial_done, "hints_seen": hints_seen, "history": history}


func player_from_dict(d: Dictionary) -> void:
	quiz.from_dict(d.get("quiz", {}))
	achievements.from_dict(d.get("achievements", {}))
	sessions.from_dict(d.get("sessions", {}))
	tutorial_done = d.get("tutorial_done", false)
	hints_seen.assign(d.get("hints_seen", []))
	history.assign(d.get("history", []))


# --- Simpan / muat (SaveManager memetakannya ke tabel SQLite) -------------------------

## Kamus save datar (format SAVE_VERSION 3). Tiap modul menulis kuncinya sendiri (save_to).
func to_dict() -> Dictionary:
	var d := {
		"version": SAVE_VERSION,
		"profile": {"name": player_name, "avatar": avatar,
			"background": background["id"], "difficulty": difficulty["id"]},
		"month": month, "cash": cash, "health": health, "happiness": happiness,
		"food_id": food_id, "housing_id": housing_id, "story_seen": story_seen,
		"net_worth_history": net_worth_history, "last_report": last_report,
		"rng_seed": str(rng.seed), "rng_state": str(rng.state),
		"market": market.to_dict(),
		"stats": stats,
		"danger": [negative_cash_months, zero_health_months, zero_happiness_months],
		"goals_reached": goals_reached,
	}
	for module: GameModule in modules:
		module.save_to(d)
	return d


## JSON mengubah semua angka menjadi float, jadi field int dikonversi ulang dengan int().
## Mengembalikan false jika data tidak valid / versinya tidak dikenal.
func load_from_dict(d: Dictionary) -> bool:
	if int(d.get("version", 0)) != SAVE_VERSION:
		push_warning("Versi save tidak dikenal: %s" % d.get("version"))
		return false
	var profile: Dictionary = d["profile"]
	player_name = profile["name"]
	avatar = int(profile["avatar"])
	background = find_option(economy["backgrounds"], profile["background"])
	difficulty = find_option(economy["difficulties"], profile["difficulty"])
	month = int(d["month"])
	cash = int(d["cash"])
	health = int(d["health"])
	happiness = int(d["happiness"])
	food_id = d["food_id"]
	housing_id = d["housing_id"]
	story_seen.assign(d.get("story_seen", ["start"]))  # save lama: cerita hari pertama sudah lewat
	net_worth_history.assign(d["net_worth_history"])
	last_report = d["last_report"]
	rng.seed = String(d["rng_seed"]).to_int()
	rng.state = String(d["rng_state"]).to_int()
	stats = _new_stats().merged(d.get("stats", {}), true)  # save lama (M5) belum punya stats
	var danger: Array = d.get("danger", [0, 0, 0])
	negative_cash_months = int(danger[0])
	zero_health_months = int(danger[1])
	zero_happiness_months = int(danger[2])
	goals_reached.assign(d.get("goals_reached", []))
	for module: GameModule in modules:
		module.load_from(d)
	_report_signals.clear()
	is_over = false
	end_result = {}

	market = Market.new()
	market.load_state(
		DataLoader.load_json(ASSETS_PATH).get("assets", []),
		DataLoader.load_json(MARKET_PATH),
		DataLoader.load_json(NEWS_PATH).get("news", []),
		d["market"])
	events.restore_pending_vars()
	life.begin()  # save sebelum v2b: bab dimulai sekarang, JHT/JP diperkirakan
	run_id += 1
	is_active = true
	changed.emit()
	return true


# --- Kondisi menang/kalah & statistik (M6, GDD 5.11) ----------------------------------

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
		"loans_taken": 0, "borrowed_total": 0, "debt_interest": 0.0, "debt_fees": 0, "missed_payments": 0,
		"loan_defaults": 0, "loans_paid_off": 0,
		"vehicles_bought": 0, "vehicles_sold": 0, "vehicles_seized": 0, "vehicle_costs": 0,
		"properties_bought": 0, "properties_sold": 0, "properties_seized": 0, "property_costs": 0,
		"rent_income": 0, "property_gains": 0, "offer_loans": 0, "restructures": 0, "refinances": 0,
		"projects_done": 0, "projects_excellent": 0, "projects_revised": 0, "projects_failed": 0, "project_income": 0,
		"scams_avoided": 0, "mortgages_paid_off": 0, "bear_months_held": 0,
		"best_trade": {}, "worst_trade": {}, "best_event": {}, "worst_event": {},
	}


## Simpan nilai terbaik/terburuk (mis. transaksi paling untung & paling rugi).
func record_extreme(best_key: String, worst_key: String, value: float, info: Dictionary) -> void:
	var record := info.merged({"value": value, "month": month})
	if value > 0 and (stats[best_key].is_empty() or value > stats[best_key]["value"]):
		stats[best_key] = record
	elif value < 0 and (stats[worst_key].is_empty() or value < stats[worst_key]["value"]):
		stats[worst_key] = record


func _track_monthly_stats(worth: float) -> void:
	stats["peak_net_worth"] = maxf(stats["peak_net_worth"], worth)
	if worth > 10_000_000 and cash / worth > 0.7:
		stats["cash_heavy_months"] += 1
	# Menahan saham/reksa dana saham saat pasar lesu (pencapaian Investor Sabar, v1.5d).
	if market.regime_of("stock") == "bear":
		var held := 0.0
		for id: String in portfolio.holdings:
			if market.get_asset(id).factor == "stock":
				held += portfolio.holding_value(id)
		if held >= nominal(float(achievements.data.get("bear_hold_min_value", 5_000_000))):
			stats["bear_months_held"] += 1


## Hitung bulan berturut-turut dalam kondisi bahaya. Mengembalikan teks peringatan untuk laporan.
func _update_danger_counters() -> Array[String]:
	var limit := int(economy["end"]["danger_months"])
	negative_cash_months = negative_cash_months + 1 if cash < 0 else 0
	zero_health_months = zero_health_months + 1 if health <= 0 else 0
	zero_happiness_months = 0  # v2b langkah 4: kebahagiaan habis tidak lagi mengakhiri permainan (lihat Mental)
	var warnings: Array[String] = []
	if negative_cash_months > 0:
		warnings.append(tr("WARN_BANKRUPT") % [negative_cash_months, limit])
	if zero_health_months > 0:
		warnings.append(tr("WARN_HEALTH") % [zero_health_months, limit])
	return warnings


## Akhir permainan. v2b: meninggal dunia (selalu setelah peringatan, lihat Life.check_health) lebih
## dulu; kesehatan 0 selama danger_months = meninggal karena sakit parah (peringatan tiap bulan);
## batas usia = tutup usia. Pensiun tidak lagi mengakhiri permainan.
func _check_end() -> bool:
	var limit := int(economy["end"]["danger_months"])
	if not life.death.is_empty():
		finish_game("died", life.death["cause"])
	elif negative_cash_months >= limit:
		finish_game("lose", "bankrupt")
	elif zero_health_months >= limit:
		life.die("illness")
		finish_game("died", "illness")
	elif age() >= int(life.data["max_age"]):
		life.die("old_age")
		finish_game("died", "old_age")
	return is_over


func _check_goals() -> void:
	if net_worth() >= float(economy["end"]["win_net_worth"]) and not "millionaire" in goals_reached:
		goals_reached.append("millionaire")
		emit_later(goal_reached, "millionaire")
	if is_financially_free() and not "freedom" in goals_reached:
		goals_reached.append("freedom")
		emit_later(goal_reached, "freedom")


## Aturan 4%: investasi bisa "menggaji" pemain sebesar 4% per tahun tanpa habis, ditambah sewa
## bersih properti yang disewakan (v1.5c).
func passive_income() -> float:
	return portfolio.investments_value() * float(economy["end"]["freedom_rate"]) / 12.0 + properties.rent_income()


## Pengeluaran rutin sebulan yang harus ditutup pendapatan pasif agar bebas finansial:
## biaya hidup + biaya kendaraan + cicilan utang + premi asuransi + belanja gaya hidup sesuai
## rencana gaji. Gaya hidup ikut naik bersama gaji, jadi "lifestyle creep" ikut menjauhkan
## kebebasan finansial.
func monthly_spending() -> int:
	return monthly_expenses() + vehicles.running_cost() + properties.running_cost() + debt.installments_total() \
		+ insurance.premiums_total() + budget.lifestyle_spending()


func is_financially_free() -> bool:
	return passive_income() > 0 and passive_income() >= monthly_spending()


## Skor warisan: kekayaan (per Rp1 juta) + kesehatan + kebahagiaan + level x 10.
func legacy_score() -> int:
	return floori(net_worth() / 1_000_000.0) + health + happiness + progress.level() * 10


## Mengakhiri permainan. `result_type`: win | lose | retired | died (v2b; reason = penyebab:
## old_age | critical | illness, payout = uang pertanggungan asuransi jiwa untuk ahli waris).
func finish_game(result_type: String, reason: String) -> void:
	is_over = true
	events.pending = {}
	end_result = {
		"type": result_type, "reason": reason, "month": month, "age": age(),
		"net_worth": net_worth(), "peak": stats["peak_net_worth"], "score": legacy_score(),
	}
	if result_type == "died":
		end_result["payout"] = int(life.death.get("payout", 0))
	history.push_front({
		"name": player_name, "avatar": avatar, "background": background["id"],
		"difficulty": difficulty["id"], "type": result_type, "reason": reason,
		"months": month, "net_worth": net_worth(), "date": int(Time.get_unix_time_from_system()),
	})
	history.resize(mini(history.size(), 10))
	player_changed.emit()
	changed.emit()
	emit_later(game_ended, end_result)


# --- Lompat waktu (M6.5, disimpan untuk masa pensiun v2b) ----------------------------

## Maju beberapa bulan sekaligus. Berhenti lebih awal jika ada event, peringatan,
## penjualan paksa, instrumen baru, target tercapai, atau game berakhir.
## Laporan bulanan digabung menjadi satu; signal lain ditunda agar popup tampil
## SETELAH laporan gabungan (urutan sama seperti saat maju satu bulan).
func fast_forward(months: int) -> void:
	if events.has_pending() or is_over:
		return
	fast_forwarding = true
	var reports: Array[Dictionary] = []
	for i in months:
		var goals_before := goals_reached.size()
		var stages_before := progress.unlocked_stages.size()
		advance_month()
		reports.append(last_report)
		var interrupted: bool = is_over or events.has_pending() \
				or goals_reached.size() != goals_before or progress.unlocked_stages.size() != stages_before \
				or not last_report["warnings"].is_empty() or not last_report["forced_sales"].is_empty() \
				or last_report.has("critical_started") or last_report.has("twilight") \
				or last_report.has("depression_started")  # v2b: peringatan kesehatan, usia & kesehatan mental
		if interrupted:
			break
	fast_forwarding = false
	last_report = _merge_reports(reports)
	month_advanced.emit(last_report)
	var pending := _deferred.duplicate()
	_deferred.clear()
	for send: Callable in pending:
		send.call()


func _merge_reports(reports: Array[Dictionary]) -> Dictionary:
	var merged: Dictionary = reports[-1].duplicate(true)
	if reports.size() == 1:
		return merged
	for key: String in ["salary", "food_cost", "housing_cost", "invest_change", "interest",
			"health_delta", "happiness_delta", "lifestyle_cost", "emergency_saved",
			"income_tax", "trade_fee", "trade_tax", "interest_tax", "insurance_premium", "loan_paid",
			"vehicle_cost", "vehicle_depreciation", "rent_income", "rent_tax", "property_cost"]:
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
	for key: String in ["loan_missed", "loan_closed", "loan_defaults", "loan_rate_changes", "property_sold",
			"property_notes", "rumors", "contracts_done"]:
		var items: Array = []
		for r: Dictionary in reports:
			items.append_array(r.get(key, []))
		merged[key] = items
	merged["credit_before"] = reports[0].get("credit_before", debt.credit_score)
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
	merged["movers"] = portfolio.movers_since(reports[0]["start_prices"])
	return merged
