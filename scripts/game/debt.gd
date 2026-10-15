class_name Debt
extends GameModule
## Utang & kredit (v1.5c): pinjaman bank, cicilan anuitas bulanan, tunggakan & denda, gagal bayar
## (macet), pelunasan dipercepat, dan skor kredit. Kredit beragunan (kendaraan, langkah 2; properti,
## langkah 3) menarik agunannya saat macet. KPR: bunga tetap beberapa tahun, lalu mengambang mengikuti
## suku bunga BI. Data: data/loans.json.
##
## Analogi web: mirip modul tagihan langganan. Tiap bulan tagihan ditarik otomatis; yang gagal
## ditarik menumpuk menjadi tunggakan, dan setelah beberapa kali gagal seluruh sisa ditagih.

const LOANS_PATH := "res://data/loans.json"
## Event yang dijadwalkan modul ini (bukan undian), lihat scheduled_events(): penagih utang & surat
## peringatan sebulan sebelum macet, dan masa bunga tetap KPR yang akan berakhir (dengan / tanpa
## pilihan take over).
const SCHEDULED_EVENTS := ["debt_collector", "collateral_warning", "kpr_rate_reset", "kpr_rate_reset_basic"]

var data: Dictionary = {}  # isi data/loans.json
## Pinjaman aktif: [{id, product, principal, balance, rate, months_total, months_left, start_month,
## arrears, missed, interest_paid, collateral, fixed_until, float_spread}]. balance = sisa pokok;
## rate = bunga per tahun (dikunci saat cair); arrears = tunggakan + denda (Rupiah); missed = bulan
## menunggak berturut-turut; collateral = agunan {"type": "vehicle", "id": "motor"} /
## {"type": "property", "id": uid} atau {} (tanpa agunan); fixed_until = bulan mulai bunga mengambang
## (-1 = tetap sampai lunas), float_spread = tambahan di atas suku bunga BI saat mengambang.
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
		loan["collateral"] = loan.get("collateral", {})
		loan["fixed_until"] = int(loan.get("fixed_until", -1))
		loan["float_spread"] = float(loan.get("float_spread", 0.0))
		loans.append(loan)
	credit_score = int(d.get("credit_score", credit_score))
	loan_seq = int(d.get("loan_seq", 0))


## Efek event (v1.5c langkah 4). Pinjaman yang dituju & angkanya diambil dari isian event yang sedang
## tampil (event_vars), jadi teks, biaya pilihan, dan efeknya selalu cocok.
func apply_effects(e: Dictionary) -> void:
	if e.has("credit_score"):
		_add_score(int(e["credit_score"]))
	var vars: Dictionary = gs.events.pending_vars
	if e.has("take_loan"):  # tawaran paylater / KTA: "spend" = langsung dibelanjakan, "keep" = masuk kas
		var offer: Dictionary = vars.get("loan_offer", {})
		if not offer.is_empty() and not _open(offer["product"], int(offer["amount"]), int(offer["tenor"])).is_empty():
			gs.stats["offer_loans"] += 1
			if e["take_loan"] == "spend":
				gs.cash -= int(offer["amount"])
	var loan := find(int(vars.get("loan_id", -1)))
	if loan.is_empty():
		return
	if e.get("pay_arrears", false):  # tunggakan sudah dibayar lewat biaya pilihan (cost_var "arrears")
		loan["arrears"] = 0
		loan["missed"] = 0
	if e.get("restructure", false):  # tunggakan digabung ke pokok, tenor diperpanjang
		loan["balance"] += int(loan["arrears"])
		loan["arrears"] = 0
		loan["missed"] = 0
		loan["months_left"] += int(data["restructure_months"])
		loan["months_total"] += int(data["restructure_months"])
		gs.stats["restructures"] += 1
	if e.get("refinance", false):  # take over KPR: biaya sudah dibayar (cost_var "fee")
		var refi: Dictionary = product(loan["product"])["refinance"]
		loan["rate"] = float(vars["refi_rate"])
		loan["fixed_until"] = gs.month + int(refi["fixed_months"]) + 1
		gs.stats["refinances"] += 1
		gs.stats["debt_fees"] += int(vars["fee"])
	if e.get("prepay_part", false):  # pelunasan sebagian: pokok + penalti sudah dibayar (cost_var "prepay")
		loan["balance"] = maxf(0.0, loan["balance"] - int(vars["prepay_amount"]))
		gs.stats["debt_fees"] += int(vars["prepay_penalty"])


