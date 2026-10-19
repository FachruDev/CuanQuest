class_name Fund
extends GameModule
## Dana kelolaan (v2c): setelah tahap 7 terbuka (ujian WMI di kuis + kekayaan bersih Rp1 M), pemain
## mengelola uang investor (data/investors.json) secara paruh waktu. Pemain tidak memilih transaksi satu
## per satu, tetapi menetapkan ALOKASI per keranjang aset (data/fund.json); dana diseimbangkan ulang tiap
## bulan. Setiap investor memegang unit penyertaan: setoran / NAB per unit, pencairan = unit x NAB.
##
## Dana investor TERPISAH dari uang pribadi (seperti disimpan di bank kustodian): kas & aset dana tidak
## masuk kekayaan bersih, neraca, atau skor warisan. Yang masuk kas pemain hanya fee manajemen & fee kinerja.
## Langkah 2: kepuasan tiap investor (imbal hasil vs target, penurunan dari puncak, mandat), peringatan lalu
## penarikan dana, evaluasi tahunan (fee kinerja di atas high-water mark, tambah setoran, perpanjangan
## kontrak), dan reputasi manajer yang membuka investor besar.
## Memakai RNG sendiri (seed + rng_offset) dan baru bekerja setelah tahap 7 terbuka, jadi permainan tanpa
## dana kelolaan tetap sama persis. Analogi web: seperti admin "akun bersama" yang mengatur strategi
## uang milik orang lain; setiap pemilik bisa menarik dananya kapan saja.

const DATA_PATH := "res://data/fund.json"
const INVESTORS_PATH := "res://data/investors.json"
const STAGE := 7  # tahap buka (data/unlocks.json)

var data: Dictionary = {}  # isi data/fund.json
var investor_defs: Array = []  # isi data/investors.json
var allocation: Dictionary = {}  # id keranjang -> persen (total 100)
var holdings: Dictionary = {}  # asset_id -> unit milik dana
var cash := 0.0  # kas dana (bukan kas pemain)
var nav := 0.0  # NAB per unit di akhir bulan terakhir
## Investor aktif: [{uid, id, units, deposited, joined, contract_end, hwm (high-water mark NAB), join_nav,
## peak_nav (puncak NAB sejak bergabung), year_nav (NAB di evaluasi terakhir), satisfaction, warned (bulan
## peringatan, -1 = tidak), perf_paid}]
var investors: Array[Dictionary] = []
## Tawaran di papan: [{uid, id, amount, expires}]
var board: Array[Dictionary] = []
var reputation := 0
var record: Dictionary = {}  # statistik dana sepanjang permainan (lihat _new_record)
var nav_history: Array[float] = []  # NAB tiap akhir bulan selama dana punya investor
var seq := 0  # nomor urut tawaran & investor
var rng := RandomNumberGenerator.new()


func load_data() -> void:
	data = DataLoader.load_json(DATA_PATH)
	investor_defs = DataLoader.load_json(INVESTORS_PATH).get("investors", [])


func reset() -> void:
	allocation = {}
	for id: String in data["default_allocation"]:
		allocation[id] = int(data["default_allocation"][id])
	holdings.clear()
	cash = 0.0
	nav = float(data["start_nav"])
	investors.clear()
	board.clear()
	reputation = int(data["reputation"]["start"])
	record = _new_record()
	nav_history.clear()
	seq = 0
	rng.seed = gs.rng.seed + int(data["rng_offset"])  # GameState.rng sudah di-seed sebelum modul di-reset/dimuat


func _new_record() -> Dictionary:
	return {"mgmt_fees": 0.0, "perf_fees": 0.0, "joined": 0, "returned": 0, "left": 0, "ended": 0, "renewed": 0,
		"topups": 0, "warnings": 0, "offers": 0, "trade_costs": 0.0, "peak_value": 0.0, "month_fee": 0.0}


func save_to(d: Dictionary) -> void:
	d["fund"] = {"allocation": allocation, "holdings": holdings, "cash": cash, "nav": nav, "investors": investors,
		"board": board, "reputation": reputation, "record": record, "nav_history": nav_history, "seq": seq,
		"rng": [str(rng.seed), str(rng.state)]}.duplicate(true)  # salinan: reset() berikutnya tidak mengubah save


