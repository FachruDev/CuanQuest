class_name Budget
extends GameModule
## Rencana gaji & autodebet (v1.5-0 langkah 2): porsi gaji untuk gaya hidup, dana darurat,
## impian, dan investasi otomatis. Juga pengelola dana darurat (tabungan).

## Rencana gaji (v1.5-0): porsi dalam persen gaji. Dijalankan otomatis tiap awal bulan.
## {"lifestyle": 0.05, "emergency": 0.1, "invest": {asset_id: 0.1}, "salary_seen": int, "confirmed": bool}
var plan: Dictionary = {}
var plan_applied_month := -1  # bulan terakhir rencana dijalankan (cegah dobel)
var month_income := 0  # penghasilan yang benar-benar diterima bulan ini


func reset() -> void:
	plan = default_plan()
	plan_applied_month = -1


func save_to(d: Dictionary) -> void:
	d.merge({"plan": plan, "plan_applied_month": plan_applied_month, "month_income": month_income})


func load_from(d: Dictionary) -> void:
	plan = default_plan().merged(d.get("plan", {}), true)
	plan["salary_seen"] = int(plan["salary_seen"])
	plan_applied_month = int(d.get("plan_applied_month", -1))
	month_income = int(d.get("month_income", gs.career.salary))


## Jika kas kurang dari `amount`, kekurangannya diambil dari tabungan dana darurat (autodebet).
func draw_emergency(amount: int) -> void:
	var savings := emergency_asset_id()
	if gs.cash < amount and gs.portfolio.units_of(savings) >= amount - gs.cash:
		gs.portfolio.sell(savings, ceili(amount - gs.cash), "forced")


func config() -> Dictionary:
	return gs.economy["budget"]


func default_plan() -> Dictionary:
	var cfg := config()
	return {"lifestyle": float(cfg["default_lifestyle"]), "emergency": float(cfg["default_emergency"]),
		"invest": {}, "dreams": {}, "salary_seen": gs.career.salary, "confirmed": false}


## Rencana perlu dicek pemain: belum pernah disimpan, atau gaji pokok berubah sejak terakhir dicek.
func needs_review() -> bool:
	if not gs.career.is_employed():
		return false  # belum ada gaji untuk dibagi; popup muncul setelah diterima kerja
	return not plan.get("confirmed", false) or int(plan.get("salary_seen", 0)) != gs.career.salary


## Menyimpan rencana dari popup. Saat pertama kali disimpan, rencana langsung dijalankan
## untuk bulan ini (gaji bulan ini sudah masuk). Mengembalikan ringkasan yang dijalankan ({} jika tidak).
func set_plan(new_plan: Dictionary) -> Dictionary:
	var first: bool = not plan.get("confirmed", false)
	plan = new_plan.duplicate(true)
	plan["confirmed"] = true
	plan["salary_seen"] = gs.career.salary
	var applied := {}
	if first and plan_applied_month != gs.month:
		applied = apply(month_income)
		gs.dreams.check()
		gs.portfolio.snapshot_turn()  # autodebet pertama bukan transaksi manual
	gs.changed.emit()
	gs.state_committed.emit()
	gs.flush_report_signals()
	return applied


## Popup rencana ditutup tanpa disimpan: perubahan gaji dianggap sudah dilihat.
func acknowledge_review() -> void:
	plan["salary_seen"] = gs.career.salary


## Aset yang bisa diikutkan autodebet: sudah terbuka dan bukan tabungan/deposito.
func autodebet_assets() -> Array[MarketAsset]:
	var result: Array[MarketAsset] = []
	for asset: MarketAsset in gs.market.assets.values():
		if not asset.is_interest() and gs.progress.is_asset_unlocked(asset.id):
			result.append(asset)
	return result


func emergency_asset_id() -> String:
	return config()["emergency_asset"]


func emergency_balance() -> float:
	return gs.portfolio.holding_value(emergency_asset_id())


## Target dana darurat: N x pengeluaran pokok bulanan (makan + tempat tinggal).
func emergency_target() -> float:
	return float(gs.monthly_expenses() * int(config()["emergency_target_months"]))


## Efek kebahagiaan per bulan dari porsi gaya hidup (lihat economy.json budget.lifestyle_happiness).
func lifestyle_happiness(share: float) -> int:
	var effect := 0
	for row: Array in config()["lifestyle_happiness"]:
		if share + 0.0001 >= float(row[0]):
			effect = int(row[1])
	return effect


