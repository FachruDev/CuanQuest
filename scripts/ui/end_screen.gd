extends Control
## Layar akhir (tema "Senja Cuan"): hasil, kartu pemain & skor, rincian skor warisan (v2b), statistik,
## perjalanan karier, neraca akhir, grafik kekayaan riil seumur hidup per bab, keputusan terbaik/terburuk,
## dan analisis (GDD 5.11).

const TITLE_SCENE := "res://scenes/title.tscn"
const NEW_GAME_SCENE := "res://scenes/new_game.tscn"
## Per jenis hasil: [warna judul, variasi lencana, ikon lencana].
const RESULT_LOOK := {
	"win": [Color("#1e7f5c"), &"BadgeGoldPanel", "res://assets/icons/badge_trophy.svg"],
	"retired": [Color("#23877b"), &"BadgeTealPanel", "res://assets/icons/badge_retire.svg"],
	"lose": [Color("#c2452d"), &"WarningBadgePanel", "res://assets/icons/badge_lose.svg"],
	"died": [Color("#2b2147"), &"BadgeTealPanel", "res://assets/icons/badge_life.svg"],  # v2b: tenang, bukan "kalah"
}
const TREND_UP := preload("res://assets/icons/trend_up.svg")
const TREND_DOWN := preload("res://assets/icons/trend_down.svg")
const BULB := preload("res://assets/icons/lightbulb.svg")
## Gaya batang per bagian skor warisan (lainnya XpBar).
const LEGACY_BARS := {"health": &"HealthBar", "happiness": &"HappinessBar"}


func _ready() -> void:
	%PlayAgainButton.pressed.connect(_leave_to.bind(NEW_GAME_SCENE))
	%TitleButton.pressed.connect(_leave_to.bind(TITLE_SCENE))
	var r := GameState.end_result
	if r.is_empty():  # dibuka langsung dari editor tanpa permainan yang selesai
		return
	Music.play("" if r["type"] == "died" else "end")  # akhir hidup: hening (pedoman konten sensitif prinsip 7)

	var look: Array = RESULT_LOOK.get(r["type"], RESULT_LOOK["win"])
	%ResultTitle.text = tr("END_TITLE_" + str(r["type"]).to_upper())
	%ResultTitle.add_theme_color_override("font_color", look[0])
	%Badge.theme_type_variation = look[1]
	%BadgeIcon.texture = load(look[2])
	if r["type"] == "died":  # v2b: penyebab umum, usia, dan warisan (pedoman konten sensitif)
		%ReasonLabel.text = UiText.death_text(r)
	else:
		%ReasonLabel.text = tr("END_REASON_" + str(r["reason"]).to_upper())

	%Avatar.avatar_index = GameState.avatar
	%Avatar.display_name = GameState.player_name
	%NameLabel.text = GameState.player_name
	UiText.apply_avatar_frame(%Avatar.get_parent(), GameState.achievements.current_frame())  # kosmetik (v1.5d)
	if GameState.achievements.current_title() != "":  # gelar pilihan pemain
		%InfoChips.add_child(_chip(GameState.achievements.current_title(), &"MoodGreen"))
	var months := int(r["month"])
	var job_title := tr(GameState.career.current_job_def()["title"]) if GameState.career.is_employed() else tr("CAREER_UNEMPLOYED")
	if GameState.life.retired:  # v2b
		job_title = tr("CAREER_RETIRED")
	%InfoChips.add_child(_chip(job_title, &"MoodGold"))
	%InfoChips.add_child(_chip(GameState.education.level_name(GameState.education.level), &"MoodNeutral"))
	%InfoChips.add_child(_chip(tr("END_AGE") % int(r["age"]), &"MoodNeutral"))
	%InfoChips.add_child(_chip(tr("END_PLAYED") % [floori(months / 12.0), months % 12], &"MoodNeutral"))
	%ScoreLabel.text = tr("END_SCORE") % int(r["score"])  # skor warisan v2 untuk semua hasil (v2b langkah 5)
	if r.get("best", false):
		%ScoreLabel.text += " · " + tr("END_SCORE_BEST")
	_add_legacy_card(r.get("legacy", {}))

	var s := GameState.stats
	_add_stat("END_STAT_NET_WORTH", Fmt.rupiah(r["net_worth"]))
	_add_stat("END_STAT_PEAK", Fmt.rupiah(r["peak"]))
	_add_stat("END_STAT_SALARY", Fmt.rupiah(s["total_salary"]))
	_add_stat("END_STAT_LIVING", Fmt.rupiah(s["total_living"]))
	_add_stat("END_STAT_INTEREST", Fmt.rupiah(s["total_interest"]))
	_add_stat("END_STAT_FEES", Fmt.rupiah(s["total_fees"]))
	_add_stat("END_STAT_EVENTS", str(int(s["events"])))
	_add_stat("END_STAT_QUIZ", str(GameState.quiz.correct_ids.size()))
	_add_stat("END_STAT_LEVEL", str(GameState.progress.level()))
	_add_stat("END_STAT_PROMOTIONS", str(int(s["promotions"])))
	_add_stat("END_STAT_UNEMPLOYED", str(int(s["months_unemployed"])))
	var fund_fees := float(GameState.fund.record["mgmt_fees"]) + float(GameState.fund.record["perf_fees"])
	if fund_fees > 0.0:  # dana kelolaan (v2c)
		_add_stat("END_STAT_FUND_FEES", Fmt.rupiah(fund_fees))
	_add_career_log()
	_add_balance_sheet()

	%LifeChart.set_data(GameState.legacy.real_history())  # nilai riil, dengan penanda bab (v2b langkah 5)
	%LifeChart.set_marks(GameState.legacy.chapter_marks().map(func(mark: Array) -> Array:
		return [mark[0], tr("CHAPTER_" + str(mark[1]).to_upper())]))
	var chart_note := _label(tr("END_CHART_NOTE"), &"SmallMutedLabel")
	chart_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var content: VBoxContainer = %StatsGrid.get_parent()
	content.add_child(chart_note)
	content.move_child(chart_note, content.get_node("ChartCard").get_index() + 1)

	_add_highlight("END_BEST_TRADE", s["best_trade"], "asset_key")
	_add_highlight("END_WORST_TRADE", s["worst_trade"], "asset_key")
	_add_highlight("END_BEST_EVENT", s["best_event"], "title")
	_add_highlight("END_WORST_EVENT", s["worst_event"], "title")

	for text in EndAnalysis.insights(GameState):
		%InsightList.add_child(_insight_card(text))

	if r["type"] != "died":  # akhir hidup tanpa bunyi perayaan atau getar
		Sfx.play("fail" if r["type"] == "lose" else "success")
	if r["type"] == "lose":
		Sfx.vibrate(300)


