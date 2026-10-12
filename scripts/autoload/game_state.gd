extends Node
## State global permainan (didaftarkan sebagai Autoload bernama "GameState").
## Analogi web: ini "store" (Redux/Pinia). UI tidak mengubah data langsung,
## melainkan memanggil fungsi di sini, lalu mendengarkan signal `changed` untuk re-render.

signal changed

const ASSETS_PATH := "res://data/assets.json"
const START_CASH := 10_000_000

var month: int = 0                 # 0 = Jan tahun 1
var cash: int = 0                  # Rupiah disimpan sebagai int (hindari error pembulatan float)
var holdings: Dictionary = {}      # asset_id -> { "units": float, "cost": float }
var market := Market.new()


func _ready() -> void:
	TranslationServer.set_locale("id")
	new_game()


func new_game(seed_value: int = -1) -> void:
	if seed_value < 0:
		seed_value = randi()
	month = 0
	cash = START_CASH
	holdings.clear()
	market = Market.new()
	market.setup(_load_asset_defs(), seed_value)
	changed.emit()


func advance_month() -> void:
	market.step()
	month += 1
	changed.emit()


# --- Portofolio ---------------------------------------------------------------

func units_of(asset_id: String) -> float:
	return holdings.get(asset_id, {}).get("units", 0.0)


func cost_of(asset_id: String) -> float:
	return holdings.get(asset_id, {}).get("cost", 0.0)


func holding_value(asset_id: String) -> float:
	return units_of(asset_id) * market.get_asset(asset_id).price


func net_worth() -> float:
	var total := float(cash)
	for asset_id: String in holdings:
		total += holding_value(asset_id)
	return total


## Beli aset senilai `amount` Rupiah (sudah termasuk fee).
## Mengembalikan { ok, error, units, fee } supaya UI bisa menampilkan pesan.
func buy(asset_id: String, amount: int) -> Dictionary:
	if amount <= 0:
		return {"ok": false, "error": "ERR_AMOUNT_INVALID"}
	if amount > cash:
		return {"ok": false, "error": "ERR_NOT_ENOUGH_CASH"}

	var asset := market.get_asset(asset_id)
	var fee := amount * asset.buy_fee
	var units := (amount - fee) / asset.price

	var h: Dictionary = holdings.get(asset_id, {"units": 0.0, "cost": 0.0})
	h["units"] += units
	h["cost"] += amount
	holdings[asset_id] = h
	cash -= amount

	changed.emit()
	return {"ok": true, "units": units, "fee": fee}


## Jual aset senilai `amount` Rupiah (berdasarkan harga pasar sebelum fee).
func sell(asset_id: String, amount: int) -> Dictionary:
	var held := units_of(asset_id)
	if amount <= 0:
		return {"ok": false, "error": "ERR_AMOUNT_INVALID"}
	if held <= 0.0:
		return {"ok": false, "error": "ERR_NOT_ENOUGH_UNITS"}

	var asset := market.get_asset(asset_id)
	var units := amount / asset.price
	if units > held * 1.0001:
		return {"ok": false, "error": "ERR_NOT_ENOUGH_UNITS"}
	if units >= held * 0.999:
		units = held  # jual semua, hindari sisa "debu" 0.0001 unit

	var gross := units * asset.price
	var fee := gross * asset.sell_fee
	var proceeds := floori(gross - fee)

	var h: Dictionary = holdings[asset_id]
	h["cost"] -= h["cost"] * (units / held)  # kurangi modal secara proporsional
	h["units"] -= units
	if h["units"] <= 0.0:
		holdings.erase(asset_id)
	cash += proceeds

	changed.emit()
	return {"ok": true, "units": units, "fee": fee, "proceeds": proceeds}


# --- Internal -----------------------------------------------------------------

func _load_asset_defs() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ASSETS_PATH))
	if parsed == null:
		push_error("Gagal membaca %s" % ASSETS_PATH)
		return []
	return parsed["assets"]
