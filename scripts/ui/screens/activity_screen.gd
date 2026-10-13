extends ScrollContainer
## Tab Aktivitas (tema "Senja Cuan"): aktivitas bulanan (energi), level & XP,
## kuis (jatah mingguan, tanpa iklan), dan progres unlock instrumen.

## Main yang menampilkan popup kuis (lewat antrean popup), screen ini hanya meminta.
signal quiz_requested(question: Dictionary)

const TOPICS := ["basics", "risk", "scam", "instruments"]
const BOLT_ICON := preload("res://assets/icons/bolt.svg")
const BOLT_FULL := Color("#ffc95c")
const BOLT_EMPTY := Color("#5a4e78")
const ACTIVITY_ICON := "res://assets/icons/activities/%s.svg"
const ACTIVITY_TILES := {
	"side_job": &"IconTileGold", "course": &"IconTileBlue", "self_study": &"IconTileMint",
	"exercise": &"IconTileCoral", "hangout": &"IconTilePurple", "rest": &"IconTileBlue",
}
const DIMMED := Color(1, 1, 1, 0.5)

## activity_id -> { button, faded: Array[Control], cost: Label, used: Label, reason: Label }
var _activity_rows: Dictionary = {}


func _ready() -> void:
	%StartQuizButton.pressed.connect(_on_start_quiz)
	_build_activities()
	GameState.changed.connect(_refresh)
	visibility_changed.connect(_refresh)  # jatah kuis bisa reset karena waktu nyata berjalan
	_refresh()


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	_refresh_energy()
	_refresh_activities()

	var per_level := int(GameState.economy["xp_per_level"])
	%LevelNumber.text = str(GameState.level())
	%LevelLabel.text = tr("ACT_LEVEL") % GameState.level()
	%XpLabel.text = tr("ACT_XP_DETAIL") % [GameState.xp, GameState.xp_in_level(), per_level]
	%XpBar.max_value = per_level
	%XpBar.value = GameState.xp_in_level()

	var quiz := GameState.quiz
	var free_left := quiz.free_left()
	%QuizInfo.text = tr("ACT_QUIZ_INFO") % [free_left, int(GameState.economy["quiz"]["free_per_week"])]
	%StartQuizButton.disabled = not quiz.can_start()
	%StartQuizButton.get_child(0).modulate = DIMMED if %StartQuizButton.disabled else Color.WHITE

	_clear(%TopicChips)
	for topic: String in TOPICS:
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"TopicChip"
		chip.add_child(_label("%s  %d" % [tr("TOPIC_" + topic.to_upper()), quiz.correct_in_topic(topic)],
				&"TopicChipLabel"))
		%TopicChips.add_child(chip)

	_build_unlocks()


## Satu ikon petir per poin energi bulan ini: kuning = tersisa, ungu redup = terpakai.
func _refresh_energy() -> void:
	%EnergyTitle.text = "%s · %s" % [tr("ACT_ENERGY_TITLE"),
		tr("ACT_ENERGY_COUNT") % [GameState.energy, GameState.energy_capacity]]
	while %EnergyIcons.get_child_count() < GameState.energy_capacity:
		var bolt := TextureRect.new()
		bolt.texture = BOLT_ICON
		bolt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bolt.custom_minimum_size = Vector2(24, 30)
		%EnergyIcons.add_child(bolt)
	for i in %EnergyIcons.get_child_count():
		var bolt: TextureRect = %EnergyIcons.get_child(i)
		bolt.visible = i < GameState.energy_capacity
		bolt.self_modulate = BOLT_FULL if i < GameState.energy else BOLT_EMPTY


## Kartu tahap unlock: hijau jika sudah terbuka; jika belum, daftar syarat merah/hijau.
func _build_unlocks() -> void:
	_clear(%UnlockList)
	for stage: Dictionary in GameState.stage_defs:
		var stage_num := int(stage["stage"])
		var unlocked := GameState.is_stage_unlocked(stage_num)
		var card := PanelContainer.new()
		card.theme_type_variation = &"UnlockOpenCard" if unlocked else &"HomeCard"
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		card.add_child(box)

		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 12)
		var badge := PanelContainer.new()
		badge.theme_type_variation = &"NumberBadge"
		badge.custom_minimum_size = Vector2(40, 40)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var number := _label(str(stage_num), &"NumberLabel")
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(number)
		var title := _label(tr(stage["name_key"]), &"AssetNameLabel")
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var status := PanelContainer.new()
		status.theme_type_variation = &"ChipWhite" if unlocked else &"MoodNeutral"
		status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var status_label := _label(tr("UNLOCK_OPEN") if unlocked else tr("UNLOCK_LOCKED"), &"MoodLabel")
		if unlocked:
			status_label.add_theme_color_override("font_color", Palette.GAIN)
		status.add_child(status_label)
		head.add_child(badge)
		head.add_child(title)
		head.add_child(status)
		box.add_child(head)

		var assets := _label(UiText.stage_assets_text(stage_num), &"SmallMutedLabel")
		assets.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(assets)

		if not unlocked:
			var reqs := VBoxContainer.new()
			reqs.add_theme_constant_override("separation", 4)
			UiText.fill_requirements(reqs, stage)
			box.add_child(reqs)
		%UnlockList.add_child(card)


