class_name Market
extends RefCounted
## Simulasi pasar: menyimpan semua aset dan menggerakkan harganya tiap bulan, hari demi hari.
## Memakai RNG ber-seed sendiri agar hasilnya bisa direproduksi (penting untuk save/load).
##
## Komponen simulasi:
## - Siklus pasar (bull / sideways / bear) per faktor ("stock", "crypto"), durasinya acak.
## - Faktor bersama: aset satu faktor cenderung bergerak searah (korelasi).
## - Inflasi & indeks harga (v1.5a): inflasi tahunan bergerak pelan; indeks harga dipakai
##   GameState untuk menaikkan biaya hidup, biaya event, dan harga impian.
## - Suku bunga acuan: bank sentral menaikkan/menurunkan mengikuti inflasi. Menentukan bunga
##   tabungan & deposito serta imbal hasil RD pasar uang; keputusannya menggoyang harga saham.
## - Berita: guncangan harga sekali untuk satu aset atau satu faktor, atau mengubah inflasi,
##   pada satu tanggal acak di bulan itu (terlihat sebagai lonjakan di grafik harian).

const WARMUP_MONTHS := 12  # riwayat harga palsu agar grafik tidak kosong di awal

var assets: Dictionary = {}       # id -> MarketAsset (urutan sesuai assets.json)
var rng := RandomNumberGenerator.new()
var config: Dictionary = {}       # isi data/market.json
var news_defs: Array = []         # isi data/news.json
var policy_rate: float = 0.0      # suku bunga acuan per tahun
var inflation: float = 0.0        # inflasi tahunan saat ini (0.035 = 3,5% per tahun)
var price_level: float = 1.0      # indeks harga (1.0 = harga di awal permainan)
var price_levels: Array[float] = []  # indeks harga tiap bulan permainan (indeks = bulan)
var regimes: Dictionary = {}      # faktor -> { "id": "bull", "months_left": 7 }
var news_log: Array[Dictionary] = []  # terbaru di depan


func setup(asset_defs: Array, market_config: Dictionary, news: Array, seed_value: int) -> void:
	rng.seed = seed_value
	config = market_config
	news_defs = news
	policy_rate = config["start_policy_rate"]
	inflation = config["macro"]["inflation_mean"]
	price_level = 1.0
	price_levels.assign([price_level])
	assets.clear()
	for def: Dictionary in asset_defs:
		var asset := MarketAsset.from_def(def)
		assets[asset.id] = asset

	regimes.clear()
	var regime_ids: Array = config["regimes"].keys()
	for factor: String in config["factors"]:
		regimes[factor] = _new_regime(regime_ids[rng.randi() % regime_ids.size()])

	for i in WARMUP_MONTHS:
		step(-WARMUP_MONTHS + i)
	news_log.clear()  # berita masa warmup tidak ditampilkan


## Gerakkan pasar satu bulan. `month` = bulan game tempat berita ditampilkan.
## Mengembalikan daftar berita bulan ini.
func step(month: int) -> Array[Dictionary]:
	var news: Array[Dictionary] = []
	var shocks: Dictionary = {}  # asset_id -> {tanggal: guncangan harga}

	_update_regimes(month, news)
	if month > 0:  # masa warmup (riwayat palsu) tidak menaikkan harga-harga
		_step_macro(month, news, shocks)
	if rng.randf() < config["news_chance"]:
		_roll_news(month, rng.randi_range(1, MarketAsset.DAYS_IN_MONTH), news, shocks)

	# Angka acak bersama per hari untuk tiap faktor (sumber korelasi harian).
	# Urutan loop HARUS tetap (ikut file data), bukan urutan Dictionary `regimes`:
	# setelah save/load lewat JSON urutan key bisa berubah, dan angka acak akan
	# tertukar antar faktor sehingga hasil simulasi tidak lagi sama.
	var no_factor: Array[float] = []
	no_factor.resize(MarketAsset.DAYS_IN_MONTH)  # isi 0.0: aset tanpa faktor bergerak sendiri
	var factor_z := {}
	for factor: String in _factor_order():
		var daily: Array[float] = []
		for day in MarketAsset.DAYS_IN_MONTH:
			daily.append(rng.randfn(0.0, 1.0))
		factor_z[factor] = daily

	for asset: MarketAsset in assets.values():
		if asset.rate_linked:
			asset.drift = maxf(0.0, policy_rate + asset.rate_spread)
		var regime_drift := 0.0
		var vol_mult := 1.0
		if regimes.has(asset.factor):
			var regime: Dictionary = config["regimes"][regimes[asset.factor]["id"]]
			regime_drift = regime["drift"] * config["factors"][asset.factor]["drift_scale"]
			vol_mult = regime["vol_mult"]
		var z: Array[float] = factor_z.get(asset.factor, no_factor)
		asset.step_month(rng, z, regime_drift, vol_mult, shocks.get(asset.id, {}))

	for item in news:
		news_log.push_front(item)
	news_log.resize(mini(news_log.size(), int(config["news_log_size"])))
	return news


