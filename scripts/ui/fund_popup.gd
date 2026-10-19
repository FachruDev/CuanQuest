extends ModalPopup
## Popup "Dana Kelolaan" (v2c): ringkasan dana investor, alokasi per keranjang, daftar investor (bisa
## dikembalikan dananya), dan tawaran investor (terima / tolak). Dana investor terpisah dari uang pribadi.
## Analogi web: dashboard admin "akun bersama" — strategi diatur di sini, uangnya tetap milik pemiliknya.

signal accepted(investor_name: String, amount: int)
signal funds_returned(investor_name: String, payout: int)
signal allocation_applied(cost: float)

var _draft: Dictionary = {}  # alokasi yang sedang disusun (belum diterapkan)
var _confirm_uid := -1  # investor yang tombol "Kembalikan Dana"-nya sudah diketuk sekali
var _detail_uid := -1  # investor yang sedang dilihat rinciannya (langkah 3), -1 = tampilan utama


func open() -> void:
	_draft = GameState.fund.allocation.duplicate()
	_confirm_uid = -1
	_detail_uid = -1
	%Title.text = tr("FUND_TITLE")
	%SubtitleHolder.show()
	%Body.show()
	%Body.text = tr("FUND_BODY")
	_build()
	_clear(%Buttons)
	var close_button := UiText.chunky_button(tr("BTN_CLOSE"), &"NeutralButton", &"NeutralButtonLabel", 68.0, 26)
	close_button.pressed.connect(close)
	%Buttons.add_child(close_button)
	%Scroll.scroll_vertical = 0
	show()
	_fit_scroll()


func _build() -> void:
	var fund := GameState.fund
	var detail := fund.find_investor(_detail_uid)
	if not detail.is_empty():
		_build_detail(detail)
		return
	_detail_uid = -1
	%Subtitle.text = tr("FUND_SUBTITLE") % [Fmt.rupiah(fund.value()), Fmt.rupiah(fund.current_nav())]
	_clear(%Rows)
	_add_summary()
	_add_allocation()
	_add_investors()
	_add_offers()
	var fees: Dictionary = fund.data["management_fee"]
	%Rows.add_child(_label(tr("FUND_NOTE") % [UiText.percent_rate(float(fees["conservative"])),
		UiText.percent_rate(float(fees["moderate"])), UiText.percent_rate(float(fees["aggressive"])),
		UiText.percent_rate(float(fund.data["performance_fee"]))], &"SmallMutedLabel"))


func _rebuild() -> void:
	var scroll: int = %Scroll.scroll_vertical
	_build()
	await get_tree().process_frame
	%Scroll.scroll_vertical = scroll


func _add_summary() -> void:
	var fund := GameState.fund
	%Rows.add_child(_label(tr("FUND_SUMMARY"), &"ReportHeaderLabel"))
	var start := float(fund.data["start_nav"])
	_value_row(tr("FUND_VALUE"), Fmt.rupiah(fund.value()))
	_value_row(tr("FUND_NAV"), "%s (%s)" % [Fmt.rupiah(fund.current_nav()), Fmt.percent(fund.current_nav() / start - 1.0)])
	_value_row(tr("FUND_PROFILE"), tr("FUND_PROFILE_FEE") % [UiText.fund_profile(fund.profile_of()),
		UiText.percent_rate(fund.management_fee())])
	_value_row(tr("FUND_REPUTATION"), "%d / 100" % fund.reputation)
	_value_row(tr("FUND_FEE_MONTH"), Fmt.rupiah(fund.record["month_fee"]))
	_value_row(tr("FUND_FEE_TOTAL"), Fmt.rupiah(fund.record["mgmt_fees"]))
	_value_row(tr("FUND_PERF_TOTAL"), Fmt.rupiah(fund.record["perf_fees"]))
	%Rows.add_child(_label(tr("FUND_REPUTATION_HINT"), &"SmallMutedLabel"))
	%Rows.add_child(_label(tr("FUND_ENERGY") % [maxi(fund.energy_cost(), int(fund.data["energy"])),
		int(fund.data["investors_per_energy"])], &"SmallMutedLabel"))


