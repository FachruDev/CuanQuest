class_name Vehicles
extends GameModule
## Kendaraan (v1.5c langkah 2): motor & mobil sebagai aset yang nilainya menyusut, dengan biaya
## rutin (bensin, servis, pajak) dan tambahan kebahagiaan tiap bulan. Didapat dari Impian yang
## terwujud, dibeli tunai, atau dengan kredit (kendaraan menjadi agunan). Data: data/vehicles.json.

const VEHICLES_PATH := "res://data/vehicles.json"

var data: Dictionary = {}  # isi data/vehicles.json
## Kendaraan dimiliki: [{id, since, paid, loan_id}]. since = bulan dibeli (awal penyusutan),
## paid = harga beli, loan_id = id pinjaman di Debt (-1 = dibeli tanpa kredit).
var owned: Array[Dictionary] = []


func load_data() -> void:
	data = DataLoader.load_json(VEHICLES_PATH)


func reset() -> void:
	owned.clear()


func save_to(d: Dictionary) -> void:
	d["vehicles"] = owned


## Save sebelum v1.5c langkah 2 belum punya kendaraan: impian motor/mobil yang sudah terwujud
## menjadi kendaraan (modul ini dimuat setelah Dreams, lihat urutan GameState.modules).
func load_from(d: Dictionary) -> void:
	owned.clear()
	if d.has("vehicles"):
		for saved: Dictionary in d["vehicles"]:
			owned.append({"id": saved["id"], "since": int(saved["since"]), "paid": int(saved["paid"]),
				"loan_id": int(saved.get("loan_id", -1))})
		return
	for entry: Dictionary in gs.dreams.entries:
		var vehicle_id: String = gs.dreams.find_def(entry["id"]).get("vehicle", "")
		if vehicle_id != "" and entry["status"] == "achieved":
			add_owned(vehicle_id, int(entry["achieved_month"]), roundi(entry["saved"]))


# --- Data & nilai ---------------------------------------------------------------------

func defs() -> Array:
	return data.get("vehicles", [])


func def(id: String) -> Dictionary:
	for d: Dictionary in defs():
		if d["id"] == id:
			return d
	return {}


func find(id: String) -> Dictionary:
	for entry: Dictionary in owned:
		if entry["id"] == id:
			return entry
	return {}


func owns(id: String) -> bool:
	return not find(id).is_empty()


func has_any() -> bool:
	return not owned.is_empty()


## Kendaraan utama untuk event & asuransi: yang termahal (mobil jika punya). {} jika tidak ada.
func primary() -> Dictionary:
	var best: Dictionary = {}
	for entry: Dictionary in owned:
		if best.is_empty() or float(def(entry["id"])["price"]) > float(def(best["id"])["price"]):
			best = entry
	return best


## Harga baru hari ini (harga awal x indeks harga, per Rp10.000 seperti biaya impian).
func price(id: String) -> int:
	return gs.nominal(def(id)["price"], 10_000)


## Nilai pasar pada bulan `month` dengan indeks harga `level` (bawaan: sekarang): harga baru x
## (1 - penyusutan)^usia, minimal min_value_ratio dari harga baru.
func value(entry: Dictionary, month: int = -1, level: float = -1.0) -> int:
	if month < 0:
		month = gs.month
	if level < 0.0:
		level = gs.price_level()
	var d := def(entry["id"])
	var years := maxf(0.0, (month - int(entry["since"])) / 12.0)
	var ratio := maxf(float(data["min_value_ratio"]), pow(1.0 - float(d["depreciation"]), years))
	return roundi(float(d["price"]) * level * ratio / 10_000.0) * 10_000


func total_value() -> float:
	var total := 0.0
	for entry: Dictionary in owned:
		total += value(entry)
	return total


## Penurunan nilai kendaraan yang sudah dimiliki sejak `from_month` (indeks harga `level`), untuk
## laporan bulanan.
func depreciation_since(from_month: int, level: float) -> int:
	var total := 0
	for entry: Dictionary in owned:
		if int(entry["since"]) <= from_month:
			total += value(entry, from_month, level) - value(entry)
	return total


## Biaya rutin sebulan satu kendaraan (harga hari ini x pengali tingkat kesulitan).
func cost_of(id: String) -> int:
	return gs.nominal(float(def(id)["running_cost"]) * float(gs.difficulty["expense_mult"]))


func running_cost() -> int:
	var total := 0
	for entry: Dictionary in owned:
		total += cost_of(entry["id"])
	return total


func happiness() -> int:
	var total := 0
	for entry: Dictionary in owned:
		total += int(def(entry["id"])["happiness"])
	return total


## Dasar biaya perbaikan di event ("cost_vehicle"): nilai pasar kendaraan utama (harga hari ini).
## Sama dengan dasar premi asuransi, jadi asuransi kendaraan rata-rata tetap lebih mahal dari
## klaimnya, seperti di dunia nyata (simulator v1.5c langkah 2).
func repair_base() -> float:
	var entry := primary()
	return 0.0 if entry.is_empty() else float(value(entry))


## Pinjaman yang masih berjalan untuk kendaraan ini ({} jika tanpa kredit atau sudah lunas).
func loan_of(entry: Dictionary) -> Dictionary:
	return gs.debt.find(int(entry["loan_id"])) if int(entry["loan_id"]) >= 0 else {}


# --- Membeli ----------------------------------------------------------------------------

## Impian aktif yang menabung untuk kendaraan ini ({} jika tidak ada). Dananya dipakai lebih dulu.
func dream_of(id: String) -> Dictionary:
	return gs.dreams.get_active(def(id).get("dream", ""))


