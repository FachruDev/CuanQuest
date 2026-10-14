class_name Fmt
extends RefCounted
## Helper format angka gaya Indonesia: Rp1.234.567 dan +2,35%.


## Diatur oleh Settings: true = format ringkas (Rp1,25 jt / Rp3,40 M).
static var compact := false


static func rupiah(value: float) -> String:
	var n := roundi(value)
	var minus := "-" if n < 0 else ""
	if compact and absi(n) >= 1_000_000:
		return minus + "Rp" + _short(absi(n))
	return minus + "Rp" + _group_thousands(absi(n))


## Selalu ringkas, apa pun pengaturan: Rp12,50 jt (untuk ruang sempit seperti kartu simpanan).
static func rupiah_short(value: float) -> String:
	var n := roundi(value)
	if absi(n) < 1_000_000:
		return rupiah(value)
	return ("-" if n < 0 else "") + "Rp" + _short(absi(n))


## 1.250.000 -> "1,25 jt" | 3.400.000.000 -> "3,40 M" (miliar) | ... "T" (triliun)
static func _short(n: int) -> String:
	if n >= 1_000_000_000_000:
		return number(n / 1e12) + " T"
	if n >= 1_000_000_000:
		return number(n / 1e9) + " M"
	return number(n / 1e6) + " jt"


## Gaya teks cerita: Rp3,1 juta / Rp800 ribu / Rp2 miliar (maks. 2 desimal, nol di belakang dibuang).
static func rupiah_words(value: float) -> String:
	var n := absi(roundi(value))
	var minus := "-" if roundi(value) < 0 else ""
	for unit: Array in [[1_000_000_000, " miliar"], [1_000_000, " juta"], [1_000, " ribu"]]:
		if n >= unit[0]:
			var text := number(n / float(unit[0]), 2)
			if text.contains(","):
				text = text.rstrip("0").rstrip(",")
			return minus + "Rp" + text + unit[1]
	return rupiah(value)


## Selalu dengan tanda: +Rp1.000 / -Rp1.000
static func signed_rupiah(value: float) -> String:
	return ("+" if roundi(value) >= 0 else "") + rupiah(value)


static func number(value: float, decimals: int = 2) -> String:
	var parts := ("%.*f" % [decimals, absf(value)]).split(".")  # "1234.50" -> ["1234", "50"]
	var text := _group_thousands(parts[0].to_int())
	if parts.size() > 1:
		text += "," + parts[1]
	return ("-" if value < 0 else "") + text


## Jumlah unit: kripto bisa 0,000123 unit, saham ratusan unit.
static func units(value: float) -> String:
	if value < 1.0:
		return number(value, 6)
	if value < 100.0:
		return number(value, 4)
	return number(value, 2)


static func percent(ratio: float) -> String:
	return ("%+.2f%%" % (ratio * 100.0)).replace(".", ",")


## Tanpa tanda +, untuk suku bunga/fee: 4,50%
static func percent_plain(ratio: float) -> String:
	return ("%.2f%%" % (ratio * 100.0)).replace(".", ",")


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
