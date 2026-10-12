extends Node
## State global permainan (didaftarkan sebagai Autoload bernama "GameState").
## Analogi web: ini "store" (Redux/Pinia). UI tidak mengubah data langsung,
## melainkan memanggil fungsi di sini, lalu mendengarkan signal `changed` untuk re-render.

signal changed
signal month_advanced(report: Dictionary)

const ASSETS_PATH := "res://data/assets.json"
const ECONOMY_PATH := "res://data/economy.json"

var economy: Dictionary = {}       # isi data/economy.json

var month: int = 0                 # 0 = Jan tahun 1
var cash: int = 0                  # Rupiah disimpan sebagai int (hindari error pembulatan float)
var salary: int = 0
var health: int = 0                # 0..100
var happiness: int = 0             # 0..100
var food_id: String = ""
var housing_id: String = ""
var holdings: Dictionary = {}      # asset_id -> { "units": float, "cost": float }
var market := Market.new()
var net_worth_history: Array[float] = []
var last_report: Dictionary = {}


func _ready() -> void:
	TranslationServer.set_locale("id")
	economy = DataLoader.load_json(ECONOMY_PATH)
	new_game()


func new_game(seed_value: int = -1) -> void:
	if seed_value < 0:
		seed_value = randi()
	month = 0
	cash = int(economy["start_cash"])
	salary = int(economy["salary"])
	health = int(economy["start_health"])
	happiness = int(economy["start_happiness"])
	food_id = economy["default_food"]
	housing_id = economy["default_housing"]
	holdings.clear()
	market = Market.new()
	market.setup(DataLoader.load_json(ASSETS_PATH).get("assets", []), seed_value)
	_start_month()
	net_worth_history = [net_worth()]
	last_report = {}
	changed.emit()


## Tombol "Lanjut": tutup bulan ini (pasar bergerak), lalu buka bulan baru.
func advance_month() -> void:
	var net_worth_before := net_worth()
	var invest_before := investments_value()
	market.step()
	var invest_change := investments_value() - invest_before

	var from_month := month
	month += 1
	var start_report := _start_month()
	net_worth_history.append(net_worth())

	last_report = start_report.merged({
		"from_month": from_month,
		"to_month": month,
		"invest_change": invest_change,
		"net_worth_before": net_worth_before,
		"net_worth_after": net_worth(),
		"cash_after": cash,
	})
	changed.emit()
	month_advanced.emit(last_report)


## Awal bulan: gaji masuk, biaya hidup terpotong, kesehatan & kebahagiaan berubah.
func _start_month() -> Dictionary:
	var food := food_option()
	var housing := housing_option()
	var health_before := health
	var happiness_before := happiness

	cash += salary - int(food["cost"]) - int(housing["cost"])
	health = clampi(health + int(food["health"]) + int(housing["health"]), 0, 100)
	happiness = clampi(happiness + int(food["happiness"]) + int(housing["happiness"]), 0, 100)

	return {
		"salary": salary,
		"food_cost": int(food["cost"]),
		"housing_cost": int(housing["cost"]),
		"health_delta": health - health_before,
		"happiness_delta": happiness - happiness_before,
	}


# --- Biaya hidup --------------------------------------------------------------

func food_option() -> Dictionary:
	return _find_option(economy["food"], food_id)


func housing_option() -> Dictionary:
	return _find_option(economy["housing"], housing_id)


func monthly_expenses() -> int:
	return int(food_option()["cost"]) + int(housing_option()["cost"])


## Pilihan baru berlaku saat awal bulan berikutnya.
func set_food(id: String) -> void:
	food_id = id
	changed.emit()


func set_housing(id: String) -> void:
	housing_id = id
	changed.emit()


func _find_option(options: Array, id: String) -> Dictionary:
	for option: Dictionary in options:
		if option["id"] == id:
			return option
	push_error("Opsi tidak ditemukan: %s" % id)
	return options[0]


# --- Portofolio ---------------------------------------------------------------

func units_of(asset_id: String) -> float:
	return holdings.get(asset_id, {}).get("units", 0.0)


func cost_of(asset_id: String) -> float:
	return holdings.get(asset_id, {}).get("cost", 0.0)


func holding_value(asset_id: String) -> float:
	return units_of(asset_id) * market.get_asset(asset_id).price


func investments_value() -> float:
	var total := 0.0
	for asset_id: String in holdings:
		total += holding_value(asset_id)
	return total


func total_cost() -> float:
	var total := 0.0
	for asset_id: String in holdings:
		total += cost_of(asset_id)
	return total


func net_worth() -> float:
	return cash + investments_value()


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