## Rincian pembelian sebelum dijalankan (satu sumber angka untuk popup dan buy()).
## method "cash": bayar penuh; "credit": uang muka `dp_ratio` x harga + kredit `tenor` bulan.
## -> {ok, id, method, price, dream_fund, upfront, loan (quote Debt atau {}), total, extra, requirements}
##    upfront = dibayar sekarang (dana impian dulu, lalu kas); total = semua yang dibayar termasuk bunga.
func buy_quote(id: String, method: String, dp_ratio: float = 0.0, tenor: int = 0) -> Dictionary:
	var vehicle_price := price(id)
	var fund := roundi(float(dream_of(id).get("saved", 0.0)))
	var reqs: Array[Dictionary] = [{"type": "not_owned", "met": not owns(id)}]
	var upfront := vehicle_price
	var total := vehicle_price
	var loan: Dictionary = {}
	if method == "credit":
		upfront = roundi(vehicle_price * dp_ratio / 10_000.0) * 10_000
		loan = gs.debt.quote(def(id)["loan"], vehicle_price - upfront, tenor)
		reqs.append_array(loan["requirements"])
		total = upfront + int(loan["total"])
	reqs.append({"type": "cash", "need": upfront, "have": gs.cash + fund, "met": gs.cash + fund >= upfront})
	return {"ok": reqs.all(func(r: Dictionary) -> bool: return r["met"]), "id": id, "method": method,
		"price": vehicle_price, "dream_fund": fund, "upfront": upfront, "loan": loan, "total": total,
		"extra": total - vehicle_price, "requirements": reqs}


## Membeli kendaraan. Dana impian kendaraan ini dipakai lebih dulu. Tunai = impiannya terwujud
## (lengkap dengan perayaan); kredit = impiannya ditutup tanpa hadiah dan dananya menjadi uang muka.
func buy(id: String, method: String, dp_ratio: float = 0.0, tenor: int = 0) -> Dictionary:
	var q := buy_quote(id, method, dp_ratio, tenor)
	if not q["ok"]:
		return {"ok": false}
	var vehicle_price: int = q["price"]
	var upfront: int = q["upfront"]
	var loan_id := -1
	if method == "credit":
		if not tenor in gs.debt.tenor_options(gs.debt.product(def(id)["loan"])):
			return {"ok": false}
		var taken := gs.debt.take(def(id)["loan"], vehicle_price - upfront, tenor, {"type": "vehicle", "id": id})
		if not taken["ok"]:
			return {"ok": false}
		loan_id = int(taken["loan"]["id"])
		gs.cash -= vehicle_price - upfront  # uang pinjaman langsung dibayarkan ke dealer
	var dream := dream_of(id)
	var from_dream := mini(int(q["dream_fund"]), upfront)
	gs.cash -= upfront - from_dream
	if not dream.is_empty():
		gs.cash += roundi(float(dream["saved"]) - from_dream)  # sisa dana impian (jika lebih dari DP) ke kas
		if method == "cash":
			dream["saved"] = float(vehicle_price)
			gs.dreams.achieve(dream)
		else:
			gs.dreams.close_entry(dream)
	owned.append({"id": id, "since": gs.month, "paid": vehicle_price, "loan_id": loan_id})
	gs.stats["vehicles_bought"] += 1
	gs.changed.emit()
	gs.state_committed.emit()
	gs.flush_report_signals()  # perayaan impian terwujud
	return {"ok": true}


## Impian kendaraan terwujud dari dananya sendiri (Dreams.check) atau save lama.
func add_owned(id: String, since: int, paid: int) -> void:
	if owns(id) or def(id).is_empty():
		return
	owned.append({"id": id, "since": since, "paid": paid, "loan_id": -1})


# --- Menjual & ditarik ------------------------------------------------------------------

## Rincian menjual ke dealer: harga jual = sell_ratio x nilai pasar. Kredit yang masih berjalan
## dilunasi dari hasil penjualan (ditambah kas jika kurang).
## -> {value, proceeds, payoff, net, ok}
func sell_quote(id: String) -> Dictionary:
	var entry := find(id)
	var market_value := value(entry)
	var proceeds := roundi(market_value * float(data["sell_ratio"]) / 10_000.0) * 10_000
	var loan := loan_of(entry)
	var payoff := 0 if loan.is_empty() else int(gs.debt.payoff_quote(loan)["total"])
	return {"value": market_value, "proceeds": proceeds, "payoff": payoff, "net": proceeds - payoff,
		"ok": gs.cash + proceeds >= payoff}


func sell(id: String) -> bool:
	var entry := find(id)
	if entry.is_empty():
		return false
	var q := sell_quote(id)
	if not q["ok"]:
		return false
	gs.cash += int(q["proceeds"])
	var loan := loan_of(entry)
	if not loan.is_empty():
		gs.debt.pay_off(int(loan["id"]))
	owned.erase(entry)
	gs.stats["vehicles_sold"] += 1
	gs.changed.emit()
	gs.state_committed.emit()
	return true


## Kredit macet: kendaraan ditarik dan dilelang (dipanggil Debt). -> {name, value} (hasil lelang).
func seize(id: String) -> Dictionary:
	var entry := find(id)
	if entry.is_empty():
		return {"name": "", "value": 0}
	var auction := roundi(value(entry) * float(gs.debt.data["seize_value_ratio"]) / 10_000.0) * 10_000
	owned.erase(entry)
	gs.stats["vehicles_seized"] += 1
	return {"name": def(id)["name"], "value": auction}
