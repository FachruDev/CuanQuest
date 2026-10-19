class_name MonthReport
extends RefCounted
## Mengisi sebuah VBoxContainer dengan baris-baris laporan bulanan (tema "Senja Cuan").
## Dipakai di popup ringkasan dan di tab Portofolio (seperti komponen yang di-reuse).

## Kekayaan awal tahun minimal agar persentase perubahan ditampilkan (laporan tahunan, v1.5d).
const ANNUAL_PERCENT_FROM := 10_000_000.0


## `with_net_worth`: false jika kekayaan bersih sudah ditampilkan di tempat lain
## (popup laporan menampilkannya di bagian sorotan beranimasi).
static func fill(box: VBoxContainer, r: Dictionary, with_net_worth := true) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()

	if r.is_empty():
		_add_text(box, TranslationServer.translate("REPORT_EMPTY"), Palette.MUTED)
		return

	_add_header(box, "REPORT_INCOME")
	var retirement: Dictionary = r.get("retirement", {})
	if not retirement.is_empty():  # bulan pensiun (v2b): JHT & JP sekaligus
		_add_row(box, "REPORT_JHT", Fmt.signed_rupiah(retirement["jht"]), Palette.GAIN)
		if int(retirement["jp_lump"]) > 0:
			_add_row(box, "REPORT_JP_LUMP", Fmt.signed_rupiah(retirement["jp_lump"]), Palette.GAIN)
	if r.get("retired", false):
		_add_row(box, "REPORT_PENSION", Fmt.signed_rupiah(r.get("pension", 0)),
			Palette.GAIN if int(r.get("pension", 0)) > 0 else Palette.MUTED)
	elif r.get("unemployed", false):
		_add_row(box, "REPORT_SALARY_UNEMPLOYED", Fmt.rupiah(0), Palette.LOSS)
	elif r.get("unpaid_leave", false):
		_add_row(box, "REPORT_SALARY_UNPAID", Fmt.rupiah(0), Palette.LOSS)
	else:
		_add_row(box, "REPORT_SALARY", Fmt.signed_rupiah(r["salary"]), Palette.GAIN)
		if int(r.get("income_tax", 0)) > 0:
			_add_row(box, "REPORT_INCOME_TAX", Fmt.signed_rupiah(-r["income_tax"]), Palette.LOSS)
	if int(r.get("rent_income", 0)) > 0:
		_add_row(box, "REPORT_RENT", Fmt.signed_rupiah(r["rent_income"]), Palette.GAIN)
	if int(r.get("fund_fee", 0)) > 0:  # v2c: fee manajemen dana kelolaan masuk kas pribadi
		_add_row(box, "REPORT_FUND_FEE", Fmt.signed_rupiah(r["fund_fee"]), Palette.GAIN)
	if float(r.get("salary_raise", 0.0)) > 0.0:
		_add_row(box, "REPORT_SALARY_RAISE", Fmt.percent(r["salary_raise"]), Palette.GAIN)
	if float(r.get("merit_raise", 0.0)) > 0.0:
		_add_row_text(box, TranslationServer.translate("REPORT_MERIT_RAISE") % int(r["review_performance"]),
			Fmt.percent(r["merit_raise"]), Palette.GAIN)

	_add_career(box, r)
	_add_debt(box, r)

	_add_header(box, "REPORT_EXPENSES")
	_add_row(box, "REPORT_FOOD", Fmt.signed_rupiah(-r["food_cost"]), Palette.LOSS)
	_add_row(box, "REPORT_HOUSING", Fmt.signed_rupiah(-r["housing_cost"]), Palette.LOSS)
	if int(r.get("property_cost", 0)) > 0:
		_add_row(box, "REPORT_PROPERTY", Fmt.signed_rupiah(-r["property_cost"]), Palette.LOSS)
	for note: Dictionary in r.get("property_notes", []):
		_add_text(box, TranslationServer.translate(note["key"]) % TranslationServer.translate(note["name"]), Palette.MUTED)
	for sale: Dictionary in r.get("property_sold", []):
		_add_text(box, TranslationServer.translate("REPORT_PROPERTY_SOLD") % [TranslationServer.translate(sale["name"]),
			Fmt.rupiah(sale["net"]), Fmt.signed_rupiah(sale["gain"])], Palette.GAIN if int(sale["net"]) >= 0 else Palette.LOSS)
		if sale.get("was_home", false):
			_add_text(box, TranslationServer.translate("REPORT_MOVED_OUT"), Palette.MUTED)
	if int(r.get("vehicle_cost", 0)) > 0:
		_add_row(box, "REPORT_VEHICLE", Fmt.signed_rupiah(-r["vehicle_cost"]), Palette.LOSS)
	if int(r.get("vehicle_depreciation", 0)) >= 1000:
		_add_text(box, TranslationServer.translate("REPORT_VEHICLE_DEPRECIATION") % Fmt.rupiah(r["vehicle_depreciation"]),
			Palette.MUTED)
	if int(r.get("loan_paid", 0)) > 0:
		_add_row(box, "REPORT_LOAN_PAID", Fmt.signed_rupiah(-r["loan_paid"]), Palette.LOSS)
	if int(r.get("insurance_premium", 0)) > 0:
		_add_row(box, "REPORT_INSURANCE", Fmt.signed_rupiah(-r["insurance_premium"]), Palette.LOSS)
	if r.has("study_fee"):
		_add_row_text(box, TranslationServer.translate("REPORT_TUITION") % [TranslationServer.translate(r["study_program"]),
			int(r["study_done"]), int(r["study_total"])], Fmt.signed_rupiah(-r["study_fee"]), Palette.LOSS)
	for policy_name: String in r.get("insurance_lapsed", []):
		_add_text(box, TranslationServer.translate("REPORT_INSURANCE_LAPSED") % TranslationServer.translate(policy_name), Palette.LOSS)
	for policy_name: String in r.get("insurance_ended", []):  # asuransi berjangka berakhir (v2b)
		_add_text(box, TranslationServer.translate("REPORT_INSURANCE_ENDED") % TranslationServer.translate(policy_name), Palette.MUTED)
	if int(r.get("lifestyle_cost", 0)) > 0:
		_add_row(box, "REPORT_LIFESTYLE", Fmt.signed_rupiah(-r["lifestyle_cost"]), Palette.LOSS)

	var autodebet: Array = r.get("autodebet", [])
	var skipped: Array = r.get("autodebet_skipped", [])
	if int(r.get("emergency_saved", 0)) > 0 or not autodebet.is_empty() or not skipped.is_empty() \
			or not r.get("dream_saved", []).is_empty():
		_add_header(box, "REPORT_PLAN")
		if int(r.get("emergency_saved", 0)) > 0:
			_add_row_text(box, TranslationServer.translate("REPORT_EMERGENCY"), Fmt.rupiah(r["emergency_saved"]), Palette.GAIN)
		for item: Dictionary in autodebet:
			_add_row_text(box, TranslationServer.translate("REPORT_AUTODEBET") % TranslationServer.translate(item["asset_key"]),
				Fmt.rupiah(item["amount"]), Palette.GAIN)
		for item: Dictionary in r.get("dream_saved", []):
			_add_row_text(box, TranslationServer.translate("REPORT_DREAM_SAVED") % TranslationServer.translate(item["name"]),
				Fmt.rupiah(item["amount"]), Palette.GAIN)
		for asset_key: String in skipped:
			_add_text(box, TranslationServer.translate("REPORT_AUTODEBET_SKIPPED") % TranslationServer.translate(asset_key), Palette.LOSS)

	_add_header(box, "REPORT_INVESTMENT")
	if r.get("interest", 0.0) > 0.0:
		_add_row(box, "REPORT_INTEREST", Fmt.signed_rupiah(r["interest"]), Palette.GAIN)
	_add_row(box, "REPORT_INVEST_CHANGE", Fmt.signed_rupiah(r["invest_change"]), signed_color(r["invest_change"]))

	_add_orders(box, r)
	_add_leverage(box, r)
	_add_costs(box, r)
	_add_fund(box, r)

	if r.has("inflation_month"):
		_add_header(box, "REPORT_ECONOMY")
		_add_row(box, "REPORT_INFLATION", TranslationServer.translate("REPORT_INFLATION_VALUE") % [
			Fmt.percent(r["inflation_month"]), Fmt.percent_plain(r["inflation_year"])], Palette.MUTED)
		if float(r.get("erosion", 0.0)) >= 1000.0:
			_add_row(box, "REPORT_EROSION", Fmt.signed_rupiah(-r["erosion"]), Palette.LOSS)

	var delayed: Array = r.get("delayed", [])
	if not delayed.is_empty():
		_add_header(box, "REPORT_EVENTS")
		for text: String in delayed:
			_add_bullet(box, "- " + UiText.money(TranslationServer.translate(text)))

	var news: Array = r.get("news", [])
	if not news.is_empty():
		_add_header(box, "REPORT_NEWS")
		for item: Dictionary in news:
			_add_bullet(box, "- " + news_text(item))

	_add_rumors(box, r)
	_add_contracts(box, r)

	var targets: Array = r.get("targets", [])
	if not targets.is_empty():
		_add_header(box, "REPORT_TARGETS")
		for target: Dictionary in targets:
			var status := UiText.target_status(target)
			_add_row_text(box, UiText.target_text(target), status["text"], status["color"])

	if int(r.get("turn_trades", 0)) > 0:
		var edge: float = r["trade_edge"]
		_add_header(box, "REPORT_TRADES")
		_add_row(box, "REPORT_TRADE_EDGE", Fmt.signed_rupiah(edge), signed_color(edge))
		_add_text(box, TranslationServer.translate("REPORT_TRADE_META") % [int(r["turn_trades"]), Fmt.rupiah(r["turn_fees"])], Palette.MUTED)
		if edge >= 0.0:
			_add_text(box, TranslationServer.translate("REPORT_TRADE_GOOD"), Palette.MUTED)
		else:
			_add_text(box, TranslationServer.translate("REPORT_TRADE_BAD") % Fmt.rupiah(-edge), Palette.MUTED)

	_add_header(box, "REPORT_WELLBEING")
	_add_row(box, "STAT_HEALTH", "%+d" % r["health_delta"], signed_color(r["health_delta"]))
	if int(r.get("aging_health", 0)) > 0:  # v2b langkah 2
		_add_text(box, TranslationServer.translate("REPORT_AGING_HEALTH") % int(r["aging_health"]), Palette.MUTED)
	if r.has("critical"):  # v2b langkah 3: peringatan setiap bulan selama kondisi kritis
		var exit := int(GameState.life.data["mortality"]["critical_exit"])
		var chance := float(r["critical"]["chance"])
		_add_text(box, TranslationServer.translate("REPORT_CRITICAL") % [UiText.percent_short(chance), exit] if chance > 0.0
			else TranslationServer.translate("REPORT_CRITICAL_YOUNG") % exit, Palette.LOSS)
	_add_row(box, "STAT_HAPPINESS", "%+d" % r["happiness_delta"], signed_color(r["happiness_delta"]))
	if r.has("depressed"):  # v2b langkah 4: status Depresi (bahasa netral, pedoman konten sensitif)
		var mental_cfg: Dictionary = GameState.mental.data
		_add_text(box, TranslationServer.translate("REPORT_DEPRESSED") % [-int(mental_cfg["effects"]["energy"]),
			int(mental_cfg["exit_above"])], Palette.INK)
	elif r.has("low_mood"):
		_add_text(box, TranslationServer.translate("REPORT_LOW_MOOD"), Palette.MUTED)
	if r.get("depression_ended", false):
		_add_text(box, TranslationServer.translate("REPORT_DEPRESSION_ENDED"), Palette.GAIN)

	if with_net_worth:
		var after: float = r["net_worth_after"]
		_add_net_worth_box(box, after, net_worth_change_text(r), after - float(r["net_worth_before"]))

	for sale: Dictionary in r.get("forced_sales", []):
		_add_text(box, TranslationServer.translate("REPORT_FORCED_SALE") % [
			TranslationServer.translate(sale["asset_key"]), Fmt.rupiah(sale["proceeds"])], Palette.LOSS)
	for warning: String in r.get("warnings", []):
		_add_text(box, warning, Palette.LOSS)


