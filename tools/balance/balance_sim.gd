extends Node
## Simulator keseimbangan ekonomi (v1.5a langkah 5). Memainkan banyak permainan dengan
## beberapa "tipe pemain" tanpa UI, lalu mencetak ringkasan per tipe pada tahun 10, 20, 30.
## Analogi web: seperti load test / skrip seed yang menjalankan ribuan sesi otomatis.
##
## Jalankan (data asli aman karena --save-root):
##   Godot --headless --path . res://tools/balance/balance_sim.tscn -- --save-root=user://_sim/
##       [--games=40] [--years=30] [--persona=all|hemat|penabung|boros|spekulan|acak|pelajar|pengutang|pengendara|
##       pembeli_rumah|pembeli_rumah_kota|pembeli_rumah_nekat|pemburu_rumor|periset|pekerja_lepas|gila_kerja]
##       [--difficulty=normal]
##       [--background=s1|d3|sma]
## Folder tools/ tidak ikut ke APK (exclude_filter di export_presets.cfg).

## Tipe pemain. invest = porsi gaji untuk autodebet; choice = cara memilih di event.
const PERSONAS := {
	"hemat": {"desc": "Hemat & investasi rutin", "food": "standard", "housing": "kos", "lifestyle": 0.05,
		"emergency": 0.15, "invest": 0.25, "insurance": {"health": "health_basic"}, "choice": "prudent",
		"quiz": true, "lump_invest": true, "activities": true},
	"penabung": {"desc": "Menabung saja (tabungan)", "food": "standard", "housing": "kos", "lifestyle": 0.05,
		"emergency": 0.3, "invest": 0.0, "insurance": {"health": "health_basic"}, "choice": "prudent",
		"quiz": false, "cash_to_savings": true, "activities": true},
	"boros": {"desc": "Gaya hidup mewah", "food": "luxury", "housing": "kos", "lifestyle": 0.2,
		"emergency": 0.0, "invest": 0.0, "insurance": {}, "choice": "lavish", "quiz": false},
	"spekulan": {"desc": "Spekulasi saham & kripto", "food": "standard", "housing": "kos", "lifestyle": 0.1,
		"emergency": 0.05, "invest": 0.0, "insurance": {}, "choice": "gambler", "quiz": true, "speculate": true},
	"acak": {"desc": "Pilihan acak", "food": "", "housing": "", "lifestyle": 0.05, "emergency": 0.1,
		"invest": 0.0, "insurance": {}, "choice": "random", "quiz": false, "random_trades": true},
	"pelajar": {"desc": "Hemat + kuliah & kursus", "food": "standard", "housing": "kos", "lifestyle": 0.05,
		"emergency": 0.15, "invest": 0.25, "insurance": {"health": "health_basic"}, "choice": "prudent",
		"quiz": true, "lump_invest": true, "activities": true, "study": true, "courses": true},
	"pengutang": {"desc": "Gaya hidup mewah + KTA saat kas menipis", "food": "luxury", "housing": "kos", "lifestyle": 0.2,
		"emergency": 0.0, "invest": 0.0, "insurance": {}, "choice": "lavish", "quiz": false, "borrow": true},
	"pengendara": {"desc": "Hemat + motor & mobil kredit", "food": "standard", "housing": "kos", "lifestyle": 0.05,
		"emergency": 0.15, "invest": 0.25, "insurance": {"health": "health_basic", "vehicle": "vehicle_allrisk"},
		"choice": "prudent", "quiz": true, "lump_invest": true, "activities": true, "vehicles": true},
	"pembeli_rumah": {"desc": "Hemat + KPR rumah untuk dihuni", "food": "standard", "housing": "kos", "lifestyle": 0.05,
		"emergency": 0.15, "invest": 0.25, "insurance": {"health": "health_basic"}, "choice": "prudent",
		"quiz": true, "lump_invest": true, "activities": true,
		"homes": [["subsidi", "kpr_subsidi", 0.05], ["house45", "kpr", 0.2]]},
	"pembeli_rumah_kota": {"desc": "Hemat + KPR Rumah Tipe 45 untuk dihuni", "food": "standard", "housing": "kos",
		"lifestyle": 0.05, "emergency": 0.15, "invest": 0.25, "insurance": {"health": "health_basic"}, "choice": "prudent",
		"quiz": true, "lump_invest": true, "activities": true, "homes": [["house45", "kpr", 0.2]]},
	"pembeli_rumah_nekat": {"desc": "KPR Rumah Tipe 45 DP 10% tanpa cadangan, pilihan acak", "food": "standard",
		"housing": "kos", "lifestyle": 0.1, "emergency": 0.0, "invest": 0.1, "insurance": {}, "choice": "random",
		"quiz": false, "lump_invest": true, "homes": [["house45", "kpr", 0.1]], "home_buffer": 0.0},
	"pemburu_rumor": {"desc": "Hemat + membeli setiap rumor naik tanpa riset", "food": "standard", "housing": "kos",
		"lifestyle": 0.05, "emergency": 0.15, "invest": 0.25, "insurance": {"health": "health_basic"}, "choice": "prudent",
		"quiz": true, "lump_invest": true, "activities": true, "rumors": "follow"},
	"periset": {"desc": "Hemat + riset mendalam, membeli hanya jika riset mendukung", "food": "standard", "housing": "kos",
		"lifestyle": 0.05, "emergency": 0.15, "invest": 0.25, "insurance": {"health": "health_basic"}, "choice": "prudent",
		"quiz": true, "lump_invest": true, "activities": true, "rumors": "research"},
	"pekerja_lepas": {"desc": "Hemat + 1 proyek sampingan sekaligus (teliti)", "food": "standard", "housing": "kos",
		"lifestyle": 0.05, "emergency": 0.15, "invest": 0.25, "insurance": {"health": "health_basic"}, "choice": "prudent",
		"quiz": true, "lump_invest": true, "activities": true, "projects": 1},
	"gila_kerja": {"desc": "Hemat + selalu 2 proyek sampingan sekaligus", "food": "standard", "housing": "kos",
		"lifestyle": 0.05, "emergency": 0.15, "invest": 0.25, "insurance": {"health": "health_basic"}, "choice": "prudent",
		"quiz": true, "lump_invest": true, "activities": true, "projects": 2},
}
const CHECKPOINTS := [5, 10, 20, 30]

