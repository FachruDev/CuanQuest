class_name Leverage
extends GameModule
## Posisi leverage & margin (v2a langkah 3). Pemain menyetor margin (uang sendiri), memilih leverage
## (mis. 5x) dan arah: naik (long) atau turun (short). Besar posisi = margin x leverage, sehingga
## untung dan rugi ikut berlipat. Sisanya dana pinjaman yang dikenai biaya inap setiap hari.
##
## Margin terpisah per posisi, satu posisi per aset. Setelah pasar bergerak (check_month), ekuitas
## = margin + untung/rugi berjalan - biaya inap diperiksa HARI DEMI HARI:
## - ekuitas <= liquidation x margin kapan pun -> posisi ditutup paksa di harga hari itu. Jika harga
##   melompat melewati batas (berita), ekuitas bisa minus: kekurangannya DITAGIH KE KAS (bisa memicu
##   jual paksa & bangkrut), jadi posisi berlawanan atau "lempar koin" tidak bisa dijadikan celah.
## - ekuitas < margin_call x margin di akhir bulan -> margin call (peringatan di laporan & kartu posisi).
## Data: data/leverage.json. Analogi web: limit kredit yang dihitung ulang setiap hari, dan akun
## otomatis dibekukan saat saldo jaminannya terlalu tipis.

const DATA_PATH := "res://data/leverage.json"
const LONG := 1
const SHORT := -1

var data: Dictionary = {}  # isi data/leverage.json
## Posisi terbuka, urut nomor: {uid, asset, side (1 long / -1 short), leverage, units, entry (harga buka),
## margin (termasuk tambahan), financing (biaya inap terkumpul), opened (bulan), fees, call (margin call)}
var positions: Array[Dictionary] = []
var seq := 0  # nomor posisi terakhir
## Rekam jejak: posisi dibuka/ditutup/dilikuidasi, bulan margin call, untung/rugi terealisasi, fee,
## biaya inap, dan kekurangan yang ditagih ke kas.
var record: Dictionary = {}
## Peringatan risiko sudah disetujui di permainan ini (v2a langkah 4). Sebelum itu posisi tidak bisa dibuka.
var risk_ack := false
var _daily: Array[float] = []  # sumbangan posisi ke kekayaan per tanggal (1-30) bulan terakhir, untuk grafik laporan


func load_data() -> void:
	data = DataLoader.load_json(DATA_PATH)


func reset() -> void:
	positions.clear()
	seq = 0
	record = new_record()
	risk_ack = false
	_daily.clear()


func save_to(d: Dictionary) -> void:
	d.merge({"positions": positions, "position_seq": seq, "leverage_record": record, "leverage_ack": risk_ack})


## Save sebelum v2a langkah 3: belum ada posisi.
func load_from(d: Dictionary) -> void:
	reset()
	for saved: Dictionary in d.get("positions", []):
		var p := saved.duplicate()
		for key: String in ["uid", "side", "leverage", "opened"]:
			p[key] = int(p[key])
		for key: String in ["units", "entry", "margin", "financing", "fees"]:
			p[key] = float(p[key])
		p["call"] = bool(p.get("call", false))
		positions.append(p)
	seq = int(d.get("position_seq", 0))
	risk_ack = bool(d.get("leverage_ack", false))
	var saved_record: Dictionary = d.get("leverage_record", {})
	for key: String in record:
		if saved_record.has(key):
			record[key] = int(saved_record[key]) if record[key] is int else float(saved_record[key])


static func new_record() -> Dictionary:
	return {"opened": 0, "closed": 0, "liquidated": 0, "margin_calls": 0, "pnl": 0.0, "fees": 0.0,
		"financing": 0.0, "shortfall": 0.0}


# --- Aturan & angka ------------------------------------------------------------------------------

## Leverage terbuka di tahap 6 (lihat data/unlocks.json).
func is_open() -> bool:
	return gs.progress.is_stage_unlocked(int(data["stage"]))


## Aturan kelas aset ini ({} = aset tidak bisa memakai leverage).
func rules_for(asset_id: String) -> Dictionary:
	var asset := gs.market.get_asset(asset_id)
	return data["classes"].get(asset.asset_class, {}) if asset != null else {}


func leverage_options(asset_id: String) -> Array[int]:
	var options: Array[int] = []
	for value in rules_for(asset_id).get("leverage", []):
		options.append(int(value))
	return options


