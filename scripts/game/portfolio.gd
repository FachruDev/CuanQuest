class_name Portfolio
extends GameModule
## Investasi: kepemilikan aset, beli/jual (fee & pajak), stop loss & take profit, bunga, riwayat
## transaksi, profil risiko, dan bahan laporan bulanan (grafik harian, aset bergerak terbesar).

const MOVERS_SHOWN := 3
const RISK_PROFILE_PATH := "res://data/risk_profile.json"
const MAX_TRANSACTIONS := 200

var holdings: Dictionary = {}  # asset_id -> { "units": float, "cost": float, "locked_until": int }
var risk_data: Dictionary = {}  # isi data/risk_profile.json
var transactions: Array[Dictionary] = []  # riwayat transaksi, terbaru di depan
var transaction_seq := 0  # nomor urut transaksi terakhir (kunci di database)
var risk_profile_id := "moderate"
# Transaksi manual selama giliran ini, untuk pembanding "kalau tidak bertransaksi" di laporan.
var turn_units: Dictionary = {}  # asset_id -> unit saat giliran dimulai
var turn_fees := 0.0  # fee + pajak transaksi manual giliran ini
## Pajak & biaya sejak laporan terakhir (v1.5a langkah 2), ditampilkan di laporan bulanan.
var month_costs: Dictionary = {}  # {"trade_fee", "trade_tax", "interest_tax"}
var turn_trades := 0
## Stop loss & take profit (v1.5a langkah 4): asset_id -> {"stop_loss": harga, "take_profit": harga}
## (0 = tidak dipakai). Dicek setiap hari saat pasar bergerak; lihat execute_orders().
var orders: Dictionary = {}


func load_data() -> void:
	risk_data = DataLoader.load_json(RISK_PROFILE_PATH)


## Profil risiko dipilih di Game Baru (lihat GameState.new_game).
func reset() -> void:
	transactions.clear()
	transaction_seq = 0
	orders.clear()
	holdings.clear()
	month_costs = new_month_costs()


func save_to(d: Dictionary) -> void:
	d.merge({"holdings": holdings, "transactions": transactions, "transaction_seq": transaction_seq,
		"risk_profile": risk_profile_id, "orders": orders, "turn_units": turn_units, "turn_fees": turn_fees,
		"turn_trades": turn_trades, "month_costs": month_costs})


func load_from(d: Dictionary) -> void:
	holdings.clear()
	for asset_id: String in d["holdings"]:
		var h: Dictionary = d["holdings"][asset_id]
		holdings[asset_id] = {"units": float(h["units"]), "cost": float(h["cost"]),
			"locked_until": int(h.get("locked_until", 0))}
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
	orders.clear()
	for asset_id: String in d.get("orders", {}):
		var saved_order: Dictionary = d["orders"][asset_id]
		orders[asset_id] = {"stop_loss": float(saved_order["stop_loss"]), "take_profit": float(saved_order["take_profit"])}
	turn_units = d.get("turn_units", {})
	turn_fees = float(d.get("turn_fees", 0.0))
	turn_trades = int(d.get("turn_trades", 0))
	month_costs = new_month_costs().merged(d.get("month_costs", {}), true)


## Efek event "sell_all": jual semua investasi karena panik.
func apply_effects(e: Dictionary) -> void:
	if e.get("sell_all", false):
		gs.stats["panic_sell"] = true
		for asset_id: String in holdings.keys():
			sell(asset_id, ceili(holding_value(asset_id)), "panic")


## Kekayaan bersih per tanggal (1-30) selama bulan yang baru disimulasikan, diawali
## `start_value`. Dipakai animasi grafik di laporan bulanan. Kas & jumlah unit tidak
## berubah di tengah bulan, jadi cukup menilai ulang portofolio dengan harga harian.
## Gaji & biaya hidup bulan baru TIDAK ikut digambar, agar lonjakannya tidak menenggelamkan
## pergerakan pasar; angka kekayaan di laporan tetap nilai setelahnya.
## `executed`: pesanan otomatis bulan ini. Sebelum tanggal terpicu, aset itu masih dipegang
## (dinilai dengan harga harian); sejak tanggal itu, uang hasil jualnya sudah di kas.
func daily_worth_series(start_value: float, executed: Array[Dictionary] = []) -> Array[float]:
	var series: Array[float] = [start_value]
	for day in range(1, MarketAsset.DAYS_IN_MONTH + 1):
		var value := float(gs.cash) + gs.dreams.funds()
		for asset_id: String in holdings:
			var asset := gs.market.get_asset(asset_id)
			value += units_of(asset_id) * (asset.price if asset.is_interest() else asset.price_on_day(day))
		for sale: Dictionary in executed:
			if day < int(sale["day"]):
				var sold := gs.market.get_asset(sale["asset_id"])
				value += float(sale["units"]) * sold.price_on_day(day) - float(sale["proceeds"])
		series.append(value)
	return series