var _rng := RandomNumberGenerator.new()
var _rumor_position: Dictionary = {}  # aset yang dibeli karena rumor (v1.5d), dijual setelah rumor terjawab
var _rumor_trades: Array[float] = []  # imbal hasil tiap transaksi rumor (0.05 = +5%)


func _ready() -> void:
	var args := _args()
	var games := int(args.get("games", "40"))
	var years := int(args.get("years", "30"))
	var difficulty: String = args.get("difficulty", "normal")
	var background: String = args.get("background", "s1")
	var names: Array = PERSONAS.keys() if args.get("persona", "all") == "all" else [args["persona"]]
	# Simpan otomatis tidak perlu (dan memperlambat) selama simulasi.
	for connection: Dictionary in GameState.state_committed.get_connections():
		GameState.state_committed.disconnect(connection["callable"])
	GameState.tutorial_done = true
	print("Simulasi %d permainan x %d tahun, kesulitan %s, latar %s" % [games, years, difficulty, background])
	var start := Time.get_ticks_msec()
	for persona: String in names:
		var results: Array[Dictionary] = []
		for g in games:
			results.append(_play(persona, 9000 + g, years, difficulty, background))
		_print_summary(persona, results, years)
	print("Selesai dalam %d detik" % ((Time.get_ticks_msec() - start) / 1000))
	get_tree().quit()


func _args() -> Dictionary:
	var result := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts := arg.trim_prefix("--").split("=", true, 1)
			result[parts[0]] = parts[1]
	return result


# --- Satu permainan ----------------------------------------------------------------

func _play(persona: String, seed_value: int, years: int, difficulty: String, background: String) -> Dictionary:
	var p: Dictionary = PERSONAS[persona]
	_rng.seed = seed_value * 7 + persona.hash()
	GameState.new_game({"name": "Sim", "background": background, "difficulty": difficulty}, seed_value)
	GameState.dreams.asked = true
	GameState.quiz.correct_ids.clear()
	if p["food"] != "":
		GameState.set_food(p["food"])
		GameState.set_housing(p["housing"])
	GameState.insurance.set_policies(p["insurance"])
	_update_plan(p)
	_rumor_position = {}
	_rumor_trades.clear()
	var snapshots := {}
	var freedom_month := -1
	var millionaire_month := -1
	var start_salary := 0  # gaji pekerjaan pertama (v1.5b: mulai tanpa kerja)
	var first_job_month := -1
	var home_month := -1
	var default_month := -1  # macet pertama
	var recovered_month := -1  # skor kredit kembali >= 60 setelah macet pertama
	for m in years * 12:
		if GameState.is_over:
			break
		_resolve_events(p)
		_monthly_actions(p)
		if GameState.month % 12 == 0:
			_update_plan(p)
		GameState.advance_month()
		_resolve_events(p)  # termasuk wawancara (negosiasi gaji) sebelum tawaran diputuskan
		_take_offer()
		if start_salary == 0 and GameState.career.is_employed():
			start_salary = roundi(GameState.career.salary / GameState.price_level())
			first_job_month = GameState.month
		if home_month < 0 and not GameState.properties.owned.is_empty():
			home_month = GameState.month
		if default_month < 0 and int(GameState.stats["loan_defaults"]) > 0:
			default_month = GameState.month
		elif default_month >= 0 and recovered_month < 0 and GameState.debt.credit_score >= 60:
			recovered_month = GameState.month
		if freedom_month < 0 and GameState.is_financially_free():
			freedom_month = GameState.month
		if millionaire_month < 0 and GameState.net_worth() >= float(GameState.economy["end"]["win_net_worth"]):
			millionaire_month = GameState.month
		if GameState.month % 12 == 0 and floori(GameState.month / 12.0) in CHECKPOINTS:
			snapshots[floori(GameState.month / 12.0)] = _snapshot(start_salary)
	var final := _snapshot(start_salary)
	for year: int in CHECKPOINTS:
		if year <= years and not snapshots.has(year):
			snapshots[year] = final  # permainan berakhir lebih awal: pakai kondisi terakhir
	return {"snapshots": snapshots, "over": GameState.is_over,
		"reason": GameState.end_result.get("reason", "") if GameState.is_over else "",
		"lost_month": GameState.month if GameState.is_over else -1,
		"freedom_month": freedom_month, "millionaire_month": millionaire_month, "first_job_month": first_job_month,
		"home_month": home_month, "default_month": default_month, "recovered_month": recovered_month,
		"rumors": int(GameState.research.record["rumors"]), "rumor_trades": _rumor_trades.duplicate(),
		"research": GameState.research.record.duplicate(true)}


