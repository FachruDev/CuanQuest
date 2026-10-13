extends RefCounted
## Dunia prototipe C "Sesi Pasar".
##
## Hidup berjalan PER BULAN lewat tombol manual (seperti v1). Di dalam bulan, grafik
## berjalan sendiri selama satu sesi dengan jumlah pergerakan tetap (`ticks_per_month`).
## Pemain boleh menekan Lanjut kapan saja; sisa pergerakan dihitung instan, sehingga satu
## bulan selalu berisi pergerakan pasar yang sama, ditonton ataupun dilewati.
##
## Tidak tahu apa-apa soal UI (bisa dites headless). Popup yang menunggu ada di `pending`.

signal logged(text: String)
signal counted(key: String)
signal flash(text: String)   # berita kilat untuk banner

const ProtoDirector := preload("res://prototypes/time/proto_director.gd")
const VERSION := 1
const NEWS_UP := ["%s: laba kuartalan di atas perkiraan.", "%s: investor besar mulai memborong.",
	"%s: kabar kerja sama dengan perusahaan raksasa."]
const NEWS_DOWN := ["%s: muncul kabar kinerja memburuk.", "%s: aksi jual besar-besaran.",
	"%s: regulator mulai menyelidiki."]


class Instrument:
	var id: String
	var name: String
	var drift: float
	var volatility: float
	var buy_fee: float
	var sell_fee: float
	var news_chance: float
	var news_min: float
	var news_max: float
	var price: float
	var month_open: float          # harga awal bulan (untuk perubahan "bulan ini")
	var follow: Array[float] = []  # sisa dampak berita untuk tick berikutnya (log-return)
	var history: Array[float] = []


var cfg: Dictionary
var instruments: Array[Instrument] = []
var rng := RandomNumberGenerator.new()   # pasar
var director := ProtoDirector.new()

var month_index := 0
var tick := 0
var ticks_per_month := 120
var seconds_per_tick := 0.75
var speed := 1
var cash := 0.0
var holdings := {}
var avg_cost := {}
var pending: Array = []      # {kind: "event"|"report"|"info", ...}

# Catatan bulan berjalan, untuk pembanding "kalau hanya ditahan".
var month_start_cash := 0.0
var month_start_worth := 0.0
var month_start_holdings := {}
var month_event_cash := 0.0
var month_trades := 0
var month_fees := 0.0
var total_edge := 0.0        # akumulasi hasil trading dibanding menahan, semua bulan

var _pause_reasons := {}
var _accumulator := 0.0


func setup(config: Dictionary, asset_defs: Array, event_defs: Array, seed_value: int) -> void:
	cfg = config
	var s: Dictionary = cfg["session"]
	ticks_per_month = int(s["ticks_per_month"])
	seconds_per_tick = float(s["seconds_per_tick"])
	rng.seed = seed_value
	director.setup(cfg["events"], event_defs, seed_value + 1)
	for item: Dictionary in cfg["market"]["instruments"]:
		var def: Dictionary = asset_defs.filter(func(a: Dictionary) -> bool: return a["id"] == item["asset_id"])[0]
		var inst := Instrument.new()
		inst.id = def["id"]
		inst.name = item["name"]
		inst.drift = def["drift"]
		inst.volatility = def["volatility"]
		inst.buy_fee = def["buy_fee"]
		inst.sell_fee = def["sell_fee"]
		inst.news_chance = item["news_chance_per_tick"]
		inst.news_min = item["news_size_min"]
		inst.news_max = item["news_size_max"]
		inst.price = def["start_price"]
		inst.month_open = inst.price
		inst.history.assign([inst.price])
		instruments.append(inst)
		holdings[inst.id] = 0.0
		avg_cost[inst.id] = 0.0


func new_game() -> void:
	cash = cfg["money"]["start_cash"]
	_begin_month()


func find(id: String) -> Instrument:
	for inst in instruments:
		if inst.id == id:
			return inst
	return null


# --- Jeda & kecepatan (alasan jeda seperti GameClock prototipe A) ----------------------

func pause(reason: String) -> void:
	_pause_reasons[reason] = true


func resume(reason: String) -> void:
	_pause_reasons.erase(reason)


func is_paused() -> bool:
	return not _pause_reasons.is_empty()


func has_pause(reason: String) -> bool:
	return _pause_reasons.has(reason)


func session_over() -> bool:
	return tick >= ticks_per_month


## Dipanggil UI setiap frame. Mengembalikan jumlah tick yang dijalankan.
func advance(real_delta: float) -> int:
	if is_paused() or session_over():
		_accumulator = 0.0
		return 0
	_accumulator += real_delta * speed
	var steps := floori(_accumulator / seconds_per_tick)
	_accumulator -= steps * seconds_per_tick
	steps = mini(steps, int(cfg["session"]["max_ticks_per_frame"]))
	for i in steps:
		_tick()
		if not pending.is_empty() or session_over():
			_accumulator = 0.0
			return i + 1
	return steps


# --- Kalender bulan ----------------------------------------------------------------------

