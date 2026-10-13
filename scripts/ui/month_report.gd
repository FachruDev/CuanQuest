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
	else:
		_add_row(box, "REPORT_SALARY", Fmt.signed_rupiah(r["salary"]), Palette.GAIN)

	_add_header(box, "REPORT_EXPENSES")
	_add_row(box, "REPORT_FOOD", Fmt.signed_rupiah(-r["food_cost"]), Palette.LOSS)
	_add_row(box, "REPORT_HOUSING", Fmt.signed_rupiah(-r["housing_cost"]), Palette.LOSS)
	if int(r.get("lifestyle_cost", 0)) > 0:
		_add_row(box, "REPORT_LIFESTYLE", Fmt.signed_rupiah(-r["lifestyle_cost"]), Palette.LOSS)

	var autodebet: Array = r.get("autodebet", [])
	var skipped: Array = r.get("autodebet_skipped", [])
	if int(r.get("emergency_saved", 0)) > 0 or not autodebet.is_empty() or not skipped.is_empty():
		_add_header(box, "REPORT_PLAN")
		if int(r.get("emergency_saved", 0)) > 0:
			_add_row_text(box, TranslationServer.translate("REPORT_EMERGENCY"), Fmt.rupiah(r["emergency_saved"]), Palette.GAIN)
		for item: Dictionary in autodebet:
			_add_row_text(box, TranslationServer.translate("REPORT_AUTODEBET") % TranslationServer.translate(item["asset_key"]),
				Fmt.rupiah(item["amount"]), Palette.GAIN)
		for asset_key: String in skipped:
			_add_text(box, TranslationServer.translate("REPORT_AUTODEBET_SKIPPED") % TranslationServer.translate(asset_key), Palette.LOSS)

	_add_header(box, "REPORT_INVESTMENT")
	if r.get("interest", 0.0) > 0.0:
		_add_row(box, "REPORT_INTEREST", Fmt.signed_rupiah(r["interest"]), Palette.GAIN)
	_add_row(box, "REPORT_INVEST_CHANGE", Fmt.signed_rupiah(r["invest_change"]), signed_color(r["invest_change"]))

	var delayed: Array = r.get("delayed", [])
	if not delayed.is_empty():
		_add_header(box, "REPORT_EVENTS")
		for text: String in delayed:
			_add_bullet(box, "- " + TranslationServer.translate(text))

	var news: Array = r.get("news", [])
	if not news.is_empty():
		_add_header(box, "REPORT_NEWS")
		for item: Dictionary in news:
			_add_bullet(box, "- " + news_text(item))

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
