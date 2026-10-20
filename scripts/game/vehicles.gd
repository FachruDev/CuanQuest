class_name Vehicles
extends GameModule
## Kendaraan (v1.5c langkah 2; garasi & pilihan model: tambahan v2): motor & mobil sebagai aset yang
## nilainya menyusut, dengan biaya rutin (bensin, servis, pajak) dan tambahan kebahagiaan tiap bulan.
## Pemain bisa punya beberapa kendaraan (termasuk model yang sama) sampai garasi penuh; tiap unit punya
## nomor sendiri (uid). Kebahagiaan hanya dari kendaraan terbaik per jenis, dan kendaraan ke-2 dst per
## jenis kena pajak progresif. Didapat dari Impian yang terwujud, dibeli tunai, atau dengan kredit
## (kendaraan menjadi agunan). Data: data/vehicles.json.

const VEHICLES_PATH := "res://data/vehicles.json"

var data: Dictionary = {}  # isi data/vehicles.json
## Kendaraan dimiliki: [{uid, id, since, paid, loan_id}]. uid = nomor unit, id = model, since = bulan
## dibeli (awal penyusutan), paid = harga beli, loan_id = id pinjaman di Debt (-1 = tanpa kredit).
var owned: Array[Dictionary] = []
var uid_seq := 0  # nomor unit terakhir yang dipakai


func load_data() -> void:
	data = DataLoader.load_json(VEHICLES_PATH)


func reset() -> void:
	owned.clear()
	uid_seq = 0


func save_to(d: Dictionary) -> void:
	d["vehicles"] = owned.duplicate(true)
	d["vehicle_seq"] = uid_seq


## Save sebelum v1.5c langkah 2 belum punya kendaraan: impian motor/mobil yang sudah terwujud
## menjadi kendaraan (modul ini dimuat setelah Dreams, lihat urutan GameState.modules). Save sebelum
## garasi (tambahan v2) belum punya nomor unit: diberi nomor urut, dan agunan kreditnya ({"type":
## "vehicle", "id": <model>}) diarahkan ke nomor unit itu (Debt sudah dimuat lebih dulu).
func load_from(d: Dictionary) -> void:
	owned.clear()
	uid_seq = int(d.get("vehicle_seq", 0))
	if d.has("vehicles"):
		for saved: Dictionary in d["vehicles"]:
			var uid := int(saved.get("uid", -1))
			if uid < 0:
				uid_seq += 1
				uid = uid_seq
			uid_seq = maxi(uid_seq, uid)
			owned.append({"uid": uid, "id": saved["id"], "since": int(saved["since"]), "paid": int(saved["paid"]),
				"loan_id": int(saved.get("loan_id", -1))})
		for entry: Dictionary in owned:
			var loan := loan_of(entry)
			if not loan.is_empty() and loan.get("collateral", {}).get("type", "") == "vehicle" \
					and loan["collateral"]["id"] is String:
				loan["collateral"]["id"] = entry["uid"]
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


## Jenis kendaraan: [{id, name}] (motor, mobil).
func categories() -> Array:
	return data.get("categories", [])


func category_of(id: String) -> String:
	return str(def(id).get("category", ""))


func category_name(category: String) -> String:
	for c: Dictionary in categories():
		if c["id"] == category:
			return c["name"]
	return category


## Unit kendaraan dengan nomor `uid` ({} jika tidak ada / sudah dijual).
func find(uid: int) -> Dictionary:
	for entry: Dictionary in owned:
		if int(entry["uid"]) == uid:
			return entry
	return {}


## Punya minimal satu unit model `id`.
func owns(id: String) -> bool:
	return owned.any(func(e: Dictionary) -> bool: return e["id"] == id)


## Punya minimal satu kendaraan jenis `category` (false untuk "").
func owns_category(category: String) -> bool:
	return category != "" and count_in(category) > 0


func count_in(category: String) -> int:
	return owned.filter(func(e: Dictionary) -> bool: return category_of(e["id"]) == category).size()


func has_any() -> bool:
	return not owned.is_empty()


func max_owned() -> int:
	return int(data.get("max_owned", 6))


func is_full() -> bool:
	return owned.size() >= max_owned()


## Kendaraan utama untuk event, asuransi, & gambar Beranda: yang termahal (mobil jika punya). {} jika tidak ada.
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


# --- Biaya rutin, pajak progresif, kebahagiaan ---------------------------------------

## Biaya rutin dasar sebulan satu unit model `id` (harga hari ini x pengali tingkat kesulitan).
func base_cost(id: String) -> int:
	return gs.nominal(float(def(id)["running_cost"]) * float(gs.difficulty["expense_mult"]))


