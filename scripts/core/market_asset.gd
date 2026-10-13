class_name MarketAsset
extends RefCounted
## Satu instrumen investasi beserta harga & riwayatnya.
## RefCounted = objek biasa (bukan Node), otomatis dibersihkan saat tidak dipakai.

const INTEREST_CLASSES := ["savings", "deposit"]
const DAYS_IN_MONTH := 30        # kalender game: 30 hari per bulan
const TRADING_DAYS := 21         # hari bursa per bulan (saham, reksa dana, tabungan)
const DAILY_KEEP_MONTHS := 24    # riwayat harian yang disimpan; sisanya cukup penutupan bulanan

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
var history: Array[float] = []       # harga HARIAN, dibatasi DAILY_KEEP_MONTHS bulan terakhir
var month_closes: Array[float] = []  # harga penutupan setiap bulan, sepanjang permainan


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
	a.month_closes = [a.price]
	return a


## Tabungan & deposito: harga tetap 1 per unit, nilainya tumbuh lewat bunga.
func is_interest() -> bool:
	return asset_class in INTEREST_CLASSES


## Jumlah langkah harga per bulan: kripto bergerak setiap hari, lainnya hanya di hari bursa.
func days_per_month() -> int:
	return DAYS_IN_MONTH if asset_class == "crypto" else TRADING_DAYS


## Gerakkan harga satu bulan, HARI DEMI HARI (Geometric Brownian Motion, GDD bagian 8.3).
## `dt` = 1/(12 x langkah per bulan), sehingga drift & volatilitas TAHUNAN tetap sama
## dengan simulasi bulanan v1; bedanya grafik kini punya titik harian.
## factor_z      : angka acak bersama per hari untuk semua aset satu faktor (sumber korelasi)
## regime_drift  : tambahan drift tahunan dari siklus pasar (bull +, bear -)
## vol_mult      : pengali volatilitas dari siklus pasar
## shock         : guncangan sekali dari berita (0.1 = +10%), terjadi pada `shock_day` (1-30)
func step_month(rng: RandomNumberGenerator, factor_z: Array[float], regime_drift: float,
		vol_mult: float, shock: float, shock_day: int) -> void:
	var steps := days_per_month()
	if is_interest():
		for i in steps:
			history.append(price)
		_close_month()
		return
	var dt := 1.0 / (12.0 * steps)
	var sigma := volatility * vol_mult
	var mu := (drift + beta * regime_drift - 0.5 * sigma * sigma) * dt
	var shock_step := floori((shock_day - 1) * steps / float(DAYS_IN_MONTH)) if shock != 0.0 else -1
	for i in steps:
		var z := rho * factor_z[i] + sqrt(1.0 - rho * rho) * rng.randfn(0.0, 1.0)
		price = maxf(price * exp(mu + sigma * sqrt(dt) * z), 1.0)
		if i == shock_step:
			price = maxf(price * (1.0 + shock), 1.0)
		history.append(price)
	_close_month()


## Harga pada tanggal `day` (1-30) di bulan yang baru disimulasikan.
func price_on_day(day: int) -> float:
	var steps := days_per_month()
	var index := ceili(day * steps / float(DAYS_IN_MONTH))  # 1..steps
	return history[history.size() - steps + index - 1]


func _close_month() -> void:
	month_closes.append(price)
	var keep := days_per_month() * DAILY_KEEP_MONTHS
	if history.size() > keep:
		history = history.slice(-keep)


## Reksa dana memakai NAB 2 desimal (Rp1.051,65); saham & kripto dibulatkan.
func price_text(value: float = price) -> String:
	if asset_class == "mutual_fund":
		return "Rp" + Fmt.number(value, 2)
	return Fmt.rupiah(value)


## Perubahan harga dibanding penutupan bulan lalu (0.05 = +5%).
func change_ratio() -> float:
	if month_closes.size() < 2:
		return 0.0
	var prev := month_closes[-2]
	return (price - prev) / prev
