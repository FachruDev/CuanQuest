class_name Properties
extends GameModule
## Properti (v1.5c langkah 3): rumah, apartemen, dan tanah yang dibeli tunai atau dengan KPR, lalu
## dihuni (menggantikan sewa tempat tinggal), disewakan (pendapatan pasif), atau dijual (laku dalam
## 1-3 bulan). Harga bergerak pelan: inflasi x indeks properti per jenis. Data: data/properties.json.
##
## Analogi web: tiap properti seperti "listing" dengan status (dihuni / disewakan / kosong / dijual)
## yang diproses oleh job bulanan month_step().

const PROPERTIES_PATH := "res://data/properties.json"

var data: Dictionary = {}  # isi data/properties.json
## Properti dimiliki: [{uid, id, since, paid, use, lease_left, vacant_left, selling_left, loan_id}].
## use: "live" (dihuni) | "rent" (disewakan) | "empty" (kosong). lease_left = sisa bulan kontrak
## penyewa; vacant_left = sisa bulan mencari penyewa; selling_left = sisa bulan sampai laku
## (-1 = tidak dijual); loan_id = id KPR di Debt (-1 = dibeli tunai).
var owned: Array[Dictionary] = []
var index: Dictionary = {}  # id jenis -> indeks harga riil (1.0 = harga awal permainan)
var uid_seq := 0
## RNG pasar properti & penyewa. Terpisah dari RNG event dan RNG pasar saham, sehingga permainan
## tanpa properti berjalan persis sama seperti sebelum fitur ini ada.
var rng := RandomNumberGenerator.new()


func load_data() -> void:
	data = DataLoader.load_json(PROPERTIES_PATH)


func reset() -> void:
	owned.clear()
	index.clear()
	for d: Dictionary in defs():
		index[d["id"]] = 1.0
	uid_seq = 0
	rng.seed = gs.rng.seed + 1  # GameState.rng sudah di-seed sebelum modul di-reset/dimuat


func save_to(d: Dictionary) -> void:
	d.merge({"properties": owned, "property_index": index, "property_seq": uid_seq,
		"property_rng": [str(rng.seed), str(rng.state)]})


## Save sebelum v1.5c langkah 3: tanpa properti, indeks mulai dari 1.0.
func load_from(d: Dictionary) -> void:
	reset()
	for saved: Dictionary in d.get("properties", []):
		var entry := saved.duplicate()
		for key: String in ["uid", "since", "paid", "lease_left", "vacant_left", "selling_left", "loan_id"]:
			entry[key] = int(entry[key])
		owned.append(entry)
	for id: String in d.get("property_index", {}):
		index[id] = float(d["property_index"][id])
	uid_seq = int(d.get("property_seq", 0))
	if d.has("property_rng"):
		rng.seed = String(d["property_rng"][0]).to_int()
		rng.state = String(d["property_rng"][1]).to_int()


# --- Data & nilai -------------------------------------------------------------------------

func defs() -> Array:
	return data.get("properties", [])


func def(id: String) -> Dictionary:
	for d: Dictionary in defs():
		if d["id"] == id:
			return d
	return {}


func find(uid: int) -> Dictionary:
	for entry: Dictionary in owned:
		if int(entry["uid"]) == uid:
			return entry
	return {}


## Properti yang dihuni sendiri ({} jika menyewa / menumpang).
func home() -> Dictionary:
	for entry: Dictionary in owned:
		if entry["use"] == "live":
			return entry
	return {}


func can_rent(id: String) -> bool:
	return def(id).get("livable", false) and def(id).get("rentable", true)


## Harga pasar hari ini (per Rp1 juta): harga awal x indeks harga x indeks properti jenis ini.
func price(id: String) -> int:
	return roundi(float(def(id)["price"]) * gs.price_level() * float(index.get(id, 1.0)) / 1_000_000.0) * 1_000_000


func value(entry: Dictionary) -> int:
	return price(entry["id"])


func total_value() -> float:
	var total := 0.0
	for entry: Dictionary in owned:
		total += value(entry)
	return total


