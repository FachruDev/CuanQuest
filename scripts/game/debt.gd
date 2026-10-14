class_name Debt
extends GameModule
## Utang & kredit (v1.5c langkah 1): pinjaman bank, cicilan anuitas bulanan, tunggakan & denda,
## gagal bayar (macet), pelunasan dipercepat, dan skor kredit. Data: data/loans.json.
##
## Analogi web: mirip modul tagihan langganan. Tiap bulan tagihan ditarik otomatis; yang gagal
## ditarik menumpuk menjadi tunggakan, dan setelah beberapa kali gagal seluruh sisa ditagih.

const LOANS_PATH := "res://data/loans.json"

var data: Dictionary = {}  # isi data/loans.json
## Pinjaman aktif: [{id, product, principal, balance, rate, months_total, months_left, start_month,
## arrears, missed, interest_paid}]. balance = sisa pokok; rate = bunga per tahun (dikunci saat
## cair); arrears = tunggakan + denda (Rupiah); missed = bulan menunggak berturut-turut.
var loans: Array[Dictionary] = []
var credit_score := 60  # 0-100, lihat loans.json "credit"
var loan_seq := 0  # nomor pinjaman terakhir (id pinjaman berikutnya = loan_seq + 1)


func load_data() -> void:
	data = DataLoader.load_json(LOANS_PATH)


func reset() -> void:
	loans.clear()
	credit_score = int(data["credit"]["start"])
	loan_seq = 0


func save_to(d: Dictionary) -> void:
	d.merge({"loans": loans, "credit_score": credit_score, "loan_seq": loan_seq})


## Save sebelum v1.5c belum punya kunci utang: mulai tanpa utang dengan skor awal.
func load_from(d: Dictionary) -> void:
	reset()
	for saved: Dictionary in d.get("loans", []):
		var loan := saved.duplicate(true)
		for key: String in ["id", "principal", "months_total", "months_left", "start_month", "arrears", "missed"]:
			loan[key] = int(loan[key])
		for key: String in ["balance", "rate", "interest_paid"]:
			loan[key] = float(loan[key])
		loans.append(loan)
	credit_score = int(d.get("credit_score", credit_score))
	loan_seq = int(d.get("loan_seq", 0))


func apply_effects(e: Dictionary) -> void:
	if e.has("credit_score"):
		_add_score(int(e["credit_score"]))


# --- Produk & skor kredit -------------------------------------------------------------

func products() -> Array:
	return data.get("products", [])


func product(id: String) -> Dictionary:
	for prod: Dictionary in products():
		if prod["id"] == id:
			return prod
	return {}


## Tingkat skor kredit {min, key, rate}: tingkat pertama yang batas bawahnya terlampaui.
func grade(score: int = credit_score) -> Dictionary:
	var grades: Array = data["credit"]["grades"]
	for g: Dictionary in grades:
		if score >= int(g["min"]):
			return g
	return grades[-1]


func score_ok() -> bool:
	return credit_score >= int(data["credit"]["min_score"])


## Bunga per tahun jika mengajukan sekarang: suku bunga BI + spread produk + penyesuaian skor.
func rate_for(prod: Dictionary) -> float:
	return snappedf(gs.market.policy_rate + float(prod["rate_spread"]) + float(grade()["rate"]), 0.0001)


# --- Hitungan cicilan (anuitas) -------------------------------------------------------

## Cicilan anuitas per bulan untuk sisa pokok `balance`, bunga per tahun `rate`, sisa `months` bulan.
static func annuity(balance: float, rate: float, months: int) -> float:
	var r := rate / 12.0
	if months <= 1:
		return balance * (1.0 + r)
	if r <= 0.0:
		return balance / months
	return balance * r / (1.0 - pow(1.0 + r, -months))


## Cicilan yang ditagih bulan ini: dibulatkan ke atas per Rp1.000, bulan terakhir pas sisa utang.
## Dihitung ulang tiap bulan dari sisa pokok, jadi tetap benar jika bunga berubah (KPR mengambang).
static func payment_for(balance: float, rate: float, months: int) -> int:
	if months <= 0 or balance <= 0.5:
		return 0
	if months == 1:
		return ceili(balance * (1.0 + rate / 12.0))
	return ceili(annuity(balance, rate, months) / 1000.0) * 1000


## Total yang dibayar jika semua cicilan lancar (hitungan sama persis dengan pay_installments).
static func schedule_total(amount: float, rate: float, months: int) -> int:
	var balance := amount
	var total := 0
	for left in range(months, 0, -1):
		var payment := payment_for(balance, rate, left)
		total += payment
		balance = maxf(0.0, balance * (1.0 + rate / 12.0) - payment)
	return total


func installment(loan: Dictionary) -> int:
	return payment_for(loan["balance"], loan["rate"], loan["months_left"])


## Total cicilan terjadwal sebulan (tanpa tunggakan): rencana gaji, sisa modal, kebebasan finansial.
func installments_total() -> int:
	var total := 0
	for loan: Dictionary in loans:
		total += installment(loan)
	return total


