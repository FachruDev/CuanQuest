class_name Fmt
extends RefCounted
## Helper format angka gaya Indonesia: Rp1.234.567 dan +2,35%.


static func rupiah(value: float) -> String:
	var n := roundi(value)
	return ("-" if n < 0 else "") + "Rp" + _group_thousands(absi(n))


static func number(value: float, decimals: int = 2) -> String:
	var parts := ("%.*f" % [decimals, absf(value)]).split(".")  # "1234.50" -> ["1234", "50"]
	var text := _group_thousands(parts[0].to_int())
	if parts.size() > 1:
		text += "," + parts[1]
	return ("-" if value < 0 else "") + text


static func percent(ratio: float) -> String:
	return ("%+.2f%%" % (ratio * 100.0)).replace(".", ",")


## month_index 0 = Jan tahun 1.
static func game_date(month_index: int) -> String:
	var month_name := TranslationServer.translate("MONTH_%d" % (month_index % 12 + 1))
	var year := floori(month_index / 12.0) + 1
	return TranslationServer.translate("FMT_DATE") % [month_name, year]


static func _group_thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out