## Simpan kondisi pasar. RNG state disimpan sebagai string karena bilangan 64-bit
## akan kehilangan presisi jika disimpan sebagai angka JSON (float 53-bit).
func to_dict() -> Dictionary:
	var asset_states := {}
	for asset: MarketAsset in assets.values():
		asset_states[asset.id] = {"price": asset.price, "history": asset.history,
			"month_closes": asset.month_closes}
	return {
		"rng_seed": str(rng.seed), "rng_state": str(rng.state),
		"policy_rate": policy_rate, "regimes": regimes, "news_log": news_log,
		"inflation": inflation, "price_level": price_level, "price_levels": price_levels,
		"assets": asset_states,
	}


## Kebalikan to_dict(): parameter aset diambil dari file data terbaru, harga dari save.
func load_state(asset_defs: Array, market_config: Dictionary, news: Array, d: Dictionary) -> void:
	config = market_config
	news_defs = news
	assets.clear()
	for def: Dictionary in asset_defs:
		var asset := MarketAsset.from_def(def)
		var saved: Dictionary = d["assets"].get(asset.id, {})
		if not saved.is_empty():
			asset.price = saved["price"]
			asset.history.assign(saved["history"])
			asset.month_closes.assign(saved["month_closes"])
		assets[asset.id] = asset
	rng.seed = String(d["rng_seed"]).to_int()
	rng.state = String(d["rng_state"]).to_int()
	policy_rate = d["policy_rate"]
	# Save v1.5-0 belum punya inflasi: harga dianggap mulai naik sejak dimuat.
	inflation = d.get("inflation", config["macro"]["inflation_mean"])
	price_level = d.get("price_level", 1.0)
	price_levels.assign(d.get("price_levels", [price_level]))
	regimes.clear()
	for factor: String in d["regimes"]:
		var r: Dictionary = d["regimes"][factor]
		regimes[factor] = {"id": r["id"], "months_left": int(r["months_left"])}
	news_log.clear()
	for item: Dictionary in d["news_log"]:
		item["month"] = int(item["month"])
		item["day"] = int(item.get("day", 0))
		news_log.append(item)


func get_asset(id: String) -> MarketAsset:
	return assets.get(id)


## Bunga tahunan (sebelum pajak) untuk tabungan/deposito.
func rate_for(asset: MarketAsset) -> float:
	return maxf(0.005, policy_rate + asset.rate_spread)


## Kenaikan harga yang benar-benar terjadi selama `months` bulan terakhir (0.035 = 3,5%).
func realized_inflation(months: int = 12) -> float:
	var from := maxi(price_levels.size() - 1 - months, 0)
	return price_level / price_levels[from] - 1.0


func regime_of(factor: String) -> String:
	return regimes[factor]["id"]


# --- Internal -----------------------------------------------------------------

func _new_regime(id: String) -> Dictionary:
	var def: Dictionary = config["regimes"][id]
	return {"id": id, "months_left": rng.randi_range(int(def["min_months"]), int(def["max_months"]))}


func _factor_order() -> Array:
	return config["factors"].keys()


func _update_regimes(month: int, news: Array[Dictionary]) -> void:
	for factor: String in _factor_order():
		var regime: Dictionary = regimes[factor]
		regime["months_left"] -= 1
		if regime["months_left"] > 0:
			continue
		var next: Dictionary = config["regimes"][regime["id"]]["next"]
		var next_id: String = next.keys()[rng.rand_weighted(PackedFloat32Array(next.values()))]
		regimes[factor] = _new_regime(next_id)
		news.append(_make_news(month, "NEWS_REGIME_%s_%s" % [factor.to_upper(), next_id.to_upper()], "", 0.0))


