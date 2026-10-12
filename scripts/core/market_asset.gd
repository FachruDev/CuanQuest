class_name MarketAsset
extends RefCounted
## Satu instrumen investasi beserta harga & riwayatnya.
## RefCounted = objek biasa (bukan Node), otomatis dibersihkan saat tidak dipakai.

var id: String
var name_key: String
var asset_class: String
var drift: float          # imbal hasil rata-rata per TAHUN (0.10 = 10%)
var volatility: float     # kegoncangan per TAHUN (0.25 = 25%)
var buy_fee: float
var sell_fee: float
var risk: int             # 1 (rendah) .. 5 (ekstrem)

var price: float
var history: Array[float] = []


static func from_def(def: Dictionary) -> MarketAsset:
	var a := MarketAsset.new()
	a.id = def["id"]
	a.name_key = def["name_key"]
	a.asset_class = def["class"]
	a.drift = def["drift"]
	a.volatility = def["volatility"]
	a.buy_fee = def["buy_fee"]
	a.sell_fee = def["sell_fee"]
	a.risk = int(def["risk"])
	a.price = def["start_price"]
	a.history = [a.price]
	return a


## Gerakkan harga satu bulan (Geometric Brownian Motion, lihat GDD bagian 8.3).
func step(rng: RandomNumberGenerator) -> void:
	var mu := drift / 12.0
	var sigma := volatility / sqrt(12.0)
	var z := rng.randfn(0.0, 1.0)
	price = maxf(price * exp(mu - 0.5 * sigma * sigma + sigma * z), 1.0)
	history.append(price)


## Perubahan harga dibanding bulan lalu (0.05 = +5%).
func change_ratio() -> float:
	if history.size() < 2:
		return 0.0
	var prev := history[-2]
	return (price - prev) / prev