## Utang (v1.5c): cicilan menunggak, pinjaman lunas atau macet, dan perubahan skor kredit.
static func _add_debt(box: VBoxContainer, r: Dictionary) -> void:
	var missed: Array = r.get("loan_missed", [])
	var closed: Array = r.get("loan_closed", [])
	var defaults: Array = r.get("loan_defaults", [])
	var rate_changes: Array = r.get("loan_rate_changes", [])
	var score_change := int(r.get("credit_score", 0)) - int(r.get("credit_before", r.get("credit_score", 0)))
	if missed.is_empty() and closed.is_empty() and defaults.is_empty() and rate_changes.is_empty() and score_change == 0:
		return
	_add_header(box, "REPORT_DEBT")
	for item: Dictionary in rate_changes:
		_add_text(box, TranslationServer.translate("REPORT_LOAN_RATE") % [item["name"], Fmt.percent_plain(item["from"]),
			Fmt.percent_plain(item["to"]), Fmt.rupiah(item["payment"])],
			Palette.LOSS if float(item["to"]) > float(item["from"]) else Palette.GAIN)
	for item: Dictionary in missed:
		_add_text(box, TranslationServer.translate("REPORT_LOAN_MISSED") % [item["name"], int(item["months"]),
			int(item["limit"]), Fmt.rupiah(item["arrears"])], Palette.LOSS)
	for item: Dictionary in defaults:
		if item.has("seized"):
			_add_text(box, TranslationServer.translate("REPORT_LOAN_SEIZED") % [item["name"],
				TranslationServer.translate(item["seized"]), Fmt.rupiah(item["auction"]), Fmt.rupiah(item["amount"])], Palette.LOSS)
		else:
			_add_text(box, TranslationServer.translate("REPORT_LOAN_DEFAULT") % [item["name"], Fmt.rupiah(item["amount"])], Palette.LOSS)
	for loan_name: String in closed:
		_add_text(box, TranslationServer.translate("REPORT_LOAN_CLOSED") % loan_name, Palette.GAIN)
	if score_change != 0:
		_add_row(box, "CREDIT_SCORE", "%d (%+d)" % [int(r["credit_score"]), score_change], signed_color(score_change))