func can_short(asset_id: String) -> bool:
	return rules_for(asset_id).get("short", false)


func position_of(asset_id: String) -> Dictionary:
	for p: Dictionary in positions:
		if p["asset"] == asset_id:
			return p
	return {}


func find(uid: int) -> Dictionary:
	for p: Dictionary in positions:
		if int(p["uid"]) == uid:
			return p
	return {}


## Margin minimal & pilihan margin: angka bulat yang mudah dibaca (tidak ikut inflasi).
func min_margin() -> int:
	return int(data["min_margin"])


func margin_steps() -> Array[int]:
	var steps: Array[int] = []
	for value in data["margin_steps"]:
		steps.append(int(value))
	return steps


func max_positions() -> int:
	return int(data["max_positions"])


## Biaya inap per tahun atas dana pinjaman.
func financing_rate() -> float:
	return gs.market.policy_rate + float(data["financing_spread"])


func notional(p: Dictionary) -> float:
	return p["units"] * p["entry"]


## Dana pinjaman = besar posisi - margin (menambah margin mengurangi pinjaman & biaya inap).
func borrowed(p: Dictionary) -> float:
	return maxf(0.0, notional(p) - p["margin"])


## Ekuitas = margin + untung/rugi berjalan - biaya inap. `price` <= 0 = harga sekarang.
func equity(p: Dictionary, price := -1.0) -> float:
	var at := price if price > 0.0 else gs.market.get_asset(p["asset"]).price
	return p["margin"] + p["side"] * p["units"] * (at - p["entry"]) - p["financing"]


func monthly_financing(p: Dictionary) -> float:
	return borrowed(p) * financing_rate() / 12.0


## Harga ketika ekuitas tepat `ratio` x margin (memperhitungkan biaya inap yang sudah terkumpul).
func price_at_ratio(p: Dictionary, ratio: float) -> float:
	var room: float = p["margin"] * (1.0 - ratio) - p["financing"]  # rugi harga yang masih bisa ditahan
	return maxf(0.0, p["entry"] - p["side"] * room / p["units"])


func liquidation_price(p: Dictionary) -> float:
	return price_at_ratio(p, float(data["liquidation"]))


func call_price(p: Dictionary) -> float:
	return price_at_ratio(p, float(data["margin_call"]))


func total_equity() -> float:
	var total := 0.0
	for p: Dictionary in positions:
		total += equity(p)
	return total


## Ada posisi yang sedang margin call (peringatan Beranda & event "Tidak Bisa Tidur").
func calls() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in positions:
		if p.get("call", false):
			out.append(p)
	return out


## Pemain menekan "Saya paham risikonya" di peringatan sebelum transaksi leverage pertama.
func acknowledge_risk() -> void:
	risk_ack = true
	gs.changed.emit()


func total_margin() -> float:
	var total := 0.0
	for p: Dictionary in positions:
		total += p["margin"]
	return total


func _fee_rate(asset_id: String) -> float:
	return float(rules_for(asset_id).get("fee", 0.0))


# --- Buka, tambah margin, tutup -----------------------------------------------------------------

## Rincian membuka posisi SEBELUM dijalankan (satu sumber untuk popup & open()). Angka pratinjau
## tetap diisi walau ada error (mis. kas kurang), agar pemain bisa melihat risikonya.
## -> {ok, error, args, asset_id, side, leverage, margin, notional, units, price, fee, total,
##     financing_month, call_price, liquidation_price, loss_5, loss_10}
func quote(asset_id: String, side: int, lev: int, margin: int) -> Dictionary:
	var q := {"ok": false, "error": "", "args": [], "asset_id": asset_id, "side": side, "leverage": lev, "margin": margin}
	var rules := rules_for(asset_id)
	if not is_open():
		q["error"] = "LEV_ERR_LOCKED"
	elif not risk_ack:
		q["error"] = "LEV_ERR_WARNING"
	elif rules.is_empty():
		q["error"] = "LEV_ERR_ASSET"
	elif side == SHORT and not rules["short"]:
		q["error"] = "LEV_ERR_SHORT"
	elif lev not in leverage_options(asset_id):
		q["error"] = "LEV_ERR_LEVERAGE"
	elif not position_of(asset_id).is_empty():
		q["error"] = "LEV_ERR_EXISTS"
	elif positions.size() >= max_positions():
		q["error"] = "LEV_ERR_MAX"
		q["args"] = [max_positions()]
	elif margin < min_margin():
		q["error"] = "LEV_ERR_MIN"
		q["args"] = [Fmt.rupiah(min_margin())]
	if (q["error"] != "" and q["error"] != "LEV_ERR_MIN") or margin <= 0:
		return q
	var price := gs.market.get_asset(asset_id).price
	var size := float(margin) * lev
	var fee := roundf(size * _fee_rate(asset_id))
	var preview := {"asset": asset_id, "side": side, "units": size / price, "entry": price, "margin": float(margin), "financing": 0.0}
	q.merge({"notional": size, "units": size / price, "price": price, "fee": fee, "total": margin + int(fee),
		"financing_month": monthly_financing(preview), "call_price": call_price(preview),
		"liquidation_price": liquidation_price(preview), "loss_5": size * 0.05, "loss_10": size * 0.10})
	if q["error"] == "" and margin + int(fee) > gs.cash:
		q["error"] = "LEV_ERR_CASH"
		q["args"] = [Fmt.rupiah(margin + int(fee))]
	q["ok"] = q["error"] == ""
	return q