## Biaya rutin sebulan satu properti: PBB + perawatan (apartemen: termasuk IPL).
func cost_of(entry: Dictionary) -> int:
	var rate := float(data["pbb_rate"]) + float(def(entry["id"])["maintenance"])
	return roundi(value(entry) * rate / 12.0 / 1000.0) * 1000


func running_cost() -> int:
	var total := 0
	for entry: Dictionary in owned:
		total += cost_of(entry)
	return total


## Sewa kotor sebulan jika disewakan sekarang.
func rent_gross(id: String) -> int:
	return roundi(price(id) * float(def(id)["rent_yield"]) / 12.0 / 1000.0) * 1000


func rent_tax(gross: int) -> int:
	return roundi(gross * float(data["rent_tax"]) / 1000.0) * 1000


func rent_net(id: String) -> int:
	var gross := rent_gross(id)
	return gross - rent_tax(gross)


## Sewa bersih sebulan dari properti yang sedang ditempati penyewa (Rencana Gaji & Beranda).
func expected_rent() -> int:
	var total := 0
	for entry: Dictionary in owned:
		if entry["use"] == "rent" and int(entry["vacant_left"]) == 0:
			total += rent_net(entry["id"])
	return total


## Pendapatan pasif dari sewa untuk kebebasan finansial: semua properti yang disewakan (termasuk
## yang sedang mencari penyewa, seperti investor menghitung sewa tahunan).
func rent_income() -> int:
	var total := 0
	for entry: Dictionary in owned:
		if entry["use"] == "rent":
			total += rent_net(entry["id"])
	return total


## Pilihan "tempat tinggal" saat menghuni rumah sendiri (format sama dengan economy.json housing).
## Tanpa sewa; rumah di pinggir kota (commute_cost) membawa ongkos perjalanan sebagai biaya tinggal.
func home_option(entry: Dictionary) -> Dictionary:
	var d := def(entry["id"])
	return {"id": "own", "name_key": tr("HOUSING_OWN") % tr(d["name"]), "cost": int(d.get("commute_cost", 0)),
		"health": 0, "happiness": int(d["happiness"])}


## Bulan pertama properti boleh dijual (-1 jika bebas dijual), mis. rumah subsidi setelah 5 tahun.
func sellable_from(entry: Dictionary) -> int:
	var hold := int(def(entry["id"]).get("min_hold_months", 0))
	return int(entry["since"]) + hold if hold > 0 else -1


func loan_of(entry: Dictionary) -> Dictionary:
	return gs.debt.find(int(entry["loan_id"])) if int(entry["loan_id"]) >= 0 else {}


# --- Event (v1.5c langkah 4) ----------------------------------------------------------------

## Rumah tapak yang terkena event kerusakan: rumah yang dihuni jika berupa rumah, selain itu rumah
## termahal yang dimiliki ({} jika tidak punya rumah tapak).
func event_house() -> Dictionary:
	var current := home()
	if not current.is_empty() and def(current["id"]).get("kind", "") == "house":
		return current
	var best: Dictionary = {}
	for entry: Dictionary in owned:
		if def(entry["id"]).get("kind", "") == "house" and (best.is_empty() or value(entry) > value(best)):
			best = entry
	return best


## Properti yang sedang ditempati penyewa (yang pertama), untuk event penyewa bermasalah.
func tenant_entry() -> Dictionary:
	for entry: Dictionary in owned:
		if entry["use"] == "rent" and int(entry["vacant_left"]) == 0:
			return entry
	return {}


## Properti yang dituju event (isian "property_uid"); efek tertunda tanpa isian memakai rumah tapak utama.
func _event_target() -> Dictionary:
	var uid := int(gs.events.pending_vars.get("property_uid", -1))
	return find(uid) if uid >= 0 else event_house()


func event_vars(id: String) -> Dictionary:
	var entry: Dictionary = {}
	match id:
		"roof_leak":
			entry = event_house()
		"home_renovation":
			entry = home()
		"tenant_late":
			entry = tenant_entry()
	if entry.is_empty():
		return {}
	return {"property_uid": entry["uid"], "property": def(entry["id"])["name"], "rent2": rent_net(entry["id"]) * 2}