func _snapshot(start_salary: int) -> Dictionary:
	var level := GameState.price_level()
	return {
		"alive": not GameState.is_over,
		"worth": GameState.net_worth(),
		"real_worth": GameState.real_value(GameState.net_worth()),
		"real_salary_growth": (GameState.career.salary / level) / float(maxi(start_salary, 1)),
		"real_salary": GameState.career.salary / level,
		"employed": GameState.career.is_employed(),
		"skill": GameState.career.skill,
		"months_unemployed": int(GameState.stats["months_unemployed"]),
		"health": GameState.health, "happiness": GameState.happiness,
		"taxes": float(GameState.stats["total_taxes"]),
		"claims": float(GameState.stats["insurance_claims"]),
		"premiums": float(GameState.stats["insurance_premiums"]),
		"uninsured": float(GameState.stats["uninsured_medical"]),
		"events": int(GameState.stats["events"]),
		"salary_total": float(GameState.stats["total_salary"]),
		"living_total": float(GameState.stats["total_living"]),
		"promotions": int(GameState.stats["promotions"]),
		"layoffs": int(GameState.stats["layoffs"]),
		"top_level": int(GameState.stats["top_level"]),
		"performance": roundi(GameState.career.performance) if GameState.career.is_career() else -1,
		"level": int(GameState.career.current_job_def()["level"]) if GameState.career.is_career() else 0,
		"education": GameState.education.level,
		"graduations": int(GameState.stats["graduations"]),
		"tuition": float(GameState.stats["tuition"]),
		"loans_taken": int(GameState.stats["loans_taken"]),
		"missed_payments": int(GameState.stats["missed_payments"]),
		"loan_defaults": int(GameState.stats["loan_defaults"]),
		"debt_interest": float(GameState.stats["debt_interest"]),
		"credit_score": GameState.debt.credit_score,
		"offer_loans": int(GameState.stats["offer_loans"]),
		"restructures": int(GameState.stats["restructures"]),
		"refinances": int(GameState.stats["refinances"]),
		"motor": GameState.vehicles.owns("motor"),
		"car": GameState.vehicles.owns("car"),
		"vehicle_value": GameState.vehicles.total_value(),
		"vehicle_costs": float(GameState.stats["vehicle_costs"]),
		"vehicles_seized": int(GameState.stats["vehicles_seized"]),
		"vehicles_bought": int(GameState.stats["vehicles_bought"]),
		"own_home": not GameState.properties.home().is_empty(),
		"properties_bought": int(GameState.stats["properties_bought"]),
		"properties_seized": int(GameState.stats["properties_seized"]),
		"property_value": GameState.properties.total_value(),
		"property_costs": float(GameState.stats["property_costs"]),
		"projects_done": int(GameState.stats["projects_done"]),
		"projects_failed": int(GameState.stats["projects_failed"]),
		"projects_revised": int(GameState.stats["projects_revised"]),
		"project_income": float(GameState.stats["project_income"]),
		"reputation": GameState.contracts.reputation,
	}


## Rencana gaji tiap Januari: porsi investasi dibagi ke aset yang sudah terbuka.
func _update_plan(p: Dictionary) -> void:
	for category: String in p["insurance"]:  # polis berhenti (kas habis): daftar lagi seperti pemain sungguhan
		if not GameState.insurance.policies.has(category):
			GameState.insurance.set_policies({category: p["insurance"][category]})
	var plan := GameState.budget.default_plan()
	plan["lifestyle"] = p["lifestyle"]
	plan["emergency"] = p["emergency"]
	var invest := {}
	var share: float = p["invest"]
	if share > 0.0:
		var unlocked := GameState.budget.autodebet_assets().map(func(a: MarketAsset) -> String: return a.id)
		var mix: Array = [["RDPU", share]]
		if "RDS" in unlocked:
			mix = [["RDS", share - 0.1], ["RDPU", 0.1]]
		if "BSNT" in unlocked:
			mix = [["RDS", share - 0.15], ["BSNT", 0.05], ["MPGN", 0.05], ["RDPU", 0.05]]
		for item: Array in mix:
			if item[0] in unlocked and item[1] > 0.0:
				invest[item[0]] = item[1]
	plan["invest"] = invest
	GameState.budget.set_plan(plan)


## Semua tipe pemain mencari kerja: lamar lowongan dengan gaji x peluang terbaik
## (jika sudah bekerja, hanya yang gajinya minimal 10% lebih tinggi).
func _job_actions() -> void:
	var options: Array = []
	for i in GameState.career.job_board.size():
		if GameState.career.apply_block_reason(i) != "":
			continue
		var opening: Dictionary = GameState.career.job_board[i]
		if GameState.career.is_employed() and opening["salary"] <= GameState.career.salary * 1.1:
			continue
		options.append([float(opening["salary"]) * GameState.career.hire_chance(GameState.career.job_def(opening["job_id"])), i])
	options.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for option: Array in options.slice(0, int(GameState.career.data["applications_per_month"])):
		GameState.career.apply_job(option[1])


## Tipe pemain yang kuliah: daftar program pertama yang tersedia jika kas cukup untuk 6 bulan kuliah.
func _study_actions(expenses: float) -> void:
	if GameState.education.is_studying():
		return
	var options := GameState.education.available_programs()
	if not options.is_empty() and GameState.cash >= int(options[0]["fee"]) * 6 + expenses:
		GameState.education.enroll(options[0]["def"]["id"])


