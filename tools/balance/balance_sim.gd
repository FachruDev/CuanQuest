extends Node
## Simulator keseimbangan ekonomi (v1.5a langkah 5). Memainkan banyak permainan dengan
## beberapa "tipe pemain" tanpa UI, lalu mencetak ringkasan per tipe pada tahun 10, 20, 30.
## Analogi web: seperti load test / skrip seed yang menjalankan ribuan sesi otomatis.
##
## Jalankan (data asli aman karena --save-root):
##   Godot --headless --path . res://tools/balance/balance_sim.tscn -- --save-root=user://_sim/
##       [--games=40] [--years=30] [--persona=all|hemat|penabung|boros|spekulan|acak] [--difficulty=normal]
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
}
const CHECKPOINTS := [5, 10, 20, 30]

var _rng := RandomNumberGenerator.new()


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
	var snapshots := {}
	var freedom_month := -1
	var millionaire_month := -1
	var start_salary := 0  # gaji pekerjaan pertama (v1.5b: mulai tanpa kerja)
	var first_job_month := -1
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
		"freedom_month": freedom_month, "millionaire_month": millionaire_month, "first_job_month": first_job_month}


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
	var money := (float(effects.get("cash", 0.0)) - _out_of_pocket(choice)) / expenses
	if scam:
		return -_out_of_pocket(choice) - (1e9 if choice.has("outcomes") or effects.get("cash", 0.0) > 0.0 else 0.0)
	return money * 6.0 + float(effects.get("health", 0)) + float(effects.get("happiness", 0)) \
		+ float(effects.get("salary_pct", 0.0)) * 100.0 - float(effects.get("unpaid_months", 0)) * 10.0 \
		+ float(effects.get("performance", 0)) * 0.4 + float(effects.get("skill", 0)) * 2.0 \
		+ float(effects.get("offer_raise", 0.0)) * 150.0 + float(effects.get("promote", 0)) * 40.0 \
		+ float(effects.get("scholarship", 0.0)) * 30.0 + float(effects.get("sponsored_study", 0)) * 20.0 \
		- float(effects.get("study_delay", 0)) * 3.0


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
				"scholarship", "sponsored_study", "study_delay"]:
			result[key] = float(result.get(key, 0.0)) + part[0] * float(effects.get(key, 0))
		result["cash"] = float(result.get("cash", 0.0)) + part[0] * GameState.nominal(effects.get("cash", 0))
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