func _on_start_quiz() -> void:
	var question := GameState.start_quiz()
	if not question.is_empty():
		quiz_requested.emit(question)


# --- Aktivitas bulanan (energi) ---------------------------------------------

## Satu kartu per aktivitas: ikon | nama, chip (energi, biaya, jumlah dipakai), deskripsi, alasan terkunci.
func _build_activities() -> void:
	for def: Dictionary in GameState.activity_defs():
		var id: String = def["id"]
		var button := ChunkyButton.new()
		button.theme_type_variation = &"ActivityRowButton"
		button.press_depth = 5.0
		button.pressed.connect(_on_activity.bind(id))

		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.offset_bottom = -5  # bibir bawah tombol
		for side: String in ["left", "right"]:
			margin.add_theme_constant_override("margin_" + side, 16)
		for side: String in ["top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 12)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		margin.add_child(row)

		var tile := UiText.icon_tile(ACTIVITY_ICON % id, ACTIVITY_TILES.get(id, &"IconTileGold"))
		row.add_child(tile)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 4)
		row.add_child(text)

		var name_label := _label(tr(def["name"]), &"AssetNameLabel")
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(name_label)

		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 6)
		chips.add_theme_constant_override("v_separation", 4)
		chips.add_child(_energy_chip(int(def["energy"])))
		var cost_label := _label("", &"SmallChipGoldLabel")
		chips.add_child(_chip(cost_label, &"SmallChipGold"))
		var used_label := _label("", &"SmallChipNeutralLabel")
		chips.add_child(_chip(used_label, &"SmallChipNeutral"))
		text.add_child(chips)

		var desc := _label(tr(def["desc"]), &"SmallMutedLabel")
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(desc)
		var reason := _label("", &"ReasonLabel")
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(reason)

		_ignore_mouse(margin)  # klik diteruskan ke Button
		button.add_child(margin)
		%ActivityList.add_child(button)
		UiText.fit_to_content(button, margin, 5.0)
		_activity_rows[id] = {"button": button, "faded": [tile, name_label, chips, desc],
			"cost": cost_label, "used": used_label, "reason": reason}


func _refresh_activities() -> void:
	for def: Dictionary in GameState.activity_defs():
		var row: Dictionary = _activity_rows[def["id"]]
		var cost := int(def.get("cost", 0))
		row["cost"].text = Fmt.rupiah(cost) if cost > 0 else tr("ACT_FREE")
		var used: int = GameState.activity_counts.get(def["id"], 0)
		row["used"].text = tr("ACT_ITEM_USED") % [used, int(def.get("max_per_month", 1))]
		var reason := GameState.activity_block_reason(def)
		row["reason"].text = tr(reason) if reason != "" else ""
		row["reason"].visible = reason != ""
		row["button"].disabled = reason != ""
		for node: Control in row["faded"]:
			node.modulate = DIMMED if reason != "" else Color.WHITE


func _on_activity(activity_id: String) -> void:
	var result := GameState.do_activity(activity_id)
	%FeedbackBox.show()
	if result["ok"]:
		Sfx.play("success")
		%ActivityFeedback.text = tr("ACT_DONE") % UiText.changes_text(result["changes"])
		%FeedbackBox.theme_type_variation = &"FeedbackGood"
		%ActivityFeedback.add_theme_color_override("font_color", Color("#1e5e45"))
	else:
		%ActivityFeedback.text = tr(result["error"])
		%FeedbackBox.theme_type_variation = &"FeedbackBad"
		%ActivityFeedback.add_theme_color_override("font_color", Palette.LOSS)


# --- bantuan ------------------------------------------------------------------

func _energy_chip(energy: int) -> PanelContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var bolt := TextureRect.new()
	bolt.texture = BOLT_ICON
	bolt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bolt.custom_minimum_size = Vector2(10, 13)
	bolt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bolt.self_modulate = BOLT_FULL
	box.add_child(bolt)
	box.add_child(_label(str(energy), &"EnergyChipLabel"))
	return _chip(box, &"EnergyChip")


func _chip(content: Control, variation: StringName) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = variation
	chip.add_child(content)
	return chip


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
