class_name MonthReport
extends RefCounted
## Mengisi sebuah VBoxContainer dengan baris-baris laporan bulanan (tema "Senja Cuan").
## Dipakai di popup ringkasan dan di tab Portofolio (seperti komponen yang di-reuse).


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
	if r.get("unemployed", false):
		_add_row(box, "REPORT_SALARY_UNEMPLOYED", Fmt.rupiah(0), Palette.LOSS)
	elif r.get("unpaid_leave", false):
		_add_row(box, "REPORT_SALARY_UNPAID", Fmt.rupiah(0), Palette.LOSS)
	else:
		_add_row(box, "REPORT_SALARY", Fmt.signed_rupiah(r["salary"]), Palette.GAIN)
		if int(r.get("income_tax", 0)) > 0:
			_add_row(box, "REPORT_INCOME_TAX", Fmt.signed_rupiah(-r["income_tax"]), Palette.LOSS)
	if int(r.get("rent_income", 0)) > 0:
		_add_row(box, "REPORT_RENT", Fmt.signed_rupiah(r["rent_income"]), Palette.GAIN)
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
	_add_costs(box, r)

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
	_add_row(box, "STAT_HAPPINESS", "%+d" % r["happiness_delta"], signed_color(r["happiness_delta"]))

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
