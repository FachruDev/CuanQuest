class_name MonthReport
extends RefCounted
## Mengisi sebuah VBoxContainer dengan baris-baris laporan bulanan.
## Dipakai di popup ringkasan dan di tab Portofolio (seperti komponen yang di-reuse).

const GREEN := Color("#2ecc71")
const RED := Color("#e74c3c")
const MUTED := Color(1, 1, 1, 0.6)
const FONT_SIZE := 24


static func fill(box: VBoxContainer, r: Dictionary) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()

	if r.is_empty():
		_add_text(box, "REPORT_EMPTY", MUTED)
		return

	_add_header(box, "REPORT_INCOME")
	_add_row(box, "REPORT_SALARY", Fmt.signed_rupiah(r["salary"]), GREEN)

	_add_header(box, "REPORT_EXPENSES")
	_add_row(box, "REPORT_FOOD", Fmt.signed_rupiah(-r["food_cost"]), RED)
	_add_row(box, "REPORT_HOUSING", Fmt.signed_rupiah(-r["housing_cost"]), RED)

	_add_header(box, "REPORT_INVESTMENT")
	_add_row(box, "REPORT_INVEST_CHANGE", Fmt.signed_rupiah(r["invest_change"]), color_of(r["invest_change"]))

	_add_header(box, "REPORT_WELLBEING")
	_add_row(box, "STAT_HEALTH", "%+d" % r["health_delta"], color_of(r["health_delta"]))
	_add_row(box, "STAT_HAPPINESS", "%+d" % r["happiness_delta"], color_of(r["happiness_delta"]))

	box.add_child(HSeparator.new())
	var before: float = r["net_worth_before"]
	var after: float = r["net_worth_after"]
	_add_row(box, "LBL_NET_WORTH", Fmt.rupiah(after), Color.WHITE)
	var change_text := Fmt.signed_rupiah(after - before)
	if before > 0:
		change_text += " (%s)" % Fmt.percent((after - before) / before)
	_add_row(box, "REPORT_NET_WORTH_CHANGE", change_text, color_of(after - before))

	if r["cash_after"] < 0:
		_add_text(box, "REPORT_WARN_NEGATIVE_CASH", RED)


static func color_of(value: float) -> Color:
	if value > 0:
		return GREEN
	if value < 0:
		return RED
	return MUTED


static func _add_header(box: VBoxContainer, key: String) -> void:
	var label := Label.new()
	label.text = TranslationServer.translate(key)
	label.add_theme_font_size_override("font_size", 20)
	label.modulate = MUTED
	box.add_child(label)


static func _add_row(box: VBoxContainer, key: String, value: String, color: Color) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = TranslationServer.translate(key)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", FONT_SIZE)
	var value_label := Label.new()
	value_label.text = value
	value_label.modulate = color
	value_label.add_theme_font_size_override("font_size", FONT_SIZE)
	row.add_child(name_label)
	row.add_child(value_label)
	box.add_child(row)


static func _add_text(box: VBoxContainer, key: String, color: Color) -> void:
	var label := Label.new()
	label.text = TranslationServer.translate(key)
	label.modulate = color
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 22)
	box.add_child(label)
