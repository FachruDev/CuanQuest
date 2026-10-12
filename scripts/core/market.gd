class_name Market
extends RefCounted
## Simulasi pasar: menyimpan semua aset dan menggerakkan harganya tiap bulan.
## Memakai RNG ber-seed sendiri agar hasilnya bisa direproduksi (penting untuk save/load).

const WARMUP_MONTHS := 12  # riwayat harga palsu agar grafik tidak kosong di awal

var assets: Dictionary = {}  # id -> MarketAsset
var rng := RandomNumberGenerator.new()


func setup(defs: Array, seed_value: int) -> void:
	rng.seed = seed_value
	assets.clear()
	for def in defs:
		var asset := MarketAsset.from_def(def)
		assets[asset.id] = asset
	for i in WARMUP_MONTHS:
		step()


func step() -> void:
	for asset: MarketAsset in assets.values():
		asset.step(rng)


func get_asset(id: String) -> MarketAsset:
	return assets.get(id)