## Save sebelum v2c: belum ada dana kelolaan, semua mulai dari awal.
func load_from(d: Dictionary) -> void:
	reset()
	var f: Dictionary = d.get("fund", {})
	if f.is_empty():
		return
	allocation = {}
	for id: String in f["allocation"]:
		allocation[id] = int(f["allocation"][id])
	holdings = {}
	for id: String in f["holdings"]:
		holdings[id] = float(f["holdings"][id])
	cash = float(f["cash"])
	nav = float(f["nav"])
	investors.assign(f["investors"])
	for inv: Dictionary in investors:
		_normalize(inv)
	board.assign(f["board"])
	reputation = int(f["reputation"])
	record = _new_record().merged(f["record"], true)
	nav_history.assign(f["nav_history"])
	seq = int(f["seq"])
	rng.seed = String(f["rng"][0]).to_int()
	rng.state = String(f["rng"][1]).to_int()


# --- Keadaan dana ----------------------------------------------------------------------------------

func is_unlocked() -> bool:
	return gs.progress.is_stage_unlocked(STAGE)


func is_active() -> bool:
	return not investors.is_empty()


func holding_value(asset_id: String) -> float:
	return float(holdings.get(asset_id, 0.0)) * gs.market.get_asset(asset_id).price


## Nilai dana = kas dana + nilai aset dana (milik investor, bukan milik pemain).
func value() -> float:
	var total := cash
	for asset_id: String in holdings:
		total += holding_value(asset_id)
	return total


func units_total() -> float:
	var total := 0.0
	for inv: Dictionary in investors:
		total += float(inv["units"])
	return total


## NAB per unit saat ini (sebelum ada investor: NAB terakhir / awal).
func current_nav() -> float:
	var units := units_total()
	return value() / units if units > 0.0 else nav


func investor_value(inv: Dictionary) -> float:
	return float(inv["units"]) * current_nav()


## Investor dari save langkah 1 belum punya kolom kepuasan & NAB acuan: diisi bawaan.
func _normalize(inv: Dictionary) -> void:
	var hwm := float(inv.get("hwm", nav))
	var defaults := {"join_nav": hwm, "peak_nav": maxf(hwm, nav), "year_nav": hwm, "warned": -1, "perf_paid": 0.0,
		"satisfaction": int(data["satisfaction"]["start"])}
	for key: String in defaults:
		if not inv.has(key):
			inv[key] = defaults[key]


## Imbal hasil per tahun sejak bergabung, dari NAB (tidak terpengaruh tambah setoran maupun fee kinerja).
func investor_annual_return(inv: Dictionary) -> float:
	var months := gs.month - int(inv["joined"])
	if months <= 0:
		return 0.0
	return pow(current_nav() / maxf(float(inv["join_nav"]), 0.0001), 12.0 / months) - 1.0


## Penurunan NAB dari puncaknya sejak investor bergabung (0..1).
func investor_drawdown(inv: Dictionary) -> float:
	return maxf(1.0 - current_nav() / maxf(float(inv["peak_nav"]), 0.0001), 0.0)


func is_warned(inv: Dictionary) -> bool:
	return int(inv["warned"]) >= 0


## very_happy | happy | doubtful | disappointed (teks FUND_SAT_<ID>).
static func satisfaction_level(value: int) -> String:
	if value >= 75:
		return "very_happy"
	if value >= 50:
		return "happy"
	if value >= 35:
		return "doubtful"
	return "disappointed"


func add_reputation(delta: int) -> void:
	reputation = clampi(reputation + delta, 0, 100)


## Imbal hasil investor sejak bergabung (nilai sekarang dibanding total setoran).
func investor_return(inv: Dictionary) -> float:
	return investor_value(inv) / maxf(float(inv["deposited"]), 1.0) - 1.0


func def(id: String) -> Dictionary:
	for d: Dictionary in investor_defs:
		if d["id"] == id:
			return d
	return {}


func find_investor(uid: int) -> Dictionary:
	for inv: Dictionary in investors:
		if int(inv["uid"]) == uid:
			return inv
	return {}


func find_offer(uid: int) -> Dictionary:
	for offer: Dictionary in board:
		if int(offer["uid"]) == uid:
			return offer
	return {}


# --- Alokasi & profil --------------------------------------------------------------------------------

func baskets() -> Array:
	return data["baskets"]


func basket(id: String) -> Dictionary:
	for b: Dictionary in baskets():
		if b["id"] == id:
			return b
	return {}


