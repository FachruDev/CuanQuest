class_name BalanceSheet
extends RefCounted
## Kartu neraca (v1.5c langkah 4): aset - utang = kekayaan bersih, ditambah rasio utang terhadap aset.
## Dipakai tab Portofolio dan layar akhir. Angkanya dari GameState.balance_sheet().
##
## Analogi web: komponen presentational yang hanya menerima data lalu merender baris-barisnya.

## Rasio utang terhadap aset: hijau sampai batas pertama, emas sampai batas kedua, merah di atasnya.
const RATIO_OK := 0.3
const RATIO_WARN := 0.5


## Kosongkan `box` lalu isi dengan neraca saat ini.
static func fill(box: VBoxContainer, sheet: Dictionary) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	box.add_child(_label(_t("SHEET_ASSETS"), &"ReportHeaderLabel"))
	for item: Dictionary in sheet["assets"]:
		var value := float(item["value"])
		if is_zero_approx(value) and item["key"] != "LBL_CASH":
			continue  # baris kosong (mis. belum punya kendaraan) disembunyikan
		box.add_child(_row(_t(item["key"]), Fmt.rupiah(value), Palette.LOSS if value < 0 else Color(), false))
	box.add_child(_row(_t("SHEET_TOTAL_ASSETS"), Fmt.rupiah(sheet["total_assets"]), Color(), true))

	box.add_child(_label(_t("SHEET_DEBTS"), &"ReportHeaderLabel"))
	if sheet["debts"].is_empty():
		box.add_child(_label(_t("SHEET_NO_DEBT"), &"SmallMutedLabel"))
	for item: Dictionary in sheet["debts"]:
		box.add_child(_row(_t(item["name"]), Fmt.signed_rupiah(-float(item["value"])), Palette.LOSS, false))
	var total_debt := float(sheet["total_debt"])
	if total_debt > 0.0:
		box.add_child(_row(_t("SHEET_TOTAL_DEBT"), Fmt.signed_rupiah(-total_debt), Palette.LOSS, true))

	var line := Panel.new()
	line.theme_type_variation = &"Divider"
	line.custom_minimum_size = Vector2(0, 2)
	box.add_child(line)
	var worth := float(sheet["net_worth"])
	box.add_child(_row(_t("SHEET_NET_WORTH"), Fmt.rupiah(worth), Palette.GAIN if worth >= 0 else Palette.LOSS, true))

	var assets := float(sheet["total_assets"])
	if total_debt > 0.0 and assets > 0.0:
		var ratio := total_debt / assets
		var color := Palette.GAIN if ratio <= RATIO_OK else (Palette.GOLD if ratio <= RATIO_WARN else Palette.LOSS)
		box.add_child(_ratio_bar(ratio, color))
		var note := _label(_t("SHEET_RATIO") % roundi(ratio * 100.0), &"SmallMutedLabel")
		box.add_child(note)


## Bar porsi utang dari total aset.
static func _ratio_bar(ratio: float, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = minf(ratio, 1.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color("#f4eadb")  # warna dasar bar seperti XpBar
	back.set_corner_radius_all(7)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill_style)
	return bar


static func _row(name: String, value: String, color: Color, strong: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := _label(name, &"AssetNameLabel" if strong else &"RowLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size.x = 1
	row.add_child(name_label)
	var value_label := _label(value, &"AssetValueLabel" if strong else &"RowValueLabel")
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF  # nominal tidak boleh terpotong per huruf
	if color != Color():
		value_label.add_theme_color_override("font_color", color)
	row.add_child(value_label)
	return row


static func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func _t(key: String) -> String:
	return TranslationServer.translate(key)