func day_of_month() -> int:
	return mini(int(cfg["session"]["days_per_month"]), 1 + floori(tick * float(cfg["session"]["days_per_month"]) / ticks_per_month))


func month_name() -> String:
	return TranslationServer.translate("MONTH_%d" % (month_index % int(cfg["session"]["months_per_year"]) + 1))


func year() -> int:
	return floori(month_index / float(cfg["session"]["months_per_year"])) + 1


## Menit kalender untuk tick sekarang (dipakai jadwal Event Director).
func _now_minute() -> int:
	var days := int(cfg["session"]["days_per_month"])
	return month_index * days * 1440 + floori(tick / float(ticks_per_month) * days * 1440)


# --- Alur bulan --------------------------------------------------------------------------

func _begin_month() -> void:
	tick = 0
	month_start_cash = cash
	month_start_worth = net_worth()
	month_start_holdings = holdings.duplicate()
	month_event_cash = 0.0
	month_trades = 0
	month_fees = 0.0
	for inst in instruments:
		inst.month_open = inst.price
	var days := int(cfg["session"]["days_per_month"])
	director.plan_month(month_index * days, days, -1)


## Tombol Lanjut: sisa pergerakan bulan ini dihitung instan, lalu laporan muncul.
## Event yang jatuh tempo di sisa bulan tampil lebih dulu.
func finish_month() -> void:
	counted.emit("month")
	if not session_over():
		counted.emit("skip_early")
	while not session_over():
		_tick()
	pending.append(_month_report())


## Dipanggil UI setelah laporan ditutup: gaji & tagihan, lalu sesi bulan berikutnya.
func start_next_month() -> void:
	total_edge += trading_edge()
	month_index += 1
	cash += float(cfg["money"]["salary"]) - float(cfg["money"]["monthly_bills"])
	_begin_month()
	logged.emit("Gaji %s masuk, tagihan %s dibayar." % [Fmt.rupiah(cfg["money"]["salary"]), Fmt.rupiah(cfg["money"]["monthly_bills"])])


func _tick() -> void:
	tick += 1
	var dt := 1.0 / (ticks_per_month * float(cfg["session"]["months_per_year"]))
	var m: Dictionary = cfg["market"]
	for inst in instruments:  # urutan tetap: penting untuk determinisme RNG
		var move := (inst.drift - 0.5 * inst.volatility * inst.volatility) * dt + inst.volatility * sqrt(dt) * rng.randfn()
		if not inst.follow.is_empty():
			move += inst.follow.pop_front()
		if rng.randf() < inst.news_chance:
			move += _flash_news(inst, m)
		inst.price = maxf(inst.price * exp(move), 1.0)
		inst.history.append(inst.price)
		if inst.history.size() > int(m["history_limit"]):
			inst.history = inst.history.slice(-int(m["history_limit"]))
	if director.is_due(_now_minute()):
		var event := director.pop_event()
		pending.append({"kind": "event", "event_id": event["id"]})
		counted.emit("event")


## Berita kilat: sebagian dampak langsung terasa, sisanya menyusul (kabar asli) atau
## berbalik (rumor). Pemain yang cepat bereaksi atas kabar asli bisa diuntungkan.
## Arah naik/turun acak 50:50, jadi rata-rata jangka panjang harga tidak berubah.
func _flash_news(inst: Instrument, m: Dictionary) -> float:
	var size := rng.randf_range(inst.news_min, inst.news_max)
	var direction := 1.0 if rng.randf() < 0.5 else -1.0
	var is_true := rng.randf() < float(m["news_true_chance"])
	var instant := size * float(m["news_instant_share"])
	var follow_ticks := int(m["news_follow_ticks"])
	var later := (size - instant) if is_true else -instant
	inst.follow.clear()
	for i in follow_ticks:
		inst.follow.append(direction * later / follow_ticks)
	var pool: Array = NEWS_UP if direction > 0.0 else NEWS_DOWN
	var text: String = pool[rng.randi() % pool.size()] % inst.id
	counted.emit("flash_news")
	flash.emit(text)
	logged.emit("Kabar kilat: " + text)
	return direction * instant


# --- Transaksi -----------------------------------------------------------------------------

func holding_value(id: String) -> float:
	return holdings[id] * find(id).price


func net_worth() -> float:
	var total := cash
	for inst in instruments:
		total += holding_value(inst.id)
	return total


func unrealized_ratio(id: String) -> float:
	if holdings[id] <= 0.0 or avg_cost[id] <= 0.0:
		return 0.0
	return find(id).price / avg_cost[id] - 1.0


func buy(id: String, rupiah: float) -> bool:
	if rupiah <= 0.0 or rupiah > cash + 0.5:
		return false
	rupiah = minf(rupiah, cash)
	var inst := find(id)
	var fee := rupiah * inst.buy_fee
	var units := (rupiah - fee) / inst.price
	avg_cost[id] = (avg_cost[id] * holdings[id] + rupiah) / (holdings[id] + units)
	holdings[id] += units
	cash -= rupiah
	month_trades += 1
	month_fees += fee
	counted.emit("trade")
	logged.emit("Beli %s unit %s di %s." % [Fmt.units(units), id, Fmt.rupiah(inst.price)])
	return true


