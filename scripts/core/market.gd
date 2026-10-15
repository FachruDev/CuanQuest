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
## - Rumor (v1.5d): guncangan & berita tambahan dari GameState.research lewat parameter `extra`.
## - Aliran acak kedua (v2a): aset, faktor, dan berita baru (komoditas, valas) memakai `rng_ext`,
##   sehingga urutan angka acak pasar lama tidak bergeser dan harga aset lama tetap sama persis.
##   Faktor aliran kedua bisa "terikat" ke faktor lama (`link`), dan berita lama bisa ikut
##   menggerakkan aset baru lewat pengali tetap (`cross`), keduanya tanpa angka acak tambahan.
## - Pola musiman (v2a): drift tambahan per bulan kalender dari field `seasonal` aset.
## - Valas (v2a): kurs (faktor "fx" = pelemahan rupiah) ikut suku bunga acuan lewat `rate_drift` aset,
##   guncangan keputusan suku bunga & kepanikan bursa (`cross`), dan berita valas sendiri.

const WARMUP_MONTHS := 12  # riwayat harga palsu agar grafik tidak kosong di awal
const EXT_STREAM := 1  # nomor aliran acak kedua (field "stream" di assets.json, market.json, news.json)

var assets: Dictionary = {}       # id -> MarketAsset (urutan sesuai assets.json)
var rng := RandomNumberGenerator.new()
var rng_ext := RandomNumberGenerator.new()  # aliran acak kedua (v2a), seed = seed + ext_seed_offset
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
	rng_ext.seed = seed_value + int(market_config.get("ext_seed_offset", 4))
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
	for stream in [0, EXT_STREAM]:
		var r := _rng_of(stream)
		for factor: String in _regime_factors(stream):
			regimes[factor] = _new_regime(regime_ids[r.randi() % regime_ids.size()], r)

	for i in WARMUP_MONTHS:
		step(-WARMUP_MONTHS + i)
	news_log.clear()  # berita masa warmup tidak ditampilkan


## Gerakkan pasar satu bulan. `month` = bulan game tempat berita ditampilkan.
## `extra` = guncangan & berita dari luar pasar (rumor, v1.5d): {"shocks": {asset_id: {tanggal: guncangan}},
## "news": [berita]}. Tidak memakai RNG pasar, jadi urutan acak pasar tetap sama.
## Mengembalikan daftar berita bulan ini.
func step(month: int, extra: Dictionary = {}) -> Array[Dictionary]:
	var news: Array[Dictionary] = []
	var shocks: Dictionary = {}  # asset_id -> {tanggal: guncangan harga}

	_update_regimes(month, news, 0)
	if month > 0:  # masa warmup (riwayat palsu) tidak menaikkan harga-harga
		_step_macro(month, news, shocks)
	if rng.randf() < config["news_chance"]:
		_roll_news(month, rng.randi_range(1, MarketAsset.DAYS_IN_MONTH), news, shocks, 0)
	for asset_id: String in extra.get("shocks", {}):
		for day: int in extra["shocks"][asset_id]:
			_add_shock(shocks, asset_id, day, extra["shocks"][asset_id][day])
	for item: Dictionary in extra.get("news", []):
		news.append(item)
	# Aliran kedua (v2a): siklus komoditas, lalu satu peluang berita per kelompok (komoditas, valas).
	_update_regimes(month, news, EXT_STREAM)
	var groups: Dictionary = config.get("ext_news", {})
	for group: String in groups:
		if rng_ext.randf() < float(groups[group]):
			_roll_news(month, rng_ext.randi_range(1, MarketAsset.DAYS_IN_MONTH), news, shocks, EXT_STREAM, group)

	# Angka acak bersama per hari untuk tiap faktor (sumber korelasi harian).
	# Urutan loop HARUS tetap (ikut file data), bukan urutan Dictionary `regimes`:
	# setelah save/load lewat JSON urutan key bisa berubah, dan angka acak akan
	# tertukar antar faktor sehingga hasil simulasi tidak lagi sama.
	var no_factor: Array[float] = []
	no_factor.resize(MarketAsset.DAYS_IN_MONTH)  # isi 0.0: aset tanpa faktor bergerak sendiri
	var factor_z := {}
	for factor: String in _factor_order(0):
		var daily: Array[float] = []
		for day in MarketAsset.DAYS_IN_MONTH:
			daily.append(rng.randfn(0.0, 1.0))
		factor_z[factor] = daily
	# Faktor aliran kedua boleh terikat ke faktor lama, mis. emas berlawanan arah dengan saham:
	# z = rho_link x z_faktor_lama + sqrt(1 - rho_link^2) x z_sendiri.
	for factor: String in _factor_order(EXT_STREAM):
		var link: Dictionary = config["factors"][factor].get("link", {})
		var linked: Array[float] = factor_z.get(link.get("factor", ""), no_factor)
		var link_rho := float(link.get("rho", 0.0))
		var daily: Array[float] = []
		for day in MarketAsset.DAYS_IN_MONTH:
			daily.append(link_rho * linked[day] + sqrt(1.0 - link_rho * link_rho) * rng_ext.randfn(0.0, 1.0))
		factor_z[factor] = daily

	var season := posmod(month - 1, 12)  # bulan kalender yang sedang berjalan saat Lanjut ditekan
	var rate_gap := policy_rate - float(config["start_policy_rate"])
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
		asset.step_month(_rng_of(asset.stream), z, regime_drift, vol_mult, shocks.get(asset.id, {}),
			asset.extra_drift(season, rate_gap))

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
		"ext_rng_seed": str(rng_ext.seed), "ext_rng_state": str(rng_ext.state),
		"policy_rate": policy_rate, "regimes": regimes, "news_log": news_log,
		"inflation": inflation, "price_level": price_level, "price_levels": price_levels,
		"assets": asset_states,
	}


