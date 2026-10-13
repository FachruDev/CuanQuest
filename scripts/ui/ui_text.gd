class_name UiText
extends RefCounted
## Helper teks & label yang dipakai di beberapa layar.

## Warna kotak ikon per kelas aset (nama file ikon = id kelas di data/assets.json).
const CLASS_TILES := {
	"savings": &"IconTileBlue", "deposit": &"IconTileMint", "mutual_fund": &"IconTileGold",
	"stock": &"IconTileCoral", "crypto": &"IconTilePurple",
}
const CLASS_ICON := "res://assets/icons/classes/%s.svg"


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
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.theme_type_variation = &"ReqLabel"
		label.add_theme_color_override("font_color", Palette.GAIN if status["met"] else Palette.LOSS)
		box.add_child(label)


## Button tidak ikut membesar mengikuti anaknya; samakan tingginya dengan isi (teks bisa membungkus).
## `extra` = ruang tambahan di luar isi, mis. bibir bawah tombol tebal.
static func fit_to_content(button: Control, content: Control, extra := 0.0) -> void:
	var fit := func() -> void: button.custom_minimum_size.y = content.get_combined_minimum_size().y + extra
	content.minimum_size_changed.connect(fit)
	fit.call_deferred()


static func requirement_text(req: Dictionary, status: Dictionary) -> String:
	match req["type"]:
		"tutorial":
			return _t("REQ_TUTORIAL")
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


## Mengisi `row` dengan tombol periode grafik (GDD 5.6: mis. 1, 6, 12 bulan + Semua).
## 0 = semua data. Tombol `default_period` aktif di awal.
static func build_period_buttons(row: HBoxContainer, chart: PriceChart, default_period: int,
		periods: Array[int] = [1, 6, 12, 0]) -> void:
	var group := ButtonGroup.new()
	for months: int in periods:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.text = _t("PERIOD_%d" % months)
		button.theme_type_variation = &"PeriodButton"
		button.custom_minimum_size = Vector2(0, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.button_pressed = months == default_period
		button.pressed.connect(chart.set_period.bind(months))
		row.add_child(button)
	chart.set_period(default_period)


## Kotak ikon berwarna untuk satu kelas aset (tabungan, deposito, reksa dana, saham, kripto).
static func class_tile(asset_class: String, tile_size := 48.0) -> PanelContainer:
	return icon_tile(CLASS_ICON % asset_class, CLASS_TILES.get(asset_class, &"IconTileGold"), tile_size)


## Kotak berwarna (variasi tema `variation`) berisi ikon SVG di tengah. Ikon dilewati jika filenya belum ada.
static func icon_tile(icon_path: String, variation: StringName, tile_size := 48.0) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.theme_type_variation = variation
	tile.custom_minimum_size = Vector2(tile_size, tile_size)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2.ONE * tile_size * 0.54
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(icon)
	return tile


static func _t(key: String) -> String:
	return TranslationServer.translate(key)
