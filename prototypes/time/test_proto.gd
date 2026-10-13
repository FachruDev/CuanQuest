extends SceneTree
## Uji otomatis prototipe waktu (tanpa UI). Jalankan:
##   godot --headless --path . --script res://prototypes/time/test_proto.gd

const ProtoWorld := preload("res://prototypes/time/proto_world.gd")

var _failures := 0


func _init() -> void:
	test_calibration()
	test_calendar_and_sleep()
	test_order_queue()
	test_event_density()
	test_save_load_determinism()
	print("SELESAI: %s" % ("SEMUA LULUS" if _failures == 0 else "%d GAGAL" % _failures))
	quit(1 if _failures > 0 else 0)


func _new_world(seed_value: int) -> RefCounted:
	var world := ProtoWorld.new()
	world.setup(DataLoader.load_json("res://prototypes/time/time_config.json"),
		DataLoader.load_json("res://data/assets.json")["assets"],
		DataLoader.load_json("res://data/events.json")["events"], seed_value)
	world.new_game()
	return world


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  GAGAL ") + label)
	if not ok:
		_failures += 1


## Drift & volatilitas TAHUNAN harus tetap sesuai data/assets.json walau harga bergerak per jam.
func test_calibration() -> void:
	print("Kalibrasi harga per jam (1 tahun game, 200 seed):")
	var logs := {"BSNT": [], "GRD": []}
	for s in 200:
		var world := _new_world(1000 + s)
		var start := {}
		for inst in world.market.instruments:
			start[inst.id] = inst.price
		var clock = world.clock
		for h in 360 * 24:  # pasar saja, tanpa kas/event, agar cepat
			clock.minutes += 60
			world.market.on_hour(clock.hour(), clock.is_weekend())
		for inst in world.market.instruments:
			logs[inst.id].append(log(inst.price / start[inst.id]))
	for id: String in logs:
		var values: Array = logs[id]
		var mean := 0.0
		for v: float in values:
			mean += v
		mean /= values.size()
		var variance := 0.0
		for v: float in values:
			variance += (v - mean) * (v - mean)
		var std := sqrt(variance / (values.size() - 1))
		var def: Dictionary = DataLoader.load_json("res://data/assets.json")["assets"].filter(
			func(a: Dictionary) -> bool: return a["id"] == id)[0]
		var expected_mean: float = def["drift"] - 0.5 * def["volatility"] * def["volatility"]
		print("    %s: rata-rata log-return %.3f (target %.3f), volatilitas %.3f (target %.2f + berita)" \
			% [id, mean, expected_mean, std, def["volatility"]])
		# Galat standar rata-rata = std/sqrt(200); toleransi 3x galat standar.
		_check(absf(mean - expected_mean) < 3.0 * std / sqrt(values.size()), "%s drift tahunan sesuai" % id)
		_check(std > def["volatility"] * 0.85 and std < def["volatility"] * 1.25, "%s volatilitas tahunan sesuai" % id)


func test_calendar_and_sleep() -> void:
	print("Kalender, tidur, pingsan, lompat waktu:")
	var world := _new_world(7)
	var clock = world.clock
	_check(clock.date_text().begins_with("Senin, 1 ") and clock.time_text() == "07:00", "mulai Senin 1 Jan pukul 07:00")

	world.sleep()
	_check(clock.day() == 1 and clock.hour() == 6, "tidur -> bangun besok pukul 06:00")
	_check(is_equal_approx(world.energy, 100.0), "energi penuh setelah tidur")

	# Begadang: jalan terus sampai 02:00 -> peringatan tengah malam, lalu pingsan.
	world.pending.clear()
	clock.speed = 4
	var guard := 0
	while not (clock.day() == 2 and clock.hour() >= 9) and guard < 100000:
		world.advance(1.0)
		guard += 1
	var titles: Array = world.pending.map(func(p: Dictionary) -> String: return p.get("title", ""))
	_check(titles.has("Sudah tengah malam"), "peringatan pukul 00:00 muncul")
	_check(titles.has("Kamu pingsan karena kelelahan"), "pingsan pukul 02:00")
	_check(is_equal_approx(world.energy, 50.0) or world.energy < 50.0, "energi terbatas setelah pingsan")

	world.pending.clear()
	world.director.schedule.clear()  # tanpa event agar lompatan tidak berhenti
	world.skip_to_payday()
	_check(clock.day_of_month() == 25 and clock.hour() == 8, "lompat ke tanggal gajian (25, 08:00)")
	world.skip_to_month_end()
	_check(clock.day_of_month() == 30 and clock.hour() == 20, "lompat ke akhir bulan (30, 20:00)")
	_check(world.pending.size() == 1 and world.pending[0]["title"].begins_with("Laporan"), "laporan bulanan muncul")

	# Lompatan berhenti saat ada event.
	world.pending.clear()
	world.director.schedule.assign([clock.minutes + 3 * 1440])
	world.director.last_event_day = clock.day() + 1000  # bulan baru tidak menjadwalkan event lain
	var before: int = clock.minutes
	world.skip_to_payday()
	_check(clock.minutes == before + 3 * 1440 and world.pending[0]["kind"] == "event", "lompatan berhenti saat event")


