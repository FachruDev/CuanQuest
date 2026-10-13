class_name Market
extends RefCounted
## Simulasi pasar: menyimpan semua aset dan menggerakkan harganya tiap bulan, hari demi hari.
## Memakai RNG ber-seed sendiri agar hasilnya bisa direproduksi (penting untuk save/load).
##
## Komponen simulasi:
## - Siklus pasar (bull / sideways / bear) per faktor ("stock", "crypto"), durasinya acak.
## - Faktor bersama: aset satu faktor cenderung bergerak searah (korelasi).
## - Suku bunga acuan: menentukan bunga tabungan & deposito, bisa naik/turun lewat berita.
## - Berita: guncangan harga sekali untuk satu aset, satu faktor, atau suku bunga,
##   pada satu tanggal acak di bulan itu (terlihat sebagai lonjakan di grafik harian).

const WARMUP_MONTHS := 12  # riwayat harga palsu agar grafik tidak kosong di awal

var assets: Dictionary = {}       # id -> MarketAsset (urutan sesuai assets.json)
var rng := RandomNumberGenerator.new()
var config: Dictionary = {}       # isi data/market.json
var news_defs: Array = []         # isi data/news.json
var policy_rate: float = 0.0      # suku bunga acuan per tahun
var regimes: Dictionary = {}      # faktor -> { "id": "bull", "months_left": 7 }
var news_log: Array[Dictionary] = []  # terbaru di depan


func setup(asset_defs: Array, market_config: Dictionary, news: Array, seed_value: int) -> void:
	rng.seed = seed_value
	config = market_config
	news_defs = news
	policy_rate = config["start_policy_rate"]
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
	var shocks: Dictionary = {}  # asset_id -> guncangan harga
	var news_day := 0

	_update_regimes(month, news)
	if rng.randf() < config["news_chance"]:
		news_day = rng.randi_range(1, MarketAsset.DAYS_IN_MONTH)
		_roll_news(month, news_day, news, shocks)

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
		var regime_drift := 0.0
		var vol_mult := 1.0
		if regimes.has(asset.factor):
			var regime: Dictionary = config["regimes"][regimes[asset.factor]["id"]]
			regime_drift = regime["drift"] * config["factors"][asset.factor]["drift_scale"]
			vol_mult = regime["vol_mult"]
		var z: Array[float] = factor_z.get(asset.factor, no_factor)
		asset.step_month(rng, z, regime_drift, vol_mult, shocks.get(asset.id, 0.0), news_day)

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


func _roll_news(month: int, day: int, news: Array[Dictionary], shocks: Dictionary) -> void:
	var weights := PackedFloat32Array()
	for def: Dictionary in news_defs:
		weights.append(def["weight"])
	var def: Dictionary = news_defs[rng.rand_weighted(weights)]
	var shock := rng.randf_range(def["shock"][0], def["shock"][1])
	var target: String = def["target"]
	var asset_key := ""

	if target == "random_stock" or target == "random_crypto":
		var candidates := _assets_of_class("stock" if target == "random_stock" else "crypto")
		var asset: MarketAsset = candidates[rng.randi() % candidates.size()]
		shocks[asset.id] = shock
		asset_key = asset.name_key
	elif target.begins_with("asset:"):
		var asset := get_asset(target.trim_prefix("asset:"))
		shocks[asset.id] = shock
		asset_key = asset.name_key
	elif target.begins_with("factor:"):
		_shock_factor(target.trim_prefix("factor:"), shock, shocks)
	elif target == "rate":
		policy_rate = clampf(policy_rate + def["rate_delta"], config["min_policy_rate"], config["max_policy_rate"])
		_shock_factor("stock", shock, shocks)  # suku bunga naik biasanya menekan saham

	news.append(_make_news(month, def["text_key"], asset_key, shock, day))


## Guncangan ke semua aset satu faktor, diskalakan dengan beta masing-masing.
func _shock_factor(factor: String, shock: float, shocks: Dictionary) -> void:
	for asset: MarketAsset in assets.values():
		if asset.factor == factor:
			shocks[asset.id] = shocks.get(asset.id, 0.0) + shock * asset.beta


func _assets_of_class(asset_class: String) -> Array[MarketAsset]:
	var result: Array[MarketAsset] = []
	for asset: MarketAsset in assets.values():
		if asset.asset_class == asset_class:
			result.append(asset)
	return result


## `day` = tanggal berita (1-30); 0 untuk berita siklus pasar yang berlaku sebulan penuh.
func _make_news(month: int, text_key: String, asset_key: String, shock: float, day := 0) -> Dictionary:
	return {"month": month, "day": day, "key": text_key, "asset_key": asset_key, "shock": shock}
