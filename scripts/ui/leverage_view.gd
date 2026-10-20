class_name LeverageView
extends RefCounted
## Teks posisi leverage (v2a langkah 3) yang dipakai detail aset di Pasar dan kartu posisi di Portofolio.


static func side_text(side: int) -> String:
	return TranslationServer.translate("LEV_SIDE_LONG" if side == Leverage.LONG else "LEV_SIDE_SHORT")


## Mengisi `box` dengan ringkasan satu posisi: arah & leverage, ekuitas & untung/rugi, harga, harga
## likuidasi (jarak dari harga sekarang), biaya inap, dan peringatan margin call.
static func fill_position(box: VBoxContainer, p: Dictionary, with_name := false) -> void:
	var lev := GameState.leverage
	var asset := GameState.market.get_asset(p["asset"])
	var equity := lev.equity(p)
	var pnl := equity - float(p["margin"])
	if with_name:
		box.add_child(_label(TranslationServer.translate(asset.name_key), &"AssetNameLabel"))
	box.add_child(_label(_t("LEV_POS_HEAD") % [side_text(p["side"]), int(p["leverage"]), Fmt.rupiah(p["margin"])],
		&"RowValueLabel"))
	var equity_label := _label(_t("LEV_POS_EQUITY") % [Fmt.rupiah(equity), Fmt.signed_rupiah(pnl),
		Fmt.percent(pnl / float(p["margin"]))], &"RowLabel")
	equity_label.add_theme_color_override("font_color", MonthReport.signed_color(pnl))
	box.add_child(equity_label)
	box.add_child(_label(_t("LEV_POS_PRICES") % [asset.price_text(p["entry"]), asset.price_text()], &"SmallMutedLabel"))
	var liq := lev.liquidation_price(p)
	if p["side"] == Leverage.LONG and liq <= 0.0:  # margin menutup seluruh posisi: tidak bisa terlikuidasi
		box.add_child(_label(_t("LEV_POS_SAFE"), &"SmallMutedLabel"))
	else:
		box.add_child(_label(_t("LEV_POS_LIQ") % [asset.price_text(liq), Fmt.percent(liq / asset.price - 1.0)], &"SmallMutedLabel"))
	var financing := lev.monthly_financing(p)
	box.add_child(_label(_t("LEV_POS_FIN") % Fmt.rupiah(financing) if financing >= 1.0 else _t("LEV_POS_NO_FIN"),
		&"SmallMutedLabel"))
	if p.get("call", false):
		var call := _label(_t("LEV_POS_CALL") % Fmt.percent_plain(equity / float(p["margin"])), &"RowLabel")
		call.add_theme_color_override("font_color", Palette.LOSS)
		box.add_child(call)


static func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1
	return label


static func _t(key: String) -> String:
	return TranslationServer.translate(key)