## Urutan unit di jenisnya (1 = pertama), urut bulan beli lalu nomor unit. Dasar pajak progresif.
func order_of(entry: Dictionary) -> int:
	var category := category_of(entry["id"])
	var order := 1
	for other: Dictionary in owned:
		if other == entry or category_of(other["id"]) != category:
			continue
		if int(other["since"]) < int(entry["since"]) \
				or (int(other["since"]) == int(entry["since"]) and int(other["uid"]) < int(entry["uid"])):
			order += 1
	return order


## Tarif pajak progresif per tahun untuk unit ke-`order` di jenisnya (0 untuk unit pertama).
func progressive_rate(order: int) -> float:
	return maxf(0.0, order - 1) * float(data.get("progressive_tax", 0.0))


## Pajak progresif sebulan dari nilai `market_value` untuk unit ke-`order`.
func progressive_tax(market_value: float, order: int) -> int:
	return roundi(market_value * progressive_rate(order) / 12.0 / 1000.0) * 1000


## Biaya rutin sebulan satu unit: biaya dasar + pajak progresif.
func cost_of(entry: Dictionary) -> int:
	return base_cost(entry["id"]) + progressive_tax(value(entry), order_of(entry))


## Biaya rutin sebulan jika model `id` dibeli sekarang (unit berikutnya di jenisnya).
func new_cost(id: String) -> int:
	return base_cost(id) + progressive_tax(price(id), count_in(category_of(id)) + 1)


func running_cost() -> int:
	var total := 0
	for entry: Dictionary in owned:
		total += cost_of(entry)
	return total


## Unit yang dihitung kebahagiaannya di jenis `category`: kebahagiaan tertinggi, lalu yang dibeli
## lebih dulu. {} jika tidak punya kendaraan jenis itu.
func best_in(category: String) -> Dictionary:
	var best: Dictionary = {}
	for entry: Dictionary in owned:
		if category_of(entry["id"]) != category:
			continue
		if best.is_empty() or int(def(entry["id"])["happiness"]) > int(def(best["id"])["happiness"]) \
				or (int(def(entry["id"])["happiness"]) == int(def(best["id"])["happiness"]) and order_of(entry) < order_of(best)):
			best = entry
	return best


## Kebahagiaan sebulan: kendaraan terbaik per jenis saja (punya dua mobil tidak membuat dua kali bahagia).
func happiness() -> int:
	var total := 0
	for c: Dictionary in categories():
		var best := best_in(c["id"])
		if not best.is_empty():
			total += int(def(best["id"])["happiness"])
	return total


## Unit ini ikut dihitung kebahagiaannya (terbaik di jenisnya).
func counts_happiness(entry: Dictionary) -> bool:
	return best_in(category_of(entry["id"])) == entry


## Tambahan kebahagiaan per bulan jika model `id` dibeli sekarang.
func happiness_gain(id: String) -> int:
	var best := best_in(category_of(id))
	var current := 0 if best.is_empty() else int(def(best["id"])["happiness"])
	return maxi(0, int(def(id)["happiness"]) - current)


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

## Impian aktif yang menabung untuk kendaraan jenis yang sama dengan model `id` ({} jika tidak ada).
## Dananya dipakai lebih dulu, model apa pun yang dibeli.
func dream_of(id: String) -> Dictionary:
	var category := category_of(id)
	for entry: Dictionary in gs.dreams.active():
		var vehicle_id: String = gs.dreams.find_def(entry["id"]).get("vehicle", "")
		if vehicle_id != "" and category_of(vehicle_id) == category:
			return entry
	return {}


## Model ini bisa dibeli dengan kredit (model bekas hanya tunai).
func credit_allowed(id: String) -> bool:
	return str(def(id).get("loan", "")) != ""


