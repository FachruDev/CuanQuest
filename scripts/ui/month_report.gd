class_name MonthReport
extends RefCounted
## Mengisi sebuah VBoxContainer dengan baris-baris laporan bulanan.
## Dipakai di popup ringkasan dan di tab Portofolio (seperti komponen yang di-reuse).
## `themed` = gaya terang "Senja Cuan" (variasi tema + warna Palette); false = gaya gelap lama.

const GREEN := Color("#2ecc71")
const RED := Color("#e74c3c")
const MUTED := Color(1, 1, 1, 0.6)
const FONT_SIZE := 24


static func fill(box: VBoxContainer, r: Dictionary, themed := false) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()

	if r.is_empty():
		_add_text(box, "REPORT_EMPTY", _muted(themed), themed)
		return

	_add_header(box, "REPORT_INCOME", themed)
	if r.get("unemployed", false):
		_add_row(box, "REPORT_SALARY_UNEMPLOYED", Fmt.rupiah(0), _red(themed), themed)
	else:
		_add_row(box, "REPORT_SALARY", Fmt.signed_rupiah(r["salary"]), _green(themed), themed)

	_add_header(box, "REPORT_EXPENSES", themed)
	_add_row(box, "REPORT_FOOD", Fmt.signed_rupiah(-r["food_cost"]), _red(themed), themed)
	_add_row(box, "REPORT_HOUSING", Fmt.signed_rupiah(-r["housing_cost"]), _red(themed), themed)

	_add_header(box, "REPORT_INVESTMENT", themed)
	if r.get("interest", 0.0) > 0.0:
		_add_row(box, "REPORT_INTEREST", Fmt.signed_rupiah(r["interest"]), _green(themed), themed)
	_add_row(box, "REPORT_INVEST_CHANGE", Fmt.signed_rupiah(r["invest_change"]),
			_color_of(r["invest_change"], themed), themed)

	var delayed: Array = r.get("delayed", [])
	if not delayed.is_empty():
		_add_header(box, "REPORT_EVENTS", themed)
		for text: String in delayed:
			_add_bullet(box, "- " + TranslationServer.translate(text), themed)

	var news: Array = r.get("news", [])
	if not news.is_empty():
		_add_header(box, "REPORT_NEWS", themed)
		for item: Dictionary in news:
			_add_bullet(box, "- " + news_text(item), themed)

	_add_header(box, "REPORT_WELLBEING", themed)
	_add_row(box, "STAT_HEALTH", "%+d" % r["health_delta"], _color_of(r["health_delta"], themed), themed)
	_add_row(box, "STAT_HAPPINESS", "%+d" % r["happiness_delta"], _color_of(r["happiness_delta"], themed), themed)

	var before: float = r["net_worth_before"]
	var after: float = r["net_worth_after"]
	var change_text := Fmt.signed_rupiah(after - before)
	if before > 0:
		change_text += " (%s)" % Fmt.percent((after - before) / before)
	if themed:
		_add_net_worth_box(box, after, change_text, after - before)
	else:
		box.add_child(HSeparator.new())
		_add_row(box, "LBL_NET_WORTH", Fmt.rupiah(after), Color.WHITE, false)
		_add_row(box, "REPORT_NET_WORTH_CHANGE", change_text, color_of(after - before), false)

	for sale: Dictionary in r.get("forced_sales", []):
		_add_text_raw(box, TranslationServer.translate("REPORT_FORCED_SALE") % [
			TranslationServer.translate(sale["asset_key"]), Fmt.rupiah(sale["proceeds"])], _red(themed), themed)
	for warning: String in r.get("warnings", []):
		_add_text_raw(box, warning, _red(themed), themed)


## Teks berita yang sudah diterjemahkan, mis. "PT Bank Sentosa Tbk mencatat laba melonjak".
static func news_text(item: Dictionary) -> String:
	var text := TranslationServer.translate(item["key"])
	if item["asset_key"] != "":
		text = text % TranslationServer.translate(item["asset_key"])
	return text


static func color_of(value: float) -> Color:
	if value > 0:
		return GREEN
	if value < 0:
		return RED
	return MUTED


static func _color_of(value: float, themed: bool) -> Color:
	if not themed:
		return color_of(value)
	if value > 0:
		return Palette.GAIN
	if value < 0:
		return Palette.LOSS
	return Palette.MUTED


static func _green(themed: bool) -> Color:
	return Palette.GAIN if themed else GREEN


static func _red(themed: bool) -> Color:
	return Palette.LOSS if themed else RED


static func _muted(themed: bool) -> Color:
	return Palette.MUTED if themed else MUTED


static func _add_header(box: VBoxContainer, key: String, themed: bool) -> void:
	var label := Label.new()
	label.text = TranslationServer.translate(key)
	if themed:
		label.theme_type_variation = &"ReportHeaderLabel"
	else:
		label.add_theme_font_size_override("font_size", 20)
		label.modulate = MUTED
	box.add_child(label)


static func _add_row(box: VBoxContainer, key: String, value: String, color: Color, themed: bool) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = TranslationServer.translate(key)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := Label.new()
	value_label.text = value
	if themed:
		name_label.theme_type_variation = &"RowLabel"
		value_label.theme_type_variation = &"RowValueLabel"
		value_label.add_theme_color_override("font_color", color)
	else:
		name_label.add_theme_font_size_override("font_size", FONT_SIZE)
		value_label.modulate = color
		value_label.add_theme_font_size_override("font_size", FONT_SIZE)
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
	change_label.add_theme_color_override("font_color", _color_of(change, true))
	bottom.add_child(change_name)
	bottom.add_child(change_label)
	vbox.add_child(top)
	vbox.add_child(bottom)
	panel.add_child(vbox)
	box.add_child(panel)


static func _add_bullet(box: VBoxContainer, text: String, themed: bool) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if themed:
		label.theme_type_variation = &"SmallMutedLabel"
	else:
		label.add_theme_font_size_override("font_size", 20)
	box.add_child(label)


static func _add_text(box: VBoxContainer, key: String, color: Color, themed: bool) -> void:
	_add_text_raw(box, TranslationServer.translate(key), color, themed)


static func _add_text_raw(box: VBoxContainer, text: String, color: Color, themed: bool) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if themed:
		label.theme_type_variation = &"InfoLabel"
		label.add_theme_color_override("font_color", color)
	else:
		label.modulate = color
		label.add_theme_font_size_override("font_size", 22)
	box.add_child(label)
