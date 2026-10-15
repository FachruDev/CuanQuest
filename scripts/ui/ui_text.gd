class_name UiText
extends RefCounted
## Helper teks & label yang dipakai di beberapa layar.

## Warna kotak ikon per kelas aset (nama file ikon = id kelas di data/assets.json).
const CLASS_TILES := {
	"savings": &"IconTileBlue", "deposit": &"IconTileMint", "mutual_fund": &"IconTileGold",
	"stock": &"IconTileCoral", "crypto": &"IconTilePurple",
}
const CLASS_ICON := "res://assets/icons/classes/%s.svg"
## Ikon bidang pekerjaan: assets/icons/tracks/<bidang>.svg. Sebelum aset itu dibuat, tiap bidang
## memakai ikon lain yang berbeda agar tetap mudah dibedakan (lihat docs/KEBUTUHAN_ASET.md).
const TRACK_ICON := "res://assets/icons/tracks/%s.svg"
const TRACK_ICON_FALLBACKS := {
	"retail": "res://assets/icons/wallet.svg", "admin": "res://assets/icons/folder.svg",
	"finance": "res://assets/icons/classes/deposit.svg", "tech": "res://assets/icons/search.svg",
	"creative": "res://assets/icons/lightbulb.svg", "gig": "res://assets/icons/activities/side_job.svg",
	"general": "res://assets/icons/book.svg",  # proyek sampingan umum: les privat, terjemahan (v1.5d)
}
const TRACK_TILES := {
	"retail": &"IconTileCoral", "admin": &"IconTileBlue", "finance": &"IconTileGold",
	"tech": &"IconTilePurple", "creative": &"IconTileMint", "gig": &"IconTileCoral", "general": &"IconTileTeal",
}

static var _money_token: RegEx


## Teks dari file data boleh berisi token {rp:3000000} (harga AWAL permainan). Token diganti
## nominal hari ini mengikuti inflasi, mis. "Rp3,1 juta", agar cerita sama dengan biaya sebenarnya.
static func money(text: String) -> String:
	if not text.contains("{rp:"):
		return text
	if _money_token == null:
		_money_token = RegEx.create_from_string("\\{rp:(-?\\d+)\\}")
	var result := text
	for found in _money_token.search_all(text):
		result = result.replace(found.get_string(), Fmt.rupiah_words(GameState.nominal(found.get_string(1).to_int())))
	return result


## Teks event: token uang {rp:N} + isian event karier & pendidikan (v1.5b) dari
## GameState.events.pending_vars atau hasil resolve_event: {job}, {company}, {salary}, {months},
## {severance}, {raise}, {program}, {cert}.
static func event_text(text: String, vars: Dictionary) -> String:
	var result := money(text)
	if not result.contains("{"):
		return result
	for id: String in ["boss", "coworker"]:  # tokoh kantor: namanya mengikuti perusahaan (v1.5d)
		result = result.replace("{%s}" % id, GameState.characters.name_of(id))
	if vars.has("advice"):  # saran Kak Wulan (sudah diterjemahkan saat event tampil)
		result = result.replace("{advice}", vars["advice"])
	if vars.is_empty() or not result.contains("{"):
		return result
	if vars.has("job_id"):
		result = result.replace("{job}", _t(GameState.career.job_def(vars["job_id"]).get("title", "")))
	if vars.has("company"):
		result = result.replace("{company}", vars["company"])
	for key: String in ["salary", "severance", "rent2", "arrears", "amount", "installment", "interest", "pay_from",
			"pay_to", "pay_refi", "pay_prepaid", "fee", "prepay", "prepay_amount"]:
		if vars.has(key):
			result = result.replace("{%s}" % key, Fmt.rupiah(vars[key]))
	for key: String in ["rate_from", "rate_to", "refi_rate"]:  # bunga per tahun (utang, v1.5c)
		if vars.has(key):
			result = result.replace("{%s}" % key, Fmt.percent_plain(vars[key]))
	for key: String in ["property", "loan", "collateral"]:  # nama dari file data
		if vars.has(key):
			result = result.replace("{%s}" % key, _t(vars[key]))
	if vars.has("months"):
		result = result.replace("{months}", str(int(vars["months"])))
	if vars.has("raise"):
		result = result.replace("{raise}", "%d%%" % roundi(float(vars["raise"]) * 100.0))
	if vars.has("program_id"):
		result = result.replace("{program}", _t(GameState.education.program_def(vars["program_id"]).get("name", "")))
	if vars.has("cert"):
		result = result.replace("{cert}", _t(vars["cert"]))
	return result