## Tipe pemain pengutang: saat kas di bawah sebulan biaya hidup, ambil KTA terbesar yang disetujui
## (tenor terpanjang agar cicilannya lolos batas rasio cicilan).
func _borrow_actions(expenses: float) -> void:
	if GameState.cash >= expenses or GameState.debt.active_count("kta") > 0:
		return
	var prod := GameState.debt.product("kta")
	var tenor: int = GameState.debt.tenor_options(prod).back()
	var amounts := GameState.debt.amount_options(prod)
	for i in range(amounts.size() - 1, -1, -1):
		if GameState.debt.take("kta", amounts[i], tenor)["ok"]:
			return


## Tipe pemain pengendara: motor kredit (DP 20%, 24 bulan) begitu disetujui; mobil kredit (DP 30%,
## 48 bulan) saat gaji riil >= Rp15 jt dan kas + investasi cukup untuk DP + 3 bulan biaya hidup.
func _vehicle_actions(expenses: float) -> void:
	var vehicles := GameState.vehicles
	if not vehicles.owns("motor"):
		vehicles.buy("motor", "credit", 0.2, 24)
	if vehicles.owns("car") or GameState.career.salary / GameState.price_level() < 15_000_000:
		return
	var dp := vehicles.price("car") * 0.3
	if GameState.portfolio.liquid_assets() + GameState.portfolio.investments_value() < dp + expenses * 3:
		return
	if not vehicles.buy_quote("car", "credit", 0.3, 48)["requirements"].all(func(r: Dictionary) -> bool:
			return r["met"] or r["type"] == "cash"):
		return
	var short := dp + expenses - GameState.cash  # jual investasi secukupnya untuk uang muka
	for asset_id: String in GameState.portfolio.holdings.keys():
		if short <= 0.0:
			break
		if GameState.portfolio.is_locked(asset_id):
			continue
		var amount := mini(ceili(short * 1.01), ceili(GameState.portfolio.holding_value(asset_id)))
		if GameState.portfolio.sell(asset_id, amount)["ok"]:
			short = dp + expenses - GameState.cash
	vehicles.buy("car", "credit", 0.3, 48)


## Tipe pemain pembeli rumah: pilihan pertama di `homes` yang syaratnya terpenuhi ([properti, KPR, DP]),
## saat kas + investasi cukup untuk DP + biaya beli + `buffer` bulan biaya hidup. Tenor terpendek yang
## cicilannya lolos batas rasio cicilan. Rumahnya langsung dihuni.
func _home_actions(homes: Array, expenses: float, buffer: float) -> void:
	var properties := GameState.properties
	if not properties.owned.is_empty():
		return
	for option: Array in homes:
		var tenor := _passing_tenor(option[0], option[1], option[2])
		if tenor < 0:
			continue
		var q := properties.buy_quote(option[0], option[1], option[2], tenor)
		var upfront := float(q["upfront"])
		if GameState.portfolio.liquid_assets() + GameState.portfolio.investments_value() < upfront + expenses * buffer:
			continue
		_raise_cash(upfront + minf(expenses, expenses * buffer))
		if properties.buy(option[0], option[1], option[2], tenor, "live")["ok"]:
			return


## Tenor terpendek yang semua syaratnya (selain kas) terpenuhi; -1 jika tidak ada.
func _passing_tenor(id: String, method: String, dp: float) -> int:
	for tenor: int in GameState.debt.tenor_options(GameState.debt.product(method)):
		var reqs: Array = GameState.properties.buy_quote(id, method, dp, tenor)["requirements"]
		if reqs.all(func(r: Dictionary) -> bool: return r["met"] or r["type"] == "cash"):
			return tenor
	return -1


## Jual investasi secukupnya agar kas mencapai `target`.
func _raise_cash(target: float) -> void:
	for asset_id: String in GameState.portfolio.holdings.keys():
		var short := target - GameState.cash
		if short <= 0.0:
			return
		if GameState.portfolio.is_locked(asset_id):
			continue
		GameState.portfolio.sell(asset_id, mini(ceili(short * 1.01), ceili(GameState.portfolio.holding_value(asset_id))))


## Ambil tawaran bergaji tertinggi (jika lebih baik dari pekerjaan sekarang).
func _take_offer() -> void:
	if GameState.career.job_offers.is_empty():
		return
	var best := 0
	for i in GameState.career.job_offers.size():
		if GameState.career.job_offers[i]["salary"] > GameState.career.job_offers[best]["salary"]:
			best = i
	if not GameState.career.is_employed() or GameState.career.job_offers[best]["salary"] > GameState.career.salary:
		GameState.career.accept_offer(best)
	else:
		GameState.career.decline_offers()