## Karier (v1.5b): kinerja bulan ini, penilaian tahunan tanpa kenaikan, kelulusan / cuti kuliah,
## dan hasil lamaran kerja bulan lalu (diterima -> tawaran menunggu keputusan; ditolak).
static func _add_career(box: VBoxContainer, r: Dictionary) -> void:
	var performance := int(r.get("performance", -1))
	var accepted: Array = r.get("applications_accepted", [])
	var rejected: Array = r.get("applications_rejected", [])
	if performance < 0 and accepted.is_empty() and rejected.is_empty() \
			and not r.has("graduated") and not r.has("study_paused"):
		return
	_add_header(box, "REPORT_CAREER")
	if r.has("graduated"):
		_add_text(box, TranslationServer.translate("REPORT_GRADUATED") % [TranslationServer.translate(r["graduated"]),
			r["graduated_education"], int(r["graduated_skill"])], Palette.GAIN)
	if r.has("study_paused"):
		_add_text(box, TranslationServer.translate("REPORT_STUDY_PAUSED") % TranslationServer.translate(r["study_paused"]), Palette.LOSS)
	if performance >= 0:
		var delta := int(r.get("performance_delta", 0))
		_add_row(box, "STAT_PERFORMANCE", TranslationServer.translate("REPORT_PERFORMANCE_VALUE") % [performance,
			TranslationServer.translate(GameState.career.performance_label(performance)), delta], signed_color(delta))
	if r.has("merit_raise") and float(r["merit_raise"]) <= 0.0:
		_add_text(box, TranslationServer.translate("REPORT_NO_MERIT") % int(r["review_performance"]), Palette.MUTED)
	for title: String in accepted:
		_add_text(box, TranslationServer.translate("REPORT_APPLICATION_ACCEPTED") % title, Palette.GAIN)
	for title: String in rejected:
		_add_text(box, TranslationServer.translate("REPORT_APPLICATION_REJECTED") % title, Palette.LOSS)