## Belanja gaya hidup sebulan menurut rencana gaji (0 jika belum bekerja atau rencana belum disimpan).
func lifestyle_spending() -> int:
	if not plan.get("confirmed", false) or not gs.career.is_employed():
		return 0
	return gs.round_thousand(gs.career.net_salary() * float(plan["lifestyle"]))


## Rincian rupiah sebuah rencana untuk penghasilan `income`. Satu sumber hitungan untuk
## popup rencana, kartu Beranda, dan eksekusi di awal bulan.
func preview_for(p: Dictionary, income: int) -> Dictionary:
	var basic := gs.monthly_expenses()
	var lifestyle := gs.round_thousand(income * float(p["lifestyle"]))
	var room := maxf(0.0, emergency_target() - emergency_balance())
	var emergency := mini(gs.round_thousand(income * float(p["emergency"])), gs.round_thousand(room))
	var invest: Array[Dictionary] = []
	var invest_total := 0
	for asset: MarketAsset in autodebet_assets():
		var share := float(p["invest"].get(asset.id, 0.0))
		if share <= 0.0:
			continue
		var amount := gs.round_thousand(income * share)
		invest.append({"id": asset.id, "name_key": asset.name_key, "share": share, "amount": amount})
		invest_total += amount
	var dream_items: Array[Dictionary] = []
	var dreams_total := 0
	for entry: Dictionary in gs.dreams.active():
		var share := float(p.get("dreams", {}).get(entry["id"], 0.0))
		if share <= 0.0:
			continue
		var needed := ceili(maxf(0.0, gs.dreams.cost_of(gs.dreams.find_def(entry["id"])) - entry["saved"]) / 1000.0) * 1000
		var amount := mini(gs.round_thousand(income * share), needed)  # jangan menabung melebihi biayanya
		dream_items.append({"id": entry["id"], "name": gs.dreams.find_def(entry["id"])["name"], "share": share, "amount": amount})
		dreams_total += amount
	var vehicle := gs.vehicles.running_cost()
	var property := gs.properties.running_cost()
	var rent := gs.properties.expected_rent()
	var debt := gs.debt.installments_total()
	var insurance := gs.insurance.premiums_total()
	var tuition := gs.education.tuition_fee()
	return {"income": income, "basic": basic, "vehicle": vehicle, "property": property, "rent": rent,
		"debt": debt, "insurance": insurance, "tuition": tuition, "lifestyle": lifestyle, "emergency": emergency,
		"emergency_room": room, "invest": invest, "invest_total": invest_total, "dreams": dream_items,
		"dreams_total": dreams_total,
		"surplus": income + rent - basic - vehicle - property - debt - insurance - tuition - lifestyle - emergency
			- invest_total - dreams_total}


## Menjalankan rencana setelah gaji masuk: belanja gaya hidup, setor dana darurat, lalu
## autodebet. Pos yang kasnya tidak cukup dilewati dan dicatat di laporan.
func apply(income: int) -> Dictionary:
	var result := {"lifestyle_cost": 0, "emergency_saved": 0, "autodebet": [], "autodebet_skipped": [],
		"dream_saved": []}
	plan_applied_month = gs.month
	if income <= 0:
		return result  # menganggur: tidak ada gaji untuk dibagi
	var preview := preview_for(plan, income)

	var lifestyle := mini(int(preview["lifestyle"]), maxi(gs.cash, 0))
	gs.cash -= lifestyle
	gs.stats["total_lifestyle"] += lifestyle
	gs.happiness = clampi(gs.happiness + lifestyle_happiness(float(lifestyle) / income), 0, 100)
	result["lifestyle_cost"] = lifestyle

	var emergency: int = preview["emergency"]
	if emergency >= 1000 and emergency <= gs.cash:
		if gs.portfolio.buy(emergency_asset_id(), emergency, "auto")["ok"]:
			result["emergency_saved"] = emergency

	for item: Dictionary in preview["dreams"]:  # pos impian sebelum autodebet
		var saved: int = item["amount"]
		if saved >= 1000 and saved <= gs.cash:
			gs.cash -= saved
			gs.dreams.find_entry(item["id"])["saved"] += saved
			result["dream_saved"].append({"name": item["name"], "amount": saved})
		elif saved >= 1000:
			result["autodebet_skipped"].append(item["name"])

	for item: Dictionary in preview["invest"]:
		var amount: int = item["amount"]
		if amount >= 1000 and amount <= gs.cash and gs.portfolio.buy(item["id"], amount, "auto")["ok"]:
			gs.stats["total_autodebet"] += amount
			result["autodebet"].append({"asset_key": item["name_key"], "amount": amount})
		else:
			result["autodebet_skipped"].append(item["name_key"])
	return result