## Kebalikan to_dict(): parameter aset diambil dari file data terbaru, harga dari save.
func load_state(asset_defs: Array, market_config: Dictionary, news: Array, d: Dictionary) -> void:
	config = market_config
	news_defs = news
	assets.clear()
	var missing: Array[MarketAsset] = []  # aset baru yang belum ada di save lama (v2a)
	for def: Dictionary in asset_defs:
		var asset := MarketAsset.from_def(def)
		var saved: Dictionary = d["assets"].get(asset.id, {})
		if not saved.is_empty():
			asset.price = saved["price"]
			asset.history.assign(saved["history"])
			asset.month_closes.assign(saved["month_closes"])
		else:
			missing.append(asset)
		assets[asset.id] = asset
	rng.seed = String(d["rng_seed"]).to_int()
	rng.state = String(d["rng_state"]).to_int()
	rng_ext.seed = String(d.get("ext_rng_seed", str(rng.seed + int(config.get("ext_seed_offset", 4))))).to_int()
	if d.has("ext_rng_state"):
		rng_ext.state = String(d["ext_rng_state"]).to_int()
	policy_rate = d["policy_rate"]
	# Save v1.5-0 belum punya inflasi: harga dianggap mulai naik sejak dimuat.
	inflation = d.get("inflation", config["macro"]["inflation_mean"])
	price_level = d.get("price_level", 1.0)
	price_levels.assign(d.get("price_levels", [price_level]))
	regimes.clear()
	for factor: String in d["regimes"]:
		var r: Dictionary = d["regimes"][factor]
		regimes[factor] = {"id": r["id"], "months_left": int(r["months_left"])}
	var regime_ids: Array = config["regimes"].keys()
	for factor: String in _regime_factors(EXT_STREAM):  # save lama: siklus faktor baru dimulai sekarang
		if not regimes.has(factor):
			regimes[factor] = _new_regime(regime_ids[rng_ext.randi() % regime_ids.size()], rng_ext)
	for asset: MarketAsset in missing:  # memakai price_level yang sudah dimuat di atas
		_backfill(asset)
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

func _new_regime(id: String, r: RandomNumberGenerator) -> Dictionary:
	var def: Dictionary = config["regimes"][id]
	return {"id": id, "months_left": r.randi_range(int(def["min_months"]), int(def["max_months"]))}


func _rng_of(stream: int) -> RandomNumberGenerator:
	return rng_ext if stream == EXT_STREAM else rng