## Satu baris per keranjang: nama, isi & risiko, tombol - / + (kelipatan allocation_step).
func _add_allocation() -> void:
	var fund := GameState.fund
	var step := int(fund.data["allocation_step"])
	%Rows.add_child(_label(tr("FUND_ALLOCATION"), &"ReportHeaderLabel"))
	%Rows.add_child(_label(tr("FUND_ALLOCATION_HINT") % step, &"SmallMutedLabel"))
	var total := 0
	for b: Dictionary in fund.baskets():
		var id: String = b["id"]
		var pct := int(_draft.get(id, 0))
		total += pct
		var available := fund.basket_available(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 0)
		texts.add_child(_label(tr("FUND_BASKET_" + id.to_upper()), &"AssetNameLabel"))
		var detail := tr("FUND_BASKET_RISK") % [basket_assets(id), Fmt.number(fund.basket_risk(id), 1)]
		texts.add_child(_label(detail if available else tr("FUND_BASKET_LOCKED"), &"SmallMutedLabel"))
		row.add_child(texts)
		var minus := _small_button("-", available and pct > 0)
		minus.pressed.connect(_change.bind(id, -step))
		var value := _label("%d%%" % pct, &"AssetValueLabel")
		value.custom_minimum_size.x = 64
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var plus := _small_button("+", available and total_of(_draft) < 100)
		plus.pressed.connect(_change.bind(id, step))
		row.add_child(minus)
		row.add_child(value)
		row.add_child(plus)
		%Rows.add_child(row)
	var draft_profile := fund.profile_of(_draft)
	%Rows.add_child(_label(tr("FUND_ALLOC_TOTAL") % [total, UiText.fund_profile(draft_profile),
		UiText.percent_rate(float(fund.data["management_fee"][draft_profile]))], &"InfoLabel"))
	var breaches := fund.mandate_breaches(_draft)
	if not breaches.is_empty():
		var names: PackedStringArray = []
		for inv: Dictionary in breaches:
			names.append(tr(fund.def(inv["id"])["name"]))
		var warn := _label(tr("FUND_ALLOC_BREACH") % ", ".join(names), &"InfoLabel")
		warn.add_theme_color_override("font_color", Palette.LOSS)
		%Rows.add_child(warn)
	var changed := not _same(_draft, fund.allocation)
	var apply := UiText.chunky_button(tr("FUND_ALLOC_APPLY"), &"PrimaryButton", &"PrimaryButtonLabel", 64.0, 24)
	apply.disabled = total != 100 or not changed
	apply.pressed.connect(func() -> void:
		var result := fund.set_allocation(_draft)
		if result["ok"]:
			_draft = fund.allocation.duplicate()
			allocation_applied.emit(float(result["cost"]))
			_rebuild())
	%Rows.add_child(apply)


func _add_investors() -> void:
	var fund := GameState.fund
	%Rows.add_child(_label(tr("FUND_INVESTORS_TITLE") % fund.investors.size(), &"ReportHeaderLabel"))
	if fund.investors.is_empty():
		%Rows.add_child(_label(tr("FUND_NO_INVESTORS"), &"MutedLabel"))
		return
	for inv: Dictionary in fund.investors:
		var d := fund.def(inv["id"])
		var box := _card()
		box.add_child(_label("%s · %s" % [tr(d["name"]), tr(d["role"])], &"AssetNameLabel"))
		box.add_child(_label(tr("FUND_INV_VALUE") % [Fmt.rupiah(inv["deposited"]), Fmt.rupiah(fund.investor_value(inv)),
			Fmt.percent(fund.investor_return(inv))], &"InfoLabel"))
		var satisfaction := int(inv["satisfaction"])
		var sat := _label(tr("FUND_INV_SAT") % [satisfaction, tr("FUND_SAT_" + Fund.satisfaction_level(satisfaction).to_upper())],
			&"InfoLabel")
		sat.add_theme_color_override("font_color", Palette.GAIN if satisfaction >= 50 else (Palette.INK if satisfaction >= 35
			else Palette.LOSS))
		box.add_child(sat)
		box.add_child(_label(tr("FUND_INV_PERF") % [UiText.percent_short(fund.investor_annual_return(inv)),
			UiText.percent_short(float(d["target"])), UiText.percent_short(fund.investor_drawdown(inv)),
			UiText.percent_short(float(d["drawdown"]))], &"SmallMutedLabel"))
		box.add_child(_label(tr("FUND_INV_META") % [UiText.fund_profile(d["profile"]), Fmt.game_date(int(inv["joined"])),
			Fmt.game_date(int(inv["contract_end"]))], &"SmallMutedLabel"))
		if fund.is_warned(inv):
			var warned := _label(tr("FUND_INV_WARNED"), &"SmallMutedLabel")
			warned.add_theme_color_override("font_color", Palette.LOSS)
			box.add_child(warned)
		if not fund.mandate_ok(inv["id"]):
			var warn := _label(tr("FUND_INV_BREACH"), &"SmallMutedLabel")
			warn.add_theme_color_override("font_color", Palette.LOSS)
			box.add_child(warn)
		var uid := int(inv["uid"])
		var confirm := _confirm_uid == uid
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 10)
		var details := UiText.chunky_button(tr("FUND_DETAIL_BUTTON"), &"NeutralButton", &"NeutralButtonLabel", 52.0, 20)
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.pressed.connect(func() -> void:
			_detail_uid = uid
			_build()
			%Scroll.scroll_vertical = 0)
		buttons.add_child(details)
		var button := UiText.chunky_button(tr("FUND_RETURN_CONFIRM" if confirm else "FUND_RETURN_BUTTON"), &"NeutralButton",
			&"NeutralButtonLabel", 52.0, 20)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			if _confirm_uid != uid:  # ketuk dua kali agar tidak terpencet tanpa sengaja
				_confirm_uid = uid
				_rebuild()
				return
			_confirm_uid = -1
			var result := fund.return_funds(uid)
			if result["ok"]:
				funds_returned.emit(tr(d["name"]), roundi(float(result["payout"])))
			_rebuild())
		buttons.add_child(button)
		box.add_child(buttons)