static func track_icon(track: String) -> String:
	var icon := TRACK_ICON % track
	return icon if ResourceLoader.exists(icon) else TRACK_ICON_FALLBACKS.get(track, "res://assets/icons/wallet.svg")


static func track_tile(track: String) -> StringName:
	return TRACK_TILES.get(track, &"IconTileGold")


## Satu baris perjalanan karier: "Mar Tahun 1 · Mulai bekerja sebagai Kasir di Toko Sinar Jaya".
static func career_log_text(entry: Dictionary) -> String:
	var title := _t(GameState.career.job_def(entry.get("job_id", "")).get("title", ""))
	var company: String = entry.get("company", "")
	var program := _t(GameState.education.program_def(entry.get("program", "")).get("name", ""))
	var text := ""
	match entry["kind"]:
		"hired":
			text = _t("CAREER_LOG_HIRED") % [title, company]
		"promoted":
			text = _t("CAREER_LOG_PROMOTED") % title
		"laid_off":
			text = _t("CAREER_LOG_LAID_OFF") % [title, company]
		"resigned":
			text = _t("CAREER_LOG_RESIGNED") % [title, company]
		"graduated":
			text = _t("CAREER_LOG_GRADUATED") % program
		"dropped_out":
			text = _t("CAREER_LOG_DROPPED") % program
	return "%s · %s" % [Fmt.game_date(int(entry["month"])), text]


## Mengisi `box` dengan baris perjalanan karier, terbaru di atas (maks. `limit`).
static func fill_career_log(box: VBoxContainer, limit: int) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var entries := GameState.career.history.duplicate()
	entries.reverse()
	if entries.is_empty():
		box.add_child(_log_label(_t("CAREER_LOG_EMPTY"), &"SmallMutedLabel"))
	for entry: Dictionary in entries.slice(0, limit):
		var label := _log_label(career_log_text(entry), &"RowLabel")
		if entry["kind"] in ["laid_off", "dropped_out"]:
			label.add_theme_color_override("font_color", Palette.LOSS)
		elif entry["kind"] in ["promoted", "graduated"]:
			label.add_theme_color_override("font_color", Palette.GAIN)
		box.add_child(label)


static func _log_label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1
	return label


## {"cash": -1500000, "health": 5} -> "Kas -Rp1.500.000 | Kesehatan +5"
static func changes_text(changes: Dictionary) -> String:
	var parts: Array[String] = []
	if changes.has("cash"):
		parts.append("%s %s" % [_t("LBL_CASH"), Fmt.signed_rupiah(changes["cash"])])
	if changes.has("investments"):
		parts.append("%s %s" % [_t("PORT_INVESTED"), Fmt.signed_rupiah(changes["investments"])])
	if changes.has("debt"):
		parts.append("%s %s" % [_t("CHANGE_DEBT"), Fmt.signed_rupiah(changes["debt"])])
	if changes.has("salary"):
		parts.append("%s %s" % [_t("REPORT_SALARY"), Fmt.signed_rupiah(changes["salary"])])
	if changes.has("health"):
		parts.append("%s %+d" % [_t("STAT_HEALTH"), int(changes["health"])])
	if changes.has("happiness"):
		parts.append("%s %+d" % [_t("STAT_HAPPINESS"), int(changes["happiness"])])
	if changes.has("skill"):
		parts.append("%s %+d" % [_t("STAT_SKILL"), int(changes["skill"])])
	if changes.has("performance"):
		parts.append("%s %+d" % [_t("STAT_PERFORMANCE"), int(changes["performance"])])
	if changes.has("credit"):
		parts.append("%s %+d" % [_t("CREDIT_SCORE"), int(changes["credit"])])
	for key: String in changes:  # kedekatan dengan tokoh (v1.5d): "Kedekatan Bima +5"
		if key.begins_with("rel_"):
			parts.append(_t("CHANGE_REL") % [GameState.characters.name_of(key.trim_prefix("rel_")), int(changes[key])])
	if changes.has("xp"):
		parts.append("XP %+d" % int(changes["xp"]))
	return " | ".join(parts)


