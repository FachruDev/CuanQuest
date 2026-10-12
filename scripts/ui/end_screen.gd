extends Control
## Layar akhir: hasil, statistik, grafik kekayaan seumur hidup, keputusan terbaik/terburuk,
## dan analisis (GDD 5.11).

const TITLE_SCENE := "res://scenes/title.tscn"
const NEW_GAME_SCENE := "res://scenes/new_game.tscn"
const RESULT_COLORS := {"win": Color("#2ecc71"), "retired": Color("#5dade2"), "lose": Color("#e74c3c")}


func _ready() -> void:
	%PlayAgainButton.pressed.connect(_leave_to.bind(NEW_GAME_SCENE))
	%TitleButton.pressed.connect(_leave_to.bind(TITLE_SCENE))
	var r := GameState.end_result
	if r.is_empty():  # dibuka langsung dari editor tanpa permainan yang selesai
		return

	%ResultTitle.text = tr("END_TITLE_" + str(r["type"]).to_upper())
	%ResultTitle.modulate = RESULT_COLORS.get(r["type"], Color.WHITE)
	%ReasonLabel.text = tr("END_REASON_" + str(r["reason"]).to_upper())
	%Avatar.avatar_index = GameState.avatar
	%Avatar.display_name = GameState.player_name
	%PlayerLabel.text = tr("END_PLAYER") % [GameState.player_name, int(r["age"]),
		floori(int(r["month"]) / 12.0), int(r["month"]) % 12]
	%ScoreLabel.text = tr("END_SCORE") % int(r["score"])
	%ScoreLabel.visible = r["type"] != "lose"  # skor warisan hanya untuk pensiun / menang

	var s := GameState.stats
	_add_stat("END_STAT_NET_WORTH", Fmt.rupiah(r["net_worth"]))
	_add_stat("END_STAT_PEAK", Fmt.rupiah(r["peak"]))
	_add_stat("END_STAT_SALARY", Fmt.rupiah(s["total_salary"]))
	_add_stat("END_STAT_LIVING", Fmt.rupiah(s["total_living"]))
	_add_stat("END_STAT_INTEREST", Fmt.rupiah(s["total_interest"]))
	_add_stat("END_STAT_FEES", Fmt.rupiah(s["total_fees"]))
	_add_stat("END_STAT_EVENTS", str(int(s["events"])))
	_add_stat("END_STAT_QUIZ", str(GameState.quiz.correct_ids.size()))
	_add_stat("END_STAT_LEVEL", str(GameState.level()))

	%LifeChart.set_data(GameState.net_worth_history)

	_add_highlight("END_BEST_TRADE", s["best_trade"], "asset_key")
	_add_highlight("END_WORST_TRADE", s["worst_trade"], "asset_key")
	_add_highlight("END_BEST_EVENT", s["best_event"], "title")
	_add_highlight("END_WORST_EVENT", s["worst_event"], "title")

	for text in EndAnalysis.insights(GameState):
		var label := Label.new()
		label.text = "- " + text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 21)
		%InsightList.add_child(label)

	Sfx.play("fail" if r["type"] == "lose" else "success")
	if r["type"] == "lose":
		Sfx.vibrate(300)


func _add_stat(key: String, value: String) -> void:
	var name_label := Label.new()
	name_label.text = tr(key)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 22)
	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 22)
	%StatsGrid.add_child(name_label)
	%StatsGrid.add_child(value_label)


## "Transaksi terbaik: PT Bank Sentosa Tbk (BSNT) +Rp2.500.000 (Maret Tahun 3)"
func _add_highlight(key: String, record: Dictionary, name_field: String) -> void:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20)
	if record.is_empty():
		label.text = "%s: -" % tr(key)
		label.modulate = MonthReport.MUTED
	else:
		label.text = "%s: %s %s (%s)" % [tr(key), tr(record[name_field]),
			Fmt.signed_rupiah(record["value"]), Fmt.game_date(int(record["month"]))]
		label.modulate = MonthReport.color_of(record["value"])
	%HighlightList.add_child(label)


func _leave_to(scene: String) -> void:
	GameState.is_active = false
	get_tree().change_scene_to_file(scene)
