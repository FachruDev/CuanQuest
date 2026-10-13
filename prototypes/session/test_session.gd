extends SceneTree
## Uji otomatis prototipe C "Sesi Pasar" (tanpa UI). Jalankan:
##   godot --headless --path . --script res://prototypes/session/test_session.gd

const SessionWorld := preload("res://prototypes/session/session_world.gd")

var _failures := 0


func _init() -> void:
	test_calibration()
	test_skip_equals_watch()
	test_month_flow_and_benchmark()
	test_events_per_month()
	test_save_load_determinism()
	print("SELESAI: %s" % ("SEMUA LULUS" if _failures == 0 else "%d GAGAL" % _failures))
	quit(1 if _failures > 0 else 0)


func _new_world(seed_value: int) -> RefCounted:
	var world := SessionWorld.new()
	world.setup(DataLoader.load_json("res://prototypes/session/session_config.json"),
		DataLoader.load_json("res://data/assets.json")["assets"],
		DataLoader.load_json("res://data/events.json")["events"], seed_value)
	world.new_game()
	return world


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  GAGAL ") + label)
	if not ok:
		_failures += 1


## Lewati satu bulan penuh: Lanjut, tutup semua popup, mulai bulan berikutnya.
func _skip_month(world: RefCounted) -> Array:
	world.finish_month()
	var kinds: Array = world.pending.map(func(p: Dictionary) -> String: return p["kind"])
	world.pending.clear()
	world.start_next_month()
	return kinds


func test_calibration() -> void:
	print("Kalibrasi harga per tick (12 bulan x 120 tick, 300 seed):")
	var logs := {"BSNT": [], "GRD": []}
	for s in 300:
		var world := _new_world(300 + s)
		var start := {}
		for inst in world.instruments:
			start[inst.id] = inst.price
		for t in 12 * 120:
			world._tick()
		for inst in world.instruments:
			logs[inst.id].append(log(inst.price / start[inst.id]))
	var defs: Array = DataLoader.load_json("res://data/assets.json")["assets"]
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
		var def: Dictionary = defs.filter(func(a: Dictionary) -> bool: return a["id"] == id)[0]
		var expected: float = def["drift"] - 0.5 * def["volatility"] * def["volatility"]
		print("    %s: log-return %.3f (target %.3f), volatilitas %.3f (target %.2f + berita)" % [id, mean, expected, std, def["volatility"]])
		_check(absf(mean - expected) < 3.0 * std / sqrt(values.size()), "%s drift tahunan sesuai" % id)
		_check(std > def["volatility"] * 0.85 and std < def["volatility"] * 1.3, "%s volatilitas tahunan sesuai" % id)


## Menekan Lanjut lebih awal harus menghasilkan harga yang sama dengan menonton sampai habis.
func test_skip_equals_watch() -> void:
	print("Lanjut lebih awal = menonton sampai habis:")
	var watcher := _new_world(77)
	var skipper := _new_world(77)
	watcher.speed = 4
	while not watcher.session_over():
		watcher.advance(0.2)
		watcher.pending.clear()
	skipper.finish_month()
	_check(watcher.tick == 120 and skipper.tick == 120, "kedua sesi berhenti di tick 120")
	_check(watcher.find("BSNT").price == skipper.find("BSNT").price and watcher.find("GRD").price == skipper.find("GRD").price,
		"harga akhir bulan sama persis")
	_check(watcher.advance(5.0) == 0, "setelah sesi selesai, grafik berhenti")


func test_month_flow_and_benchmark() -> void:
	print("Alur bulan & pembanding 'kalau ditahan':")
	var world := _new_world(5)
	world.director.schedule.clear()
	_check(is_zero_approx(world.trading_edge()), "awal bulan: hasil trading 0")
	world.buy("GRD", 2_000_000)
	var fee: float = 2_000_000 * world.find("GRD").buy_fee
	_check(absf(world.trading_edge() + fee) < 1.0, "langsung setelah beli: hasil trading = -fee")
	_check(world.day_of_month() == 1, "tanggal 1 di awal sesi")
	for t in 60:
		world._tick()
	_check(world.day_of_month() == 16, "tick 60 = tanggal 16")
	var kinds := _skip_month(world)
	_check(kinds.back() == "report", "laporan muncul setelah Lanjut")
	_check(world.month_index == 1 and world.tick == 0, "bulan ke-2 dimulai dari tick 0")
	var cash_before: float = world.cash
	world.director.schedule.clear()
	_skip_month(world)
	_check(absf(world.cash - (cash_before + 6_000_000 - 3_500_000)) < 1.0, "gaji masuk & tagihan dibayar tiap bulan")
	_check(world.month_trades == 0 and is_zero_approx(world.trading_edge()), "tanpa transaksi: sama dengan menahan")


func test_events_per_month() -> void:
	print("Event per bulan (Normal, 120 bulan):")
	var world := _new_world(13)
	var events := 0
	for m in 120:
		events += _skip_month(world).count("event")
	print("    rata-rata %.2f event per bulan (target sekitar 1,45)" % (events / 120.0))
	_check(events / 120.0 > 1.0 and events / 120.0 < 2.0, "jumlah event per bulan sesuai distribusi")


func test_save_load_determinism() -> void:
	print("Simpan/muat deterministik:")
	var a := _new_world(42)
	a.buy("BSNT", 3_000_000)
	for t in 50:
		a._tick()
	a.pending.clear()
	var json := JSON.stringify(a.to_dict(), "", false, true)
	var b := SessionWorld.new()
	b.setup(DataLoader.load_json("res://prototypes/session/session_config.json"),
		DataLoader.load_json("res://data/assets.json")["assets"],
		DataLoader.load_json("res://data/events.json")["events"], 1)
	_check(b.load_state(JSON.parse_string(json)), "muat simpanan")
	for m in 3:
		_skip_month(a)
		_skip_month(b)
	_check(a.find("BSNT").price == b.find("BSNT").price and a.cash == b.cash, "harga & kas sama setelah 3 bulan")
	_check(a.total_edge == b.total_edge, "akumulasi hasil trading sama")