# --- Event terjadwal & tawaran kredit (v1.5c langkah 4) ---------------------------------

## Event bulan ini dari kondisi pinjaman (tanpa undian, jadi tidak mengubah urutan acak permainan):
## penagih utang / surat peringatan saat tunggakan tinggal sebulan lagi sebelum macet, dan
## pemberitahuan masa bunga tetap KPR yang berakhir bulan depan.
func scheduled_events() -> Array[Dictionary]:
	var picked: Array[Dictionary] = []
	for id: String in SCHEDULED_EVENTS:
		if not event_loan(id).is_empty():
			var def := gs.events.catalog.find(id)
			if not def.is_empty():
				picked.append(def)
	return picked


func scheduled_event_valid(id: String) -> bool:
	return not event_loan(id).is_empty()


## Pinjaman yang dituju event terjadwal `id` ({} jika tidak ada): yang pertama memenuhi kondisinya.
func event_loan(id: String) -> Dictionary:
	for loan: Dictionary in loans:
		match id:
			"debt_collector", "collateral_warning":
				var secured := not (loan["collateral"] as Dictionary).is_empty()
				if int(loan["missed"]) == int(data["default_after"]) - 1 and secured == (id == "collateral_warning"):
					return loan
			"kpr_rate_reset", "kpr_rate_reset_basic":
				if int(loan["fixed_until"]) == gs.month + 1 and can_refinance(loan) == (id == "kpr_rate_reset"):
					return loan
	return {}


## Take over KPR ke bank lain: pegawai, skor kredit cukup baik, tanpa tunggakan, sisa tenor cukup panjang.
func can_refinance(loan: Dictionary) -> bool:
	var refi: Dictionary = product(loan["product"]).get("refinance", {})
	return not refi.is_empty() and gs.career.is_career() and credit_score >= int(refi["min_score"]) \
		and not has_arrears() and int(loan["months_left"]) >= int(refi["min_months_left"])


## Tawaran kredit lewat event: {product, amount, tenor} yang lolos semua syarat, atau {} jika tidak ada.
## Jumlah tetap (offer.amount, paylater) atau jumlah terbesar sampai offer.salary_mult x gaji (KTA).
## offer.min_score: bank hanya menawarkan "pre-approved" ke nasabah dengan riwayat kredit cukup baik.
func offer(product_id: String) -> Dictionary:
	var prod := product(product_id)
	var cfg: Dictionary = prod.get("offer", {})
	if cfg.is_empty() or credit_score < int(cfg.get("min_score", 0)):
		return {}
	var tenor := int(cfg["tenor"])
	if not tenor in tenor_options(prod):
		return {}
	var amounts: Array[int] = []
	if cfg.has("amount"):
		amounts.append(gs.nominal(cfg["amount"], 100_000))
	else:
		amounts = amount_options(prod)
	var cap := gs.career.salary * float(cfg["salary_mult"]) if cfg.has("salary_mult") else INF
	for i in range(amounts.size() - 1, -1, -1):  # dari jumlah terbesar
		if amounts[i] <= cap and quote(product_id, amounts[i], tenor)["ok"]:
			return {"product": product_id, "amount": amounts[i], "tenor": tenor}
	return {}