## Stop loss / take profit yang terpicu bulan ini (v1.5a langkah 4): tanggal, harga, untung/rugi,
## dan harga akhir bulan sebagai pembanding (apakah menjual lebih awal menguntungkan?).
static func _add_orders(box: VBoxContainer, r: Dictionary) -> void:
	var executed: Array = r.get("orders", [])
	if executed.is_empty():
		return
	_add_header(box, "REPORT_ORDERS")
	for sale: Dictionary in executed:
		var asset := GameState.market.get_asset(sale["asset_id"])
		var title := TranslationServer.translate("REPORT_ORDER_" + str(sale["kind"]).to_upper()) % TranslationServer.translate(sale["asset_key"])
		_add_row_text(box, title, Fmt.signed_rupiah(sale["proceeds"]), Palette.GAIN)
		_add_text(box, TranslationServer.translate("REPORT_ORDER_DETAIL") % [int(sale["day"]),
			asset.price_text(sale["price"]), Fmt.signed_rupiah(sale["pnl"]), asset.price_text(sale["end_price"])], Palette.MUTED)


## Posisi leverage bulan ini (v2a langkah 3): untung/rugi berjalan, biaya inap, likuidasi (termasuk
## kekurangan yang ditagih ke kas), dan margin call.
static func _add_leverage(box: VBoxContainer, r: Dictionary) -> void:
	var lev: Dictionary = r.get("leverage", {})
	if lev.is_empty():
		return
	_add_header(box, "REPORT_LEVERAGE")
	_add_row(box, "REPORT_LEV_PNL", Fmt.signed_rupiah(lev["pnl"]), signed_color(lev["pnl"]))
	_add_row(box, "REPORT_LEV_FINANCING", Fmt.signed_rupiah(-float(lev["financing"])), Palette.LOSS)
	for item: Dictionary in lev["liquidated"]:
		_add_text(box, TranslationServer.translate("REPORT_LEV_LIQUIDATED") % [int(item["day"]),
			TranslationServer.translate(item["asset_key"]), LeverageView.side_text(item["side"]), int(item["leverage"]),
			Fmt.signed_rupiah(item["pnl"])], Palette.LOSS)
		if float(item["shortfall"]) > 0.0:
			_add_text(box, TranslationServer.translate("REPORT_LEV_SHORTFALL") % Fmt.rupiah(item["shortfall"]), Palette.LOSS)
	for item: Dictionary in lev["margin_calls"]:
		_add_text(box, TranslationServer.translate("REPORT_LEV_CALL") % [TranslationServer.translate(item["asset_key"]),
			Fmt.rupiah(item["equity"]), Fmt.rupiah(item["margin"])], Palette.LOSS)