## Keranjang bisa dipilih jika semua asetnya sudah terbuka untuk pemain (mis. valas setelah tahap 5).
func basket_available(id: String) -> bool:
	for asset_id: String in basket(id)["assets"]:
		if not gs.progress.is_asset_unlocked(asset_id):
			return false
	return true


func basket_risk(id: String) -> float:
	var assets: Array = basket(id)["assets"]
	var total := 0.0
	for asset_id: String in assets:
		total += gs.market.get_asset(asset_id).risk
	return total / assets.size()


## Rata-rata risiko alokasi (1-5), ditimbang persentase keranjang.
func allocation_risk(alloc: Dictionary = allocation) -> float:
	var total := 0.0
	for id: String in alloc:
		total += int(alloc[id]) / 100.0 * basket_risk(id)
	return total


func profile_of(alloc: Dictionary = allocation) -> String:
	var risk := allocation_risk(alloc)
	var id := ""
	for row: Array in data["profiles"]:
		if risk >= float(row[0]):
			id = row[1]
	return id


func profile_rank(id: String) -> int:
	var profiles: Array = data["profiles"]
	for i in profiles.size():
		if profiles[i][1] == id:
			return i
	return 0


## Mandat terpenuhi jika profil dana tidak lebih berisiko dari profil investor.
func mandate_ok(investor_id: String, alloc: Dictionary = allocation) -> bool:
	return profile_rank(profile_of(alloc)) <= profile_rank(def(investor_id)["profile"])


## Investor yang mandatnya akan dilanggar oleh alokasi `alloc` (untuk peringatan sebelum diterapkan).
func mandate_breaches(alloc: Dictionary = allocation) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for inv: Dictionary in investors:
		if not mandate_ok(inv["id"], alloc):
			out.append(inv)
	return out


## "" jika alokasi sah, atau key pesan error.
func allocation_error(alloc: Dictionary) -> String:
	var total := 0
	for id: String in alloc:
		var pct := int(alloc[id])
		if basket(id).is_empty() or pct < 0 or pct % int(data["allocation_step"]) != 0:
			return "FUND_ERR_STEP"
		if pct > 0 and not basket_available(id):
			return "FUND_ERR_LOCKED"
		total += pct
	return "" if total == 100 else "FUND_ERR_TOTAL"


## Terapkan alokasi baru dan langsung seimbangkan ulang dana. -> {ok, error, cost}
func set_allocation(alloc: Dictionary) -> Dictionary:
	var error := allocation_error(alloc)
	if error != "":
		return {"ok": false, "error": error}
	allocation = {}
	for id: String in alloc:
		if int(alloc[id]) > 0:
			allocation[id] = int(alloc[id])
	var cost := rebalance(true)
	gs.changed.emit()
	return {"ok": true, "cost": cost}


## Bobot target per aset (0..1): persen keranjang dibagi rata ke asetnya.
func target_weights() -> Dictionary:
	var weights := {}
	for id: String in allocation:
		var assets: Array = basket(id)["assets"]
		for asset_id: String in assets:
			weights[asset_id] = float(weights.get(asset_id, 0.0)) + int(allocation[id]) / 100.0 / assets.size()
	return weights


## Seimbangkan ulang ke bobot target: jual yang kelebihan dulu, lalu beli dengan kas dana. Tanpa `force`,
## hanya aset yang menyimpang lebih dari rebalance_band yang ditransaksikan. Mengembalikan total biaya.
func rebalance(force := false) -> float:
	var total := value()
	if total <= 0.0:
		return 0.0
	var band := float(data["rebalance_band"]) * total
	var weights := target_weights()
	var cost := 0.0
	for asset_id: String in holdings.keys():
		var diff := total * float(weights.get(asset_id, 0.0)) - holding_value(asset_id)
		if diff < 0.0 and (force or -diff > band or not weights.has(asset_id)):
			cost += _sell_value(asset_id, -diff)
	for asset_id: String in weights:
		var diff := total * float(weights[asset_id]) - holding_value(asset_id)
		if diff > 0.0 and (force or diff > band):
			cost += _buy_value(asset_id, minf(diff, cash))
	record["trade_costs"] = float(record["trade_costs"]) + cost
	return cost


func _buy_value(asset_id: String, amount: float) -> float:
	if amount <= 1.0:
		return 0.0
	var asset := gs.market.get_asset(asset_id)
	var fee := amount * (asset.buy_fee + asset.buy_tax)
	holdings[asset_id] = float(holdings.get(asset_id, 0.0)) + (amount - fee) / asset.price
	cash -= amount
	return fee