func open(asset_id: String, side: int, lev: int, margin: int) -> Dictionary:
	var q := quote(asset_id, side, lev, margin)
	if not q["ok"]:
		return q
	seq += 1
	positions.append({"uid": seq, "asset": asset_id, "side": side, "leverage": lev, "units": q["units"],
		"entry": q["price"], "margin": float(margin), "financing": 0.0, "opened": gs.month, "fees": q["fee"], "call": false})
	gs.cash -= int(q["total"])
	record["opened"] += 1
	record["fees"] += q["fee"]
	gs.portfolio.add_fee(q["fee"])
	gs.portfolio.log_leverage("lev_open", gs.market.get_asset(asset_id), margin, q["units"], q["fee"], 0.0)
	gs.changed.emit()
	q["uid"] = seq
	return q


## Tambah margin dari kas: harga likuidasi menjauh dan dana pinjaman (biaya inap) berkurang.
func add_margin(uid: int, amount: int) -> Dictionary:
	var p := find(uid)
	if p.is_empty():
		return {"ok": false, "error": "LEV_ERR_NONE"}
	if amount <= 0:
		return {"ok": false, "error": "ERR_AMOUNT_INVALID"}
	if amount > gs.cash:
		return {"ok": false, "error": "ERR_NOT_ENOUGH_CASH"}
	p["margin"] += amount
	p["call"] = equity(p) < float(data["margin_call"]) * p["margin"]
	gs.cash -= amount
	gs.changed.emit()
	return {"ok": true}


## Hasil menutup posisi di harga `price` (<= 0 = harga sekarang): fee tutup, uang kembali (bisa minus
## jika rugi melebihi margin), untung/rugi terhadap margin.
func close_quote(uid: int, price := -1.0) -> Dictionary:
	var p := find(uid)
	if p.is_empty():
		return {}
	var at := price if price > 0.0 else gs.market.get_asset(p["asset"]).price
	var fee := roundf(p["units"] * at * _fee_rate(p["asset"]))
	var proceeds := roundf(equity(p, at) - fee)
	return {"price": at, "fee": fee, "proceeds": proceeds, "pnl": proceeds - p["margin"], "equity": equity(p, at)}


## `kind`: lev_close (manual) | lev_liquidated (batas likuidasi) | lev_forced (menutup kas minus).
func close(uid: int, kind := "lev_close", price := -1.0) -> Dictionary:
	var p := find(uid)
	if p.is_empty():
		return {"ok": false, "error": "LEV_ERR_NONE"}
	var q := close_quote(uid, price)
	var proceeds: float = q["proceeds"]
	var shortfall := maxf(0.0, -proceeds)  # rugi di atas margin: ditagih ke kas
	gs.cash += int(proceeds)
	record["liquidated" if kind == "lev_liquidated" else "closed"] += 1
	record["pnl"] += q["pnl"]
	record["fees"] += q["fee"]
	record["financing"] += p["financing"]
	record["shortfall"] += shortfall
	gs.portfolio.add_fee(q["fee"])
	var asset := gs.market.get_asset(p["asset"])
	gs.portfolio.log_leverage(kind, asset, proceeds, p["units"], q["fee"], q["pnl"])
	gs.record_extreme("best_trade", "worst_trade", q["pnl"], {"asset_key": asset.name_key})
	positions.erase(p)
	if kind == "lev_close":
		gs.changed.emit()
	return {"ok": true, "proceeds": proceeds, "pnl": q["pnl"], "fee": q["fee"], "shortfall": shortfall, "price": q["price"]}