## Pajak & biaya bulan ini (v1.5a langkah 2): fee & pajak transaksi (termasuk autodebet dan
## jual paksa), pajak bunga, lalu total termasuk PPh 21.
static func _add_costs(box: VBoxContainer, r: Dictionary) -> void:
	var trade_fee := float(r.get("trade_fee", 0.0))
	var trade_tax := float(r.get("trade_tax", 0.0))
	var interest_tax := float(r.get("interest_tax", 0.0))
	if trade_fee + trade_tax + interest_tax < 1.0:
		return
	_add_header(box, "REPORT_COSTS")
	if trade_fee >= 1.0:
		_add_row(box, "REPORT_TRADE_FEE", Fmt.signed_rupiah(-trade_fee), Palette.LOSS)
	if trade_tax >= 1.0:
		_add_row(box, "REPORT_TRADE_TAX", Fmt.signed_rupiah(-trade_tax), Palette.LOSS)
	if interest_tax >= 1.0:
		_add_row(box, "REPORT_INTEREST_TAX", Fmt.signed_rupiah(-interest_tax), Palette.LOSS)
	var total := trade_fee + trade_tax + interest_tax + float(r.get("income_tax", 0))
	_add_text(box, TranslationServer.translate("REPORT_COSTS_TOTAL") % Fmt.rupiah(total), Palette.MUTED)