## Isian teks event utang: angka yang sama dipakai untuk teks, biaya pilihan (cost_var), dan efek.
func event_vars(id: String) -> Dictionary:
	match id:
		"paylater_offer", "kta_offer":
			var o := offer("paylater" if id == "paylater_offer" else "kta")
			if o.is_empty():
				return {}
			var q := quote(o["product"], o["amount"], o["tenor"])
			return {"loan_offer": o, "amount": o["amount"], "installment": q["payment"], "interest": q["interest"],
				"months": o["tenor"]}
		"debt_collector", "collateral_warning":
			var loan := event_loan(id)
			if loan.is_empty():
				return {}
			var vars := {"loan_id": loan["id"], "loan": product(loan["product"])["short"], "arrears": loan["arrears"]}
			var collateral: Dictionary = loan["collateral"]
			match collateral.get("type", ""):
				"vehicle":
					vars["collateral"] = gs.vehicles.def(collateral["id"]).get("name", "")
				"property":
					vars["collateral"] = gs.properties.def(gs.properties.find(int(collateral["id"])).get("id", "")).get("name", "")
			return vars
		"kpr_rate_reset", "kpr_rate_reset_basic":
			var loan := event_loan(id)
			if loan.is_empty():
				return {}
			var prod := product(loan["product"])
			var balance: float = loan["balance"]
			var months := int(loan["months_left"])
			var rate_to := snappedf(maxf(0.0, gs.market.policy_rate + float(loan["float_spread"])), 0.0001)
			var prepay_amount := roundi(balance * float(prod.get("prepay_part", 0.1)) / 100_000.0) * 100_000
			var prepay_penalty := roundi(prepay_amount * float(prod.get("prepay_penalty", 0.0)) / 1000.0) * 1000
			var vars := {"loan_id": loan["id"], "loan": prod["short"], "rate_from": loan["rate"], "rate_to": rate_to,
				"pay_from": installment(loan), "pay_to": payment_for(balance, rate_to, months),
				"prepay_amount": prepay_amount, "prepay_penalty": prepay_penalty, "prepay": prepay_amount + prepay_penalty,
				"pay_prepaid": payment_for(balance - prepay_amount, rate_to, months)}
			if id == "kpr_rate_reset":
				var refi: Dictionary = prod["refinance"]
				var refi_rate := snappedf(gs.market.policy_rate + float(refi["spread"]) + float(grade()["rate"]), 0.0001)
				var pay_refi := payment_for(balance, refi_rate, months)
				var fee := roundi(balance * float(refi["fee"]) / 1000.0) * 1000
				vars.merge({"refi_rate": refi_rate, "pay_refi": pay_refi, "fee": fee,
					"saving": (int(vars["pay_to"]) - pay_refi) * int(refi["fixed_months"]) - fee})
			return vars
	return {}


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
## Produk berbunga tetap dari pemerintah ("fixed_rate", KPR subsidi) tidak ikut BI maupun skor.
func rate_for(prod: Dictionary) -> float:
	if prod.has("fixed_rate"):
		return float(prod["fixed_rate"])
	return snappedf(gs.market.policy_rate + float(prod["rate_spread"]) + float(grade()["rate"]), 0.0001)


## Bunga mengambang KPR jika suku bunga BI tetap seperti sekarang (0 jika produk tidak mengambang).
func float_rate_for(prod: Dictionary) -> float:
	if not prod.has("float_spread"):
		return 0.0
	return snappedf(gs.market.policy_rate + float(prod["float_spread"]) + float(grade()["rate"]), 0.0001)


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
## KPR: `float_after` cicilan pertama berbunga `rate`, sisanya berbunga `float_rate`.
static func schedule_total(amount: float, rate: float, months: int, float_after: int = -1, float_rate: float = 0.0) -> int:
	var balance := amount
	var total := 0
	for i in months:
		var r := float_rate if float_after >= 0 and i >= float_after else rate
		var payment := payment_for(balance, r, months - i)
		total += payment
		balance = maxf(0.0, balance * (1.0 + r / 12.0) - payment)
	return total