## Faktor milik satu aliran acak, urut sesuai market.json (urutan tetap = hasil sama setelah muat).
func _factor_order(stream: int) -> Array:
	return config["factors"].keys().filter(func(f: String) -> bool:
		return int(config["factors"][f].get("stream", 0)) == stream)


## Faktor yang punya siklus naik/datar/turun ("regimes": false = tanpa siklus, mis. emas & valas).
func _regime_factors(stream: int) -> Array:
	return _factor_order(stream).filter(func(f: String) -> bool:
		return config["factors"][f].get("regimes", true))


func _update_regimes(month: int, news: Array[Dictionary], stream: int) -> void:
	var r := _rng_of(stream)
	for factor: String in _regime_factors(stream):
		var regime: Dictionary = regimes[factor]
		regime["months_left"] -= 1
		if regime["months_left"] > 0:
			continue
		var next: Dictionary = config["regimes"][regime["id"]]["next"]
		var next_id: String = next.keys()[r.rand_weighted(PackedFloat32Array(next.values()))]
		regimes[factor] = _new_regime(next_id, r)
		news.append(_make_news(month, "NEWS_REGIME_%s_%s" % [factor.to_upper(), next_id.to_upper()], "", 0.0))


## Save lama (sebelum v2a) belum punya aset baru: riwayat isian WARMUP_MONTHS bulan dengan aliran
## acak kedua, mulai dari harga awal x indeks harga sekarang (harga ikut naik bersama inflasi).
func _backfill(asset: MarketAsset) -> void:
	asset.price *= price_level
	asset.history.assign([asset.price])
	asset.month_closes.assign([asset.price])
	for i in WARMUP_MONTHS:
		var z: Array[float] = []
		for day in MarketAsset.DAYS_IN_MONTH:
			z.append(rng_ext.randfn(0.0, 1.0))
		asset.step_month(rng_ext, z, 0.0, 1.0)


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
	_apply_cross(def, shock, shocks, day)
	news.append(_make_news(month, def["text_key"], "", shock, day, policy_rate))


func _news_def(id: String) -> Dictionary:
	for def: Dictionary in news_defs:
		if def["id"] == id:
			return def
	return {}


## Satu berita acak dari aliran `stream` (berita lama 0, berita komoditas/valas 1), dibatasi ke
## kelompok `group` jika diisi (field "group" di news.json).
func _roll_news(month: int, day: int, news: Array[Dictionary], shocks: Dictionary, stream: int,
		group := "") -> void:
	var r := _rng_of(stream)
	var candidates: Array[Dictionary] = []
	var weights := PackedFloat32Array()
	for def: Dictionary in news_defs:
		# Keputusan suku bunga hanya dari _step_macro.
		if not def.get("scheduled", false) and int(def.get("stream", 0)) == stream \
				and (group == "" or def.get("group", "") == group):
			candidates.append(def)
			weights.append(def["weight"])
	if candidates.is_empty():
		return
	var def: Dictionary = candidates[r.rand_weighted(weights)]
	var shock := r.randf_range(def["shock"][0], def["shock"][1])
	var target: String = def["target"]
	var asset_key := ""

	if target == "random_stock" or target == "random_crypto":
		var pool := _assets_of_class("stock" if target == "random_stock" else "crypto")
		var asset: MarketAsset = pool[r.randi() % pool.size()]
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

	_apply_cross(def, shock, shocks, day)
	news.append(_make_news(month, def["text_key"], asset_key, shock, day))


## Dampak ikutan berita ke aset lain dengan pengali tetap (v2a), mis. bursa global anjlok -> emas naik:
## "cross": {"factor:gold": -0.5, "asset:MINYAK": -3.0} = guncangan berita x pengali. Tanpa angka acak.
func _apply_cross(def: Dictionary, shock: float, shocks: Dictionary, day: int) -> void:
	var cross: Dictionary = def.get("cross", {})
	for target: String in cross:
		var amount := shock * float(cross[target])
		if target.begins_with("factor:"):
			_shock_factor(target.trim_prefix("factor:"), amount, shocks, day)
		elif target.begins_with("asset:") and assets.has(target.trim_prefix("asset:")):
			_add_shock(shocks, target.trim_prefix("asset:"), day, amount)


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
