extends Node
## Uji otomatis v2a langkah 1: komoditas & emas (aliran acak kedua, pola musiman, berita ikutan,
## save lama, tahap unlock, beli/jual, tampilan). Jalankan dengan -- --save-root=user://_uji_commodity/

const NEW_IDS := ["EMAS", "MINYAK", "CPO", "KOPI"]

var _fail := 0
var _pass := 0


func _ready() -> void:
	TranslationServer.set_locale("id")
	for sig: Signal in [GameState.state_committed, GameState.player_changed]:
		for c: Dictionary in sig.get_connections():
			sig.disconnect(c["callable"])
	GameState.tutorial_done = true
	_test_data()
	_test_streams()
	_test_save_load()
	_test_old_save()
	_test_season()
	_test_cross()
	_test_statistics()
	_test_texts()
	_test_game()
	await _test_ui()
	print("HASIL: %d lulus, %d gagal" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _check(name: String, ok: bool, info: Variant = "") -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
		print("GAGAL: ", name, " ", info)


func _defs() -> Array:
	return DataLoader.load_json("res://data/assets.json")["assets"]


func _config() -> Dictionary:
	return DataLoader.load_json("res://data/market.json")


func _news() -> Array:
	return DataLoader.load_json("res://data/news.json")["news"]


func _market(seed_value: int) -> Market:
	var m := Market.new()
	m.setup(_defs(), _config(), _news(), seed_value)
	return m


## Pasar "versi lama": tanpa aset, faktor, berita aliran kedua, dan tanpa dampak ikutan.
func _old_market(seed_value: int) -> Market:
	var cfg := _config()
	for f: String in cfg["factors"].keys():
		if int(cfg["factors"][f].get("stream", 0)) != 0:
			cfg["factors"].erase(f)
	cfg.erase("ext_news_chance")
	var news: Array = []
	for d: Dictionary in _news():
		if int(d.get("stream", 0)) == 0:
			var copy := d.duplicate(true)
			copy.erase("cross")
			news.append(copy)
	var m := Market.new()
	m.setup(_defs().filter(func(d: Dictionary) -> bool: return int(d.get("stream", 0)) == 0), cfg, news, seed_value)
	return m


func _test_data() -> void:
	var m := _market(1)
	for id: String in NEW_IDS:
		var a := m.get_asset(id)
		_check("aset %s ada" % id, a != null)
		if a == null:
			continue
		_check("%s kelas komoditas, aliran 2" % id, a.asset_class == "commodity" and a.stream == 1)
		_check("%s punya satuan" % id, a.unit_key != "")
		_check("%s tahap" % id, a.stage == (3 if id == "EMAS" else 4), a.stage)
		if id != "EMAS":
			var total := 0.0
			for v in a.seasonal:
				total += v
			_check("%s pola musiman 12 bulan, jumlah 0" % id, a.seasonal.size() == 12 and absf(total) < 1e-9, total)
	_check("emas tanpa pola musiman", m.get_asset("EMAS").seasonal.is_empty())
	_check("siklus komoditas ada", m.regimes.has("commodity"))
	_check("emas tanpa siklus", not m.regimes.has("gold"))
	_check("harga awal emas", is_equal_approx(MarketAsset.from_def(_defs().filter(func(d: Dictionary) -> bool:
		return d["id"] == "EMAS")[0]).price, 1250000.0))


## Harga, inflasi, suku bunga & berita pasar lama SAMA PERSIS dengan pasar tanpa aset v2a.
func _test_streams() -> void:
	for seed_value in [3, 17, 99]:
		var a := _market(seed_value)
		var b := _old_market(seed_value)
		var same := true
		var news_same := true
		for month in range(1, 121):
			var na := a.step(month)
			var nb := b.step(month)
			var old_a := na.filter(func(n: Dictionary) -> bool: return not _is_new_news(n["key"]))
			if str(old_a) != str(nb):
				news_same = false
		for asset: MarketAsset in b.assets.values():
			var other := a.get_asset(asset.id)
			if other.price != asset.price or other.month_closes != asset.month_closes:
				same = false
		_check("seed %d: harga aset lama identik" % seed_value, same)
		_check("seed %d: berita lama identik" % seed_value, news_same)
		_check("seed %d: inflasi & suku bunga identik" % seed_value,
			a.inflation == b.inflation and a.policy_rate == b.policy_rate and a.price_level == b.price_level)
		_check("seed %d: siklus saham & kripto identik" % seed_value,
			str(a.regimes["stock"]) == str(b.regimes["stock"]) and str(a.regimes["crypto"]) == str(b.regimes["crypto"]))


func _is_new_news(key: String) -> bool:
	return "_CMD_" in key or "REGIME_COMMODITY" in key


func _test_save_load() -> void:
	var a := _market(21)
	for month in range(1, 30):
		a.step(month)
	var saved := JSON.parse_string(JSON.stringify(a.to_dict()))
	_check("save menyimpan rng aliran kedua", saved.has("ext_rng_state") and saved.has("ext_rng_seed"))
	var b := Market.new()
	b.load_state(_defs(), _config(), _news(), saved)
	var same := true
	for month in range(30, 60):
		if str(a.step(month)) != str(b.step(month)):
			same = false
	for asset: MarketAsset in a.assets.values():
		if absf(asset.price - b.get_asset(asset.id).price) > absf(asset.price) * 1e-12:
			same = false
	_check("simpan/muat: pasar tetap sama (termasuk komoditas)", same)


## Save sebelum v2a: aset komoditas, rng kedua, & siklus komoditas belum ada.
func _test_old_save() -> void:
	var a := _market(31)
	for month in range(1, 40):
		a.step(month)
	var d: Dictionary = JSON.parse_string(JSON.stringify(a.to_dict()))
	for id: String in NEW_IDS:
		d["assets"].erase(id)
	d.erase("ext_rng_seed")
	d.erase("ext_rng_state")
	d["regimes"].erase("commodity")
	var b := Market.new()
	b.load_state(_defs(), _config(), _news(), d)
	_check("save lama: siklus komoditas dibuat", b.regimes.has("commodity"))
	var ok := true
	for id: String in NEW_IDS:
		var asset := b.get_asset(id)
		ok = ok and asset.month_closes.size() == Market.WARMUP_MONTHS + 1 and asset.price > 0.0
		ok = ok and asset.history.size() == 1 + Market.WARMUP_MONTHS * MarketAsset.TRADING_DAYS
	_check("save lama: riwayat isian 12 bulan untuk aset baru", ok)
	var start: float = _defs().filter(func(x: Dictionary) -> bool: return x["id"] == "EMAS")[0]["start_price"]
	_check("save lama: harga isian ikut indeks harga", b.get_asset("EMAS").month_closes[0] == start * a.price_level,
		[b.get_asset("EMAS").month_closes[0], start * a.price_level])
	var old_same := true
	for asset: MarketAsset in a.assets.values():
		if not asset.id in NEW_IDS and b.get_asset(asset.id).price != asset.price:
			old_same = false
	_check("save lama: harga aset lama tetap", old_same)
	b.step(40)
	_check("save lama: pasar bisa jalan", b.get_asset("CPO").month_closes.size() == Market.WARMUP_MONTHS + 2)


## Pola musiman = tambahan drift tepat sebesar season_drift / 12 per bulan (tanpa gejolak & berita).
func _test_season() -> void:
	var def: Dictionary = _defs().filter(func(x: Dictionary) -> bool: return x["id"] == "CPO")[0].duplicate(true)
	def["volatility"] = 0.0
	def["drift"] = 0.0
	var a := MarketAsset.from_def(def)
	var b := MarketAsset.from_def(def)
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 5
	rng_b.seed = 5
	var z: Array[float] = []
	z.resize(MarketAsset.DAYS_IN_MONTH)
	a.step_month(rng_a, z, 0.0, 1.0, {}, a.season_drift(1))  # Februari +0,30/tahun
	b.step_month(rng_b, z, 0.0, 1.0, {}, 0.0)
	_check("Februari: CPO naik exp(0,30/12)", is_equal_approx(a.price / b.price, exp(0.30 / 12.0)), a.price / b.price)
	_check("season_drift Agustus CPO -0,30", is_equal_approx(a.season_drift(7), -0.30))
	_check("aset tanpa musim: 0", MarketAsset.from_def(_defs()[4]).season_drift(3) == 0.0)


func _test_cross() -> void:
	var m := _market(7)
	var shocks := {}
	m._apply_cross({"cross": {"factor:gold": -0.5, "asset:MINYAK": -3.0, "factor:commodity": 0.5}}, -0.04, shocks, 9)
	_check("bursa anjlok -> emas naik", is_equal_approx(shocks["EMAS"][9], 0.02), shocks.get("EMAS"))
	_check("pengali aset: minyak", is_equal_approx(shocks["MINYAK"][9], 0.12 - 0.02 * 1.2), shocks.get("MINYAK"))
	_check("faktor komoditas memakai beta (CPO 0,9)", is_equal_approx(shocks["CPO"][9], -0.02 * 0.9), shocks.get("CPO"))
	_check("saham tidak tersentuh", not shocks.has("BSNT"))
	var before := m.rng_ext.state
	var shocks2 := {}
	m._apply_cross({"cross": {"factor:gold": 1.0}}, 0.01, shocks2, 3)
	_check("dampak ikutan tanpa angka acak", m.rng_ext.state == before)
	var defs := {}
	for d: Dictionary in _news():
		defs[d["id"]] = d
	_check("BI menaikkan suku bunga menekan emas", float(defs["rate_up"]["cross"]["factor:gold"]) > 0.0
		and float(defs["rate_up"]["shock"][1]) < 0.0)
	_check("BBM naik mengangkat minyak", float(defs["fuel_up"]["cross"]["asset:MINYAK"]) < 0.0)


## Statistik jangka panjang (10 pasar x 60 tahun): imbal hasil, korelasi, dan pola musiman terlihat.
func _test_statistics() -> void:
	var logs := {}  # id -> log return bulanan
	var season_logs := {}  # id -> [jumlah per bulan kalender, jumlah sampel]
	for id: String in NEW_IDS + ["RDS"]:
		logs[id] = []
		season_logs[id] = [[], []]
		for i in 12:
			season_logs[id][0].append(0.0)
			season_logs[id][1].append(0)
	var months := 720
	for seed_value in range(100, 110):
		var m := _market(seed_value)
		for month in range(1, months + 1):
			var prev := {}
			for id: String in logs:
				prev[id] = m.get_asset(id).price
			m.step(month)
			var season := posmod(month - 1, 12)
			for id: String in logs:
				var r := log(m.get_asset(id).price / prev[id])
				logs[id].append(r)
				season_logs[id][0][season] += r
				season_logs[id][1][season] += 1
	var line := "imbal hasil geometrik/tahun:"
	var annual := {}
	for id: String in NEW_IDS:
		annual[id] = exp(_mean(logs[id]) * 12.0) - 1.0
		line += " %s %.1f%%" % [id, annual[id] * 100.0]
	print(line)
	_check("emas tumbuh 3-9%/tahun", annual["EMAS"] > 0.03 and annual["EMAS"] < 0.09, annual["EMAS"])
	for id: String in ["MINYAK", "CPO", "KOPI"]:
		_check("%s tumbuh 0-7%%/tahun" % id, annual[id] > 0.0 and annual[id] < 0.07, annual[id])
	var corr_gold := _corr(logs["EMAS"], logs["RDS"])
	var corr_cmd := _corr(logs["CPO"], logs["RDS"])
	print("korelasi bulanan dengan RD saham: emas %.2f, CPO %.2f, minyak %.2f" % [corr_gold, corr_cmd,
		_corr(logs["MINYAK"], logs["RDS"])])
	_check("emas berlawanan dengan saham", corr_gold < -0.1, corr_gold)
	_check("komoditas sedikit searah dengan saham", corr_cmd > 0.03, corr_cmd)
	var cpo: Array = season_logs["CPO"]
	var wet := 0.0
	var dry := 0.0
	for m_index in [10, 11, 0, 1, 2]:
		wet += cpo[0][m_index] / cpo[1][m_index] / 5.0
	for m_index in [4, 5, 6, 7, 8]:
		dry += cpo[0][m_index] / cpo[1][m_index] / 5.0
	print("CPO rata-rata log return bulanan: Nov-Mar %.2f%%, Mei-Sep %.2f%%" % [wet * 100.0, dry * 100.0])
	_check("pola musiman CPO terlihat jangka panjang", wet - dry > 0.02, [wet, dry])


func _mean(values: Array) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / values.size()


func _corr(a: Array, b: Array) -> float:
	var ma := _mean(a)
	var mb := _mean(b)
	var cov := 0.0
	var va := 0.0
	var vb := 0.0
	for i in a.size():
		cov += (a[i] - ma) * (b[i] - mb)
		va += (a[i] - ma) * (a[i] - ma)
		vb += (b[i] - mb) * (b[i] - mb)
	return cov / sqrt(va * vb)


func _test_texts() -> void:
	var missing := []
	for d: Dictionary in _news():
		if tr(d["text_key"]) == d["text_key"]:
			missing.append(d["text_key"])
		if String(d["target"]).begins_with("asset:") and not tr(d["text_key"]).contains("%s"):
			missing.append(d["text_key"] + " tanpa %s")
	for r in ["BULL", "SIDEWAYS", "BEAR"]:
		if tr("NEWS_REGIME_COMMODITY_" + r) == "NEWS_REGIME_COMMODITY_" + r:
			missing.append("REGIME " + r)
	var m := _market(1)
	for id: String in NEW_IDS:
		var a := m.get_asset(id)
		for key in [a.name_key, "DESC_" + a.name_key, a.unit_key]:
			if tr(key) == key:
				missing.append(key)
	for key in ["CLASS_COMMODITY", "DESC_COMMODITY", "INFO_UNIT", "INFO_SEASON", "MARKET_MOOD_COMMODITY"]:
		if tr(key) == key:
			missing.append(key)
	_check("semua teks komoditas ada", missing.is_empty(), missing)
	_check("musim CPO", UiText.season_text(m.get_asset("CPO")).contains("menguat Nov-Mar")
		and UiText.season_text(m.get_asset("CPO")).contains("melemah Mei-Sep"), UiText.season_text(m.get_asset("CPO")))
	_check("musim kopi", UiText.season_text(m.get_asset("KOPI")).contains("menguat Des-Mar")
		and UiText.season_text(m.get_asset("KOPI")).contains("melemah Mei-Jul"), UiText.season_text(m.get_asset("KOPI")))
	_check("musim minyak", UiText.season_text(m.get_asset("MINYAK")).contains("menguat Feb-Mei")
		and UiText.season_text(m.get_asset("MINYAK")).contains("melemah Sep-Des"), UiText.season_text(m.get_asset("MINYAK")))
	_check("emas tanpa teks musim", UiText.season_text(m.get_asset("EMAS")) == "")
	var seasonal: Array[float] = [0.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.2]
	_check("rentang melewati akhir tahun", UiText._month_ranges(seasonal, 1.0) == "Des-Jan", UiText._month_ranges(seasonal, 1.0))
	seasonal = [0.2, 0.0, 0.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	_check("dua rentang terpisah", UiText._month_ranges(seasonal, 1.0) == "Jan, Mar", UiText._month_ranges(seasonal, 1.0))
	_check("tidak ada bulan melemah", UiText._month_ranges(seasonal, -1.0) == "-")


func _test_game() -> void:
	GameState.new_game({"name": "Uji", "background": "s1", "difficulty": "normal"}, 404)
	_check("permainan baru punya emas", GameState.market.get_asset("EMAS") != null)
	_check("emas terkunci di awal", not GameState.progress.is_asset_unlocked("EMAS"))
	GameState.progress.unlocked_stages.assign([1, 2, 3])
	_check("tahap 3 membuka emas", GameState.progress.is_asset_unlocked("EMAS"))
	_check("tahap 3 belum membuka minyak", not GameState.progress.is_asset_unlocked("MINYAK"))
	_check("emas bisa diautodebet", GameState.budget.autodebet_assets().any(func(a: MarketAsset) -> bool: return a.id == "EMAS"))
	GameState.cash = 50_000_000
	var price: float = GameState.market.get_asset("EMAS").price
	var q := GameState.portfolio.trade_quote("EMAS", true, 10_000_000)
	_check("fee beli emas 1%", is_equal_approx(q["fee"], 100_000.0), q["fee"])
	var result := GameState.portfolio.buy("EMAS", 10_000_000)
	_check("beli emas", result["ok"] and is_equal_approx(result["units"], 9_900_000.0 / price), result)
	var sell := GameState.portfolio.sell("EMAS", ceili(GameState.portfolio.holding_value("EMAS")))
	_check("jual emas: fee 1%, rugi selisih harga ±2%", sell["ok"] and absf(float(sell["pnl"]) + 199_000.0) < 2_000.0, sell)
	GameState.progress.unlocked_stages.assign([1, 2, 3, 4])
	_check("tahap 4 membuka minyak, sawit, kopi", GameState.progress.is_asset_unlocked("MINYAK")
		and GameState.progress.is_asset_unlocked("CPO") and GameState.progress.is_asset_unlocked("KOPI"))
	GameState.portfolio.buy("CPO", 5_000_000)
	_check("pegang komoditas = konteks aset berisiko", GameState.events.context_flags()["holds_risky"])
	for m in 3:
		GameState.advance_month()
		while GameState.events.has_pending():
			GameState.events.resolve(GameState.events.pending["choices"].size() - 1)
	var saved := GameState.to_dict()
	var price_cpo: float = GameState.market.get_asset("CPO").price
	GameState.load_from_dict(JSON.parse_string(JSON.stringify(saved)))
	_check("simpan/muat permainan: harga CPO tetap", is_equal_approx(GameState.market.get_asset("CPO").price, price_cpo))
	_check("simpan/muat permainan: kepemilikan CPO tetap", GameState.portfolio.units_of("CPO") > 0.0)
	# Save lama tanpa aset komoditas tetap bisa dimuat.
	var old: Dictionary = JSON.parse_string(JSON.stringify(saved))
	for id: String in NEW_IDS:
		old["market"]["assets"].erase(id)
	old["market"].erase("ext_rng_state")
	old["market"].erase("ext_rng_seed")
	old["market"]["regimes"].erase("commodity")
	old["holdings"].erase("CPO")
	GameState.load_from_dict(old)
	_check("save lama dimuat: emas ada", GameState.market.get_asset("EMAS").month_closes.size() == Market.WARMUP_MONTHS + 1)
	GameState.advance_month()
	_check("save lama: bulan berikutnya jalan", GameState.market.get_asset("EMAS").month_closes.size() == Market.WARMUP_MONTHS + 2)
	_check("rumor hanya untuk saham & kripto", _rumor_classes_ok())


func _rumor_classes_ok() -> bool:
	GameState.progress.unlocked_stages.assign([1, 2, 3, 4])
	for def: Dictionary in GameState.research.data["rumors"]:
		for asset_id: String in GameState.research._targets(def):
			if GameState.market.get_asset(asset_id).asset_class == "commodity":
				return false
	return true


func _test_ui() -> void:
	GameState.new_game({"name": "Uji", "background": "s1", "difficulty": "normal"}, 405)
	GameState.progress.unlocked_stages.assign([1, 2, 3, 4])
	var screen: Node = load("res://scenes/screens/market_screen.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	var headers := []
	for child in screen.get_node("%AssetList").get_children():
		if child is Label:
			headers.append(child.text)
	_check("daftar pasar punya kelas KOMODITAS", "KOMODITAS" in headers, headers)
	_check("baris emas ada", screen._rows.has("EMAS") and screen._rows.has("KOPI"))
	var chips := []
	for chip in screen.get_node("%MoodRow").get_children():
		chips.append(chip.get_child(0).text if chip.get_child_count() > 0 else "")
	_check("chip siklus komoditas", chips.any(func(t: String) -> bool: return t.begins_with("Komoditas")), chips)
	screen._show_detail("CPO")
	await get_tree().process_frame
	var info: String = screen.get_node("%InfoLabel").text
	_check("detail CPO: satuan & pola musiman", info.contains("1 unit = 1 ton") and info.contains("Nov-Mar"), info)
	_check("detail CPO: penjelasan khusus", screen.get_node("%DescLabel").text.contains("El Niño"))
	screen.queue_free()
	var tile := UiText.class_tile("commodity")
	_check("ikon kelas komoditas (pengganti sementara)", tile.get_child_count() == 1)
	tile.free()