func _sell_value(asset_id: String, amount: float) -> float:
	var asset := gs.market.get_asset(asset_id)
	var units := minf(amount / asset.price, float(holdings.get(asset_id, 0.0)))
	if units <= 0.0:
		return 0.0
	var gross := units * asset.price
	var fee := gross * (asset.sell_fee + asset.sell_tax)
	holdings[asset_id] = float(holdings[asset_id]) - units
	if float(holdings[asset_id]) * asset.price < 1.0:
		holdings.erase(asset_id)
	cash += gross - fee
	return fee


## Kas dana minimal `amount` (untuk fee & pencairan): jual semua aset secara proporsional.
func _raise_cash(amount: float) -> float:
	var cost := 0.0
	for attempt in 3:
		var need := amount - cash
		var invested := value() - cash
		if need <= 0.0 or invested <= 0.0:
			break
		var fraction := minf(need * 1.02 / invested, 1.0)  # sedikit lebih untuk menutup fee jual
		for asset_id: String in holdings.keys():
			cost += _sell_value(asset_id, holding_value(asset_id) * fraction)
	record["trade_costs"] = float(record["trade_costs"]) + cost
	return cost


# --- Investor -------------------------------------------------------------------------------------------

## Terima tawaran: setoran masuk kas dana, investor mendapat unit = setoran / NAB, lalu dana diseimbangkan.
func accept(uid: int) -> Dictionary:
	var offer := find_offer(uid)
	if offer.is_empty():
		return {"ok": false, "error": "FUND_ERR_OFFER"}
	var amount := float(offer["amount"])
	var price := current_nav()
	cash += amount
	board.erase(offer)
	seq += 1
	investors.append({"uid": seq, "id": offer["id"], "units": amount / price, "deposited": amount,
		"joined": gs.month, "contract_end": gs.month + int(data["contract_months"]), "hwm": price, "join_nav": price,
		"peak_nav": price, "year_nav": price, "satisfaction": int(data["satisfaction"]["start"]), "warned": -1,
		"perf_paid": 0.0})
	record["joined"] = int(record["joined"]) + 1
	rebalance()
	gs.changed.emit()
	return {"ok": true, "amount": amount}


func decline(uid: int) -> void:
	board.erase(find_offer(uid))
	gs.changed.emit()


## Kembalikan seluruh dana seorang investor. `reason`: returned (oleh pemain; reputasi turun sedikit, lebih
## banyak jika investor sedang kecewa) | left (investor pergi karena kecewa; reputasi turun) | ended (kontrak
## selesai baik-baik). Aset dana dijual proporsional; investor menerima unit x NAB. -> {ok, payout}
func return_funds(uid: int, reason := "returned") -> Dictionary:
	var inv := find_investor(uid)
	if inv.is_empty():
		return {"ok": false, "error": "FUND_ERR_INVESTOR"}
	var cfg: Dictionary = data["reputation"]
	if reason == "returned":
		add_reputation(int(cfg["returned_warned"]) if is_warned(inv) else int(cfg["returned"]))
	elif reason == "left":
		add_reputation(int(cfg["left"]))
	var payout := investor_value(inv)
	_raise_cash(payout)
	payout = minf(payout, cash)
	cash -= payout
	investors.erase(inv)
	record[reason] = int(record.get(reason, 0)) + 1
	if investors.is_empty():  # sisa "debu" dari pembulatan dibersihkan
		holdings.clear()
		cash = 0.0
	gs.changed.emit()
	return {"ok": true, "payout": payout, "id": inv["id"]}


## Energi bulanan yang dipakai mengelola dana (rapat & laporan investor).
func energy_cost() -> int:
	return int(data["energy"]) if is_active() else 0


# --- Alur bulanan (dipanggil GameState.advance_month setelah _start_month) -------------------------------