func _monthly_actions(p: Dictionary) -> void:
	_job_actions()
	var expenses := float(GameState.monthly_expenses())
	if p.get("study", false):
		_study_actions(expenses)
	if p.get("borrow", false):
		_borrow_actions(expenses)
	if p.get("vehicles", false):
		_vehicle_actions(expenses)
	if p.has("homes"):
		_home_actions(p["homes"], expenses, float(p.get("home_buffer", 3.0)))
	if p.has("rumors"):  # sebelum aktivitas: riset memakai energi
		_rumor_actions(p["rumors"], expenses)
	if p.has("projects"):  # sebelum aktivitas: proyek memakai energi
		_project_actions(int(p["projects"]))
	if p.get("courses", false) and GameState.career.skill < 80.0 and GameState.cash > expenses * 2:
		GameState.activities.perform("course")
	if p["quiz"]:
		_simulate_quiz()
	if p.get("activities", false):  # aktivitas gratis untuk menjaga kesehatan & kebahagiaan
		for i in 4:
			var id := "exercise" if GameState.health <= GameState.happiness else "rest"
			if GameState.health >= 80 and GameState.happiness >= 80:
				break
			if not GameState.activities.perform(id)["ok"] and not GameState.activities.perform("rest")["ok"]:
				break
	if p.get("cash_to_savings", false) and GameState.cash > expenses * 2:
		GameState.portfolio.buy("TAB", int(GameState.cash - expenses * 2))
	if p.get("lump_invest", false) and GameState.month % 12 == 6 and GameState.cash > expenses * 3:
		var target := "RDS" if GameState.progress.is_asset_unlocked("RDS") else "RDPU"
		GameState.portfolio.buy(target, int(GameState.cash - expenses * 3))
	if p.get("speculate", false):
		if _rng.randf() < 0.4 and GameState.cash > expenses:
			var pool := ["GRD", "MRP", "BARA", "NUSA", "RDS", "RDPU"].filter(func(id: String) -> bool:
				return GameState.progress.is_asset_unlocked(id))
			GameState.portfolio.buy(pool[0] if _rng.randf() < 0.6 else pool[_rng.randi() % pool.size()], int(GameState.cash * 0.3))
		elif _rng.randf() < 0.2 and not GameState.portfolio.holdings.is_empty():
			var held: Array = GameState.portfolio.holdings.keys()
			var id: String = held[_rng.randi() % held.size()]
			GameState.portfolio.sell(id, int(GameState.portfolio.holding_value(id) * 0.5))
	if p.get("random_trades", false):
		if GameState.cash > expenses * 3 and _rng.randf() < 0.3:
			var ids := ["RDPU", "DEP", "BSNT", "RDS", "GRD"]
			GameState.portfolio.buy(ids[_rng.randi() % ids.size()], int(GameState.cash * 0.1))
		elif _rng.randf() < 0.15 and not GameState.portfolio.holdings.is_empty():
			var held: Array = GameState.portfolio.holdings.keys()
			var id: String = held[_rng.randi() % held.size()]
			GameState.portfolio.sell(id, int(GameState.portfolio.holding_value(id) * 0.5))


## Tipe pemain rumor (v1.5d langkah 2): "follow" membeli setiap rumor naik tanpa riset; "research" memakai
## riset mendalam dan membeli hanya jika hasilnya mendukung (rumor naik "benar" atau rumor turun "hoaks").
## Posisi dijual sebulan kemudian, setelah rumor terjawab.
func _rumor_actions(style: String, expenses: float) -> void:
	var research := GameState.research
	if not _rumor_position.is_empty() and not (research.has_rumor()
			and int(research.rumor["month"]) == int(_rumor_position["month"])):
		var id: String = _rumor_position["asset"]
		var value := minf(float(_rumor_position["units"]) * GameState.market.get_asset(id).price,
			GameState.portfolio.holding_value(id))
		var sold := GameState.portfolio.sell(id, ceili(value)) if value > 0.0 else {"ok": false}
		if sold["ok"]:
			_rumor_trades.append(float(sold["proceeds"]) / float(_rumor_position["paid"]) - 1.0)
		_rumor_position = {}
	if not research.has_rumor() or not _rumor_position.is_empty():
		return
	var rumor := research.rumor
	var buy: bool = rumor["direction"] == "up"
	if style == "research":
		if research.block_reason("deep") == "":
			research.research("deep")
		if not research.is_researched("deep"):
			return
		buy = research.verdict("deep") == (rumor["direction"] == "up")
	var amount := int(minf(GameState.cash - expenses * 2.0, GameState.net_worth() * 0.2))
	if not buy or amount < 1_000_000:
		return
	var result := GameState.portfolio.buy(rumor["asset"], amount)
	if result["ok"]:
		_rumor_position = {"asset": rumor["asset"], "month": rumor["month"], "paid": amount, "units": result["units"]}


## Tipe pemain proyek sampingan (v1.5d langkah 3): ambil tawaran dengan nilai harapan terbesar
## (bayaran x peluang berhasil) sampai `limit` proyek aktif; teliti jika energi cukup, selain itu cepat.
func _project_actions(limit: int) -> void:
	var contracts := GameState.contracts
	while contracts.active.size() < limit and not contracts.board.is_empty():
		var best := 0
		for i in contracts.board.size():
			var offer: Dictionary = contracts.board[i]
			var top: Dictionary = contracts.board[best]
			if float(offer["pay"]) * contracts.chance_for(offer, "careful") > float(top["pay"]) * contracts.chance_for(top, "careful"):
				best = i
		var strategy := "careful" if contracts.accept_block_reason(best, "careful") == "" else "fast"
		if not contracts.accept(best, strategy)["ok"]:
			return


## Pemain yang rajin kuis: soal dasar terjawab di bulan 2, soal risiko di bulan 8
## (jatah kuis mengikuti minggu nyata, jadi di simulasi cukup ditandai benar).
func _simulate_quiz() -> void:
	for item: Array in [[2, "basics"], [8, "risk"]]:
		if GameState.month == item[0]:
			var count := 0
			for q: Dictionary in GameState.quiz.questions:
				if q["topic"] == item[1] and count < 3:
					GameState.quiz.correct_ids[q["id"]] = true
					count += 1


