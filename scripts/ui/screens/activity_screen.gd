extends ScrollContainer
## Tab Aktivitas: level & XP, kuis (jatah mingguan + iklan), dan progres unlock instrumen.

## Main yang menampilkan popup kuis (lewat antrean popup), screen ini hanya meminta.
signal quiz_requested(question: Dictionary)

const TOPICS := ["basics", "risk", "scam", "instruments"]


func _ready() -> void:
	%StartQuizButton.pressed.connect(_on_start_quiz)
	%AdButton.pressed.connect(_on_watch_ad)
	GameState.changed.connect(_refresh)
	visibility_changed.connect(_refresh)  # jatah kuis bisa reset karena waktu nyata berjalan
	_refresh()


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	var per_level := int(GameState.economy["xp_per_level"])
	%LevelLabel.text = tr("ACT_LEVEL") % [GameState.level(), GameState.xp]
	%XpBar.max_value = per_level
	%XpBar.value = GameState.xp_in_level()

	var quiz := GameState.quiz
	var free_left := quiz.free_left()
	%QuizInfo.text = tr("ACT_QUIZ_INFO") % [free_left, int(GameState.economy["quiz"]["free_per_week"])]
	if quiz.bonus_credits > 0:
		%QuizInfo.text += "\n" + tr("ACT_QUIZ_BONUS") % quiz.bonus_credits
	%StartQuizButton.disabled = not quiz.can_start()
	%AdButton.visible = free_left == 0 and quiz.bonus_credits == 0
	%AdButton.disabled = quiz.ads_left() == 0 or not AdService.is_available()
	%AdButton.text = tr("ACT_WATCH_AD") % quiz.ads_left()

	var topic_parts: Array[String] = []
	for topic: String in TOPICS:
		topic_parts.append("%s %d" % [tr("TOPIC_" + topic.to_upper()), quiz.correct_in_topic(topic)])
	%TopicLabel.text = tr("ACT_TOPIC_PROGRESS") % " | ".join(topic_parts)

	_build_unlocks()


func _build_unlocks() -> void:
	for child in %UnlockList.get_children():
		%UnlockList.remove_child(child)
		child.queue_free()
	for stage: Dictionary in GameState.stage_defs:
		var stage_num := int(stage["stage"])
		var unlocked := GameState.is_stage_unlocked(stage_num)
		var card := PanelContainer.new()
		var box := VBoxContainer.new()
		card.add_child(box)

		var title := Label.new()
		title.text = "%s  -  %s" % [tr(stage["name_key"]), tr("UNLOCK_OPEN") if unlocked else tr("UNLOCK_LOCKED")]
		title.modulate = MonthReport.GREEN if unlocked else Color.WHITE
		title.add_theme_font_size_override("font_size", 24)
		box.add_child(title)

		var assets := Label.new()
		assets.text = UiText.stage_assets_text(stage_num)
		assets.modulate = MonthReport.MUTED
		assets.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		assets.add_theme_font_size_override("font_size", 19)
		box.add_child(assets)

		if not unlocked:
			var reqs := VBoxContainer.new()
			UiText.fill_requirements(reqs, stage)
			box.add_child(reqs)
		%UnlockList.add_child(card)


func _on_start_quiz() -> void:
	var question := GameState.start_quiz()
	if not question.is_empty():
		quiz_requested.emit(question)


func _on_watch_ad() -> void:
	AdService.show_rewarded(GameState.grant_quiz_credit)