# --- Alur bulanan (dipanggil GameState.advance_month) ---------------------------------------------

## Setelah pasar bergerak: biaya inap terkumpul dan ekuitas dicek hari demi hari; posisi yang menyentuh
## batas likuidasi ditutup paksa di harga hari itu. Posisi yang selamat tetapi ekuitasnya di bawah batas
## margin call ditandai. -> bahan laporan {count, pnl, financing, liquidated: [...], margin_calls: [...]},
## atau {} jika tidak ada posisi (laporan & golden runner tidak berubah).
func check_month() -> Dictionary:
	_daily.clear()
	if positions.is_empty():
		return {}
	_daily.resize(MarketAsset.DAYS_IN_MONTH)
	_daily.fill(0.0)
	var rate := financing_rate()
	var liq_ratio := float(data["liquidation"])
	var result := {"count": positions.size(), "pnl": 0.0, "financing": 0.0, "liquidated": [], "margin_calls": []}
	for p: Dictionary in positions.duplicate():  # urut nomor posisi: hasil sama setelah simpan/muat
		var asset := gs.market.get_asset(p["asset"])
		var steps := asset.days_per_month()
		var base := asset.history.size() - steps
		var equity_before := equity(p, asset.month_closes[-2])
		var fin_step := borrowed(p) * rate / 12.0 / steps
		var start_fin: float = p["financing"]
		var values: Array[float] = []  # ekuitas per hari bursa
		var hit := -1
		for i in steps:
			p["financing"] += fin_step
			var value := equity(p, asset.history[base + i])
			values.append(value)
			if value <= liq_ratio * p["margin"]:
				hit = i
				break
		result["financing"] += p["financing"] - start_fin
		var proceeds := 0.0
		if hit >= 0:
			var side: int = p["side"]
			var lev: int = p["leverage"]
			var closed := close(int(p["uid"]), "lev_liquidated", asset.history[base + hit])
			proceeds = closed["proceeds"]
			result["pnl"] += proceeds - equity_before
			result["liquidated"].append({"asset_id": asset.id, "asset_key": asset.name_key, "side": side, "leverage": lev,
				"day": floori(hit * MarketAsset.DAYS_IN_MONTH / float(steps)) + 1, "price": closed["price"],
				"pnl": closed["pnl"], "proceeds": proceeds, "shortfall": closed["shortfall"]})
		else:
			var after := equity(p)
			result["pnl"] += after - equity_before
			p["call"] = after < float(data["margin_call"]) * p["margin"]
			if p["call"]:
				record["margin_calls"] += 1
				result["margin_calls"].append({"asset_id": asset.id, "asset_key": asset.name_key, "equity": after, "margin": p["margin"],
					"liquidation_price": liquidation_price(p)})
		for day in range(1, MarketAsset.DAYS_IN_MONTH + 1):
			var index := ceili(day * steps / float(MarketAsset.DAYS_IN_MONTH)) - 1
			if hit >= 0 and index >= hit:
				continue  # sudah ditutup: uangnya sudah ada di kas akhir bulan
			_daily[day - 1] += values[index] - proceeds
	return result


## Sumbangan posisi ke kekayaan pada tanggal `day` (1-30) bulan yang baru disimulasikan, dibanding kas
## akhir bulan (lihat Portfolio.daily_worth_series). 0 jika bulan itu tidak ada posisi.
func daily_value(day: int) -> float:
	return _daily[day - 1] if _daily.size() >= day else 0.0


## Kas minus di awal bulan (setelah aset dijual paksa): posisi ditutup paksa, mulai ekuitas terbesar.
func cover_cash() -> Array[Dictionary]:
	var sales: Array[Dictionary] = []
	var ordered := positions.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ea := equity(a)
		var eb := equity(b)
		return ea > eb if ea != eb else int(a["uid"]) < int(b["uid"]))
	for p: Dictionary in ordered:
		if gs.cash >= 0:
			break
		var asset_key: String = gs.market.get_asset(p["asset"]).name_key
		var closed := close(int(p["uid"]), "lev_forced")
		sales.append({"asset_key": asset_key, "proceeds": int(closed["proceeds"])})
	return sales