## Mengisi `box` dengan satu label per syarat unlock: hijau jika terpenuhi, merah jika belum.
static func fill_requirements(box: VBoxContainer, stage: Dictionary) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	for req: Dictionary in stage["requirements"]:
		var status := GameState.progress.requirement_status(req)
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


## Tombol tebal gaya Senja Cuan dibuat lewat kode: ChunkyButton + Label "Content" sebagai anak
## (sama seperti tombol di scene .tscn). `variation` mis. PrimaryButton / NeutralButton / DangerButton.
static func chunky_button(text: String, variation: StringName, label_variation: StringName,
		height := 80.0, font_size := 0) -> Button:
	var button := ChunkyButton.new()
	button.theme_type_variation = variation
	button.custom_minimum_size = Vector2(0, height)
	var label := Label.new()
	label.name = "Content"
	label.text = text
	label.theme_type_variation = label_variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 12.0
	label.offset_right = -12.0
	label.offset_bottom = -7.0  # sisakan bibir bawah tombol
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	button.add_child(label)
	return button


## Bingkai avatar (kosmetik v1.5d): warna garis & latar panel AvatarFrame dari data/achievements.json
## "frames"; bingkai bercahaya diberi bayangan berwarna. Bingkai bawaan = gaya tema apa adanya.
static func apply_avatar_frame(panel: PanelContainer, frame: Dictionary) -> void:
	panel.remove_theme_stylebox_override("panel")
	var base := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if base == null or frame["id"] == GameState.achievements.frames()[0]["id"]:
		return
	var style := base.duplicate() as StyleBoxFlat
	style.border_color = Color(frame["border"])
	style.bg_color = Color(frame["bg"])
	if frame.has("glow"):
		style.shadow_color = Color(Color(frame["glow"]), 0.6)
		style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)


## Cache render sederhana (penutup v1.5): true jika `key` untuk bagian `part` berbeda dari yang terakhir
## digambar (lalu disimpan). Layar memakainya agar daftar panjang tidak dibangun ulang di setiap aksi
## kecil. Analogi web: seperti React.memo / useMemo dengan daftar dependensi. Kunci sebaiknya memuat
## run_id (permainan baru/dimuat) dan format angka (Fmt.compact).
static func changed_key(cache: Dictionary, part: String, key: Variant) -> bool:
	var text := str(key)
	if cache.get(part, "") == text:
		return false
	cache[part] = text
	return true


## Nominal ringkas untuk tombol: 500000 -> "Rp500 rb", 1000000 -> "Rp1 jt"
static func amount_short(amount: int) -> String:
	if amount >= 1_000_000 and amount % 1_000_000 == 0:
		return "Rp%d jt" % (amount / 1_000_000)
	if amount >= 1000 and amount % 1000 == 0:
		return "Rp%d rb" % (amount / 1000)
	return Fmt.rupiah(amount)


## Kalimat sebuah target bulanan, mis. "Investasikan minimal Rp1.000.000 secara manual".
static func target_text(target: Dictionary) -> String:
	var key := "TARGET_" + str(target["type"]).to_upper()
	match target["type"]:
		"invest", "save", "dream_deposit":
			return _t(key) % Fmt.rupiah(target["goal"])
		"health", "happiness":
			return _t(key) % int(target["goal"])
		"activity":
			for def: Dictionary in GameState.activities.defs():
				if def["id"] == target["param"]:
					return _t(key) % _t(def["name"])
	return _t(key)


## Status target: teks & warna ("Selesai" hijau, "Gagal" merah, "Berjalan" redup).
static func target_status(target: Dictionary) -> Dictionary:
	match target["state"]:
		"done":
			return {"text": _t("TARGET_DONE"), "color": Palette.GAIN}
		"failed":
			return {"text": _t("TARGET_FAILED"), "color": Palette.LOSS}
	return {"text": _t("TARGET_OPEN"), "color": Palette.MUTED}