# --- Pilihan event per tipe pemain -------------------------------------------------

func _resolve_events(p: Dictionary) -> void:
	var guard := 0
	while GameState.events.has_pending() and guard < 10:
		guard += 1
		GameState.events.resolve(_pick_choice(GameState.events.pending, p["choice"]))


func _pick_choice(event: Dictionary, style: String) -> int:
	var choices: Array = event["choices"]
	var affordable: Array[int] = []
	for i in choices.size():
		if GameState.events.can_choose(choices[i]):
			affordable.append(i)
	if affordable.is_empty():
		return choices.size() - 1
	match style:
		"random":
			return affordable[_rng.randi() % affordable.size()]
		"lavish":
			var best := affordable[0]
			for i in affordable:
				if _out_of_pocket(choices[i]) > _out_of_pocket(choices[best]):
					best = i
			return best
		"gambler":
			if event["category"] in ["scam", "finance", "market"]:
				return affordable[0]
			return affordable[_rng.randi() % affordable.size()]
	# prudent: tolak penipuan, sisanya nilai manfaat kesehatan/kebahagiaan dibanding biayanya.
	var best := affordable[0]
	var best_score := -INF
	for i in affordable:
		var score := _choice_score(choices[i], event["category"] == "scam")
		if score > best_score:
			best = i
			best_score = score
	return best


func _out_of_pocket(choice: Dictionary) -> float:
	return float(GameState.events.choice_cost(choice) - GameState.insurance.cover(choice))


func _choice_score(choice: Dictionary, scam: bool) -> float:
	var effects := _expected_effects(choice)
	var expenses := float(maxi(GameState.monthly_expenses(), 1))
	var money := (float(effects.get("cash", 0.0)) + _debt_money(choice) - _out_of_pocket(choice)) / expenses
	if scam:
		return -_out_of_pocket(choice) - (1e9 if choice.has("outcomes") or effects.get("cash", 0.0) > 0.0 else 0.0)
	return money * 6.0 + float(effects.get("health", 0)) + float(effects.get("happiness", 0)) \
		+ float(effects.get("salary_pct", 0.0)) * 100.0 - float(effects.get("unpaid_months", 0)) * 10.0 \
		+ float(effects.get("performance", 0)) * 0.4 + float(effects.get("skill", 0)) * 2.0 \
		+ float(effects.get("offer_raise", 0.0)) * 150.0 + float(effects.get("promote", 0)) * 40.0 \
		+ float(effects.get("scholarship", 0.0)) * 30.0 + float(effects.get("sponsored_study", 0)) * 20.0 \
		- float(effects.get("study_delay", 0)) * 3.0 + float(effects.get("credit_score", 0)) * 0.3 \
		+ float(effects.get("rel", 0.0)) * 0.15  # kedekatan dengan tokoh (v1.5d)


## Nilai uang efek utang (v1.5c langkah 4), dari isian event yang sedang tampil: bunga tawaran kredit
## (ditambah harga barang jika langsung dibelanjakan) adalah biaya; membayar tunggakan / pokok bukan
## kerugian (utang berkurang); take over KPR menghemat bunga selama masa bunga tetap barunya.
func _debt_money(choice: Dictionary) -> float:
	var vars: Dictionary = GameState.events.pending_vars
	var effects: Dictionary = choice.get("effects", {})
	var money := 0.0
	if effects.has("take_loan"):
		money -= float(vars.get("interest", 0)) + (float(vars.get("amount", 0)) if effects["take_loan"] == "spend" else 0.0)
	if effects.get("pay_arrears", false):
		money += float(vars.get("arrears", 0))
	if effects.get("prepay_part", false):
		money += float(vars.get("prepay_amount", 0))
	if effects.get("refinance", false):
		money += float(vars.get("saving", 0)) + float(vars.get("fee", 0))
	return money


## Efek rata-rata pilihan (outcomes ditimbang peluangnya); cash dalam Rupiah hari ini.
func _expected_effects(choice: Dictionary) -> Dictionary:
	var result := {}
	var parts: Array = []
	if choice.has("outcomes"):
		for o: Dictionary in choice["outcomes"]:
			parts.append([float(o["chance"]), o.get("effects", {})])
	else:
		parts.append([1.0, choice.get("effects", {})])
	for part: Array in parts:
		var effects: Dictionary = part[1]
		for key: String in ["health", "happiness", "salary_pct", "unpaid_months", "performance", "skill", "offer_raise", "promote",
				"scholarship", "sponsored_study", "study_delay", "credit_score"]:
			result[key] = float(result.get(key, 0.0)) + part[0] * float(effects.get(key, 0))
		result["cash"] = float(result.get("cash", 0.0)) + part[0] * GameState.nominal(effects.get("cash", 0))
		var rel_total := 0.0  # jumlah perubahan kedekatan semua tokoh
		for id: String in effects.get("rel", {}):
			rel_total += float(effects["rel"][id])
		result["rel"] = float(result.get("rel", 0.0)) + part[0] * rel_total
	return result


# --- Ringkasan ---------------------------------------------------------------------

