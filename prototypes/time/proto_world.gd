extends RefCounted
## Dunia prototipe: jam + pasar + kas + energi + Event Director + antrean pesanan.
##
## Tidak tahu apa-apa soal UI, sehingga bisa dites headless. UI memanggil advance(),
## sleep(), skip_to_payday(), buy(), sell(), lalu membaca state. Kejadian yang harus
## tampil sebagai popup (dan menjeda jam) ditaruh di `pending`; catatan biasa dikirim
## lewat signal `logged`.

signal logged(text: String)
signal counted(key: String)   # untuk metrik uji: trade, queued, sleep, pass_out, ...

const GameClock := preload("res://prototypes/time/game_clock.gd")
const ProtoMarket := preload("res://prototypes/time/proto_market.gd")
const ProtoDirector := preload("res://prototypes/time/proto_director.gd")
const VERSION := 1

var cfg: Dictionary
var clock := GameClock.new()
var market := ProtoMarket.new()
var director := ProtoDirector.new()

var cash := 0.0
var reserved_cash := 0.0      # kas yang ditahan untuk pesanan beli di antrean
var holdings := {}            # id -> unit (termasuk yang ditahan untuk pesanan jual)
var reserved_units := {}      # id -> unit yang ditahan untuk pesanan jual
var orders: Array = []        # [{id, asset, side, amount, created}]
var energy := 100.0
var warned_tonight := false
var month_start_worth := 0.0
var next_order_id := 1
var pending: Array = []       # popup yang menunggu: {kind: "info"|"event", title, body, event_id}

var _mode := ""               # "" = berjalan biasa | "sleep" | "skip"


func setup(config: Dictionary, asset_defs: Array, event_defs: Array, seed_value: int) -> void:
	cfg = config
	clock.setup(cfg["clock"], cfg["calendar"])
	market.setup(cfg["market"], cfg["calendar"], asset_defs, seed_value)
	director.setup(cfg["events"], event_defs, seed_value + 1)
	for inst in market.instruments:
		holdings[inst.id] = 0.0
		reserved_units[inst.id] = 0.0


func new_game() -> void:
	cash = cfg["money"]["start_cash"]
	energy = _energy_for_hour(clock.hour())
	month_start_worth = net_worth()
	director.plan_month(0, clock.days_per_month, clock.minutes)


# --- Menjalankan waktu --------------------------------------------------------------

## Dipanggil UI setiap frame. Mengembalikan jumlah langkah yang dijalankan.
## Berhenti lebih awal bila ada popup baru, karena UI akan menjeda jam.
func advance(real_delta: float) -> int:
	var steps := clock.consume(real_delta)
	for i in steps:
		_step()
		if not pending.is_empty():
			return i + 1
	return steps


## Tidur sampai pukul 06:00 berikutnya. Pasar tetap disimulasikan; event yang jatuh
## tempo selama tidur muncul saat bangun.
func sleep() -> void:
	var start := clock.minutes
	_run_until(clock.next_time_at_hour(int(cfg["day"]["wake_hour"])), "sleep", false)
	var slept_hours := (clock.minutes - start) / 60.0
	energy = minf(float(cfg["day"]["energy_max"]), energy + slept_hours * float(cfg["day"]["energy_per_sleep_hour"]))
	warned_tonight = false
	counted.emit("sleep")
	logged.emit("Tidur %d jam. Energi sekarang %d." % [roundi(slept_hours), roundi(energy)])


func skip_to_payday() -> void:
	var cal: Dictionary = cfg["calendar"]
	_skip(clock.next_time_at_date(int(cal["payday"]), int(cal["payday_hour"])), "skip_payday")


func skip_to_month_end() -> void:
	var cal: Dictionary = cfg["calendar"]
	_skip(clock.next_time_at_date(int(cal["report_day"]), int(cal["report_hour"])), "skip_month_end")


## Lompat waktu: karakter dianggap hidup normal (tidur tiap malam). Berhenti otomatis
## bila ada event atau laporan.
func _skip(target: int, metric: String) -> void:
	counted.emit(metric)
	_run_until(target, "skip", true)
	energy = _energy_for_hour(clock.hour())
	warned_tonight = false


func _run_until(target: int, mode: String, stop_on_popup: bool) -> void:
	var previous := _mode
	_mode = mode
	while clock.minutes < target:
		_step()
		if stop_on_popup and not pending.is_empty():
			break
	_mode = previous


func _step() -> void:
	clock.minutes += clock.step_minutes
	if clock.minute() == 0:
		_on_hour()
	if director.is_due(clock.minutes):
		var event := director.pop_event()
		pending.append({"kind": "event", "event_id": event["id"]})
		counted.emit("event")