## Laporan tahunan (v1.5d langkah 4): pemasukan, pengeluaran per pos, hasil investasi vs inflasi,
## kekayaan bersih (nominal & riil), impian & pencapaian tahun itu.
static func fill_annual(box: VBoxContainer, a: Dictionary) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	if a.get("partial", false):
		_add_text(box, TranslationServer.translate("ANNUAL_PARTIAL") % int(a["months"]), Palette.MUTED)

	_add_header(box, "ANNUAL_INCOME")
	var income: Dictionary = a["income"]
	for row: Array in [["salary", "REPORT_SALARY"], ["pension", "REPORT_PENSION"], ["rent_income", "REPORT_RENT"],
			["fund_fee", "REPORT_FUND_FEE"]]:
		if float(income.get(row[0], 0.0)) != 0.0:
			_add_row(box, row[1], Fmt.rupiah(income[row[0]]), Palette.GAIN)
	if float(a["projects"]) > 0.0:
		_add_row(box, "ANNUAL_PROJECTS", Fmt.rupiah(a["projects"]), Palette.GAIN)
	_add_row(box, "ANNUAL_TOTAL", Fmt.rupiah(a["income_total"]), Palette.INK)

	_add_header(box, "ANNUAL_EXPENSES")
	var expenses: Dictionary = a["expenses"]
	for row: Array in [["income_tax", "REPORT_INCOME_TAX"], ["food_cost", "REPORT_FOOD"], ["housing_cost", "REPORT_HOUSING"],
			["vehicle_cost", "REPORT_VEHICLE"], ["property_cost", "REPORT_PROPERTY"], ["loan_paid", "REPORT_LOAN_PAID"],
			["insurance_premium", "REPORT_INSURANCE"], ["study_fee", "ANNUAL_TUITION"], ["lifestyle_cost", "REPORT_LIFESTYLE"]]:
		if float(expenses.get(row[0], 0.0)) > 0.0:
			_add_row(box, row[1], Fmt.rupiah(expenses[row[0]]), Palette.LOSS)
	if float(a["costs"]) > 0.0:
		_add_row(box, "ANNUAL_TRADE_COSTS", Fmt.rupiah(a["costs"]), Palette.LOSS)
	_add_row(box, "ANNUAL_TOTAL", Fmt.rupiah(a["expense_total"]), Palette.INK)
	var left := float(a["income_total"]) - float(a["expense_total"])
	var rate := left / float(a["income_total"]) if float(a["income_total"]) > 0.0 else 0.0
	_add_text(box, TranslationServer.translate("ANNUAL_LEFT") % [Fmt.signed_rupiah(left), roundi(rate * 100.0)],
		Palette.GAIN if left >= 0.0 else Palette.LOSS)

	_add_header(box, "ANNUAL_INVEST")
	var gain: float = a["invest_gain"]
	_add_row(box, "ANNUAL_INVEST_GAIN", Fmt.signed_rupiah(gain), signed_color(gain))
	var inflation: float = a["inflation"]
	if float(a["invest_avg"]) >= 1_000_000.0:
		var ret: float = a["invest_return"]
		_add_row(box, "ANNUAL_INVEST_RETURN", Fmt.percent(ret), signed_color(ret))
		_add_row(box, "ANNUAL_INFLATION", Fmt.percent(inflation), Palette.MUTED)
		_add_text(box, TranslationServer.translate("ANNUAL_BEAT_INFLATION" if ret > inflation else "ANNUAL_BELOW_INFLATION"),
			Palette.MUTED)
	else:
		_add_row(box, "ANNUAL_INFLATION", Fmt.percent(inflation), Palette.MUTED)
		_add_text(box, TranslationServer.translate("ANNUAL_NO_INVEST"), Palette.MUTED)

	_add_header(box, "ANNUAL_WORTH")
	var start: float = a["worth_start"]
	var end: float = a["worth_end"]
	_add_row(box, "ANNUAL_WORTH_START", Fmt.rupiah(start), Palette.INK)
	_add_row(box, "ANNUAL_WORTH_END", Fmt.rupiah(end), Palette.INK)
	var change_text := Fmt.signed_rupiah(end - start)
	var meaningful := start >= ANNUAL_PERCENT_FROM  # dari modal sangat kecil, persentase tidak bermakna
	if meaningful:
		change_text += " (%s)" % Fmt.percent((end - start) / start)
	_add_row(box, "ANNUAL_WORTH_CHANGE", change_text, signed_color(end - start))
	if meaningful:
		_add_row(box, "ANNUAL_WORTH_REAL", Fmt.percent(a["real_change"]), signed_color(a["real_change"]))

	var dreams: Array = a.get("dreams", [])
	var unlocked: Array = a.get("achievements", [])
	_add_header(box, "ANNUAL_MILESTONES")
	_add_text(box, TranslationServer.translate("ANNUAL_EVENTS") % int(a.get("events", 0)), Palette.MUTED)
	if not dreams.is_empty():
		var names: Array[String] = []
		for name: String in dreams:
			names.append(TranslationServer.translate(name))
		_add_text(box, TranslationServer.translate("ANNUAL_DREAMS") % ", ".join(names), Palette.GAIN)
	if not unlocked.is_empty():
		var names: Array[String] = []
		for id: String in unlocked:
			names.append(TranslationServer.translate("ACH_" + id.to_upper()))
		_add_text(box, TranslationServer.translate("ANNUAL_ACHIEVEMENTS") % ", ".join(names), Palette.GAIN)