func _print_summary(persona: String, results: Array[Dictionary], years: int) -> void:
	var lost := results.filter(func(r: Dictionary) -> bool: return r["over"])
	var reasons := {}
	for r: Dictionary in lost:
		reasons[r["reason"]] = reasons.get(r["reason"], 0) + 1
	print("\n== %s (%s) ==" % [persona, PERSONAS[persona]["desc"]])
	print("  kalah: %d/%d %s" % [lost.size(), results.size(), str(reasons) if not reasons.is_empty() else ""])
	print("  bebas finansial: %s | Rp1 miliar: %s" % [
		_month_stat(results, "freedom_month"), _month_stat(results, "millionaire_month")])
	var first_jobs: Array = results.map(func(r: Dictionary) -> float: return float(r["first_job_month"]))
	first_jobs = first_jobs.filter(func(m: float) -> bool: return m >= 0.0)
	first_jobs.sort()
	if not first_jobs.is_empty():
		print("  kerja pertama: bulan ke-%d median, ke-%d (p90), tidak pernah bekerja %d%%" % [
			roundi(_pct(first_jobs, 0.5)), roundi(_pct(first_jobs, 0.9)), roundi(100.0 - 100.0 * first_jobs.size() / results.size())])
	for year: int in CHECKPOINTS:
		if year > years:
			continue
		var snaps: Array = results.map(func(r: Dictionary) -> Dictionary: return r["snapshots"][year])
		var employed := snaps.filter(func(s: Dictionary) -> bool: return s["employed"]).size()
		print("  tahun %2d: kekayaan riil %s | nominal median %s | gaji riil %s (x%s) | sehat %s | bahagia %s | bekerja %d%% | keahlian %d | jenjang %d | pendidikan %s" % [
			year, _range(snaps, "real_worth", true), Fmt.rupiah_short(_median(snaps, "worth")),
			Fmt.rupiah_short(_median(snaps, "real_salary")), Fmt.number(_median(snaps, "real_salary_growth"), 2), int(_median(snaps, "health")), int(_median(snaps, "happiness")),
			roundi(100.0 * employed / snaps.size()), int(_median(snaps, "skill")), int(_median(snaps, "level")),
			GameState.education.level_name(int(_median(snaps, "education")))])
	var last: int = CHECKPOINTS.filter(func(y: int) -> bool: return y <= years).max()
	var finals: Array = results.map(func(r: Dictionary) -> Dictionary: return r["snapshots"][last])
	print("  tahun %d: gaji total %s | biaya hidup total %s (median, nominal)" % [last,
		Fmt.rupiah_short(_median(finals, "salary_total")), Fmt.rupiah_short(_median(finals, "living_total"))])
	print("  tahun %d: pajak total %s | premi asuransi %s | klaim %s | berobat tanpa asuransi %s (median, nominal)" % [
		last, Fmt.rupiah_short(_median(finals, "taxes")), Fmt.rupiah_short(_median(finals, "premiums")),
		Fmt.rupiah_short(_median(finals, "claims")), Fmt.rupiah_short(_median(finals, "uninsured"))])
	var laid_off := finals.filter(func(f: Dictionary) -> bool: return f["layoffs"] > 0).size()
	var careers := finals.filter(func(f: Dictionary) -> bool: return f["performance"] >= 0)
	print("  tahun %d: lulus kuliah median %d | uang kuliah median %s" % [last, int(_median(finals, "graduations")),
		Fmt.rupiah_short(_median(finals, "tuition"))])
	print("  tahun %d: promosi median %d | pernah PHK %d%% | jenjang tertinggi median %d | kinerja median %d" % [
		last, int(_median(finals, "promotions")), roundi(100.0 * laid_off / finals.size()),
		int(_median(finals, "top_level")), int(_median(careers, "performance")) if not careers.is_empty() else -1])
	var buyers := finals.filter(func(f: Dictionary) -> bool: return f["properties_bought"] > 0)
	if not buyers.is_empty():
		var homes: Array = results.map(func(r: Dictionary) -> float: return float(r["home_month"])).filter(
			func(m: float) -> bool: return m >= 0.0)
		homes.sort()
		print("  tahun %d: rumah sendiri %d%% | beli rumah median tahun %s | nilai properti median %s | PBB & perawatan total %s | pernah dilelang %d%%" % [
			last, roundi(100.0 * finals.filter(func(f: Dictionary) -> bool: return f["own_home"]).size() / finals.size()),
			Fmt.number(_pct(homes, 0.5) / 12.0, 1), Fmt.rupiah_short(_median(buyers, "property_value")),
			Fmt.rupiah_short(_median(buyers, "property_costs")),
			roundi(100.0 * buyers.filter(func(f: Dictionary) -> bool: return f["properties_seized"] > 0).size() / buyers.size())])
	var owners := finals.filter(func(f: Dictionary) -> bool: return f["vehicles_bought"] > 0)
	if not owners.is_empty():
		var seized := owners.filter(func(f: Dictionary) -> bool: return f["vehicles_seized"] > 0).size()
		print("  tahun %d: punya motor %d%% | punya mobil %d%% | biaya kendaraan total median %s | nilai kendaraan median %s | pernah ditarik %d%%" % [
			last, roundi(100.0 * finals.filter(func(f: Dictionary) -> bool: return f["motor"]).size() / finals.size()),
			roundi(100.0 * finals.filter(func(f: Dictionary) -> bool: return f["car"]).size() / finals.size()),
			Fmt.rupiah_short(_median(owners, "vehicle_costs")), Fmt.rupiah_short(_median(owners, "vehicle_value")),
			roundi(100.0 * seized / owners.size())])
	var borrowers := finals.filter(func(f: Dictionary) -> bool: return f["loans_taken"] > 0)
	if not borrowers.is_empty():
		var defaulted := borrowers.filter(func(f: Dictionary) -> bool: return f["loan_defaults"] > 0).size()
		print("  tahun %d: pernah berutang %d%% | pinjaman median %d | menunggak median %d kali | pernah macet %d%% | bunga utang median %s | skor kredit median %d" % [
			last, roundi(100.0 * borrowers.size() / finals.size()), int(_median(borrowers, "loans_taken")),
			int(_median(borrowers, "missed_payments")), roundi(100.0 * defaulted / borrowers.size()),
			Fmt.rupiah_short(_median(borrowers, "debt_interest")), int(_median(borrowers, "credit_score"))])
		var share := func(key: String) -> int:
			return roundi(100.0 * finals.filter(func(f: Dictionary) -> bool: return f[key] > 0).size() / finals.size())
		print("  tahun %d: terima tawaran kredit %d%% | restrukturisasi %d%% | take over KPR %d%%" % [
			last, share.call("offer_loans"), share.call("restructures"), share.call("refinances")])
	_print_rumors(results)
	var freelancers := finals.filter(func(f: Dictionary) -> bool: return f["projects_done"] + f["projects_failed"] > 0)
	if not freelancers.is_empty():
		print("  tahun %d: proyek selesai median %d | gagal median %d | revisi median %d | penghasilan proyek median %s (nominal) | reputasi median %d" % [
			last, int(_median(freelancers, "projects_done")), int(_median(freelancers, "projects_failed")),
			int(_median(freelancers, "projects_revised")), Fmt.rupiah_short(_median(freelancers, "project_income")),
			int(_median(freelancers, "reputation"))])
	var defaults: Array = results.filter(func(r: Dictionary) -> bool: return r["default_month"] >= 0)
	if not defaults.is_empty():
		var recovered: Array = defaults.filter(func(r: Dictionary) -> bool: return r["recovered_month"] >= 0)
		var waits: Array = recovered.map(func(r: Dictionary) -> float: return float(r["recovered_month"] - r["default_month"]))
		waits.sort()
		print("  macet: %d permainan | skor kredit pulih ke 60: %d%% (median %s bulan) | bangkrut setelah macet %d" % [
			defaults.size(), roundi(100.0 * recovered.size() / defaults.size()),
			Fmt.number(_pct(waits, 0.5), 0) if not waits.is_empty() else "-",
			defaults.filter(func(r: Dictionary) -> bool: return r["over"]).size()])