func _add_offers() -> void:
	var fund := GameState.fund
	%Rows.add_child(_label(tr("FUND_OFFERS_TITLE"), &"ReportHeaderLabel"))
	if fund.board.is_empty():
		%Rows.add_child(_label(tr("FUND_NO_OFFERS"), &"MutedLabel"))
		return
	for offer: Dictionary in fund.board:
		var d := fund.def(offer["id"])
		var box := _card()
		box.add_child(_label("%s · %s" % [tr(d["name"]), tr(d["role"])], &"AssetNameLabel"))
		box.add_child(_label(tr(d["desc"]), &"SmallMutedLabel"))
		box.add_child(_label(tr("FUND_OFFER_TERMS") % [Fmt.rupiah(offer["amount"]), UiText.fund_profile(d["profile"]),
			UiText.percent_short(float(d["target"])), UiText.percent_short(float(d["drawdown"]))], &"InfoLabel"))
		box.add_child(_label(tr("FUND_OFFER_UNTIL") % Fmt.game_date(int(offer["expires"]) - 1), &"SmallMutedLabel"))
		if not fund.mandate_ok(offer["id"]):
			var warn := _label(tr("FUND_OFFER_BREACH") % [UiText.fund_profile(fund.profile_of()), UiText.fund_profile(d["profile"])],
				&"SmallMutedLabel")
			warn.add_theme_color_override("font_color", Palette.LOSS)
			box.add_child(warn)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var uid := int(offer["uid"])
		var accept := UiText.chunky_button(tr("FUND_ACCEPT"), &"PrimaryButton", &"PrimaryButtonLabel", 56.0, 22)
		accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		accept.pressed.connect(func() -> void:
			var result := fund.accept(uid)
			if result["ok"]:
				accepted.emit(tr(d["name"]), roundi(float(result["amount"])))
			_rebuild())
		var decline := UiText.chunky_button(tr("FUND_DECLINE"), &"NeutralButton", &"NeutralButtonLabel", 56.0, 22)
		decline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		decline.pressed.connect(func() -> void:
			fund.decline(uid)
			_rebuild())
		row.add_child(accept)
		row.add_child(decline)
		box.add_child(row)