func current_prices() -> Dictionary:
	var prices := {}
	for asset: MarketAsset in gs.market.assets.values():
		prices[asset.id] = asset.price
	return prices


## Aset dengan pergerakan terbesar sejak `start_prices`, untuk kartu sorotan laporan.
## Aset yang dimiliki didahulukan; aset yang belum terbuka dilewati.
## -> [{"id": "BSNT", "name_key": ..., "change": 0.062, "owned": true}, ...]
func movers_since(start_prices: Dictionary) -> Array:
	var candidates: Array = []
	for asset: MarketAsset in gs.market.assets.values():
		if asset.is_interest() or not start_prices.has(asset.id):
			continue
		var owned := units_of(asset.id) > 0.0
		if not owned and not gs.progress.is_asset_unlocked(asset.id):
			continue
		candidates.append({"id": asset.id, "name_key": asset.name_key, "owned": owned,
			"change": asset.price / float(start_prices[asset.id]) - 1.0})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["owned"] != b["owned"]:
			return a["owned"]
		return absf(a["change"]) > absf(b["change"]))
	return candidates.slice(0, MOVERS_SHOWN)


## Bunga bulanan tabungan & deposito (setelah pajak) ditambahkan ke saldo. Mengembalikan totalnya.
func pay_interest() -> float:
	var total := 0.0
	for asset_id: String in holdings:
		var asset := gs.market.get_asset(asset_id)
		if not asset.is_interest():
			continue
		var gross: float = holdings[asset_id]["units"] * gs.market.rate_for(asset) / 12.0
		var tax := gross * asset.interest_tax  # pajak final bunga (deposito 20%)
		holdings[asset_id]["units"] += gross - tax
		total += gross - tax
		add_tax("interest_tax", tax)
	gs.stats["total_interest"] += total
	return total


func new_month_costs() -> Dictionary:
	return {"trade_fee": 0.0, "trade_tax": 0.0, "interest_tax": 0.0}


func add_tax(key: String, amount: float) -> void:
	month_costs[key] += amount
	gs.stats["total_taxes"] += amount


## Kas + aset berisiko sangat rendah (tabungan, deposito, RD pasar uang).
func liquid_assets() -> float:
	var total := float(gs.cash)
	for asset_id: String in holdings:
		if gs.market.get_asset(asset_id).risk <= 1:
			total += holding_value(asset_id)
	return total


func units_of(asset_id: String) -> float:
	return holdings.get(asset_id, {}).get("units", 0.0)


func cost_of(asset_id: String) -> float:
	return holdings.get(asset_id, {}).get("cost", 0.0)


func holding_value(asset_id: String) -> float:
	return units_of(asset_id) * gs.market.get_asset(asset_id).price


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


## Rincian satu transaksi SEBELUM dijalankan. Satu sumber hitungan untuk layar konfirmasi,
## buy(), dan sell() (mirip fungsi hitung total checkout yang dipakai UI dan backend).
## Beli: `amount` = uang yang dibayar (fee & pajak diambil dari situ).
## Jual: `amount` = nilai pasar aset yang dijual (fee, pajak, & penalti dipotong dari situ).
## `at_price` > 0: harga per unit tertentu (mis. harga hari stop loss terpicu), bukan harga sekarang.
## -> {ok, error, buy, asset_id, amount, units, fee, tax, penalty, net, pnl, warnings}
##    net: beli = yang benar-benar masuk ke investasi; jual = uang yang diterima.
func trade_quote(asset_id: String, is_buy: bool, amount: int, at_price: float = 0.0) -> Dictionary:
	var asset := gs.market.get_asset(asset_id)
	var price := at_price if at_price > 0.0 else asset.price
	var q := {"ok": false, "error": "", "buy": is_buy, "asset_id": asset_id, "amount": amount,
		"units": 0.0, "fee": 0.0, "tax": 0.0, "penalty": 0.0, "net": 0.0, "pnl": 0.0, "warnings": []}
	if is_buy and not gs.progress.is_asset_unlocked(asset_id):
		q["error"] = "ERR_LOCKED"
	elif amount <= 0:
		q["error"] = "ERR_AMOUNT_INVALID"
	elif is_buy and amount > gs.cash:
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
	var cfg: Dictionary = gs.economy["trade_warnings"]
	var warnings: Array[Dictionary] = []
	if q["buy"]:
		var risky := asset.risk >= int(cfg["risky_from"])
		if exceeds_risk_profile(asset):
			warnings.append({"id": "risk", "args": [risk_profile()["name"]]})
		var invest_after: float = investments_value() + q["net"]
		var share: float = (holding_value(asset.id) + q["net"]) / maxf(invest_after, 1.0)
		if risky and invest_after >= gs.nominal(cfg["concentration_min"]) and share > float(cfg["concentration"]):
			warnings.append({"id": "concentration", "args": [share]})
		if risky and gs.budget.emergency_balance() < gs.budget.emergency_target():
			warnings.append({"id": "emergency", "args": [gs.budget.emergency_balance(), gs.budget.emergency_target()]})
		if asset.asset_class != "savings" and gs.cash - int(q["amount"]) < gs.monthly_expenses():
			warnings.append({"id": "low_cash", "args": [gs.monthly_expenses()]})
	else:
		if q["penalty"] > 0.0:
			warnings.append({"id": "penalty", "args": [locked_until(asset.id)]})
		if q["pnl"] < 0.0:
			warnings.append({"id": "loss", "args": [-q["pnl"]]})
	return warnings