## Rumor & riset (v1.5d langkah 2): jumlah rumor per permainan; untuk tipe pemain rumor juga hasil transaksinya.
func _print_rumors(results: Array[Dictionary]) -> void:
	var counts: Array = results.map(func(r: Dictionary) -> float: return float(r["rumors"]))
	counts.sort()
	var trades: Array[float] = []
	var deep := [0, 0]
	var costs: Array = []
	for r: Dictionary in results:
		trades.append_array(r["rumor_trades"])
		deep[0] += int(r["research"]["deep"][0])
		deep[1] += int(r["research"]["deep"][1])
		costs.append(float(r["research"]["costs"]))
	var line := "  rumor: %s per permainan (median)" % Fmt.number(_pct(counts, 0.5), 0)
	if not trades.is_empty():
		var total := 0.0
		var wins := 0
		for t: float in trades:
			total += t
			wins += 1 if t > 0.0 else 0
		costs.sort()
		line += " | transaksi rumor %d (%s/permainan) | imbal hasil rata-rata %s | untung %d%%" % [trades.size(),
			Fmt.number(float(trades.size()) / results.size(), 1), Fmt.percent(total / trades.size()), roundi(100.0 * wins / trades.size())]
		if deep[0] > 0:
			line += " | riset mendalam tepat %d%% (%d) | biaya riset median %s" % [roundi(100.0 * deep[1] / deep[0]), deep[0],
				Fmt.rupiah_short(_pct(costs, 0.5))]
	print(line)


## "median Rp... (p10 ... p90 ...)"
func _range(snaps: Array, key: String, money: bool) -> String:
	var values: Array = snaps.map(func(s: Dictionary) -> float: return float(s[key]))
	values.sort()
	var fmt := func(v: float) -> String: return Fmt.rupiah_short(v) if money else Fmt.number(v, 2)
	return "%s (p10 %s, p90 %s)" % [fmt.call(_pct(values, 0.5)), fmt.call(_pct(values, 0.1)), fmt.call(_pct(values, 0.9))]


func _median(snaps: Array, key: String) -> float:
	var values: Array = snaps.map(func(s: Dictionary) -> float: return float(s[key]))
	values.sort()
	return _pct(values, 0.5)


static func _pct(sorted: Array, q: float) -> float:
	if sorted.is_empty():
		return 0.0
	return float(sorted[clampi(roundi(q * (sorted.size() - 1)), 0, sorted.size() - 1)])


## "65% tercapai, median tahun 18"
func _month_stat(results: Array[Dictionary], key: String) -> String:
	var months: Array = results.map(func(r: Dictionary) -> int: return int(r[key])).filter(func(m: int) -> bool: return m >= 0)
	if months.is_empty():
		return "0%"
	months.sort()
	return "%d%% (median tahun %s)" % [roundi(100.0 * months.size() / results.size()),
		Fmt.number(_pct(months, 0.5) / 12.0, 1)]
