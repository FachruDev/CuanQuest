class_name Insurance
extends GameModule
## Asuransi (v1.5a langkah 3): polis per kategori, premi bulanan, masa tunggu, dan klaim saat event.
## Data: data/insurance.json.

const INSURANCE_PATH := "res://data/insurance.json"

var data: Dictionary = {}  # isi data/insurance.json
## Asuransi (v1.5a langkah 3): kategori -> {"id": id produk, "since": bulan polis dimulai}
var policies: Dictionary = {}


func load_data() -> void:
	data = DataLoader.load_json(INSURANCE_PATH)


func reset() -> void:
	policies.clear()


func save_to(d: Dictionary) -> void:
	d["policies"] = policies


func load_from(d: Dictionary) -> void:
	policies.clear()
	for category: String in d.get("policies", {}):
		var saved_policy: Dictionary = d["policies"][category]
		policies[category] = {"id": saved_policy["id"], "since": int(saved_policy["since"])}


func products_in(category: String) -> Array:
	return data.get("products", []).filter(func(p: Dictionary) -> bool:
		return p["category"] == category)


func find_product(id: String) -> Dictionary:
	for p: Dictionary in data.get("products", []):
		if p["id"] == id:
			return p
	return {}


## Produk polis di kategori ini ({} jika tidak punya).
func policy_product(category: String) -> Dictionary:
	return find_product(policies.get(category, {}).get("id", ""))


## Produk polis yang sudah melewati masa tunggu ({} jika belum/ tidak ada).
func active_policy(category: String) -> Dictionary:
	if not policies.has(category):
		return {}
	if gs.month - int(policies[category]["since"]) < int(data.get("waiting_months", 1)):
		return {}
	return policy_product(category)


## Premi sebulan (harga hari ini). Kendaraan: persen per tahun dari harga kendaraan.
func premium(product: Dictionary) -> int:
	if product.has("premium_rate"):
		return gs.nominal(gs.dreams.vehicle_base_value() * float(product["premium_rate"]) / 12.0)
	return gs.nominal(product["premium"])


func premiums_total() -> int:
	var total := 0
	for category: String in policies:
		var product := policy_product(category)
		if not product.is_empty():
			total += premium(product)
	return total


## Pilihan dari popup Perlindungan: {kategori: id produk atau ""}. Polis baru/ganti produk
## memulai masa tunggu dari bulan ini; premi pertama dibayar awal bulan depan.
func set_policies(choices: Dictionary) -> void:
	for category: String in choices:
		var id: String = choices[category]
		if id == "":
			policies.erase(category)
		elif policies.get(category, {}).get("id", "") != id:
			policies[category] = {"id": id, "since": gs.month}
	gs.changed.emit()
	gs.state_committed.emit()


## Bagian biaya pilihan event yang ditanggung asuransi aktif (0 jika tidak ada).
func cover(choice: Dictionary) -> int:
	var category := claim_category(choice)
	if category == "":
		return 0
	var product := active_policy(category)
	if product.is_empty():
		return 0
	var cost := float(gs.events.choice_cost(choice)) - gs.nominal(product.get("deductible", 0))
	return maxi(0, roundi(cost * float(product.get("coverage", 0.0))))


func claim_category(choice: Dictionary) -> String:
	match choice.get("claim", ""):
		"medical":
			return "health"
		"vehicle":
			return "vehicle"
	return ""


## Premi semua polis di awal bulan. Jika kas kurang, kekurangannya diambil dari tabungan dana
## darurat; jika masih tidak cukup, polis berhenti (lapse).
func pay_premiums() -> Dictionary:
	var paid := 0
	var lapsed: Array[String] = []
	for category: String in policies.keys():
		var product := policy_product(category)
		if product.is_empty() or (category == "vehicle" and gs.dreams.vehicle() == ""):
			policies.erase(category)
			continue
		var amount := premium(product)
		gs.budget.draw_emergency(amount)
		if gs.cash < amount:
			policies.erase(category)
			lapsed.append(product["name"])
			continue
		gs.cash -= amount
		paid += amount
	gs.stats["insurance_premiums"] += paid
	return {"insurance_premium": paid, "insurance_lapsed": lapsed}