func _on_hour() -> void:
	var hour := clock.hour()
	if hour == 0:
		counted.emit("day")
		if clock.day_of_month() == 1:
			month_start_worth = net_worth()
			director.plan_month(clock.day(), clock.days_per_month, clock.minutes)

	var result := market.on_hour(hour, clock.is_weekend())
	for text: String in result["news"]:
		logged.emit("Kabar: " + text)
	for id: String in result["opened"]:
		_execute_orders(id)

	_calendar(hour)
	if _mode == "":
		_awake_hour(hour)


func _calendar(hour: int) -> void:
	var cal: Dictionary = cfg["calendar"]
	var money: Dictionary = cfg["money"]
	var dom := clock.day_of_month()
	if dom == int(cal["bill_day"]) and hour == int(cal["bill_hour"]):
		cash -= float(money["monthly_bills"])
		logged.emit("Tagihan bulanan dibayar: %s" % Fmt.signed_rupiah(-float(money["monthly_bills"])))
	if dom == int(cal["payday"]) and hour == int(cal["payday_hour"]):
		cash += float(money["salary"])
		logged.emit("Gaji masuk: %s" % Fmt.signed_rupiah(money["salary"]))
	if dom == int(cal["report_day"]) and hour == int(cal["report_hour"]):
		pending.append(_month_report())


## Hanya saat berjalan biasa (bukan tidur/lompat): energi berkurang, begadang diperingatkan.
func _awake_hour(hour: int) -> void:
	var day_cfg: Dictionary = cfg["day"]
	energy = maxf(0.0, energy - float(day_cfg["energy_per_awake_hour"]))
	if hour == int(day_cfg["midnight_warning_hour"]) and not warned_tonight:
		warned_tonight = true
		pending.append(_info("Sudah tengah malam",
			"Segera tidur. Jika masih bangun pukul %02d:00, kamu akan pingsan karena kelelahan." % int(day_cfg["pass_out_hour"])))
	if hour == int(day_cfg["pass_out_hour"]) or energy <= 0.0:
		_pass_out()


func _pass_out() -> void:
	var day_cfg: Dictionary = cfg["day"]
	counted.emit("pass_out")
	_run_until(clock.next_time_at_hour(int(day_cfg["pass_out_wake_hour"])), "sleep", false)
	energy = float(day_cfg["pass_out_energy"])
	warned_tonight = false
	pending.append(_info("Kamu pingsan karena kelelahan",
		"Kamu tertidur di tempat dan baru bangun pukul %02d:00 dengan energi %d. Tidur lebih awal agar energimu pulih penuh." \
			% [int(day_cfg["pass_out_wake_hour"]), int(day_cfg["pass_out_energy"])]))


## Energi seandainya bangun pukul 06:00 lalu beraktivitas sampai jam `hour`.
func _energy_for_hour(hour: int) -> float:
	var day_cfg: Dictionary = cfg["day"]
	var awake := hour - int(day_cfg["wake_hour"])
	if awake < 0:
		awake += 24
	return clampf(float(day_cfg["energy_max"]) - awake * float(day_cfg["energy_per_awake_hour"]), 0.0, float(day_cfg["energy_max"]))


# --- Transaksi & antrean pesanan -------------------------------------------------------

func is_open(id: String) -> bool:
	return market.is_open(market.find(id), clock.is_weekend(), clock.hour())


func available_units(id: String) -> float:
	return holdings[id] - reserved_units[id]


func holding_value(id: String) -> float:
	return holdings[id] * market.find(id).price


func net_worth() -> float:
	var total := cash + reserved_cash
	for inst in market.instruments:
		total += holding_value(inst.id)
	return total


## Membeli senilai `rupiah`. -> "filled" | "queued" | "" (gagal)
func buy(id: String, rupiah: float) -> String:
	if rupiah <= 0.0 or rupiah > cash + 0.5:
		return ""
	rupiah = minf(rupiah, cash)
	cash -= rupiah
	counted.emit("trade")
	if is_open(id):
		_fill_buy(id, rupiah, false)
		return "filled"
	reserved_cash += rupiah
	_queue(id, "buy", rupiah)
	return "queued"


## Menjual `units` unit. -> "filled" | "queued" | "" (gagal)
func sell(id: String, units: float) -> String:
	units = minf(units, available_units(id))
	if units <= 0.0:
		return ""
	counted.emit("trade")
	if is_open(id):
		_fill_sell(id, units, false)
		return "filled"
	reserved_units[id] += units
	_queue(id, "sell", units)
	return "queued"