## Sisa utang = pokok + tunggakan (dikurangkan dari kekayaan bersih).
func outstanding() -> float:
	var total := 0.0
	for loan: Dictionary in loans:
		total += float(loan["balance"]) + int(loan["arrears"])
	return total


func has_arrears() -> bool:
	return loans.any(func(loan: Dictionary) -> bool: return int(loan["arrears"]) > 0)


func find(id: int) -> Dictionary:
	for loan: Dictionary in loans:
		if int(loan["id"]) == id:
			return loan
	return {}


func active_count(product_id: String) -> int:
	return loans.filter(func(loan: Dictionary) -> bool: return loan["product"] == product_id).size()


## Kolektibilitas OJK dari bulan menunggak: 1 Lancar, 2 Dalam Perhatian Khusus, 3 Kurang Lancar,
## 4 Diragukan, 5 Macet.
static func collectibility(missed: int) -> int:
	if missed <= 0:
		return 1
	if missed <= 2:
		return 2
	if missed == 3:
		return 3
	return 4 if missed <= 5 else 5


# --- Pengajuan ------------------------------------------------------------------------

## Plafon: max_salary_mult x gaji bruto.
func max_amount(prod: Dictionary) -> int:
	return roundi(gs.career.salary * float(prod.get("max_salary_mult", 0)))