## Rincian satu investor (langkah 3): grafik nilai investasinya tiap bulan, setoran, untung/rugi, imbal hasil
## vs target, penurunan vs batas, kepuasan, fee kinerja, evaluasi terakhir, dan kontrak.
func _build_detail(inv: Dictionary) -> void:
	var fund := GameState.fund
	var d := fund.def(inv["id"])
	%Subtitle.text = "%s · %s" % [tr(d["name"]), tr(d["role"])]
	_clear(%Rows)
	var back := UiText.chunky_button(tr("FUND_BACK"), &"NeutralButton", &"NeutralButtonLabel", 52.0, 20)
	back.pressed.connect(func() -> void:
		_detail_uid = -1
		_rebuild())
	%Rows.add_child(back)
	%Rows.add_child(_label(tr(d["desc"]), &"SmallMutedLabel"))
	%Rows.add_child(_label(tr("FUND_DETAIL_CHART"), &"ReportHeaderLabel"))
	var chart := PriceChart.new()
	chart.light_style = true
	chart.max_points = Fund.MAX_VALUES
	chart.custom_minimum_size = Vector2(0, 170)
	var series: Array[float] = []
	series.assign(inv.get("values", []))
	chart.set_data(series)
	%Rows.add_child(chart)
	%Rows.add_child(_label(tr("FUND_DETAIL_NUMBERS"), &"ReportHeaderLabel"))
	var value := fund.investor_value(inv)
	var gain := value - float(inv["deposited"])
	_value_row(tr("FUND_DETAIL_DEPOSITED"), Fmt.rupiah(inv["deposited"]))
	_value_row(tr("FUND_DETAIL_VALUE"), Fmt.rupiah(value))
	_value_row(tr("FUND_DETAIL_GAIN"), "%s (%s)" % [Fmt.signed_rupiah(gain), Fmt.percent(fund.investor_return(inv))])
	_value_row(tr("FUND_DETAIL_ANNUAL"), tr("FUND_DETAIL_VS") % [UiText.percent_short(fund.investor_annual_return(inv)),
		UiText.percent_short(float(d["target"]))])
	_value_row(tr("FUND_DETAIL_DRAWDOWN"), tr("FUND_DETAIL_LIMIT") % [UiText.percent_short(fund.investor_drawdown(inv)),
		UiText.percent_short(float(d["drawdown"]))])
	var satisfaction := int(inv["satisfaction"])
	_value_row(tr("FUND_DETAIL_SAT"), "%d/100 · %s" % [satisfaction, tr("FUND_SAT_" + Fund.satisfaction_level(satisfaction).to_upper())])
	_value_row(tr("FUND_DETAIL_MANDATE"), "%s · %s" % [UiText.fund_profile(d["profile"]),
		tr("FUND_MANDATE_OK" if fund.mandate_ok(inv["id"]) else "FUND_MANDATE_BREACH")])
	_value_row(tr("FUND_DETAIL_PERF"), Fmt.rupiah(inv["perf_paid"]))
	_value_row(tr("FUND_DETAIL_LAST_EVAL"), Fmt.percent(inv["last_eval"]) if inv.has("last_eval") else "-")
	_value_row(tr("FUND_DETAIL_JOINED"), Fmt.game_date(int(inv["joined"])))
	_value_row(tr("FUND_DETAIL_CONTRACT"), Fmt.game_date(int(inv["contract_end"])))
	if fund.is_warned(inv):
		var warned := _label(tr("FUND_INV_WARNED"), &"SmallMutedLabel")
		warned.add_theme_color_override("font_color", Palette.LOSS)
		%Rows.add_child(warned)


func _change(id: String, delta: int) -> void:
	var pct := clampi(int(_draft.get(id, 0)) + delta, 0, 100)
	if delta > 0 and total_of(_draft) + delta > 100:
		return
	_draft[id] = pct
	_rebuild()


static func total_of(alloc: Dictionary) -> int:
	var total := 0
	for id: String in alloc:
		total += int(alloc[id])
	return total


## Nama aset dalam keranjang; saham cukup kodenya, mis. "BSNT, MPGN, NUSA, BARA".
static func basket_assets(id: String) -> String:
	var names: PackedStringArray = []
	for asset_id: String in GameState.fund.basket(id)["assets"]:
		var asset := GameState.market.get_asset(asset_id)
		names.append(asset_id if asset.asset_class == "stock" else TranslationServer.translate(asset.name_key))  # saham: kode saja
	return ", ".join(names)


func _same(a: Dictionary, b: Dictionary) -> bool:
	for id: String in GameState.fund.data["baskets"].map(func(x: Dictionary) -> String: return x["id"]):
		if int(a.get(id, 0)) != int(b.get(id, 0)):
			return false
	return true


func _card() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"HomeCard"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	%Rows.add_child(panel)
	return box


func _small_button(text: String, enabled: bool) -> Button:
	var button := UiText.chunky_button(text, &"NeutralButton", &"NeutralButtonLabel", 48.0, 26)
	button.custom_minimum_size.x = 56
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.disabled = not enabled
	return button


func _value_row(name: String, value: String) -> void:
	var row := HBoxContainer.new()
	var name_label := _label(name, &"RowLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value_label := _label(value, &"RowValueLabel")
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	%Rows.add_child(row)


## Area isi di-scroll; tingginya mengikuti isi (dibatasi) setelah label selesai ditata.
func _fit_scroll() -> void:
	await get_tree().process_frame
	%Scroll.custom_minimum_size.y = minf(%Rows.get_combined_minimum_size().y, 560.0)


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1
	return label


func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