## Judul + kartu "Rincian Skor Warisan" tepat setelah kartu pemain (v2b langkah 5): enam bagian skor
## dengan nilai, poin, dan batangnya, lalu total.
func _add_legacy_card(score: Dictionary) -> void:
	if score.is_empty():
		return
	var content: VBoxContainer = %StatsGrid.get_parent()
	var index := content.get_node("PlayerCard").get_index() + 1
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	var title := _label(tr("LEGACY_TITLE"), &"SubSectionLabel")
	var card := PanelContainer.new()
	card.theme_type_variation = &"HomeCard"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	for id: String in Legacy.PARTS:
		box.add_child(_legacy_row(id, score["parts"][id]))
	var line := Panel.new()
	line.theme_type_variation = &"Divider"
	line.custom_minimum_size = Vector2(0, 2)
	box.add_child(line)
	var total := HBoxContainer.new()
	var total_name := _label(tr("LEGACY_TOTAL"), &"AssetNameLabel")
	total_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total.add_child(total_name)
	total.add_child(_label(tr("LEGACY_POINTS") % [int(score["total"]), 1000], &"AssetValueLabel"))
	box.add_child(total)
	var note := _label(tr("LEGACY_NOTE"), &"SmallMutedLabel")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	for node: Control in [gap, title, card]:
		content.add_child(node)
		content.move_child(node, index)
		index += 1


