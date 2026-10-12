class_name UiText
extends RefCounted
## Helper teks & label yang dipakai di beberapa layar.


## {"cash": -1500000, "health": 5} -> "Kas -Rp1.500.000 | Kesehatan +5"
static func changes_text(changes: Dictionary) -> String:
	var parts: Array[String] = []
	if changes.has("cash"):
		parts.append("%s %s" % [_t("LBL_CASH"), Fmt.signed_rupiah(changes["cash"])])
	if changes.has("investments"):
		parts.append("%s %s" % [_t("PORT_INVESTED"), Fmt.signed_rupiah(changes["investments"])])
	if changes.has("salary"):
		parts.append("%s %s" % [_t("REPORT_SALARY"), Fmt.signed_rupiah(changes["salary"])])
	if changes.has("health"):
		parts.append("%s %+d" % [_t("STAT_HEALTH"), int(changes["health"])])
	if changes.has("happiness"):
		parts.append("%s %+d" % [_t("STAT_HAPPINESS"), int(changes["happiness"])])
	if changes.has("xp"):
		parts.append("XP %+d" % int(changes["xp"]))
	return " | ".join(parts)


## Mengisi `box` dengan satu label per syarat unlock: hijau jika terpenuhi, merah jika belum.
static func fill_requirements(box: VBoxContainer, stage: Dictionary) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	for req: Dictionary in stage["requirements"]:
		var status := GameState.requirement_status(req)
		var label := Label.new()
		label.text = ("%s  %s" % [_t("REQ_DONE") if status["met"] else _t("REQ_TODO"), requirement_text(req, status)])
		label.modulate = MonthReport.GREEN if status["met"] else MonthReport.RED
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 20)
		box.add_child(label)


static func requirement_text(req: Dictionary, status: Dictionary) -> String:
	match req["type"]:
		"emergency_fund":
			return _t("REQ_EMERGENCY") % [int(req["months"]), Fmt.rupiah(status["current"]), Fmt.rupiah(status["target"])]
		"net_worth":
			return _t("REQ_NET_WORTH") % [Fmt.rupiah(status["current"]), Fmt.rupiah(status["target"])]
		"level":
			return _t("REQ_LEVEL") % [int(status["current"]), int(status["target"])]
		"quiz_topic":
			return _t("REQ_QUIZ") % [_t("TOPIC_" + str(req["topic"]).to_upper()), int(status["current"]), int(status["target"])]
	return ""


## Nama-nama aset di satu tahap unlock, dipisah koma.
static func stage_assets_text(stage: int) -> String:
	var names: Array[String] = []
	for asset: MarketAsset in GameState.market.assets.values():
		if asset.stage == stage:
			names.append(_t(asset.name_key))
	return ", ".join(names)


static func _t(key: String) -> String:
	return TranslationServer.translate(key)