func cancel_order(order_id: int) -> void:
	for order: Dictionary in orders:
		if int(order["id"]) != order_id:
			continue
		if order["side"] == "buy":
			reserved_cash -= order["amount"]
			cash += order["amount"]
		else:
			reserved_units[order["asset"]] -= order["amount"]
		orders.erase(order)
		counted.emit("cancel")
		logged.emit("Pesanan %s %s dibatalkan." % [_side_text(order["side"]), order["asset"]])
		return


func _queue(id: String, side: String, amount: float) -> void:
	orders.append({"id": next_order_id, "asset": id, "side": side, "amount": amount, "created": clock.minutes})
	next_order_id += 1
	counted.emit("queued")
	logged.emit("Bursa tutup. Pesanan %s %s masuk antrean dan dieksekusi saat bursa buka." % [_side_text(side), id])


## Saat bursa buka: semua pesanan instrumen itu dieksekusi di harga pembukaan.
func _execute_orders(id: String) -> void:
	for order: Dictionary in orders.duplicate():
		if order["asset"] != id:
			continue
		orders.erase(order)
		if order["side"] == "buy":
			reserved_cash -= order["amount"]
			_fill_buy(id, order["amount"], true)
		else:
			reserved_units[id] -= order["amount"]
			_fill_sell(id, order["amount"], true)


func _fill_buy(id: String, rupiah: float, from_queue: bool) -> void:
	var inst := market.find(id)
	var units := rupiah * (1.0 - inst.buy_fee) / inst.price
	holdings[id] += units
	logged.emit("%s: beli %s unit %s di %s." % [_fill_prefix(from_queue), Fmt.units(units), id, Fmt.rupiah(inst.price)])


func _fill_sell(id: String, units: float, from_queue: bool) -> void:
	var inst := market.find(id)
	holdings[id] -= units
	var proceeds := units * inst.price * (1.0 - inst.sell_fee)
	cash += proceeds
	logged.emit("%s: jual %s unit %s di %s (%s)." % [_fill_prefix(from_queue), Fmt.units(units), id,
		Fmt.rupiah(inst.price), Fmt.signed_rupiah(proceeds)])


func _fill_prefix(from_queue: bool) -> String:
	return "Pesanan antrean dieksekusi di harga pembukaan" if from_queue else "Transaksi berhasil"


func _side_text(side: String) -> String:
	return "beli" if side == "buy" else "jual"


# --- Popup -------------------------------------------------------------------------------

func _info(title: String, body: String) -> Dictionary:
	return {"kind": "info", "title": title, "body": body}


func _month_report() -> Dictionary:
	var worth := net_worth()
	var invested := worth - cash - reserved_cash
	var month_name := TranslationServer.translate("MONTH_%d" % clock.month_of_year())
	return _info("Laporan %s" % month_name,
		"Kekayaan awal bulan: %s\nKekayaan sekarang: %s (%s)\n\nKas: %s\nInvestasi: %s" % [
			Fmt.rupiah(month_start_worth), Fmt.rupiah(worth), Fmt.signed_rupiah(worth - month_start_worth),
			Fmt.rupiah(cash + reserved_cash), Fmt.rupiah(invested)])


## Menerapkan pilihan event. -> {"result": teks, "cash": perubahan kas}
func resolve_event(event: Dictionary, choice_index: int) -> Dictionary:
	var outcome := director.resolve(event, choice_index)
	cash += outcome["cash"]
	return outcome


func can_afford(choice: Dictionary) -> bool:
	var cost := float(choice.get("cost", 0))
	return cost == 0.0 or cost <= cash


# --- Simpan / muat -----------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"version": VERSION, "clock": clock.to_dict(), "market": market.to_dict(),
		"director": director.to_dict(), "cash": cash, "reserved_cash": reserved_cash,
		"holdings": holdings, "reserved_units": reserved_units, "orders": orders, "energy": energy,
		"warned_tonight": warned_tonight, "month_start_worth": month_start_worth,
		"next_order_id": next_order_id, "pending": pending}


## false jika versi simpanan berbeda (prototipe tidak memakai migrasi).
func load_state(d: Dictionary) -> bool:
	if int(d.get("version", 0)) != VERSION:
		return false
	clock.load_state(d["clock"])
	market.load_state(d["market"])
	director.load_state(d["director"])
	cash = d["cash"]
	reserved_cash = d["reserved_cash"]
	for inst in market.instruments:
		holdings[inst.id] = float(d["holdings"][inst.id])
		reserved_units[inst.id] = float(d["reserved_units"][inst.id])
	orders.clear()
	for order: Dictionary in d["orders"]:
		order["id"] = int(order["id"])
		order["created"] = int(order["created"])
		orders.append(order)
	energy = d["energy"]
	warned_tonight = d["warned_tonight"]
	month_start_worth = d["month_start_worth"]
	next_order_id = int(d["next_order_id"])
	pending = d["pending"]
	return true