func _legacy_row(id: String, part: Dictionary) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var top := HBoxContainer.new()
	var name_label := _label(tr("LEGACY_" + id.to_upper()), &"AssetNameLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	top.add_child(_label(tr("LEGACY_POINTS") % [int(part["points"]), int(part["max"])], &"AssetValueLabel"))
	row.add_child(top)
	var detail := _label(legacy_detail(id, part["value"]), &"SmallMutedLabel")
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(detail)
	var bar := ProgressBar.new()
	bar.theme_type_variation = LEGACY_BARS.get(id, &"XpBar")
	bar.custom_minimum_size = Vector2(0, 12)
	bar.show_percentage = false
	bar.max_value = int(part["max"])
	bar.value = int(part["points"])
	row.add_child(bar)
	return row


## Keterangan nilai satu bagian skor warisan (dipakai juga oleh uji).
static func legacy_detail(id: String, value: Variant) -> String:
	match id:
		"wealth":
			return TranslationServer.translate("LEGACY_WEALTH_DETAIL") % Fmt.rupiah(value)
		"age":
			return TranslationServer.translate("LEGACY_AGE_DETAIL") % int(value)
		"health", "happiness":
			return TranslationServer.translate("LEGACY_AVG_DETAIL") % roundi(value)
		"dreams":
			return TranslationServer.translate("LEGACY_DREAMS_DETAIL") % int(value)
		"wisdom":
			var w: Dictionary = value
			var parts: PackedStringArray = [TranslationServer.translate("LEGACY_SCAMS_DETAIL") % [int(w["scams_avoided"]),
				int(w["scams_fallen"])]]
			parts.append(TranslationServer.translate("LEGACY_NO_DEFAULT") if int(w["defaults"]) == 0
				else TranslationServer.translate("LEGACY_DEFAULTED") % int(w["defaults"]))
			parts.append(TranslationServer.translate("LEGACY_NEGATIVE_CASH") if w["negative_cash"]
				else TranslationServer.translate("LEGACY_NO_NEGATIVE_CASH"))
			return " · ".join(parts)
	return ""


## Judul + kartu "Perjalanan Karier" sebelum bagian Keputusan Penting.
func _add_career_log() -> void:
	var content: VBoxContainer = %StatsGrid.get_parent()
	var index := content.get_node("HighlightTitle").get_index()
	var title := _label(tr("PROFILE_CAREER_TITLE"), &"SubSectionLabel")
	var card := PanelContainer.new()
	card.theme_type_variation = &"HomeCard"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	UiText.fill_career_log(box, 12)
	content.add_child(title)
	content.move_child(title, index)
	content.add_child(card)
	content.move_child(card, index + 1)


## Judul + kartu "Neraca Akhir" (aset - utang) setelah Perjalanan Karier.
func _add_balance_sheet() -> void:
	var content: VBoxContainer = %StatsGrid.get_parent()
	var index := content.get_node("HighlightTitle").get_index()
	var title := _label(tr("SHEET_END_TITLE"), &"SubSectionLabel")
	var card := PanelContainer.new()
	card.theme_type_variation = &"HomeCard"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	BalanceSheet.fill(box, GameState.balance_sheet())
	content.add_child(title)
	content.move_child(title, index)
	content.add_child(card)
	content.move_child(card, index + 1)


func _add_stat(key: String, value: String) -> void:
	var tile := PanelContainer.new()
	tile.theme_type_variation = &"StatTile"
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var name_label := _label(tr(key), &"TileCapsLabel")
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)
	box.add_child(_label(value, &"TileValueLabel"))
	tile.add_child(box)
	%StatsGrid.add_child(tile)


## Satu baris keputusan penting: panah naik/turun | judul + nama + tanggal | nilai berwarna.
func _add_highlight(key: String, record: Dictionary, name_field: String) -> void:
	if %HighlightList.get_child_count() > 0:
		var line := Panel.new()
		line.theme_type_variation = &"Divider"
		line.custom_minimum_size = Vector2(0, 2)
		%HighlightList.add_child(line)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var value: float = record.get("value", 0.0)
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"ChangeFlat" if record.is_empty() else (&"ChangeUp" if value >= 0 else &"ChangeDown")
	chip.custom_minimum_size = Vector2(40, 40)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not record.is_empty():
		var arrow := TextureRect.new()
		arrow.texture = TREND_UP if value >= 0 else TREND_DOWN
		arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		arrow.custom_minimum_size = Vector2(16, 14)
		arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(arrow)
	row.add_child(chip)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	texts.add_child(_label(tr(key), &"TileCapsLabel"))
	var name_label := _label("-" if record.is_empty() else tr(record[name_field]), &"AssetNameLabel")
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(name_label)
	if not record.is_empty():
		texts.add_child(_label(Fmt.game_date(int(record["month"])), &"SmallMutedLabel"))
	row.add_child(texts)

	if not record.is_empty():
		var value_label := _label(Fmt.signed_rupiah(value), &"AssetValueLabel")
		value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		value_label.add_theme_color_override("font_color", MonthReport.signed_color(value))
		row.add_child(value_label)
	%HighlightList.add_child(row)


func _insight_card(text: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"TipCard"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var icon := TextureRect.new()
	icon.texture = BULB
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(24, 26)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var label := _label(text, &"InfoLabel")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(icon)
	row.add_child(label)
	card.add_child(row)
	return card


func _chip(text: String, variation: StringName) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = variation
	chip.add_child(_label(text, &"MoodLabel"))
	return chip


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label


func _leave_to(scene: String) -> void:
	GameState.is_active = false
	get_tree().change_scene_to_file(scene)