## Inflasi bulan ini & rapat bank sentral (v1.5a langkah 1, lihat market.json "macro").
func _step_macro(month: int, news: Array[Dictionary], shocks: Dictionary) -> void:
	var macro: Dictionary = config["macro"]
	var mean: float = macro["inflation_mean"]
	inflation = clampf(mean + float(macro["inflation_persistence"]) * (inflation - mean)
		+ rng.randfn(0.0, macro["inflation_noise"]), macro["inflation_min"], macro["inflation_max"])
	price_level *= 1.0 + inflation / 12.0
	price_levels.append(price_level)

	# Bank sentral menaikkan suku bunga saat inflasi tinggi (meredam belanja & kredit),
	# menurunkannya saat inflasi rendah. Tidak setiap bulan: hanya jika selisihnya cukup besar.
	var target_rate := float(macro["neutral_real_rate"]) + inflation \
		+ float(macro["rate_reaction"]) * (inflation - mean)
	var gap := target_rate - policy_rate
	if absf(gap) < float(macro["rate_band"]) or rng.randf() >= float(macro["rate_meeting_chance"]):
		return
	var new_rate := clampf(policy_rate + float(macro["rate_step"]) * signf(gap),
		config["min_policy_rate"], config["max_policy_rate"])
	if is_equal_approx(new_rate, policy_rate):
		return
	policy_rate = new_rate
	var def := _news_def("rate_up" if gap > 0.0 else "rate_down")
	var days: Array = macro["meeting_days"]
	var day := rng.randi_range(int(days[0]), int(days[1]))
	var shock := rng.randf_range(def["shock"][0], def["shock"][1])
	_shock_factor("stock", shock, shocks, day)  # suku bunga naik biasanya menekan saham
	news.append(_make_news(month, def["text_key"], "", shock, day, policy_rate))


func _news_def(id: String) -> Dictionary:
	for def: Dictionary in news_defs:
		if def["id"] == id:
			return def
	return {}


func _roll_news(month: int, day: int, news: Array[Dictionary], shocks: Dictionary) -> void:
	var candidates: Array[Dictionary] = []
	var weights := PackedFloat32Array()
	for def: Dictionary in news_defs:
		if not def.get("scheduled", false):  # keputusan suku bunga hanya dari _step_macro
			candidates.append(def)
			weights.append(def["weight"])
	var def: Dictionary = candidates[rng.rand_weighted(weights)]
	var shock := rng.randf_range(def["shock"][0], def["shock"][1])
	var target: String = def["target"]
	var asset_key := ""

	if target == "random_stock" or target == "random_crypto":
		var pool := _assets_of_class("stock" if target == "random_stock" else "crypto")
		var asset: MarketAsset = pool[rng.randi() % pool.size()]
		_add_shock(shocks, asset.id, day, shock)
		asset_key = asset.name_key
	elif target.begins_with("asset:"):
		var asset := get_asset(target.trim_prefix("asset:"))
		_add_shock(shocks, asset.id, day, shock)
		asset_key = asset.name_key
	elif target.begins_with("factor:"):
		_shock_factor(target.trim_prefix("factor:"), shock, shocks, day)
	elif target == "inflation":  # mis. harga BBM naik: inflasi naik, saham sedikit tertekan
		var macro: Dictionary = config["macro"]
		inflation = clampf(inflation + float(def["inflation_delta"]), macro["inflation_min"], macro["inflation_max"])
		_shock_factor("stock", shock, shocks, day)

	news.append(_make_news(month, def["text_key"], asset_key, shock, day))


## Guncangan ke semua aset satu faktor, diskalakan dengan beta masing-masing.
func _shock_factor(factor: String, shock: float, shocks: Dictionary, day: int) -> void:
	for asset: MarketAsset in assets.values():
		if asset.factor == factor:
			_add_shock(shocks, asset.id, day, shock * asset.beta)


static func _add_shock(shocks: Dictionary, asset_id: String, day: int, shock: float) -> void:
	var by_day: Dictionary = shocks.get_or_add(asset_id, {})
	by_day[day] = by_day.get(day, 0.0) + shock


func _assets_of_class(asset_class: String) -> Array[MarketAsset]:
	var result: Array[MarketAsset] = []
	for asset: MarketAsset in assets.values():
		if asset.asset_class == asset_class:
			result.append(asset)
	return result


## `day` = tanggal berita (1-30); 0 untuk berita siklus pasar yang berlaku sebulan penuh.
## `value` = angka yang ditampilkan di teks berita (mis. suku bunga baru), 0 jika tidak ada.
func _make_news(month: int, text_key: String, asset_key: String, shock: float, day := 0,
		value := 0.0) -> Dictionary:
	var item := {"month": month, "day": day, "key": text_key, "asset_key": asset_key, "shock": shock}
	if value != 0.0:
		item["value"] = value
	return item