## Biaya pilihan event "cost_property": persen nilai pasar properti yang dituju (harga hari ini).
func event_cost(ratio: float) -> int:
	var entry := _event_target()
	return 0 if entry.is_empty() else roundi(value(entry) * ratio / 1000.0) * 1000


## Efek event: biaya perbaikan (persen nilai properti), sewa yang hilang (x sewa bersih sebulan),
## dan penyewa pergi (properti mencari penyewa baru 1-2 bulan).
func apply_effects(e: Dictionary) -> void:
	if not (e.has("property_repair") or e.has("rent_months") or e.has("tenant_leave")):
		return
	var entry := _event_target()
	if entry.is_empty():
		return
	if e.has("property_repair"):
		var cost := event_cost(float(e["property_repair"]))
		gs.cash -= cost
		gs.stats["property_costs"] += cost
	if e.has("rent_months"):
		var amount := rent_net(entry["id"]) * int(e["rent_months"])
		gs.cash += amount
		gs.stats["rent_income"] += amount
	if e.get("tenant_leave", false) and entry["use"] == "rent":
		entry["lease_left"] = 0
		entry["vacant_left"] = rng.randi_range(int(data["vacancy_months"][0]), int(data["vacancy_months"][1]))


# --- Bulanan --------------------------------------------------------------------------------

## Awal bulan (dipanggil GameState._start_month): harga bergerak, biaya PBB & perawatan dipotong,
## penyewa membayar sewa (dipotong PPh final), kontrak berakhir / penyewa baru datang, dan properti
## yang dijual laku. Mengembalikan baris laporan.
func month_step() -> Dictionary:
	var report := {"rent_income": 0, "rent_tax": 0, "property_cost": 0, "property_sold": [], "property_notes": []}
	if gs.month > 0:
		_step_index()
	for entry: Dictionary in owned:
		report["property_cost"] += cost_of(entry)
	gs.cash -= int(report["property_cost"])
	gs.stats["property_costs"] += int(report["property_cost"])
	for entry: Dictionary in owned:
		if entry["use"] == "rent":
			_rent_month(entry, report)
	for entry: Dictionary in owned.duplicate():
		if int(entry["selling_left"]) > 0:
			entry["selling_left"] -= 1
			if int(entry["selling_left"]) == 0:
				report["property_sold"].append(_complete_sale(entry))
	return report


## Indeks properti tiap jenis: pertumbuhan riil per bulan + gejolak acak (lognormal).
func _step_index() -> void:
	for d: Dictionary in defs():
		var mu := float(d["growth"]) / 12.0
		var sigma := float(d["volatility"]) / sqrt(12.0)
		index[d["id"]] = float(index.get(d["id"], 1.0)) * exp(mu - sigma * sigma / 2.0 + sigma * rng.randfn(0.0, 1.0))


func _rent_month(entry: Dictionary, report: Dictionary) -> void:
	var name: String = def(entry["id"])["name"]
	if int(entry["vacant_left"]) > 0:
		entry["vacant_left"] -= 1
		if int(entry["vacant_left"]) == 0:
			entry["lease_left"] = int(data["lease_months"])
			report["property_notes"].append({"key": "REPORT_TENANT_FOUND", "name": name})
		return
	var gross := rent_gross(entry["id"])
	var tax := rent_tax(gross)
	gs.cash += gross - tax
	report["rent_income"] += gross - tax
	report["rent_tax"] += tax
	gs.stats["rent_income"] += gross - tax
	gs.stats["total_taxes"] += tax
	entry["lease_left"] -= 1
	if int(entry["lease_left"]) <= 0:
		if rng.randf() < float(data["renew_chance"]):
			entry["lease_left"] = int(data["lease_months"])
		else:
			entry["vacant_left"] = rng.randi_range(int(data["vacancy_months"][0]), int(data["vacancy_months"][1]))
			report["property_notes"].append({"key": "REPORT_TENANT_LEFT", "name": name})


# --- Membeli ----------------------------------------------------------------------------------