## Proyek sampingan yang tenggatnya tiba bulan ini (v1.5d langkah 3): hasil & bayaran, reputasi.
static func _add_contracts(box: VBoxContainer, r: Dictionary) -> void:
	var done: Array = r.get("contracts_done", [])
	if done.is_empty():
		return
	_add_header(box, "REPORT_CONTRACTS")
	for item: Dictionary in done:
		var result: String = item["result"]
		var name := TranslationServer.translate("CONTRACT_" + str(item["id"]).to_upper())
		var label := TranslationServer.translate("REPORT_CONTRACT_ROW") % [name,
			TranslationServer.translate("CONTRACT_RESULT_" + result.to_upper())]
		var pay := int(item["pay"])
		var color := Palette.GAIN if result in ["excellent", "success"] else (Palette.MUTED if result == "revision" else Palette.LOSS)
		_add_row_text(box, label, Fmt.signed_rupiah(pay) if pay > 0 else "-", color)
		if item.has("asset_change") and result != "revision":
			_add_text(box, TranslationServer.translate("REPORT_CONTRACT_TOKEN") % Fmt.percent(item["asset_change"]), Palette.MUTED)
		if item.get("short", false):
			_add_text(box, TranslationServer.translate("REPORT_CONTRACT_SHORT"), Palette.MUTED)
	_add_text(box, TranslationServer.translate("REPORT_CONTRACT_REPUTATION") % [int(r.get("reputation_before", 0)),
		int(r.get("reputation_after", 0))], Palette.MUTED)


## Rumor yang terjawab bulan ini (v1.5d langkah 2): terbukti atau hoaks, gerak harga sejak rumor,
## ketepatan riset pemain, apa yang pemain lakukan, dan pelajarannya.
static func _add_rumors(box: VBoxContainer, r: Dictionary) -> void:
	var rumors: Array = r.get("rumors", [])
	if rumors.is_empty():
		return
	_add_header(box, "REPORT_RUMOR")
	for item: Dictionary in rumors:
		var ticker: String = item["asset"]
		var proven: bool = item["is_true"]
		_add_row_text(box, TranslationServer.translate("REPORT_RUMOR_RESULT") % ticker,
			TranslationServer.translate("RUMOR_PROVEN" if proven else "RUMOR_HOAX"), Palette.INK)
		var change: float = item["change"]
		_add_row_text(box, TranslationServer.translate("REPORT_RUMOR_CHANGE") % ticker, Fmt.percent(change), signed_color(change))
		for research: Dictionary in item["research"]:
			_add_row_text(box, TranslationServer.translate("REPORT_RESEARCH") % [
				TranslationServer.translate("RESEARCH_" + str(research["level"]).to_upper()),
				TranslationServer.translate("RESEARCH_SAYS_TRUE" if research["verdict"] else "RESEARCH_SAYS_FALSE")],
				TranslationServer.translate("RESEARCH_CORRECT" if research["correct"] else "RESEARCH_WRONG"),
				Palette.GAIN if research["correct"] else Palette.LOSS)
		if item["research"].is_empty():
			_add_text(box, TranslationServer.translate("REPORT_RUMOR_NO_RESEARCH"), Palette.MUTED)
		if item["position"] != "none":
			_add_text(box, TranslationServer.translate("REPORT_RUMOR_" + str(item["position"]).to_upper()) % ticker, Palette.MUTED)
		_add_text(box, TranslationServer.translate("RUMOR_LESSON_TRUE" if proven else "RUMOR_LESSON_FALSE"), Palette.MUTED)


