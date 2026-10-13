extends SceneTree
## Uji otomatis prototipe B "Hari Cepat" (tanpa UI). Jalankan:
##   godot --headless --path . --script res://prototypes/day/test_day.gd

const DayWorld := preload("res://prototypes/day/day_world.gd")

var _failures := 0


func _init() -> void:
	test_calibration()
	test_month_flow()
	test_activity_and_missions()
	test_interruptions_per_month()
	test_save_load_determinism()
	print("SELESAI: %s" % ("SEMUA LULUS" if _failures == 0 else "%d GAGAL" % _failures))
	quit(1 if _failures > 0 else 0)


func _new_world(seed_value: int) -> RefCounted:
	var world := DayWorld.new()
	world.setup(DataLoader.load_json("res://prototypes/day/day_config.json"),
		DataLoader.load_json("res://data/assets.json")["assets"],
		DataLoader.load_json("res://data/events.json")["events"],
		DataLoader.load_json("res://data/activities.json")["activities"], seed_value)
	world.new_game()
	return world


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  GAGAL ") + label)
	if not ok:
		_failures += 1


## Jalan sampai `minutes` sambil "menutup" semua popup. Mengembalikan jenis popup yang muncul.
func _run(world: RefCounted, minutes: int) -> Array:
	var kinds: Array = []
	var target: int = world.clock.minutes + minutes
	while world.clock.minutes < target:
		world._step()
		for p: Dictionary in world.pending:
			kinds.append(p["kind"] if p["kind"] != "info" else p["title"].get_slice(" ", 0))
		world.pending.clear()
	return kinds


func test_calibration() -> void:
	print("Kalibrasi harga harian (1 tahun, 300 seed):")
	var logs := {"BSNT": [], "GRD": []}
	for s in 300:
		var world := _new_world(500 + s)
		var start := {}
		for inst in world.market.instruments:
			start[inst.id] = inst.price
		for d in 360:
			world.market.on_day(d % 7 < 5)
		for inst in world.market.instruments:
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


func test_month_flow() -> void:
	print("Alur satu bulan:")
	var world := _new_world(9)
	_check(world.pending.size() == 1 and world.pending[0]["title"].begins_with("Rencana"), "awal permainan: popup rencana bulan")
	_check(world.missions.size() == 3, "3 misi bulanan")
	world.pending.clear()
	world.director.schedule.clear()
	world.missions.clear()  # tanpa hadiah misi, agar penurunan alami terlihat
	var cash_before: float = world.cash
	var kinds := _run(world, 30 * 1440)
	_check(kinds.has("payday") and kinds.has("Laporan") and kinds.has("Rencana"), "gajian, laporan, rencana bulan baru muncul: %s" % [kinds])
	_check(world.clock.day_of_month() == 1 and world.clock.month_of_year() == 2, "masuk bulan ke-2")
	var expected: float = cash_before + 6_000_000 - 3_500_000
	_check(absf(world.cash - expected) < 1.0, "kas = awal + gaji - tagihan")
	_check(world.energy == 6, "energi diisi ulang di awal bulan")
	_check(world.health < 75 and world.happiness < 70, "kesehatan & kebahagiaan turun perlahan bila tidak dijaga")
	_check(world.phase() in ["Pagi", "Siang", "Sore", "Malam"], "fase hari tersedia")


func test_activity_and_missions() -> void:
	print("Aktivitas berdurasi & misi:")
	var world := _new_world(21)
	world.pending.clear()
	world.director.schedule.clear()
	_check(world.start_activity("exercise"), "mulai Olahraga")
	_check(world.activity_block_reason("rest") == "Sedang ada aktivitas", "satu aktivitas dalam satu waktu")
	var health_before: float = world.health
	_run(world, 1440)
	_check(world.activity.is_empty() and world.health > health_before + 3.0, "Olahraga selesai setelah 1 hari, kesehatan naik")
	_check(world.start_activity("side_job"), "mulai Kerja Sampingan (4 hari)")
	_run(world, 3 * 1440)
	_check(not world.activity.is_empty(), "belum selesai setelah 3 hari")
	var cash_before: float = world.cash
	_run(world, 1440)
	_check(world.activity.is_empty() and world.cash > cash_before + 1_000_000, "selesai di hari ke-4, dapat seperempat gaji")
	_check(world.energy == 6 - 1 - 2, "energi terpakai")

	world.missions = [{"type": "invest", "state": "open", "target": 1_000_000.0, "activity_id": "", "text": ""},
		{"type": "no_loss", "state": "open", "target": 0.0, "activity_id": "", "text": ""}]
	world.buy("BSNT", 1_200_000)
	_check(world.missions[0]["state"] == "done", "misi investasi selesai saat beli Rp1,2 jt")
	world.market.find("BSNT").price *= 0.8
	world.sell("BSNT", 1e9)
	_check(world.missions[1]["state"] == "failed", "jual rugi menggagalkan misi")


func test_interruptions_per_month() -> void:
	print("Jumlah berhenti otomatis per bulan (Normal, 5 seed x 12 bulan):")
	var counts := {}
	for s in 5:
		var world := _new_world(70 + s)
		world.pending.clear()
		for kind: String in _run(world, 360 * 1440):
			counts[kind] = int(counts.get(kind, 0)) + 1
	var total := 0
	for kind: String in counts:
		total += counts[kind]
	print("    per bulan: %.1f total | %s" % [total / 60.0, counts])
	_check(total / 60.0 >= 4.0 and total / 60.0 <= 9.0, "4-9 jeda otomatis per bulan (sekitar 30 detik berjalan)")
	_check(int(counts.get("move", 0)) / 60.0 <= 2.5, "popup gerakan harga besar tidak terlalu sering")


func test_save_load_determinism() -> void:
	print("Simpan/muat deterministik:")
	var a := _new_world(42)
	a.clock.speed = 4
	a.start_activity("course")
	for i in 400:
		a.advance(0.25)
		a.pending.clear()
	a.buy("GRD", 1_000_000)
	var json := JSON.stringify(a.to_dict(), "", false, true)
	var b := DayWorld.new()
	b.setup(DataLoader.load_json("res://prototypes/day/day_config.json"),
		DataLoader.load_json("res://data/assets.json")["assets"],
		DataLoader.load_json("res://data/events.json")["events"],
		DataLoader.load_json("res://data/activities.json")["activities"], 1)
	_check(b.load_state(JSON.parse_string(json)), "muat simpanan")
	for i in 400:
		a.advance(0.25)
		b.advance(0.25)
		a.pending.clear()
		b.pending.clear()
	_check(a.clock.minutes == b.clock.minutes and a.cash == b.cash, "jam & kas sama")
	_check(a.market.find("GRD").price == b.market.find("GRD").price, "harga sama persis")
	_check(str(a.missions) == str(b.missions) and a.health == b.health, "misi & kesehatan sama")