## Papan tawaran diperbarui, fee manajemen dipotong ke kas pemain, lalu evaluasi tahunan (ulang tahun
## kontrak) dan pemeriksaan kepuasan bulanan tiap investor, dana diseimbangkan ulang, NAB dicatat.
## Kabar penting (peringatan, investor pergi, evaluasi) dikirim setelah laporan (signal fund_notice).
## Mengembalikan bahan laporan ({} jika tahap 7 belum terbuka).
func month_tick() -> Dictionary:
	if not is_unlocked():
		return {}
	var report := {"offers": _refresh_board()}
	record["month_fee"] = 0.0
	if investors.is_empty():
		return report
	var nav_before := nav
	var fee := value() * float(data["management_fee"]) / 12.0
	_raise_cash(fee)
	fee = minf(fee, cash)
	cash -= fee
	var paid := roundi(fee)
	gs.cash += paid
	record["mgmt_fees"] = float(record["mgmt_fees"]) + paid
	record["month_fee"] = paid
	var price := current_nav()
	for inv: Dictionary in investors:
		inv["peak_nav"] = maxf(float(inv["peak_nav"]), price)
	var notices: Array[Dictionary] = []
	var perf_fee := 0
	for inv: Dictionary in investors.duplicate():
		var months := gs.month - int(inv["joined"])
		if months > 0 and months % 12 == 0:
			var result := _anniversary(inv)
			perf_fee += int(result["perf_fee"])
			notices.append_array(result["notices"])
	for inv: Dictionary in investors.duplicate():
		if not find_investor(int(inv["uid"])).is_empty():  # kontrak yang baru selesai tidak diperiksa lagi
			notices.append_array(_monthly_check(inv))
	rebalance()
	report.merge({"fee": paid, "perf_fee": perf_fee, "investors": investors.size()})
	if not notices.is_empty():
		report["notices"] = notices
		gs.queue_after_report(func() -> void: gs.fund_notice.emit(notices))
	if investors.is_empty():
		return report
	nav = current_nav()
	nav_history.append(nav)
	record["peak_value"] = maxf(float(record["peak_value"]), value())
	report.merge({"value": value(), "nav": nav, "return": nav / maxf(nav_before, 0.0001) - 1.0})
	return report


## Kepuasan bulan ini, lalu peringatan (pertama kali) atau penarikan dana (sudah diperingatkan sebelumnya).
## Mengembalikan kabar untuk popup & laporan.
func _monthly_check(inv: Dictionary) -> Array[Dictionary]:
	var cfg: Dictionary = data["satisfaction"]
	var d := def(inv["id"])
	var tolerance := float(d["drawdown"])
	var target := float(d["target"])
	var mandate := mandate_ok(inv["id"])
	var drawdown := investor_drawdown(inv)
	var annual := investor_annual_return(inv)
	var delta := 0
	if not mandate:
		delta += int(cfg["mandate"])
	if drawdown > tolerance / 2.0:
		delta += int(cfg["drawdown"])
	if gs.month - int(inv["joined"]) >= int(cfg["min_months"]):
		if annual >= target:
			delta += int(cfg["perf_good"])
		elif annual < 0.0:
			delta += int(cfg["perf_negative"])
	inv["satisfaction"] = clampi(int(inv["satisfaction"]) + delta, 0, 100)
	var satisfaction := int(inv["satisfaction"])
	var reason := "mandate" if not mandate else ("drawdown" if drawdown > tolerance / 2.0 else "performance")
	var info := {"id": inv["id"], "reason": reason, "drawdown": drawdown, "tolerance": tolerance, "annual": annual,
		"target": target, "profile": d["profile"]}
	var unhappy := satisfaction < int(cfg["leave_below"]) or drawdown > tolerance
	if is_warned(inv) and int(inv["warned"]) < gs.month and unhappy:
		var result := return_funds(int(inv["uid"]), "left")
		return [info.merged({"kind": "left", "payout": result["payout"]})]
	var near_limit := drawdown > tolerance * float(cfg["warn_drawdown"])  # sempat menurunkan risiko sebelum batas
	if not is_warned(inv) and (satisfaction < int(cfg["warn_below"]) or near_limit or not mandate):
		inv["warned"] = gs.month
		record["warnings"] = int(record["warnings"]) + 1
		return [info.merged({"kind": "warn"})]
	if is_warned(inv) and satisfaction >= int(cfg["recover_above"]) and drawdown < tolerance / 2.0 and mandate:
		inv["warned"] = -1
		return [info.merged({"kind": "calm"})]
	return []


