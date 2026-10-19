class_name Legacy
extends GameModule
## Skor warisan v2 (v2b langkah 5): 0-1000 dari kekayaan riil, usia, rata-rata kesehatan & kebahagiaan
## sepanjang hidup, impian tercapai, dan keputusan bijak. Semua dalam nilai riil agar bisa dibandingkan
## antar permainan. Modul ini juga menyediakan kekayaan bersih riil setiap bulan untuk grafik layar akhir.
## Data: data/legacy.json. Analogi web: seperti "health score" akun yang dihitung dari beberapa metrik
## berbobot, lengkap dengan rincian per metrik.

const DATA_PATH := "res://data/legacy.json"
## Urutan bagian skor (juga urutan baris rincian di layar akhir; teks LEGACY_<ID>).
const PARTS := ["wealth", "age", "health", "happiness", "dreams", "wisdom"]

var data: Dictionary = {}  # isi data/legacy.json
var health_sum := 0.0  # jumlah kesehatan di akhir setiap bulan
var happiness_sum := 0.0
var months := 0  # bulan yang sudah dicatat
var _legacy := false  # save sebelum v2b langkah 5: catatan diperkirakan saat begin()


func load_data() -> void:
	data = DataLoader.load_json(DATA_PATH)


func reset() -> void:
	health_sum = 0.0
	happiness_sum = 0.0
	months = 0
	_legacy = false


func save_to(d: Dictionary) -> void:
	d["legacy"] = {"health_sum": health_sum, "happiness_sum": happiness_sum, "months": months}


## Save sebelum v2b langkah 5: belum ada kunci "legacy", catatan diperkirakan di begin().
func load_from(d: Dictionary) -> void:
	reset()
	var l: Dictionary = d.get("legacy", {})
	if l.is_empty():
		_legacy = true
		return
	health_sum = float(l.get("health_sum", 0.0))
	happiness_sum = float(l.get("happiness_sum", 0.0))
	months = int(l.get("months", 0))


## Dipanggil setelah permainan baru dimulai atau save dimuat. Save lama: rata-rata kesehatan &
## kebahagiaan diperkirakan dari nilai sekarang, dan penipuan yang mengena dari kerugian penipuan.
func begin() -> void:
	if _legacy:
		_legacy = false
		months = gs.month
		health_sum = float(gs.health) * months
		happiness_sum = float(gs.happiness) * months
		if int(gs.stats["scams_fallen"]) == 0 and float(gs.stats["scam_loss"]) > 0.0:
			gs.stats["scams_fallen"] = 1


## Catatan akhir bulan (dipanggil GameState.advance_month setelah kekayaan bersih dihitung).
func record_month() -> void:
	health_sum += gs.health
	happiness_sum += gs.happiness
	months += 1


## Kekayaan bersih riil setiap bulan (Rupiah awal permainan), indeks = bulan: riwayat kekayaan nominal
## dibagi indeks harga bulan itu (Market.price_levels, disejajarkan dari belakang). Save lama yang indeks
## harganya tidak lengkap: bulan-bulan awal diperkirakan dengan inflasi merata sampai indeks pertama.
func real_history() -> Array[float]:
	var worth := gs.net_worth_history
	var levels: Array[float] = gs.market.price_levels
	var missing := worth.size() - levels.size()
	var first := levels[0] if not levels.is_empty() else gs.price_level()
	var out: Array[float] = []
	for i in worth.size():
		var level := levels[i - missing] if i >= missing else pow(first, float(i) / float(missing))
		out.append(worth[i] / maxf(level, 0.0001))
	return out


func average_health() -> float:
	return health_sum / months if months > 0 else float(gs.health)


func average_happiness() -> float:
	return happiness_sum / months if months > 0 else float(gs.happiness)


## Rincian skor: {"total", "parts": {id: {"points", "max", "value"}}}. `value` = angka yang ditampilkan
## (kekayaan riil, usia, rata-rata, jumlah impian, atau rincian keputusan bijak).
func breakdown() -> Dictionary:
	var parts := {}
	var real_worth := gs.real_value(gs.net_worth())
	var cfg: Dictionary = data["wealth"]
	var wealth := 0.0
	if real_worth > float(cfg["floor"]):
		wealth = clampf(log(real_worth / float(cfg["floor"])) / log(float(cfg["cap"]) / float(cfg["floor"])), 0.0, 1.0)
	parts["wealth"] = _part(wealth * float(cfg["max"]), cfg, real_worth)
	parts["age"] = _part(age_points(gs.age()), data["age"], gs.age())
	parts["health"] = _part(average_health() * float(data["health"]["max"]) / 100.0, data["health"], average_health())
	parts["happiness"] = _part(average_happiness() * float(data["happiness"]["max"]) / 100.0, data["happiness"],
		average_happiness())
	var dreams := int(gs.stats["dreams_achieved"])
	parts["dreams"] = _part(minf(dreams * float(data["dreams"]["per_dream"]), float(data["dreams"]["max"])), data["dreams"], dreams)
	var wisdom := wisdom_info()
	parts["wisdom"] = _part(float(wisdom["points"]), data["wisdom"], wisdom)
	var total := 0
	for id: String in PARTS:
		total += int(parts[id]["points"])
	return {"total": total, "parts": parts}


func total() -> int:
	return int(breakdown()["total"])


## Poin usia: interpolasi linear antar baris [usia, poin]; sebelum baris pertama 0, sesudah baris
## terakhir poin terakhir.
func age_points(age: int) -> float:
	var rows: Array = data["age"]["points"]
	if age <= int(rows[0][0]):
		return float(rows[0][1])
	for i in range(1, rows.size()):
		if age <= int(rows[i][0]):
			var t := float(age - int(rows[i - 1][0])) / float(int(rows[i][0]) - int(rows[i - 1][0]))
			return lerpf(float(rows[i - 1][1]), float(rows[i][1]), t)
	return float(rows[-1][1])


## Keputusan bijak: menolak penipuan, tidak pernah macet, tidak pernah bangkrut (kas minus).
func wisdom_info() -> Dictionary:
	var cfg: Dictionary = data["wisdom"]
	var avoided := int(gs.stats["scams_avoided"])
	var fallen := int(gs.stats["scams_fallen"])
	var defaults := int(gs.stats["loan_defaults"])
	var negative: bool = int(gs.stats["negative_cash_total"]) > 0 or gs.end_result.get("reason", "") == "bankrupt"
	var scams := clampi(avoided * int(cfg["per_scam_avoided"]) - fallen * int(cfg["per_scam_fallen"]), 0, int(cfg["scam_max"]))
	var points := scams + (int(cfg["no_default"]) if defaults == 0 else 0) + (int(cfg["no_bankrupt"]) if not negative else 0)
	return {"points": points, "scams": scams, "scams_avoided": avoided, "scams_fallen": fallen, "defaults": defaults,
		"negative_cash": negative}


## Grafik layar akhir: penanda pergantian bab [indeks bulan, id bab] dari catatan bab (Life).
func chapter_marks() -> Array:
	var marks: Array = []
	for entry: Dictionary in gs.life.chapter_log:
		var index := int(entry["month"])
		if marks.is_empty() or int(marks[-1][0]) != index:
			marks.append([index, entry["id"]])
	return marks


func _part(points: float, cfg: Dictionary, value: Variant) -> Dictionary:
	return {"points": clampi(roundi(points), 0, int(cfg["max"])), "max": int(cfg["max"]), "value": value}