func _add_trade_costs(fee: float, tax: float) -> void:
	month_costs["trade_fee"] += fee
	gs.stats["total_fees"] += fee
	add_tax("trade_tax", tax)


## Beli aset senilai `amount` Rupiah (sudah termasuk fee & pajak, lihat trade_quote).
## Mengembalikan { ok, error, units, fee, tax } supaya UI bisa menampilkan pesan.
## `kind`: buy (manual) | auto (autodebet dari rencana gaji).
func buy(asset_id: String, amount: int, kind: String = "buy") -> Dictionary:
	var q := trade_quote(asset_id, true, amount)
	if not q["ok"]:
		return {"ok": false, "error": q["error"]}
	var asset := gs.market.get_asset(asset_id)
	var fee: float = q["fee"]
	var tax: float = q["tax"]
	var units: float = q["units"]

	var h: Dictionary = holdings.get(asset_id, {"units": 0.0, "cost": 0.0, "locked_until": 0})
	h["units"] += units
	h["cost"] += amount
	if asset.lock_months > 0:
		h["locked_until"] = gs.month + asset.lock_months  # setoran baru memperpanjang tenor
	holdings[asset_id] = h
	gs.cash -= amount
	_add_trade_costs(fee, tax)
	_log_transaction(kind, asset, amount, units, fee, tax, 0.0)
	if kind == "buy":  # autodebet tidak dihitung sebagai transaksi manual
		turn_fees += fee + tax
		turn_trades += 1
		gs.targets.progress("invest", amount)

	gs.changed.emit()
	return {"ok": true, "units": units, "fee": fee, "tax": tax}


## Jual aset senilai `amount` Rupiah (berdasarkan harga pasar sebelum fee).
## `kind`: sell (manual) | forced (jual paksa saat kas minus) | panic (event panik jual)
##         | stop_loss | take_profit (pesanan otomatis, dijual di `at_price`).
func sell(asset_id: String, amount: int, kind: String = "sell", at_price: float = 0.0) -> Dictionary:
	var q := trade_quote(asset_id, false, amount, at_price)
	if not q["ok"]:
		return {"ok": false, "error": q["error"]}
	var asset := gs.market.get_asset(asset_id)
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
	gs.cash += proceeds
	_add_trade_costs(fee, tax)
	gs.record_extreme("best_trade", "worst_trade", proceeds - cost_sold, {"asset_key": asset.name_key})
	_log_transaction(kind, asset, proceeds, units, fee, tax, proceeds - cost_sold)
	if kind in ["sell", "panic"]:
		turn_fees += fee + tax
		turn_trades += 1
		if proceeds - cost_sold < 0.0:
			gs.targets.fail("no_loss")

	gs.changed.emit()
	return {"ok": true, "units": units, "fee": fee, "tax": tax, "proceeds": proceeds,
		"pnl": proceeds - cost_sold, "penalty": q["penalty"] > 0.0}


func orders_config() -> Dictionary:
	return gs.economy["orders"]


## Pesanan bisa dipasang pada aset berharga harian yang sedang dimiliki (bukan tabungan/deposito).
func can_have_order(asset_id: String) -> bool:
	return holdings.has(asset_id) and not gs.market.get_asset(asset_id).is_interest()


## {"stop_loss": harga, "take_profit": harga} atau {} jika tidak ada pesanan.
func order_of(asset_id: String) -> Dictionary:
	return orders.get(asset_id, {})


## Pasang/ubah pesanan (harga batas per unit). Keduanya 0 = hapus pesanan.
func set_order(asset_id: String, stop_loss: float, take_profit: float) -> void:
	if stop_loss <= 0.0 and take_profit <= 0.0:
		orders.erase(asset_id)
	elif can_have_order(asset_id):
		orders[asset_id] = {"stop_loss": maxf(stop_loss, 0.0), "take_profit": maxf(take_profit, 0.0)}
	gs.changed.emit()
	gs.state_committed.emit()