func sell(id: String, units: float) -> bool:
	units = minf(units, holdings[id])
	if units <= 0.0:
		return false
	var inst := find(id)
	var gross := units * inst.price
	var fee := gross * inst.sell_fee
	var profit: float = gross - fee - units * avg_cost[id]
	holdings[id] -= units
	if holdings[id] < 1e-9:
		holdings[id] = 0.0
		avg_cost[id] = 0.0
	cash += gross - fee
	month_trades += 1
	month_fees += fee
	counted.emit("trade")
	logged.emit("Jual %s unit %s di %s (untung/rugi %s)." % [Fmt.units(units), id, Fmt.rupiah(inst.price), Fmt.signed_rupiah(profit)])
	return true


## Kekayaan seandainya portofolio awal bulan ditahan tanpa transaksi apa pun.
func hold_benchmark() -> float:
	var total := month_start_cash + month_event_cash
	for inst in instruments:
		total += month_start_holdings[inst.id] * inst.price
	return total


## Hasil trading bulan ini dibanding hanya menahan (fee sudah termasuk).
func trading_edge() -> float:
	return net_worth() - hold_benchmark()


# --- Popup ---------------------------------------------------------------------------------

func _month_report() -> Dictionary:
	var worth := net_worth()
	var edge := trading_edge()
	var lines: Array[String] = [
		"Kekayaan: %s (%s)" % [Fmt.rupiah(worth), Fmt.signed_rupiah(worth - month_start_worth)],
	]
	if month_trades == 0:
		lines.append("Kamu tidak bertransaksi bulan ini; portofoliomu bergerak mengikuti pasar.")
	else:
		lines.append("Hasil trading: %s dibanding kalau hanya menahan" % Fmt.signed_rupiah(edge))
		lines.append("%d transaksi, fee %s" % [month_trades, Fmt.rupiah(month_fees)])
		if edge >= 0.0:
			lines.append("\nTrading bulan ini lebih untung daripada menahan. Ingat, hasil satu bulan bisa saja karena keberuntungan.")
		else:
			lines.append("\nMenahan saja akan lebih untung %s. Fee dan keputusan terburu-buru sering menggerus hasil." % Fmt.rupiah(-edge))
	lines.append("\nBulan depan: gaji %s, tagihan %s." % [Fmt.signed_rupiah(cfg["money"]["salary"]),
		Fmt.signed_rupiah(-float(cfg["money"]["monthly_bills"]))])
	return {"kind": "report", "title": "Laporan %s" % month_name(), "body": "\n".join(lines)}


func resolve_event(event: Dictionary, choice_index: int) -> Dictionary:
	var outcome := director.resolve(event, choice_index)
	cash += outcome["cash"]
	month_event_cash += outcome["cash"]
	return outcome


func can_afford(choice: Dictionary) -> bool:
	var cost := float(choice.get("cost", 0))
	return cost == 0.0 or cost <= cash


# --- Simpan / muat -------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var items := {}
	for inst in instruments:
		items[inst.id] = {"price": inst.price, "month_open": inst.month_open, "follow": inst.follow,
			"history": inst.history}
	return {"version": VERSION, "rng_seed": str(rng.seed), "rng_state": str(rng.state),
		"director": director.to_dict(), "instruments": items, "month_index": month_index, "tick": tick,
		"seconds_per_tick": seconds_per_tick, "speed": speed, "cash": cash, "holdings": holdings,
		"avg_cost": avg_cost, "pending": pending, "month_start_cash": month_start_cash,
		"month_start_worth": month_start_worth, "month_start_holdings": month_start_holdings,
		"month_event_cash": month_event_cash, "month_trades": month_trades, "month_fees": month_fees,
		"total_edge": total_edge, "accumulator": _accumulator}


func load_state(d: Dictionary) -> bool:
	if int(d.get("version", 0)) != VERSION:
		return false
	rng.seed = str(d["rng_seed"]).to_int()
	rng.state = str(d["rng_state"]).to_int()
	director.load_state(d["director"])
	for inst in instruments:  # urutan dari config, bukan urutan key JSON
		var s: Dictionary = d["instruments"][inst.id]
		inst.price = s["price"]
		inst.month_open = s["month_open"]
		inst.follow.assign(s["follow"])
		inst.history.assign(s["history"])
		holdings[inst.id] = float(d["holdings"][inst.id])
		avg_cost[inst.id] = float(d["avg_cost"][inst.id])
	month_index = int(d["month_index"])
	tick = int(d["tick"])
	seconds_per_tick = float(d["seconds_per_tick"])
	speed = int(d["speed"])
	cash = d["cash"]
	pending = d["pending"]
	month_start_cash = d["month_start_cash"]
	month_start_worth = d["month_start_worth"]
	month_start_holdings = d["month_start_holdings"]
	month_event_cash = d["month_event_cash"]
	month_trades = int(d["month_trades"])
	month_fees = d["month_fees"]
	total_edge = d["total_edge"]
	_accumulator = float(d["accumulator"])
	return true