## Rincian pembelian sebelum dijalankan (satu sumber angka untuk popup dan buy()).
## method "cash": bayar penuh; "credit": uang muka `dp_ratio` x harga + kredit `tenor` bulan.
## -> {ok, id, method, price, dream_fund, upfront, loan (quote Debt atau {}), total, extra, requirements}
##    upfront = dibayar sekarang (dana impian dulu, lalu kas); total = semua yang dibayar termasuk bunga.
func buy_quote(id: String, method: String, dp_ratio: float = 0.0, tenor: int = 0) -> Dictionary:
	var vehicle_price := price(id)
	var fund := roundi(float(dream_of(id).get("saved", 0.0)))
	var reqs: Array[Dictionary] = [{"type": "garage", "have": owned.size(), "need": max_owned(), "met": not is_full()}]
	var upfront := vehicle_price
	var total := vehicle_price
	var loan: Dictionary = {}
	if method == "credit":
		if not credit_allowed(id):
			reqs.append({"type": "loan_allowed", "met": false})
		else:
			upfront = roundi(vehicle_price * dp_ratio / 10_000.0) * 10_000
			loan = gs.debt.quote(def(id)["loan"], vehicle_price - upfront, tenor)
			reqs.append_array(loan["requirements"])
			total = upfront + int(loan["total"])
	reqs.append({"type": "cash", "need": upfront, "have": gs.cash + fund, "met": gs.cash + fund >= upfront})
	return {"ok": reqs.all(func(r: Dictionary) -> bool: return r["met"]), "id": id, "method": method,
		"price": vehicle_price, "dream_fund": fund, "upfront": upfront, "loan": loan, "total": total,
		"extra": total - vehicle_price, "requirements": reqs}


## Membeli kendaraan. Dana impian jenis ini dipakai lebih dulu. Tunai = impiannya terwujud
## (lengkap dengan perayaan); kredit = impiannya ditutup tanpa hadiah dan dananya menjadi uang muka.
## -> {ok, uid}
func buy(id: String, method: String, dp_ratio: float = 0.0, tenor: int = 0) -> Dictionary:
	var q := buy_quote(id, method, dp_ratio, tenor)
	if not q["ok"]:
		return {"ok": false}
	var vehicle_price: int = q["price"]
	var upfront: int = q["upfront"]
	var uid := uid_seq + 1
	var loan_id := -1
	if method == "credit":
		if not tenor in gs.debt.tenor_options(gs.debt.product(def(id)["loan"])):
			return {"ok": false}
		var taken := gs.debt.take(def(id)["loan"], vehicle_price - upfront, tenor, {"type": "vehicle", "id": uid})
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
	uid_seq = uid
	owned.append({"uid": uid, "id": id, "since": gs.month, "paid": vehicle_price, "loan_id": loan_id})
	gs.stats["vehicles_bought"] += 1
	gs.changed.emit()
	gs.state_committed.emit()
	gs.flush_report_signals()  # perayaan impian terwujud
	return {"ok": true, "uid": uid}


## Impian kendaraan terwujud dari dananya sendiri (Dreams.check) atau save lama: model standar impian itu.
func add_owned(id: String, since: int, paid: int) -> void:
	if def(id).is_empty():
		return
	uid_seq += 1
	owned.append({"uid": uid_seq, "id": id, "since": since, "paid": paid, "loan_id": -1})


# --- Menjual & ditarik ------------------------------------------------------------------

## Rincian menjual unit `uid` ke dealer: harga jual = sell_ratio x nilai pasar. Kredit yang masih
## berjalan dilunasi dari hasil penjualan (ditambah kas jika kurang).
## -> {value, proceeds, payoff, net, ok}
func sell_quote(uid: int) -> Dictionary:
	var entry := find(uid)
	if entry.is_empty():
		return {"value": 0, "proceeds": 0, "payoff": 0, "net": 0, "ok": false}
	var market_value := value(entry)
	var proceeds := roundi(market_value * float(data["sell_ratio"]) / 10_000.0) * 10_000
	var loan := loan_of(entry)
	var payoff := 0 if loan.is_empty() else int(gs.debt.payoff_quote(loan)["total"])
	return {"value": market_value, "proceeds": proceeds, "payoff": payoff, "net": proceeds - payoff,
		"ok": proceeds >= payoff or gs.cash + proceeds >= payoff}  # hasil jual menutup kredit: selalu boleh


func sell(uid: int) -> bool:
	var entry := find(uid)
	if entry.is_empty():
		return false
	var q := sell_quote(uid)
	if not q["ok"]:
		return false
	gs.cash += int(q["proceeds"])
	var loan := loan_of(entry)
	if not loan.is_empty():
		gs.debt.pay_off(int(loan["id"]), true)  # dilunasi dari hasil jual walau kas sempat minus
	owned.erase(entry)
	gs.stats["vehicles_sold"] += 1
	gs.changed.emit()
	gs.state_committed.emit()
	return true


## Kredit macet: unit `uid` ditarik dan dilelang (dipanggil Debt). -> {name, value} (hasil lelang).
func seize(uid: int) -> Dictionary:
	var entry := find(uid)
	if entry.is_empty():
		return {"name": "", "value": 0}
	var auction := roundi(value(entry) * float(gs.debt.data["seize_value_ratio"]) / 10_000.0) * 10_000
	owned.erase(entry)
	gs.stats["vehicles_seized"] += 1
	return {"name": def(entry["id"])["name"], "value": auction}