## Warna skor kredit (v1.5c): hijau = baik, redup = cukup, merah = bank menolak.
static func credit_color(score: int) -> Color:
	if score >= 60:
		return Palette.GAIN
	if score >= int(GameState.debt.data["credit"]["min_score"]):
		return Palette.MUTED
	return Palette.LOSS


## "Sisa Rp28,4 jt · 30 bulan lagi" atau "Menunggak 2 bulan (Kol 2) · tunggakan Rp2,3 jt".
static func loan_status(loan: Dictionary) -> String:
	var missed := int(loan["missed"])
	if missed > 0:
		return _t("DEBT_STATUS_LATE") % [missed, Debt.collectibility(missed), Fmt.rupiah_short(loan["arrears"])]
	return _t("DEBT_STATUS_OK") % [Fmt.rupiah_short(loan["balance"]), int(loan["months_left"])]


## Daftar syarat pinjaman / pembelian kendaraan (Debt.requirements, Vehicles.buy_quote) sebagai
## baris ✓/✗ berwarna.
static func fill_loan_requirements(box: VBoxContainer, reqs: Array) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	for req: Dictionary in reqs:
		var label := Label.new()
		label.text = "%s  %s" % [_t("REQ_DONE") if req["met"] else _t("REQ_TODO"), loan_requirement_text(req)]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 1
		label.theme_type_variation = &"ReqLabel"
		label.add_theme_color_override("font_color", Palette.GAIN if req["met"] else Palette.LOSS)
		box.add_child(label)


static func loan_requirement_text(req: Dictionary) -> String:
	match req["type"]:
		"job":
			return _t("LOAN_REQ_CAREER" if req["career"] else "LOAN_REQ_JOB") % [int(req["need"]), int(req["have"])]
		"score":
			return _t("LOAN_REQ_SCORE") % [int(req["need"]), int(req["have"])]
		"arrears":
			return _t("LOAN_REQ_ARREARS")
		"active":
			return _t("LOAN_REQ_ACTIVE")
		"limit":
			return _t("LOAN_REQ_LIMIT") % Fmt.rupiah(req["need"])
		"dsr":
			return _t("LOAN_REQ_DSR") % roundi(float(req["need"]) * 100.0)
		"not_owned":
			return _t("VEHICLE_REQ_NOT_OWNED")
		"loan_allowed":
			return _t("LOAN_REQ_ALLOWED")
		"max_salary":
			return _t("LOAN_REQ_MAX_SALARY") % [Fmt.rupiah(req["need"]), Fmt.rupiah(req["have"])]
		"first_home":
			return _t("LOAN_REQ_FIRST_HOME")
		"cash":
			return _t("VEHICLE_REQ_CASH") % [Fmt.rupiah(req["need"]), Fmt.rupiah(req["have"])]
	return ""


## Status pemakaian properti (v1.5c): dihuni, disewakan (sewa & sisa kontrak), mencari penyewa,
## kosong, ditambah status dijual.
static func property_status(entry: Dictionary) -> String:
	var text := ""
	match entry["use"]:
		"live":
			text = _t("PROPERTY_STATUS_LIVE")
		"rent":
			if int(entry["vacant_left"]) > 0:
				text = _t("PROPERTY_STATUS_VACANT") % int(entry["vacant_left"])
			else:
				text = _t("PROPERTY_STATUS_RENTED") % [Fmt.rupiah_short(GameState.properties.rent_net(entry["id"])),
					int(entry["lease_left"])]
		_:
			text = _t("PROPERTY_STATUS_EMPTY")
	if int(entry["selling_left"]) > 0:
		text += " · " + _t("PROPERTY_STATUS_SELLING") % int(entry["selling_left"])
	return text


## "Jangka pendek" / "Jangka menengah" / "Jangka panjang"
static func horizon_text(horizon: String) -> String:
	return _t("DREAM_HORIZON_" + horizon.to_upper())


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
