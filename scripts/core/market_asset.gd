class_name MarketAsset
extends RefCounted
## Satu instrumen investasi beserta harga & riwayatnya.
## RefCounted = objek biasa (bukan Node), otomatis dibersihkan saat tidak dipakai.

const INTEREST_CLASSES := ["savings", "deposit"]

var id: String
var name_key: String
var asset_class: String   # savings | deposit | mutual_fund | stock | crypto
var factor: String        # faktor pasar yang diikuti: none | stock | crypto
var drift: float          # imbal hasil rata-rata per TAHUN (0.10 = 10%)
var volatility: float     # kegoncangan per TAHUN (0.25 = 25%)
var beta: float           # seberapa kuat ikut siklus & berita pasar (1.0 = sama dengan pasar)
var rho: float            # korelasi dengan faktor pasar (0 = jalan sendiri, 1 = searah)
var buy_fee: float
var sell_fee: float
var risk: int             # 1 (sangat rendah) .. 5 (sangat tinggi)
var stage: int            # tahap unlock (lihat data/unlocks.json)

# Khusus tabungan & deposito
var rate_spread: float    # bunga = suku bunga acuan + spread
var interest_tax: float
var lock_months: int
var early_penalty: float

var price: float
var history: Array[float] = []


static func from_def(def: Dictionary) -> MarketAsset:
	var a := MarketAsset.new()
	a.id = def["id"]
	a.name_key = def["name_key"]
	a.asset_class = def["class"]
	a.factor = def.get("factor", "none")
	a.drift = def.get("drift", 0.0)
	a.volatility = def.get("volatility", 0.0)
	a.beta = def.get("beta", 0.0)
	a.rho = def.get("rho", 0.0)
	a.buy_fee = def.get("buy_fee", 0.0)
	a.sell_fee = def.get("sell_fee", 0.0)
	a.risk = int(def.get("risk", 1))
	a.stage = int(def.get("stage", 1))
	a.rate_spread = def.get("rate_spread", 0.0)
	a.interest_tax = def.get("interest_tax", 0.0)
	a.lock_months = int(def.get("lock_months", 0))
	a.early_penalty = def.get("early_penalty", 0.0)
	a.price = def["start_price"]
	a.history = [a.price]
	return a


## Tabungan & deposito: harga tetap 1 per unit, nilainya tumbuh lewat bunga.
func is_interest() -> bool:
	return asset_class in INTEREST_CLASSES


## Gerakkan harga satu bulan (Geometric Brownian Motion, lihat GDD bagian 8.3).
## factor_z      : angka acak bersama untuk semua aset satu faktor (sumber korelasi)
## regime_drift  : tambahan drift tahunan dari siklus pasar (bull +, bear -)
## vol_mult      : pengali volatilitas dari siklus pasar
## shock         : guncangan sekali dari berita (0.1 = +10%)
func step(rng: RandomNumberGenerator, factor_z: float, regime_drift: float,
		vol_mult: float, shock: float) -> void:
	if is_interest():
		history.append(price)
		return
	var mu := (drift + beta * regime_drift) / 12.0
	var sigma := volatility * vol_mult / sqrt(12.0)
	var z := rho * factor_z + sqrt(1.0 - rho * rho) * rng.randfn(0.0, 1.0)
	price = maxf(price * exp(mu - 0.5 * sigma * sigma + sigma * z) * (1.0 + shock), 1.0)
	history.append(price)


## Reksa dana memakai NAB 2 desimal (Rp1.051,65); saham & kripto dibulatkan.
func price_text(value: float = price) -> String:
	if asset_class == "mutual_fund":
		return "Rp" + Fmt.number(value, 2)
	return Fmt.rupiah(value)


## Perubahan harga dibanding bulan lalu (0.05 = +5%).
func change_ratio() -> float:
	if history.size() < 2:
		return 0.0
	var prev := history[-2]
	return (price - prev) / prev