## Pilihan jumlah pinjaman (harga hari ini) sampai plafon. Pilihan terkecil selalu ada agar
## hitungannya tetap bisa dilihat walau syarat belum terpenuhi.
func amount_options(prod: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for amount: float in prod["amounts"]:
		var value := gs.nominal(amount, 1_000_000)
		if value <= max_amount(prod) or result.is_empty():
			result.append(value)
	return result


## Pilihan tenor (bulan) yang lunas sebelum usia pensiun.
func tenor_options(prod: Dictionary) -> Array[int]:
	var months_left := (int(gs.economy["end"]["retirement_age"]) - gs.age()) * 12
	var result: Array[int] = []
	for tenor: float in prod["tenors"]:
		if int(tenor) <= months_left or result.is_empty():
			result.append(int(tenor))
	return result


## Rasio cicilan terhadap gaji bruto (DSR) jika ditambah cicilan baru `payment`; -1 jika tanpa gaji.
func dsr_with(payment: int = 0) -> float:
	if gs.career.salary <= 0:
		return -1.0
	return float(installments_total() + payment) / gs.career.salary


## Syarat pengajuan (ditampilkan ✓/✗ seperti lowongan kerja): [{type, met, need, have, ...}].
func requirements(prod: Dictionary, amount: int, payment: int) -> Array[Dictionary]:
	var reqs: Array[Dictionary] = []
	var needs_career: bool = prod.get("requires", "employed") == "career"
	var working := gs.career.is_career() if needs_career else gs.career.is_employed()
	var months := gs.career.months_at_company() if working else 0
	var need_months := int(prod.get("min_months", 0))
	reqs.append({"type": "job", "career": needs_career, "need": need_months, "have": months,
		"met": working and months >= need_months})
	reqs.append({"type": "score", "need": int(data["credit"]["min_score"]), "have": credit_score, "met": score_ok()})
	reqs.append({"type": "arrears", "met": not has_arrears()})
	if prod.has("max_active"):
		reqs.append({"type": "active", "need": int(prod["max_active"]),
			"met": active_count(prod["id"]) < int(prod["max_active"])})
	reqs.append({"type": "limit", "need": max_amount(prod), "have": amount, "met": amount <= max_amount(prod)})
	var dsr := dsr_with(payment)
	reqs.append({"type": "dsr", "need": float(data["dsr_limit"]), "have": dsr,
		"met": dsr >= 0.0 and dsr <= float(data["dsr_limit"]) + 0.0001})
	return reqs


## Hitungan pengajuan sebelum dikirim: satu sumber angka untuk popup pinjaman dan take().
## -> {ok, product, amount, tenor, rate, payment, total, interest, dsr, dsr_limit, requirements}
func quote(product_id: String, amount: int, tenor: int) -> Dictionary:
	var prod := product(product_id)
	var rate := rate_for(prod)
	var payment := payment_for(amount, rate, tenor)
	var total := schedule_total(amount, rate, tenor)
	var reqs := requirements(prod, amount, payment)
	return {"ok": reqs.all(func(r: Dictionary) -> bool: return r["met"]), "product": prod, "amount": amount,
		"tenor": tenor, "rate": rate, "payment": payment, "total": total, "interest": total - amount,
		"dsr": dsr_with(payment), "dsr_limit": float(data["dsr_limit"]), "requirements": reqs}


## Mengajukan pinjaman. Jika semua syarat terpenuhi, uang langsung cair ke kas; cicilan
## pertama ditagih awal bulan depan.
func take(product_id: String, amount: int, tenor: int) -> Dictionary:
	var prod := product(product_id)
	if prod.is_empty() or not tenor in tenor_options(prod):
		return {"ok": false}
	var q := quote(product_id, amount, tenor)
	if not q["ok"]:
		return {"ok": false}
	loan_seq += 1
	var loan := {"id": loan_seq, "product": product_id, "principal": amount, "balance": float(amount),
		"rate": q["rate"], "months_total": tenor, "months_left": tenor, "start_month": gs.month,
		"arrears": 0, "missed": 0, "interest_paid": 0.0}
	loans.append(loan)
	gs.cash += amount
	gs.stats["loans_taken"] += 1
	gs.stats["borrowed_total"] += amount
	gs.changed.emit()
	gs.state_committed.emit()
	return {"ok": true, "loan": loan}


# --- Pembayaran bulanan, gagal bayar, pelunasan ---------------------------------------

## Awal bulan: tiap pinjaman menagih tunggakan dulu, lalu cicilan bulan ini, dari kas lalu tabungan
## dana darurat. Yang tidak terbayar menjadi tunggakan + denda; menunggak default_after bulan
## berturut-turut = macet. Mengembalikan baris laporan bulanan.
func pay_installments() -> Dictionary:
	var cfg: Dictionary = data["credit"]
	var report := {"loan_paid": 0, "loan_missed": [], "loan_closed": [], "loan_defaults": [],
		"credit_before": credit_score}
	var any_paid := false
	var any_missed := false
	for loan: Dictionary in loans.duplicate():
		var name: String = product(loan["product"])["short"]
		if int(loan["arrears"]) > 0 and _collect(int(loan["arrears"])):
			report["loan_paid"] += int(loan["arrears"])
			loan["arrears"] = 0
			loan["missed"] = 0
		var payment := installment(loan)
		if payment > 0:
			var interest: float = loan["balance"] * float(loan["rate"]) / 12.0
			if int(loan["arrears"]) == 0 and _collect(payment):
				report["loan_paid"] += payment
				loan["interest_paid"] += interest
				gs.stats["debt_interest"] += interest
				any_paid = true
			else:
				loan["arrears"] += payment  # cicilan yang tidak terbayar pindah ke tunggakan
			loan["balance"] = maxf(0.0, loan["balance"] + interest - payment)
			loan["months_left"] -= 1
		if int(loan["arrears"]) > 0:
			var fee := roundi(loan["arrears"] * float(data["late_fee"]) / 1000.0) * 1000
			loan["arrears"] += fee
			loan["missed"] += 1
			gs.stats["debt_fees"] += fee
			gs.stats["missed_payments"] += 1
			_add_score(int(cfg["missed"]))
			any_missed = true
			if int(loan["missed"]) >= int(data["default_after"]):
				report["loan_defaults"].append(_default(loan))
			else:
				report["loan_missed"].append({"name": name, "months": loan["missed"],
					"limit": int(data["default_after"]), "arrears": loan["arrears"]})
		elif loan["balance"] <= 0.5 or int(loan["months_left"]) <= 0:
			loans.erase(loan)
			gs.stats["loans_paid_off"] += 1
			report["loan_closed"].append(name)
	if any_paid and not any_missed:
		_add_score(int(cfg["on_time"]))
	elif not any_missed and credit_score < int(cfg["recover_below"]):
		_add_score(int(cfg["recover"]))  # tanpa tunggakan, riwayat buruk perlahan memudar
	report["credit_score"] = credit_score
	return report


## Rincian pelunasan dipercepat: sisa pokok + tunggakan + penalti.
func payoff_quote(loan: Dictionary) -> Dictionary:
	var balance := ceili(loan["balance"])
	var penalty := roundi(balance * float(product(loan["product"]).get("prepay_penalty", 0.0)) / 1000.0) * 1000
	return {"balance": balance, "arrears": int(loan["arrears"]), "penalty": penalty,
		"total": balance + int(loan["arrears"]) + penalty}


## Melunasi pinjaman sekaligus dari kas. false jika kas tidak cukup.
func pay_off(id: int) -> bool:
	var loan := find(id)
	if loan.is_empty():
		return false
	var q := payoff_quote(loan)
	if gs.cash < int(q["total"]):
		return false
	gs.cash -= int(q["total"])
	gs.stats["debt_fees"] += int(q["penalty"])
	gs.stats["loans_paid_off"] += 1
	loans.erase(loan)
	_add_score(int(data["credit"]["payoff"]))
	gs.changed.emit()
	gs.state_committed.emit()
	return true


## Macet: pinjaman tanpa agunan ditagih seluruhnya sekaligus (sisa pokok + tunggakan). Kas boleh
## minus; GameState lalu menjual aset secara paksa, dan kas yang tetap minus berujung bangkrut.
func _default(loan: Dictionary) -> Dictionary:
	var total := ceili(loan["balance"]) + int(loan["arrears"])
	gs.cash -= total
	loans.erase(loan)
	gs.stats["loan_defaults"] += 1
	_add_score(int(data["credit"]["default"]))
	return {"name": product(loan["product"])["short"], "amount": total}


## Tagihan otomatis: kekurangan kas diambil dari tabungan dana darurat. false jika tetap kurang.
func _collect(amount: int) -> bool:
	gs.budget.draw_emergency(amount)
	if gs.cash < amount:
		return false
	gs.cash -= amount
	return true


func _add_score(delta: int) -> void:
	credit_score = clampi(credit_score + delta, 0, 100)
