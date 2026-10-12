class_name Market
extends RefCounted
## Simulasi pasar: menyimpan semua aset dan menggerakkan harganya tiap bulan.
## Memakai RNG ber-seed sendiri agar hasilnya bisa direproduksi (penting untuk save/load).
##
## Komponen simulasi:
## - Siklus pasar (bull / sideways / bear) per faktor ("stock", "crypto"), durasinya acak.
## - Faktor bersama: aset satu faktor cenderung bergerak searah (korelasi).
## - Suku bunga acuan: menentukan bunga tabungan & deposito, bisa naik/turun lewat berita.
## - Berita: guncangan harga sekali untuk satu aset, satu faktor, atau suku bunga.

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

	_update_regimes(month, news)
	if rng.randf() < config["news_chance"]:
		_roll_news(month, news, shocks)

	var factor_z := {}
	for factor: String in regimes:
		factor_z[factor] = rng.randfn(0.0, 1.0)

	for asset: MarketAsset in assets.values():
		var regime_drift := 0.0
		var vol_mult := 1.0
		if regimes.has(asset.factor):
			var regime: Dictionary = config["regimes"][regimes[asset.factor]["id"]]
			regime_drift = regime["drift"] * config["factors"][asset.factor]["drift_scale"]
			vol_mult = regime["vol_mult"]
		asset.step(rng, factor_z.get(asset.factor, 0.0), regime_drift, vol_mult, shocks.get(asset.id, 0.0))

	for item in news:
		news_log.push_front(item)
	news_log.resize(mini(news_log.size(), int(config["news_log_size"])))
	return news


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


func _update_regimes(month: int, news: Array[Dictionary]) -> void:
	for factor: String in regimes:
		var regime: Dictionary = regimes[factor]
		regime["months_left"] -= 1
		if regime["months_left"] > 0:
			continue
		var next: Dictionary = config["regimes"][regime["id"]]["next"]
		var next_id: String = next.keys()[rng.rand_weighted(PackedFloat32Array(next.values()))]
		regimes[factor] = _new_regime(next_id)
		news.append(_make_news(month, "NEWS_REGIME_%s_%s" % [factor.to_upper(), next_id.to_upper()], "", 0.0))


func _roll_news(month: int, news: Array[Dictionary], shocks: Dictionary) -> void:
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

	news.append(_make_news(month, def["text_key"], asset_key, shock))


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


func _make_news(month: int, text_key: String, asset_key: String, shock: float) -> Dictionary:
	return {"month": month, "key": text_key, "asset_key": asset_key, "shock": shock}