func test_order_queue() -> void:
	print("Jam bursa & antrean pesanan:")
	var world := _new_world(11)
	var clock = world.clock
	_check(not world.is_open("BSNT") and world.is_open("GRD"), "07:00: saham tutup, kripto buka")
	var cash_before: float = world.cash
	_check(world.buy("BSNT", 2_000_000) == "queued", "beli saham di luar jam -> antrean")
	_check(world.cash == cash_before - 2_000_000 and world.reserved_cash == 2_000_000, "kas ditahan untuk pesanan")
	_check(world.buy("GRD", 1_000_000) == "filled", "beli kripto langsung tereksekusi")
	world.buy("BSNT", 500_000)
	world.cancel_order(int(world.orders[1]["id"]))
	_check(world.orders.size() == 1 and world.reserved_cash == 2_000_000, "batalkan pesanan mengembalikan kas")

	world.director.schedule.clear()
	while clock.hour() != 9:
		world._step()
	var open_price: float = world.market.find("BSNT").price
	_check(world.orders.is_empty() and world.reserved_cash == 0.0, "09:00: pesanan dieksekusi")
	var expected_units := 2_000_000 * (1.0 - 0.0015) / open_price
	_check(is_equal_approx(world.holdings["BSNT"], expected_units), "dieksekusi di harga pembukaan")
	_check(world.sell("BSNT", 999999.0) == "filled" and world.holdings["BSNT"] < 0.0001, "jual saat bursa buka")

	while not clock.is_weekend():
		world._step()
	_check(not world.is_open("BSNT"), "akhir pekan: bursa tutup")


func test_event_density() -> void:
	print("Event Director (Normal, 120 bulan):")
	var world := _new_world(3)
	var counts := [0, 0, 0, 0]
	var gaps_ok := true
	var hours_ok := true
	var last := -99999
	for m in 120:
		var count: int = world.director.plan_month(m * 30, 30, -1)
		counts[count] += 1
		for at: int in world.director.schedule:
			var hour := (at % 1440) / 60
			hours_ok = hours_ok and hour >= 8 and hour <= 21
			gaps_ok = gaps_ok and floori(at / 1440.0) - floori(last / 1440.0) >= 4
			last = at
		world.director.schedule.clear()
	print("    0/1/2/3 event: %s (target 15/40/30/15 %%)" % [counts])
	_check(counts[0] < 40 and counts[1] > 30 and counts[3] > 5, "distribusi jumlah event masuk akal")
	_check(hours_ok, "event hanya di jam bangun 08:00-21:00")
	_check(gaps_ok, "jarak antar-event minimal 4 hari")


func test_save_load_determinism() -> void:
	print("Simpan/muat deterministik:")
	var a := _new_world(42)
	a.clock.speed = 4
	for i in 3000:
		a.advance(0.5)
		a.pending.clear()
	a.buy("GRD", 1_000_000)
	var json := JSON.stringify(a.to_dict(), "", false, true)
	var b := ProtoWorld.new()
	b.setup(DataLoader.load_json("res://prototypes/time/time_config.json"),
		DataLoader.load_json("res://data/assets.json")["assets"],
		DataLoader.load_json("res://data/events.json")["events"], 999)
	_check(b.load_state(JSON.parse_string(json)), "muat simpanan")
	for i in 3000:
		a.advance(0.5)
		b.advance(0.5)
		a.pending.clear()
		b.pending.clear()
	_check(a.clock.minutes == b.clock.minutes, "jam sama")
	_check(a.market.find("BSNT").price == b.market.find("BSNT").price
		and a.market.find("GRD").price == b.market.find("GRD").price, "harga sama persis")
	_check(a.director.schedule == b.director.schedule and a.cash == b.cash, "jadwal event & kas sama")
	var old: Dictionary = a.to_dict()
	old["version"] = 0
	_check(not b.load_state(old), "simpanan versi lain ditolak")