## BPHTB + notaris/AJB (dibayar tunai, tidak bisa dari KPR).
func buy_costs(id: String) -> int:
	return roundi(price(id) * (float(data["buy_tax"]) + float(data["buy_fee"])) / 1000.0) * 1000


## Impian aktif yang menabung untuk uang muka properti (DP Rumah) ({} jika tidak ada).
func dream_entry() -> Dictionary:
	for entry: Dictionary in gs.dreams.active():
		if gs.dreams.find_def(entry["id"]).get("keep_funds", false):
			return entry
	return {}


## Rincian pembelian sebelum dijalankan (satu sumber angka untuk popup dan buy()).
## method: "cash" atau id produk KPR di loans.json ("kpr", "kpr_subsidi").
## -> {ok, id, method, price, costs, dream_fund, upfront, loan (quote Debt atau {}), total, requirements}
##    upfront = dibayar sekarang (DP / harga penuh + biaya beli); total = semua yang dibayar termasuk
##    perkiraan bunga KPR.
func buy_quote(id: String, method: String, dp_ratio: float = 0.0, tenor: int = 0) -> Dictionary:
	var d := def(id)
	var property_price := price(id)
	var costs := buy_costs(id)
	var fund := roundi(float(dream_entry().get("saved", 0.0)))
	var reqs: Array[Dictionary] = []
	var upfront := property_price + costs
	var total := upfront
	var loan: Dictionary = {}
	if method != "cash":
		reqs.append({"type": "loan_allowed", "met": method in d.get("loans", [])})
		var dp := roundi(property_price * dp_ratio / 100_000.0) * 100_000
		loan = gs.debt.quote(method, property_price - dp, tenor)
		reqs.append_array(loan["requirements"])
		upfront = dp + costs
		total = upfront + int(loan["total"])
	reqs.append({"type": "cash", "need": upfront, "have": gs.cash + fund, "met": gs.cash + fund >= upfront})
	return {"ok": reqs.all(func(r: Dictionary) -> bool: return r["met"]), "id": id, "method": method,
		"price": property_price, "costs": costs, "dream_fund": fund, "upfront": upfront, "loan": loan,
		"total": total, "requirements": reqs}


## Membeli properti lalu langsung dipakai sesuai `use` ("live" / "rent" / "empty"). Dana impian DP
## Rumah dipakai lebih dulu; impiannya ditutup tanpa hadiah karena belum terkumpul penuh (jika sudah
## penuh, dananya sudah masuk ke kas saat impian terwujud).
func buy(id: String, method: String, dp_ratio: float = 0.0, tenor: int = 0, use: String = "empty") -> Dictionary:
	var q := buy_quote(id, method, dp_ratio, tenor)
	if not q["ok"]:
		return {"ok": false}
	var property_price: int = q["price"]
	var upfront: int = q["upfront"]
	uid_seq += 1
	var loan_id := -1
	if method != "cash":
		if not tenor in gs.debt.tenor_options(gs.debt.product(method)):
			uid_seq -= 1
			return {"ok": false}
		var loan_amount := property_price + int(q["costs"]) - upfront
		var taken := gs.debt.take(method, loan_amount, tenor, {"type": "property", "id": uid_seq})
		if not taken["ok"]:
			uid_seq -= 1
			return {"ok": false}
		loan_id = int(taken["loan"]["id"])
		gs.cash -= loan_amount  # uang KPR langsung dibayarkan ke penjual
	var dream := dream_entry()
	var from_dream := mini(int(q["dream_fund"]), upfront)
	gs.cash -= upfront - from_dream
	if not dream.is_empty():
		gs.cash += roundi(float(dream["saved"]) - from_dream)
		gs.dreams.close_entry(dream)
	var entry := {"uid": uid_seq, "id": id, "since": gs.month, "paid": property_price, "use": "empty",
		"lease_left": 0, "vacant_left": 0, "selling_left": -1, "loan_id": loan_id}
	owned.append(entry)
	gs.stats["properties_bought"] += 1
	set_use(uid_seq, use)
	return {"ok": true, "uid": uid_seq}


# --- Dihuni, disewakan, dijual --------------------------------------------------------------