## Ulang tahun kontrak: fee kinerja di atas high-water mark, evaluasi setahun (kepuasan & reputasi), tambah
## setoran bila puas, lalu perpanjangan atau akhir kontrak. -> {perf_fee, notices}
func _anniversary(inv: Dictionary) -> Dictionary:
	var price := current_nav()
	var d := def(inv["id"])
	var target := float(d["target"])
	var year_return := price / maxf(float(inv["year_nav"]), 0.0001) - 1.0
	inv["year_nav"] = price
	var fee := 0
	if price > float(inv["hwm"]):
		var amount := float(inv["units"]) * (price - float(inv["hwm"])) * float(data["performance_fee"])
		_raise_cash(amount)
		amount = minf(amount, cash)
		cash -= amount
		inv["units"] = float(inv["units"]) - amount / price
		inv["hwm"] = price
		fee = roundi(amount)
		gs.cash += fee
		inv["perf_paid"] = float(inv["perf_paid"]) + fee
		record["perf_fees"] = float(record["perf_fees"]) + fee
	var eval_cfg: Dictionary = data["evaluation"]
	var rep_cfg: Dictionary = data["reputation"]
	var grade := "negative"
	if year_return >= target:
		grade = "good"
	elif year_return >= target / 2.0:
		grade = "ok"
	elif year_return >= 0.0:
		grade = "low"
	inv["satisfaction"] = clampi(int(inv["satisfaction"]) + int(eval_cfg[grade]), 0, 100)
	add_reputation(int(rep_cfg[grade + "_year"]))
	var topup := 0
	var top_cfg: Dictionary = data["topup"]
	if grade == "good" and int(inv["satisfaction"]) >= int(top_cfg["min_satisfaction"]) \
			and rng.randf() < float(top_cfg["chance"]):
		var share: Array = top_cfg["share"]
		topup = snappedi(roundi(investor_value(inv) * rng.randf_range(float(share[0]), float(share[1]))), 10_000_000)
		if topup > 0:
			cash += topup
			inv["units"] = float(inv["units"]) + topup / price
			inv["deposited"] = float(inv["deposited"]) + topup
			record["topups"] = int(record["topups"]) + 1
	var notices: Array[Dictionary] = [{"kind": "eval", "id": inv["id"], "return": year_return, "target": target,
		"grade": grade, "perf_fee": fee, "topup": topup}]
	if gs.month >= int(inv["contract_end"]):
		if int(inv["satisfaction"]) >= int(eval_cfg["renew_min"]):
			inv["contract_end"] = int(inv["contract_end"]) + int(data["contract_months"])
			add_reputation(int(rep_cfg["renewed"]))
			record["renewed"] = int(record["renewed"]) + 1
			notices.append({"kind": "renewed", "id": inv["id"]})
		else:
			var result := return_funds(int(inv["uid"]), "ended")
			notices.append({"kind": "ended", "id": inv["id"], "payout": result["payout"]})
	return {"perf_fee": fee, "notices": notices}


## Tawaran kedaluwarsa dihapus, lalu 0-2 tawaran baru (tawaran pertama dijamin setelah tahap 7 terbuka dan
## cocok dengan profil dana).
## Mengembalikan jumlah tawaran baru.
func _refresh_board() -> int:
	var cfg: Dictionary = data["board"]
	for offer: Dictionary in board.duplicate():
		if gs.month >= int(offer["expires"]):
			board.erase(offer)
	var count := 0
	var first := int(record["offers"]) == 0
	if first or rng.randf() < float(cfg["chance"]):
		count += _add_offer(first)
		if rng.randf() < float(cfg["second_chance"]):
			count += _add_offer()
	return count


## `fitting`: hanya investor yang mandatnya cocok dengan alokasi sekarang (tawaran pertama, agar pemain
## baru tidak langsung disambut pelanggaran mandat).
func _add_offer(fitting := false) -> int:
	var taken: Array = investors.map(func(inv: Dictionary) -> String: return inv["id"])
	taken.append_array(board.map(func(o: Dictionary) -> String: return o["id"]))
	var pool := investor_defs.filter(func(d: Dictionary) -> bool:
		return not d["id"] in taken and reputation >= int(d["min_reputation"]) and (not fitting or mandate_ok(d["id"])))
	if pool.is_empty():
		return 0
	var d: Dictionary = pool[rng.randi() % pool.size()]
	var range_: Array = d["amount"]
	var amount := gs.nominal(rng.randf_range(float(range_[0]), float(range_[1])), 10_000_000)
	seq += 1
	board.append({"uid": seq, "id": d["id"], "amount": amount, "expires": gs.month + int(data["board"]["expire_months"])})
	record["offers"] = int(record["offers"]) + 1
	return 1