## "+Rp1.250.000 (+3,10%)"
static func net_worth_change_text(r: Dictionary) -> String:
	var before: float = r["net_worth_before"]
	var after: float = r["net_worth_after"]
	var text := Fmt.signed_rupiah(after - before)
	if before > 0:
		text += " (%s)" % Fmt.percent((after - before) / before)
	return text


## Teks berita yang sudah diterjemahkan, mis. "PT Bank Sentosa Tbk mencatat laba melonjak".
static func news_text(item: Dictionary) -> String:
	var text := TranslationServer.translate(item["key"])
	if item["asset_key"] != "":
		text = text % TranslationServer.translate(item["asset_key"])
	elif item.has("value"):  # mis. suku bunga acuan yang baru
		text = text % Fmt.percent_plain(item["value"])
	return text


## Warna "Senja Cuan": hijau untung, merah rugi, cokelat redup jika nol.
static func signed_color(value: float) -> Color:
	if value > 0:
		return Palette.GAIN
	if value < 0:
		return Palette.LOSS
	return Palette.MUTED


## Dana kelolaan (v2c): nilai dana investor & NAB bulan ini (terpisah dari investasi pribadi), tawaran baru.
static func _add_fund(box: VBoxContainer, r: Dictionary) -> void:
	var fund: Dictionary = r.get("fund", {})
	if fund.is_empty() or (not fund.has("value") and int(fund.get("offers", 0)) == 0):
		return
	_add_header(box, "REPORT_FUND")
	if fund.has("value"):
		var ret := float(fund["return"])
		_add_row(box, "REPORT_FUND_VALUE", Fmt.rupiah(fund["value"]), Palette.INK)
		_add_row_text(box, TranslationServer.translate("REPORT_FUND_NAV") % Fmt.rupiah(fund["nav"]), Fmt.percent(ret),
			signed_color(ret))
		_add_row(box, "REPORT_FUND_INVESTORS", str(int(fund["investors"])), Palette.INK)
	if int(fund.get("offers", 0)) > 0:
		_add_text(box, TranslationServer.translate("REPORT_FUND_OFFERS") % int(fund["offers"]), Palette.MUTED)


static func _add_header(box: VBoxContainer, key: String) -> void:
	var label := Label.new()
	label.text = TranslationServer.translate(key)
	label.theme_type_variation = &"ReportHeaderLabel"
	box.add_child(label)


static func _add_row(box: VBoxContainer, key: String, value: String, color: Color) -> void:
	_add_row_text(box, TranslationServer.translate(key), value, color)


## Seperti _add_row, tetapi nama barisnya sudah berupa teks jadi (mis. "Autodebet BSNT").
static func _add_row_text(box: VBoxContainer, name: String, value: String, color: Color) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = name
	name_label.theme_type_variation = &"RowLabel"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := Label.new()
	value_label.text = value
	value_label.theme_type_variation = &"RowValueLabel"
	value_label.add_theme_color_override("font_color", color)
	row.add_child(name_label)
	row.add_child(value_label)
	box.add_child(row)


## Kotak hijau (atau merah jika turun) berisi kekayaan bersih & perubahannya.
static func _add_net_worth_box(box: VBoxContainer, after: float, change_text: String, change: float) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"NetWorthPanel" if change >= 0 else &"NetWorthNegPanel"
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	var top := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = TranslationServer.translate("LBL_NET_WORTH")
	name_label.theme_type_variation = &"StatNameLabel"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value_label := Label.new()
	value_label.text = Fmt.rupiah(after)
	value_label.theme_type_variation = &"NetWorthValueLabel"
	top.add_child(name_label)
	top.add_child(value_label)
	var bottom := HBoxContainer.new()
	var change_name := Label.new()
	change_name.text = TranslationServer.translate("REPORT_NET_WORTH_CHANGE")
	change_name.theme_type_variation = &"SmallMutedLabel"
	change_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var change_label := Label.new()
	change_label.text = change_text
	change_label.theme_type_variation = &"RowValueLabel"
	change_label.add_theme_color_override("font_color", signed_color(change))
	bottom.add_child(change_name)
	bottom.add_child(change_label)
	vbox.add_child(top)
	vbox.add_child(bottom)
	panel.add_child(vbox)
	box.add_child(panel)


static func _add_bullet(box: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"SmallMutedLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)


static func _add_text(box: VBoxContainer, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"InfoLabel"
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