## Mengubah pemakaian properti. Menghuni rumah ini = rumah lain yang dihuni menjadi kosong;
## berhenti menyewakan = kontrak penyewa diakhiri; mulai menyewakan = mencari penyewa 1-2 bulan.
func set_use(uid: int, use: String) -> bool:
	var entry := find(uid)
	if entry.is_empty() or entry["use"] == use:
		return not entry.is_empty()
	var d := def(entry["id"])
	if (use == "live" and not d.get("livable", false)) or (use == "rent" and not can_rent(entry["id"])):
		return false
	if use == "live":
		var current := home()
		if not current.is_empty():
			current["use"] = "empty"
	entry["lease_left"] = 0
	entry["vacant_left"] = 0
	if use == "rent":
		entry["vacant_left"] = rng.randi_range(int(data["vacancy_months"][0]), int(data["vacancy_months"][1]))
	entry["use"] = use
	gs.changed.emit()
	gs.state_committed.emit()
	return true


## Pindah dari rumah sendiri ke tempat tinggal sewaan (rumahnya menjadi kosong).
func move_out() -> void:
	var current := home()
	if not current.is_empty():
		set_use(int(current["uid"]), "empty")


## Rincian penjualan dengan harga hari ini: harga - PPh final - komisi agen - pelunasan KPR.
## -> {price, tax, fee, proceeds, payoff, net, gain, locked, ok} (locked = belum boleh dijual)
func sell_quote(entry: Dictionary) -> Dictionary:
	var sale_price := value(entry)
	var tax := roundi(sale_price * float(data["sell_tax"]) / 1000.0) * 1000
	var fee := roundi(sale_price * float(data["sell_fee"]) / 1000.0) * 1000
	var loan := loan_of(entry)
	var payoff := 0 if loan.is_empty() else int(gs.debt.payoff_quote(loan)["total"])
	var proceeds := sale_price - tax - fee
	var locked := gs.month < sellable_from(entry)
	return {"price": sale_price, "tax": tax, "fee": fee, "proceeds": proceeds, "payoff": payoff,
		"net": proceeds - payoff, "gain": sale_price - int(entry["paid"]), "locked": locked,
		"ok": not locked and gs.cash + proceeds >= payoff}


## Memasang properti untuk dijual: laku setelah 1-3 bulan dengan harga saat itu.
func list_for_sale(uid: int) -> bool:
	var entry := find(uid)
	if entry.is_empty() or int(entry["selling_left"]) > 0 or not sell_quote(entry)["ok"]:
		return false
	entry["selling_left"] = rng.randi_range(int(data["sell_months"][0]), int(data["sell_months"][1]))
	gs.changed.emit()
	gs.state_committed.emit()
	return true


func cancel_sale(uid: int) -> void:
	var entry := find(uid)
	if entry.is_empty():
		return
	entry["selling_left"] = -1
	gs.changed.emit()
	gs.state_committed.emit()


## Properti laku: hasil bersih masuk kas, KPR dilunasi dari hasil penjualan, pajak tercatat.
func _complete_sale(entry: Dictionary) -> Dictionary:
	var q := sell_quote(entry)
	gs.cash += int(q["proceeds"])
	var loan := loan_of(entry)
	if not loan.is_empty():
		gs.debt.pay_off(int(loan["id"]), true)
	gs.stats["total_taxes"] += int(q["tax"])
	gs.stats["properties_sold"] += 1
	gs.stats["property_gains"] += int(q["gain"])
	owned.erase(entry)
	return {"name": def(entry["id"])["name"], "net": q["net"], "gain": q["gain"], "tax": q["tax"], "fee": q["fee"],
		"was_home": entry["use"] == "live"}


## KPR macet: properti dilelang (dipanggil Debt). -> {name, value} (hasil lelang).
func seize(uid: int) -> Dictionary:
	var entry := find(uid)
	if entry.is_empty():
		return {"name": "", "value": 0}
	var auction := roundi(value(entry) * float(gs.debt.data["seize_value_ratio"]) / 1_000_000.0) * 1_000_000
	owned.erase(entry)
	gs.stats["properties_seized"] += 1
	return {"name": def(entry["id"])["name"], "value": auction}
