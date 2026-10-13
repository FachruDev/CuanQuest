extends RefCounted
## Pasar harian prototipe B: harga bergerak SEKALI per hari (tidak ada gerak per jam).
## Saham hanya bergerak di hari bursa (dt = 1/257), kripto setiap hari (dt = 1/360),
## sehingga drift & volatilitas tahunan dari data/assets.json tetap berlaku.

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
	var session: String   # "stock" | "crypto"
	var drift: float
	var volatility: float
	var buy_fee: float
	var sell_fee: float
	var news_chance: float
	var news_min: float
	var news_max: float
	var price: float
	var last_change := 0.0       # perubahan pada hari bursa terakhir
	var history: Array[float] = []

	func is_stock() -> bool:
		return session == "stock"

	## Titik grafik per bulan kalender: saham ~21 hari bursa, kripto 30 hari.
	func points_per_month() -> int:
		return 21 if is_stock() else 30


var instruments: Array[Instrument] = []
var rng := RandomNumberGenerator.new()
var trading_days := 257
var calendar_days := 360
var history_limit := 400


func setup(market_cfg: Dictionary, asset_defs: Array, seed_value: int) -> void:
	rng.seed = seed_value
	trading_days = int(market_cfg["trading_days_per_year"])
	calendar_days = int(market_cfg["calendar_days_per_year"])
	history_limit = int(market_cfg["history_limit"])
	for cfg: Dictionary in market_cfg["instruments"]:
		var def: Dictionary = asset_defs.filter(func(a: Dictionary) -> bool: return a["id"] == cfg["asset_id"])[0]
		var inst := Instrument.new()
		inst.id = def["id"]
		inst.name = cfg["name"]
		inst.session = cfg["session"]
		inst.drift = def["drift"]
		inst.volatility = def["volatility"]
		inst.buy_fee = def["buy_fee"]
		inst.sell_fee = def["sell_fee"]
		inst.news_chance = cfg["news_chance_per_day"]
		inst.news_min = cfg["news_size_min"]
		inst.news_max = cfg["news_size_max"]
		inst.price = def["start_price"]
		inst.history.assign([inst.price])
		instruments.append(inst)


func find(id: String) -> Instrument:
	for inst in instruments:
		if inst.id == id:
			return inst
	return null


## Simpangan harian "normal" (1 sigma), untuk mendeteksi gerakan besar.
func daily_sigma(inst: Instrument) -> float:
	return inst.volatility / sqrt(trading_days if inst.is_stock() else calendar_days)


## Dijalankan setiap pergantian hari. `trading_day`: hari yang baru lewat adalah hari bursa.
## -> {"news": [teks], "changes": {id: perubahan harian}}
func on_day(trading_day: bool) -> Dictionary:
	var news: Array[String] = []
	var changes := {}
	for inst in instruments:
		if inst.is_stock() and not trading_day:
			continue
		var before := inst.price
		var dt := 1.0 / (trading_days if inst.is_stock() else calendar_days)
		var mu := (inst.drift - 0.5 * inst.volatility * inst.volatility) * dt
		inst.price *= exp(mu + inst.volatility * sqrt(dt) * rng.randfn())
		if rng.randf() < inst.news_chance:
			var size := rng.randf_range(inst.news_min, inst.news_max)
			var up := rng.randf() < 0.5
			inst.price *= 1.0 + size if up else 1.0 - size
			var pool: Array = (STOCK_NEWS_UP if up else STOCK_NEWS_DOWN) if inst.is_stock() \
					else (CRYPTO_NEWS_UP if up else CRYPTO_NEWS_DOWN)
			news.append(pool[rng.randi() % pool.size()] % [inst.id, Fmt.percent_plain(size)])
		inst.price = maxf(inst.price, 1.0)
		inst.last_change = inst.price / before - 1.0
		changes[inst.id] = inst.last_change
		inst.history.append(inst.price)
		if inst.history.size() > history_limit:
			inst.history = inst.history.slice(-history_limit)
	return {"news": news, "changes": changes}


func to_dict() -> Dictionary:
	var items := {}
	for inst in instruments:
		items[inst.id] = {"price": inst.price, "last_change": inst.last_change, "history": inst.history}
	return {"rng_seed": str(rng.seed), "rng_state": str(rng.state), "instruments": items}


func load_state(d: Dictionary) -> void:
	rng.seed = str(d["rng_seed"]).to_int()
	rng.state = str(d["rng_state"]).to_int()
	for inst in instruments:
		var s: Dictionary = d["instruments"][inst.id]
		inst.price = s["price"]
		inst.last_change = s["last_change"]
		inst.history.assign(s["history"])