## Dicek hari demi hari pada harga bulan yang baru disimulasikan. Pesanan yang tersentuh
## menjual SEMUA unit aset itu di harga hari tersebut, lalu selesai. Mengembalikan daftar
## yang terpicu untuk laporan: [{asset_id, asset_key, kind, day, price, end_price, units, proceeds, pnl}]
func execute_orders() -> Array[Dictionary]:
	var executed: Array[Dictionary] = []
	var ids: Array = orders.keys()
	ids.sort()  # urutan tetap agar hasil simulasi sama setelah simpan/muat
	for asset_id: String in ids:
		if not can_have_order(asset_id):
			orders.erase(asset_id)
			continue
		var asset := gs.market.get_asset(asset_id)
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
				gs.stats["orders_executed"] += 1
			orders.erase(asset_id)
			break
	return executed


## Deposito yang belum jatuh tempo kena penalti jika dicairkan.
func is_locked(asset_id: String) -> bool:
	return holdings.get(asset_id, {}).get("locked_until", 0) > gs.month


func locked_until(asset_id: String) -> int:
	return holdings.get(asset_id, {}).get("locked_until", 0)


## Kas minus di awal bulan: aset dijual paksa, mulai dari risiko paling rendah
## (GDD 5.8: "pemain terpaksa menjual aset, mungkin saat rugi").
func cover_negative_cash() -> Array[Dictionary]:
	var sales: Array[Dictionary] = []
	if gs.cash >= 0:
		return sales
	var ids: Array = holdings.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return gs.market.get_asset(a).risk < gs.market.get_asset(b).risk)
	for asset_id: String in ids:
		if gs.cash >= 0:
			break
		var asset := gs.market.get_asset(asset_id)
		var fee_rate := asset.sell_fee + asset.sell_tax + (asset.early_penalty if is_locked(asset_id) else 0.0)
		var needed := ceili(-gs.cash / (1.0 - fee_rate)) + 1000
		var result := sell(asset_id, mini(needed, ceili(holding_value(asset_id))), "forced")
		if result["ok"]:
			sales.append({"asset_key": asset.name_key, "proceeds": result["proceeds"]})
	for entry: Dictionary in gs.dreams.active():  # terakhir: dana pos impian terpaksa dipakai
		if gs.cash >= 0:
			break
		var taken := minf(float(entry["saved"]), -gs.cash)
		if taken <= 0.0:
			continue
		entry["saved"] -= taken
		gs.cash += roundi(taken)
		sales.append({"asset_key": gs.dreams.find_def(entry["id"])["name"], "proceeds": roundi(taken)})
	gs.stats["forced_sales"] += sales.size()
	return sales


## `kind`: buy | auto | sell | forced | panic. `pnl` = untung/rugi terealisasi (khusus jual).
func _log_transaction(kind: String, asset: MarketAsset, amount: float, units: float,
		fee: float, tax: float, pnl: float) -> void:
	transaction_seq += 1
	transactions.push_front({"seq": transaction_seq, "month": gs.month, "kind": kind, "asset_key": asset.name_key,
		"amount": amount, "units": units, "fee": fee, "tax": tax, "pnl": pnl})
	if transactions.size() > MAX_TRANSACTIONS:
		transactions.resize(MAX_TRANSACTIONS)


## Mencatat portofolio di awal giliran, agar transaksi manual bulan ini bisa dibandingkan.
func snapshot_turn() -> void:
	turn_units.clear()
	for asset_id: String in holdings:
		turn_units[asset_id] = units_of(asset_id)
	turn_fees = 0.0
	turn_trades = 0


## Selisih hasil transaksi manual bulan ini dibanding kalau portofolio awal giliran ditahan:
## (perubahan unit x pergerakan harga bulan ini) - fee. Transaksi terjadi di harga awal bulan.
func turn_trade_result(start_prices: Dictionary) -> Dictionary:
	if turn_trades == 0:
		return {"edge": 0.0, "trades": 0, "fees": 0.0}
	var ids := turn_units.keys()
	for asset_id: String in holdings:
		if asset_id not in ids:
			ids.append(asset_id)
	var edge := -turn_fees
	for asset_id: String in ids:
		var asset := gs.market.get_asset(asset_id)
		var delta := units_of(asset_id) - float(turn_units.get(asset_id, 0.0))
		edge += delta * (asset.price - float(start_prices.get(asset_id, asset.price)))
	return {"edge": edge, "trades": turn_trades, "fees": turn_fees}


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
	return gs.find_option(risk_profiles(), risk_profile_id)


func set_risk_profile(id: String) -> void:
	risk_profile_id = id
	gs.changed.emit()


## true jika risiko aset melebihi profil risiko pemain.
func exceeds_risk_profile(asset: MarketAsset) -> bool:
	return asset.risk > int(risk_profile()["max_asset_risk"])