## Sisa pokok setelah `paid` cicilan lancar berbunga `rate` (untuk perkiraan cicilan KPR mengambang).
static func balance_after(amount: float, rate: float, months: int, paid: int) -> float:
	var balance := amount
	for i in mini(paid, months):
		balance = maxf(0.0, balance * (1.0 + rate / 12.0) - payment_for(balance, rate, months - i))
	return balance


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
## hitungannya tetap bisa dilihat walau syarat belum terpenuhi. Kredit kendaraan tidak punya
## pilihan jumlah (jumlahnya = harga - uang muka).
func amount_options(prod: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for amount: float in prod.get("amounts", []):
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
	if prod.has("max_salary"):  # KPR subsidi: gaji maksimal (ikut inflasi)
		var cap := gs.nominal(prod["max_salary"])
		reqs.append({"type": "max_salary", "need": cap, "have": gs.career.salary,
			"met": gs.career.salary > 0 and gs.career.salary <= cap})
	if prod.get("first_home", false):
		reqs.append({"type": "first_home", "met": gs.properties.owned.is_empty()})
	reqs.append({"type": "score", "need": int(data["credit"]["min_score"]), "have": credit_score, "met": score_ok()})
	reqs.append({"type": "arrears", "met": not has_arrears()})
	if prod.has("max_active"):
		reqs.append({"type": "active", "need": int(prod["max_active"]),
			"met": active_count(prod["id"]) < int(prod["max_active"])})
	if prod.has("max_salary_mult"):
		reqs.append({"type": "limit", "need": max_amount(prod), "have": amount, "met": amount <= max_amount(prod)})
	var dsr := dsr_with(payment)
	reqs.append({"type": "dsr", "need": float(data["dsr_limit"]), "have": dsr,
		"met": dsr >= 0.0 and dsr <= float(data["dsr_limit"]) + 0.0001})
	return reqs


## Hitungan pengajuan sebelum dikirim: satu sumber angka untuk popup pinjaman dan take().
## KPR mengambang: total & cicilan setelah masa bunga tetap adalah PERKIRAAN (jika suku bunga BI
## tidak berubah). Syarat rasio cicilan memakai cicilan masa bunga tetap, seperti bank.
## -> {ok, product, amount, tenor, rate, payment, total, interest, dsr, dsr_limit, requirements,
##     fixed_months, float_rate, payment_after}
func quote(product_id: String, amount: int, tenor: int) -> Dictionary:
	var prod := product(product_id)
	var rate := rate_for(prod)
	var payment := payment_for(amount, rate, tenor)
	var fixed_months := int(prod.get("fixed_months", 0))
	var float_rate := float_rate_for(prod)
	var floating := fixed_months > 0 and fixed_months < tenor
	var total := schedule_total(amount, rate, tenor, fixed_months if floating else -1, float_rate)
	var payment_after := payment_for(balance_after(amount, rate, tenor, fixed_months), float_rate,
		tenor - fixed_months) if floating else 0
	var reqs := requirements(prod, amount, payment)
	return {"ok": reqs.all(func(r: Dictionary) -> bool: return r["met"]), "product": prod, "amount": amount,
		"tenor": tenor, "rate": rate, "payment": payment, "total": total, "interest": total - amount,
		"dsr": dsr_with(payment), "dsr_limit": float(data["dsr_limit"]), "requirements": reqs,
		"fixed_months": fixed_months if floating else 0, "float_rate": float_rate if floating else 0.0,
		"payment_after": payment_after}


## Mengajukan pinjaman. Jika semua syarat terpenuhi, uang langsung cair ke kas; cicilan
## pertama ditagih awal bulan depan. `collateral`: agunan untuk kredit beragunan (lihat `loans`);
## pemanggilnya (mis. Vehicles.buy) langsung membayarkan uangnya ke penjual.
func take(product_id: String, amount: int, tenor: int, collateral: Dictionary = {}) -> Dictionary:
	var loan := _open(product_id, amount, tenor, collateral)
	if loan.is_empty():
		return {"ok": false}
	gs.changed.emit()
	gs.state_committed.emit()
	return {"ok": true, "loan": loan}


## Mencairkan pinjaman tanpa memancarkan signal ({} jika ditolak). Dipakai take() dan efek event
## take_loan (yang menyimpan permainan sendiri setelah pilihan event selesai dijalankan).
func _open(product_id: String, amount: int, tenor: int, collateral: Dictionary = {}) -> Dictionary:
	var prod := product(product_id)
	if prod.is_empty() or not tenor in tenor_options(prod):
		return {}
	var q := quote(product_id, amount, tenor)
	if not q["ok"]:
		return {}
	loan_seq += 1
	var fixed_months := int(q["fixed_months"])
	var loan := {"id": loan_seq, "product": product_id, "principal": amount, "balance": float(amount),
		"rate": q["rate"], "months_total": tenor, "months_left": tenor, "start_month": gs.month,
		"arrears": 0, "missed": 0, "interest_paid": 0.0, "collateral": collateral,
		# Cicilan ke-1 jatuh bulan depan, jadi bunga mengambang mulai cicilan ke-(fixed_months + 1).
		"fixed_until": gs.month + fixed_months + 1 if fixed_months > 0 else -1,
		"float_spread": float(prod["float_spread"]) + float(grade()["rate"]) if fixed_months > 0 else 0.0}
	loans.append(loan)
	gs.cash += amount
	gs.stats["loans_taken"] += 1
	gs.stats["borrowed_total"] += amount
	return loan


# --- Pembayaran bulanan, gagal bayar, pelunasan ---------------------------------------

## Awal bulan: tiap pinjaman menagih tunggakan dulu, lalu cicilan bulan ini, dari kas lalu tabungan
## dana darurat. Yang tidak terbayar menjadi tunggakan + denda; menunggak default_after bulan
## berturut-turut = macet. Mengembalikan baris laporan bulanan.
func pay_installments() -> Dictionary:
	var cfg: Dictionary = data["credit"]
	var report := {"loan_paid": 0, "loan_missed": [], "loan_closed": [], "loan_defaults": [],
		"loan_rate_changes": [], "credit_before": credit_score}
	var any_paid := false
	var any_missed := false
	for loan: Dictionary in loans.duplicate():
		var name: String = product(loan["product"])["short"]
		var old_rate: float = loan["rate"]
		if update_rate(loan):
			report["loan_rate_changes"].append({"name": name, "from": old_rate, "to": loan["rate"],
				"payment": installment(loan)})
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


## KPR setelah masa bunga tetap: bunga = suku bunga BI sekarang + float_spread. true jika berubah.
func update_rate(loan: Dictionary) -> bool:
	if int(loan["fixed_until"]) < 0 or gs.month < int(loan["fixed_until"]):
		return false
	var new_rate := snappedf(maxf(0.0, gs.market.policy_rate + float(loan["float_spread"])), 0.0001)
	if is_equal_approx(new_rate, float(loan["rate"])):
		return false
	loan["rate"] = new_rate
	return true


## Rincian pelunasan dipercepat: sisa pokok + tunggakan + penalti.
func payoff_quote(loan: Dictionary) -> Dictionary:
	var balance := ceili(loan["balance"])
	var penalty := roundi(balance * float(product(loan["product"]).get("prepay_penalty", 0.0)) / 1000.0) * 1000
	return {"balance": balance, "arrears": int(loan["arrears"]), "penalty": penalty,
		"total": balance + int(loan["arrears"]) + penalty}


## Melunasi pinjaman sekaligus dari kas. false jika kas tidak cukup, kecuali `force` (properti
## yang terjual: hasil penjualan langsung dipakai melunasi KPR, kekurangannya membuat kas minus).
func pay_off(id: int, force: bool = false) -> bool:
	var loan := find(id)
	if loan.is_empty():
		return false
	var q := payoff_quote(loan)
	if gs.cash < int(q["total"]) and not force:
		return false
	gs.cash -= int(q["total"])
	gs.stats["debt_fees"] += int(q["penalty"])
	gs.stats["loans_paid_off"] += 1
	loans.erase(loan)
	_add_score(int(data["credit"]["payoff"]))
	gs.changed.emit()
	gs.state_committed.emit()
	return true


## Macet. Tanpa agunan: ditagih seluruhnya sekaligus (sisa pokok + tunggakan); kas boleh minus,
## GameState lalu menjual aset secara paksa, dan kas yang tetap minus berujung bangkrut.
## Beragunan: agunan ditarik & dilelang; sisa hasil lelang dikembalikan, kekurangannya dihapus.
func _default(loan: Dictionary) -> Dictionary:
	var total := ceili(loan["balance"]) + int(loan["arrears"])
	loans.erase(loan)
	gs.stats["loan_defaults"] += 1
	_add_score(int(data["credit"]["default"]))
	credit_score = mini(credit_score, int(data["credit"].get("default_max", 100)))  # catatan macet di SLIK
	var result := {"name": product(loan["product"])["short"], "amount": total}
	var collateral: Dictionary = loan.get("collateral", {})
	if collateral.is_empty():
		gs.cash -= total
		return result
	var seized := _seize(collateral)
	gs.cash += maxi(0, int(seized["value"]) - total)
	return result.merged({"seized": seized["name"], "auction": seized["value"]})


## Menarik agunan dari modul pemiliknya. -> {name, value} (nama barang & hasil lelang).
func _seize(collateral: Dictionary) -> Dictionary:
	match collateral.get("type", ""):
		"vehicle":
			return gs.vehicles.seize(collateral["id"])
		"property":
			return gs.properties.seize(int(collateral["id"]))
	return {"name": "", "value": 0}


## Tagihan otomatis: kekurangan kas diambil dari tabungan dana darurat. false jika tetap kurang.
func _collect(amount: int) -> bool:
	gs.budget.draw_emergency(amount)
	if gs.cash < amount:
		return false
	gs.cash -= amount
	return true


func _add_score(delta: int) -> void:
	credit_score = clampi(credit_score + delta, 0, 100)
