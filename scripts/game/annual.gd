class_name Annual
extends GameModule
## Laporan tahunan (v1.5d langkah 4). Setiap laporan bulanan dijumlahkan ke catatan tahun berjalan;
## setiap Januari catatan itu ditutup menjadi laporan tahun lalu: pemasukan, pengeluaran per pos,
## hasil investasi dibanding inflasi, perubahan kekayaan bersih (nominal & riil), impian yang
## terwujud, dan pencapaian yang terbuka tahun itu. Hanya membaca laporan, tidak mengubah permainan.
##
## Analogi web: seperti job agregasi akhir tahun ("year in review") di atas log transaksi bulanan.

const MAX_REPORTS := 40
## Kunci laporan bulanan yang dijumlahkan: pemasukan & pengeluaran per pos.
const INCOME_KEYS := ["salary", "rent_income"]
const EXPENSE_KEYS := ["income_tax", "food_cost", "housing_cost", "vehicle_cost", "property_cost", "loan_paid",
	"insurance_premium", "study_fee", "lifestyle_cost"]
const COST_KEYS := ["trade_fee", "trade_tax", "interest_tax"]

var acc: Dictionary = {}  # catatan tahun berjalan
var reports: Array[Dictionary] = []  # laporan tahun-tahun yang sudah lewat (terbaru di belakang)


func reset() -> void:
	acc = {}
	reports.clear()


func save_to(d: Dictionary) -> void:
	d.merge({"year_acc": acc, "annual_reports": reports})


## Save sebelum v1.5d langkah 4: catatan tahun ini dimulai saat dimuat (laporan pertama sebagian).
func load_from(d: Dictionary) -> void:
	reset()
	if d.has("year_acc") and not d["year_acc"].is_empty():
		acc = d["year_acc"].duplicate(true)
	for r: Dictionary in d.get("annual_reports", []):
		reports.append(r)


## Mulai catatan tahun baru dari kondisi sekarang (awal permainan atau setelah laporan ditutup).
func begin_year(partial := false) -> void:
	acc = {"start_month": gs.month, "worth_start": gs.net_worth(), "level_start": gs.price_level(),
		"income": {}, "expenses": {}, "costs": 0.0, "projects": 0.0, "invest_gain": 0.0, "invest_sum": 0.0,
		"months": 0, "events": int(gs.stats["events"]), "achievements": [], "partial": partial}


## Tambahkan satu laporan bulanan ke catatan tahun berjalan.
func add_month(report: Dictionary) -> void:
	if acc.is_empty():
		begin_year(true)  # save lama: catatan dimulai saat dimuat
	for key: String in INCOME_KEYS:
		_add(acc["income"], key, float(report.get(key, 0)))
	for c: Dictionary in report.get("contracts_done", []):
		acc["projects"] = float(acc["projects"]) + float(c["pay"])
	for key: String in EXPENSE_KEYS:
		_add(acc["expenses"], key, float(report.get(key, 0)))
	for key: String in COST_KEYS:
		acc["costs"] = float(acc["costs"]) + float(report.get(key, 0))
	acc["invest_gain"] = float(acc["invest_gain"]) + float(report.get("invest_change", 0.0))
	acc["invest_sum"] = float(acc["invest_sum"]) + gs.portfolio.investments_value()
	acc["months"] = int(acc["months"]) + 1


func note_achievements(ids: Array[String]) -> void:
	if acc.is_empty():
		begin_year(true)
	var list: Array = acc["achievements"]
	list.append_array(ids)


## Tutup tahun yang baru lewat menjadi laporan; catatan tahun baru dimulai. `year` = tahun ke-berapa.
func close_year(year: int) -> Dictionary:
	if acc.is_empty():
		begin_year(true)
	var level := gs.price_level()
	var worth := gs.net_worth()
	var worth_start := float(acc["worth_start"])
	var level_start := float(acc["level_start"])
	var months := maxi(int(acc["months"]), 1)
	var avg_invest := float(acc["invest_sum"]) / months
	var income_total := float(acc["projects"])
	for key: String in acc["income"]:
		income_total += float(acc["income"][key])
	var expense_total := float(acc["costs"])
	for key: String in acc["expenses"]:
		expense_total += float(acc["expenses"][key])
	var dreams: Array = []
	for entry: Dictionary in gs.dreams.entries:
		if entry["status"] == "achieved" and int(entry["achieved_month"]) >= int(acc["start_month"]):
			dreams.append(gs.dreams.find_def(entry["id"]).get("name", ""))
	var report := {
		"year": year, "partial": acc["partial"], "months": int(acc["months"]),
		"income": acc["income"].duplicate(), "projects": float(acc["projects"]), "income_total": income_total,
		"expenses": acc["expenses"].duplicate(), "costs": float(acc["costs"]), "expense_total": expense_total,
		"invest_gain": float(acc["invest_gain"]), "invest_avg": avg_invest,
		"invest_return": float(acc["invest_gain"]) / avg_invest if avg_invest >= 1_000_000.0 else 0.0,
		"inflation": level / level_start - 1.0,
		"worth_start": worth_start, "worth_end": worth,
		"real_change": (worth / level) / (worth_start / level_start) - 1.0 if worth_start > 0.0 else 0.0,
		"events": int(gs.stats["events"]) - int(acc["events"]),
		"dreams": dreams, "achievements": acc["achievements"].duplicate(),
	}
	reports.append(report)
	if reports.size() > MAX_REPORTS:
		reports.pop_front()
	begin_year()
	return report


func latest() -> Dictionary:
	return reports[-1] if not reports.is_empty() else {}


static func _add(target: Dictionary, key: String, amount: float) -> void:
	if amount != 0.0:
		target[key] = float(target.get(key, 0.0)) + amount
