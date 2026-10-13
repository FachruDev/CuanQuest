extends RefCounted
## Pasar mini prototipe: satu saham (jam bursa) dan satu kripto (24/7).
##
## Harga bergerak per JAM game dengan Geometric Brownian Motion. `dt` dihitung dari
## jumlah jam perdagangan instrumen per tahun (MVP bagian 5.1), sehingga drift dan
## volatilitas TAHUNAN dari data/assets.json tetap berlaku:
##   saham : 257 hari kerja x 7 jam = 1.799 tick/tahun, ditambah langkah "gap" saat buka
##   kripto: 360 hari x 24 jam     = 8.640 tick/tahun

const STOCK_NEWS_UP := ["%s naik %s setelah laba kuartalan melampaui perkiraan.",
	"Investor asing memborong %s, harga naik %s."]
const STOCK_NEWS_DOWN := ["%s turun %s karena kredit macet meningkat.",
	"Aksi ambil untung menekan %s, harga turun %s."]
const CRYPTO_NEWS_UP := ["%s melonjak %s setelah dikabarkan diadopsi bursa besar.",
	"Paus kripto memborong %s, harga naik %s."]
const CRYPTO_NEWS_DOWN := ["%s anjlok %s setelah rumor peretasan bursa.",
	"Regulasi baru menekan %s, harga turun %s."]


class Instrument:
	var id: String
	var name: String
	var session: String       # "stock" (jam bursa) | "crypto" (24/7)
	var open_hour := 0
	var close_hour := 24
	var drift: float
	var volatility: float
	var buy_fee: float
	var sell_fee: float
	var news_chance: float
	var news_min: float
	var news_max: float
	var price: float
	var day_open_price: float  # harga pukul 00:00 (untuk perubahan "hari ini")
	var history: Array[float] = []

	func is_stock() -> bool:
		return session == "stock"

	## Jumlah titik grafik per hari: saham = 1 gap + 7 jam, kripto = 24 jam.
	func points_per_day() -> int:
		return close_hour - open_hour + 1 if is_stock() else 24


var instruments: Array[Instrument] = []   # urutan tetap: penting untuk determinisme RNG
var rng := RandomNumberGenerator.new()
var trading_days := 257
var gap_share := 0.18
var history_limit := 800
var _calendar_days := 360


func setup(market_cfg: Dictionary, calendar_cfg: Dictionary, asset_defs: Array, seed_value: int) -> void:
	rng.seed = seed_value
	trading_days = int(market_cfg["trading_days_per_year"])
	gap_share = market_cfg["gap_variance_share"]
	history_limit = int(market_cfg["history_limit"])
	_calendar_days = int(calendar_cfg["days_per_month"]) * int(calendar_cfg["months_per_year"])
	for cfg: Dictionary in market_cfg["instruments"]:
		var def: Dictionary = asset_defs.filter(func(a: Dictionary) -> bool: return a["id"] == cfg["asset_id"])[0]
		var inst := Instrument.new()
		inst.id = def["id"]
		inst.name = cfg["name"]
		inst.session = cfg["session"]
		inst.open_hour = int(cfg.get("open_hour", 0))
		inst.close_hour = int(cfg.get("close_hour", 24))
		inst.drift = def["drift"]
		inst.volatility = def["volatility"]
		inst.buy_fee = def["buy_fee"]
		inst.sell_fee = def["sell_fee"]
		inst.news_chance = cfg["news_chance_per_tick"]
		inst.news_min = cfg["news_size_min"]
		inst.news_max = cfg["news_size_max"]
		inst.price = def["start_price"]
		inst.day_open_price = inst.price
		inst.history.assign([inst.price])
		instruments.append(inst)


func find(id: String) -> Instrument:
	for inst in instruments:
		if inst.id == id:
			return inst
	return null


func is_open(inst: Instrument, weekend: bool, hour: int) -> bool:
	if not inst.is_stock():
		return true
	return not weekend and hour >= inst.open_hour and hour < inst.close_hour


## Tick per jam game. Dipanggil tepat di pergantian jam (menit ke-0).
## Mengembalikan {"opened": [id instrumen yang baru buka], "news": [teks berita]}.
func on_hour(hour: int, weekend: bool) -> Dictionary:
	var opened: Array[String] = []
	var news: Array[String] = []
	for inst in instruments:
		if hour == 0:
			inst.day_open_price = inst.price
		if inst.is_stock():
			if weekend or hour < inst.open_hour or hour > inst.close_hour:
				continue
			if hour == inst.open_hour:
				_gap_step(inst)
				opened.append(inst.id)
				continue
			_hour_step(inst, trading_days * (inst.close_hour - inst.open_hour))
		else:
			_hour_step(inst, _calendar_days * 24)
		var headline := _maybe_news(inst)
		if headline != "":
			news.append(headline)
	return {"opened": opened, "news": news}


## Satu jam perdagangan. Koreksi Ito (-0,5 sigma^2) memakai volatilitas penuh,
## sedangkan acaknya hanya bagian (1 - gap_share), karena sisanya dipakai langkah gap.
func _hour_step(inst: Instrument, ticks_per_year: int) -> void:
	var dt := 1.0 / ticks_per_year
	var share := 1.0 - gap_share if inst.is_stock() else 1.0
	var mu := (inst.drift - 0.5 * inst.volatility * inst.volatility) * dt
	var sigma := inst.volatility * sqrt(share * dt)
	_move(inst, exp(mu + sigma * rng.randfn()))


## Lompatan harga saat bursa buka setelah malam/akhir pekan. Tanpa drift dan tanpa
## koreksi Ito sendiri, karena koreksi untuk volatilitas penuh sudah ada di tick per jam.
func _gap_step(inst: Instrument) -> void:
	var sigma := inst.volatility * sqrt(gap_share / trading_days)
	_move(inst, exp(sigma * rng.randfn()))


func _maybe_news(inst: Instrument) -> String:
	if rng.randf() >= inst.news_chance:
		return ""
	var size := rng.randf_range(inst.news_min, inst.news_max)
	var up := rng.randf() < 0.5
	_move(inst, 1.0 + size if up else 1.0 - size)
	var pool: Array = (STOCK_NEWS_UP if up else STOCK_NEWS_DOWN) if inst.is_stock() \
			else (CRYPTO_NEWS_UP if up else CRYPTO_NEWS_DOWN)
	return pool[rng.randi() % pool.size()] % [inst.id, Fmt.percent_plain(size)]


func _move(inst: Instrument, factor: float) -> void:
	inst.price = maxf(inst.price * factor, 1.0)
	inst.history.append(inst.price)
	if inst.history.size() > history_limit:
		inst.history = inst.history.slice(-history_limit)


func to_dict() -> Dictionary:
	var items := {}
	for inst in instruments:
		items[inst.id] = {"price": inst.price, "day_open_price": inst.day_open_price, "history": inst.history}
	# Keadaan RNG 64-bit disimpan sebagai teks agar tidak kehilangan presisi di JSON.
	return {"rng_seed": str(rng.seed), "rng_state": str(rng.state), "instruments": items}


func load_state(d: Dictionary) -> void:
	rng.seed = str(d["rng_seed"]).to_int()
	rng.state = str(d["rng_state"]).to_int()
	for inst in instruments:  # urutan dari config, bukan urutan key JSON
		var s: Dictionary = d["instruments"][inst.id]
		inst.price = s["price"]
		inst.day_open_price = s["day_open_price"]
		inst.history.assign(s["history"])
