extends ScrollContainer
## Tab Karier (dulu Aktivitas, tema "Senja Cuan"): pekerjaan & lowongan (v1.5b), pendidikan &
## keahlian, aktivitas bulanan (energi), level & XP, kuis (jatah mingguan, tanpa iklan), dan
## progres unlock instrumen.

## Main yang menampilkan popup kuis (lewat antrean popup), screen ini hanya meminta.
signal quiz_requested(question: Dictionary)
## Tombol "Berhenti kerja" ditekan; main menampilkan konfirmasi.
signal resign_requested
## Tombol "Daftar" program kuliah / "Berhenti kuliah" ditekan; main menampilkan konfirmasi.
signal enroll_requested(program_id: String)
signal quit_study_requested

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
## Ikon & warna kotak per bidang pekerjaan (assets/icons/tracks/<bidang>.svg, cadangan: dompet).
const TRACK_ICON := "res://assets/icons/tracks/%s.svg"
const TRACK_ICON_FALLBACK := "res://assets/icons/wallet.svg"
const TRACK_TILES := {
	"retail": &"IconTileCoral", "admin": &"IconTileBlue", "finance": &"IconTileMint",
	"tech": &"IconTilePurple", "creative": &"IconTileGold", "gig": &"IconTileCoral",
}
## Ikon program kuliah (assets/icons/education/<d3|s1|s2>.svg, cadangan: ikon kursus).
const EDUCATION_ICON := "res://assets/icons/education/%s.svg"

var _job_box: VBoxContainer    # isi kartu Pekerjaan (dibangun ulang saat data berubah)
var _board_box: VBoxContainer  # daftar lowongan bulan ini
var _education_box: VBoxContainer  # isi kartu Pendidikan & Keahlian

## activity_id -> { button, faded: Array[Control], cost: Label, used: Label, reason: Label }
var _activity_rows: Dictionary = {}


func _ready() -> void:
	%StartQuizButton.pressed.connect(_on_start_quiz)
	_build_career_sections()
	_build_activities()
	GameState.changed.connect(_refresh)
	visibility_changed.connect(_refresh)  # jatah kuis bisa reset karena waktu nyata berjalan
	_refresh()


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	_refresh_job()
	_refresh_board()
	_refresh_education()
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


# --- Pekerjaan & lowongan (v1.5b) --------------------------------------------

## Judul + kartu Pekerjaan di paling atas; judul + daftar Lowongan dan kartu Pendidikan &
## Keahlian setelah kartu energi; lalu judul untuk daftar aktivitas yang sudah ada.
func _build_career_sections() -> void:
	var page: VBoxContainer = $VBox
	var job_card := PanelContainer.new()
	job_card.theme_type_variation = &"HomeCard"
	_job_box = VBoxContainer.new()
	_job_box.add_theme_constant_override("separation", 10)
	job_card.add_child(_job_box)
	page.add_child(job_card)
	page.move_child(job_card, 0)
	var job_title := _section_title(tr("CAREER_JOB_TITLE"))
	page.add_child(job_title)
	page.move_child(job_title, 0)

	_board_box = VBoxContainer.new()
	_board_box.add_theme_constant_override("separation", 12)
	var education_card := PanelContainer.new()
	education_card.theme_type_variation = &"HomeCard"
	_education_box = VBoxContainer.new()
	_education_box.add_theme_constant_override("separation", 10)
	education_card.add_child(_education_box)
	var index := %FeedbackBox.get_index() + 1
	for node: Control in [_section_title(tr("CAREER_BOARD_TITLE")), _board_box,
			_section_title(tr("EDU_TITLE")), education_card, _section_title(tr("ACT_LIST_TITLE"))]:
		page.add_child(node)
		page.move_child(node, index)
		index += 1


func _section_title(text: String) -> Label:
	var label := _label(text, &"SubSectionLabel")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Pekerjaan sekarang (atau "Belum bekerja" + lamaran terkirim) dan bekal karier pemain.
## Pekerjaan berjenjang juga menampilkan kinerja & syarat promosi (v1.5b langkah 2).
func _refresh_job() -> void:
	_clear(_job_box)
	if GameState.is_employed():
		var def := GameState.current_job_def()
		var track := GameState.track_def(def["track"])
		var hired := int(GameState.job.get("hired", GameState.job["since"]))
		_job_box.add_child(_job_head(def, "%s · %s" % [tr(track["name"]), GameState.job["company"]],
			tr("CAREER_PER_MONTH") % Fmt.rupiah(GameState.salary)))
		var info := tr("CAREER_SINCE") % [Fmt.game_date(hired), GameState.month - hired]
		if GameState.is_career():
			info = tr("CAREER_LEVEL") % int(def["level"]) + " · " + info
		if GameState.income_volatility() > 0.0:
			info += " · " + tr("HOME_INCOME_VARIES") % roundi(GameState.income_volatility() * 100)
		if GameState.unpaid_months > 0:
			info += "\n" + tr("CAREER_UNPAID") % GameState.unpaid_months
		_job_box.add_child(_wrap(info, &"SmallMutedLabel"))
		if GameState.is_career():
			_add_performance()
			_add_promotion()
		else:
			_job_box.add_child(_wrap(tr("CAREER_GIG_NOTE"), &"SmallMutedLabel"))
		var resign := UiText.chunky_button(tr("CAREER_RESIGN"), &"NeutralButton", &"NeutralButtonLabel", 56.0, 20)
		resign.custom_minimum_size.x = 240
		resign.size_flags_horizontal = Control.SIZE_SHRINK_END
		resign.disabled = GameState.has_pending_event() or GameState.is_over
		resign.pressed.connect(func() -> void: resign_requested.emit())
		_job_box.add_child(resign)
	else:
		var title := _label(tr("CAREER_UNEMPLOYED"), &"AssetNameLabel")
		title.add_theme_color_override("font_color", Palette.LOSS)
		_job_box.add_child(title)
		_job_box.add_child(_wrap(tr("CAREER_UNEMPLOYED_HINT"), &"SmallMutedLabel"))
	if not GameState.applications.is_empty():
		var sent: Array[String] = []
		for application: Dictionary in GameState.applications:
			sent.append(tr("CAREER_SENT_ITEM") % [tr(GameState.job_def(application["job_id"])["title"]),
				roundi(float(application["chance"]) * 100)])
		_job_box.add_child(_wrap(tr("CAREER_SENT") % ", ".join(sent), &"InfoLabel"))


## Kinerja sekarang (angka, predikat, bar) dan penyusun targetnya + aturan kenaikan prestasi.
func _add_performance() -> void:
	var value := roundi(GameState.performance)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := _label(tr("CAREER_PERFORMANCE") % [value, tr(GameState.performance_label())], &"ReqLabel")
	label.add_theme_color_override("font_color",
		Palette.GAIN if value >= 60 else (Palette.INK if value >= 40 else Palette.LOSS))
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"XpBar"
	bar.custom_minimum_size = Vector2(0, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.max_value = 100
	bar.value = value
	row.add_child(bar)
	_job_box.add_child(row)
	var factors := GameState.performance_factors()
	var merit: Array[String] = []
	for item: Array in GameState.job_data["merit_raise"]["by_performance"]:
		if float(item[1]) > 0.0:
			merit.append(tr("CAREER_MERIT_ITEM") % [_percent_short(float(item[1])), int(item[0])])
	_job_box.add_child(_wrap(tr("CAREER_PERFORMANCE_INFO") % [roundi(factors["target"]), roundi(factors["skill"]),
		roundi(factors["wellbeing"]), ", ".join(merit)], &"SmallMutedLabel"))


## Jabatan berikutnya beserta syarat promosinya (✓/✗), atau keterangan jenjang tertinggi.
func _add_promotion() -> void:
	var next := GameState.next_job_def()
	if next.is_empty():
		_job_box.add_child(_wrap(tr("CAREER_PROMOTION_TOP"), &"SmallMutedLabel"))
		return
	_job_box.add_child(_wrap(tr("CAREER_PROMOTION_NEXT") % [tr(next["title"]),
		tr("CAREER_PER_MONTH") % Fmt.rupiah(GameState.promotion_salary())], &"InfoLabel"))
	var reqs := HFlowContainer.new()
	reqs.add_theme_constant_override("h_separation", 12)
	reqs.add_theme_constant_override("v_separation", 2)
	for req: Dictionary in GameState.promotion_requirements():
		var label := _label("%s %s" % ["✓" if req["met"] else "✗", _requirement_text(req, next)], &"ReqLabel")
		label.add_theme_color_override("font_color", Palette.GAIN if req["met"] else Palette.LOSS)
		reqs.add_child(label)
	_job_box.add_child(reqs)
	if GameState.promotion_ready():
		var ready := _wrap(tr("CAREER_PROMOTION_READY"), &"SmallMutedLabel")
		ready.add_theme_color_override("font_color", Palette.GAIN)
		_job_box.add_child(ready)


## Kartu per lowongan: nama, bidang & perusahaan, gaji, syarat ✓/✗, peluang, tombol Lamar.
func _refresh_board() -> void:
	_clear(_board_box)
	_board_box.add_child(_wrap(tr("CAREER_BOARD_HINT") % [int(GameState.job_data["applications_per_month"]),
		int(GameState.job_data["apply_energy"])], &"SmallMutedLabel"))
	for i in GameState.job_board.size():
		var opening: Dictionary = GameState.job_board[i]
		var def := GameState.job_def(opening["job_id"])
		var track := GameState.track_def(def["track"])
		var card := PanelContainer.new()
		card.theme_type_variation = &"HomeCard"
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		card.add_child(box)
		var sub := "%s · %s" % [tr(track["name"]), opening["company"]]
		if def["track"] != "gig":
			sub = "%s · %s" % [tr("CAREER_LEVEL") % int(def["level"]), sub]
		box.add_child(_job_head(def, sub, tr("CAREER_PER_MONTH") % Fmt.rupiah(opening["salary"])))

		var reqs := HFlowContainer.new()
		reqs.add_theme_constant_override("h_separation", 12)
		reqs.add_theme_constant_override("v_separation", 2)
		for req: Dictionary in GameState.job_requirements(def):
			var label := _label("%s %s" % ["✓" if req["met"] else "✗", _requirement_text(req, def)], &"ReqLabel")
			label.add_theme_color_override("font_color", Palette.GAIN if req["met"] else Palette.LOSS)
			reqs.add_child(label)
		if reqs.get_child_count() == 0:
			reqs.add_child(_label("✓ " + tr("CAREER_NO_REQUIREMENTS"), &"ReqLabel"))
		box.add_child(reqs)

		var footer := HBoxContainer.new()
		footer.add_theme_constant_override("separation", 8)
		var chance := GameState.hire_chance(def)
		var chance_chip := _text_chip(tr("CAREER_CHANCE") % roundi(chance * 100),
			&"MoodGreen" if chance >= 0.7 else (&"MoodGold" if chance > 0.0 else &"MoodRed"))
		chance_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		footer.add_child(chance_chip)
		if float(def.get("volatility", 0.0)) > 0.0:
			var varies := _text_chip(tr("CAREER_VARIES") % roundi(float(def["volatility"]) * 100), &"MoodNeutral")
			varies.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			footer.add_child(varies)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		footer.add_child(spacer)
		var reason := GameState.apply_block_reason(i)
		var button := UiText.chunky_button(tr("CAREER_APPLY") if reason == "" else tr(reason + "_SHORT"),
			&"PrimaryButton" if reason == "" else &"NeutralButton",
			&"PrimaryButtonLabel" if reason == "" else &"NeutralButtonLabel", 60.0, 20)
		button.custom_minimum_size.x = 200
		button.disabled = reason != ""
		button.pressed.connect(_on_apply.bind(i))
		footer.add_child(button)
		box.add_child(footer)
		_board_box.add_child(card)


func _job_head(def: Dictionary, sub: String, value: String) -> HBoxContainer:
	var icon := TRACK_ICON % def["track"]
	return _head(icon if ResourceLoader.exists(icon) else TRACK_ICON_FALLBACK,
		TRACK_TILES.get(def["track"], &"IconTileGold"), tr(def["title"]), sub, value)


## Baris kepala kartu: ikon | judul & keterangan | nilai di kanan.
func _head(icon: String, tile: StringName, title: String, sub: String, value: String) -> HBoxContainer:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(UiText.icon_tile(icon, tile))
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	texts.add_child(_wrap(title, &"AssetNameLabel"))
	texts.add_child(_wrap(sub, &"SmallMutedLabel"))
	head.add_child(texts)
	var value_label := _label(value, &"AssetValueLabel")
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(value_label)
	return head


func _requirement_text(req: Dictionary, def: Dictionary) -> String:
	match req["type"]:
		"education":
			return tr("CAREER_REQ_EDUCATION") % GameState.education_name(int(req["need"]))
		"skill":
			return tr("CAREER_REQ_SKILL") % [int(req["need"]), floori(req["have"])]
		"experience":
			return tr("CAREER_REQ_EXPERIENCE") % [int(req["need"]), tr(GameState.track_def(def["track"])["name"]), int(req["have"])]
		"tenure":
			return tr("CAREER_REQ_TENURE") % [int(req["need"]), int(req["have"])]
		"performance":
			return tr("CAREER_REQ_PERFORMANCE") % [int(req["need"]), int(req["have"])]
	return ""


func _on_apply(index: int) -> void:
	var result := GameState.apply_job(index)
	%FeedbackBox.show()
	if result["ok"]:
		Sfx.play("success")
		var opening: Dictionary = GameState.job_board[index]
		%ActivityFeedback.text = tr("CAREER_APPLIED") % tr(GameState.job_def(opening["job_id"])["title"])
		%FeedbackBox.theme_type_variation = &"FeedbackGood"
		%ActivityFeedback.add_theme_color_override("font_color", Color("#1e5e45"))
	else:
		%ActivityFeedback.text = tr(result["error"])
		%FeedbackBox.theme_type_variation = &"FeedbackBad"
		%ActivityFeedback.add_theme_color_override("font_color", Palette.LOSS)


# --- Pendidikan & keahlian (v1.5b langkah 3) ----------------------------------

## Bekal pemain (pendidikan, keahlian, pengalaman), lalu kuliah yang sedang berjalan atau
## daftar program kuliah yang bisa diambil.
func _refresh_education() -> void:
	_clear(_education_box)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	chips.add_child(_text_chip(tr("CAREER_EDUCATION") % GameState.education_name(GameState.education), &"SmallChipGold"))
	chips.add_child(_text_chip(tr("CAREER_SKILL") % floori(GameState.skill), &"SmallChipGold"))
	for track: Dictionary in GameState.job_data["tracks"]:
		var months := int(GameState.experience.get(track["id"], 0))
		if months > 0:
			chips.add_child(_text_chip(tr("CAREER_EXPERIENCE") % [tr(track["name"]), months], &"SmallChipNeutral"))
	_education_box.add_child(chips)
	var factor := pow(maxf(1.0 - GameState.skill / 100.0, 0.0), float(GameState.job_data.get("skill_curve", 1.0)))
	_education_box.add_child(_wrap(tr("EDU_SKILL_NOTE") % roundi(factor * 100.0), &"SmallMutedLabel"))

	if GameState.is_studying():
		_add_study()
		return
	var options := GameState.available_programs()
	if options.is_empty():
		_education_box.add_child(_wrap(tr("EDU_TOP") % GameState.education_name(GameState.education), &"InfoLabel"))
	for option: Dictionary in options:
		_add_program(option)


## Kuliah yang sedang berjalan: kemajuan, uang kuliah, beasiswa, beban, tombol berhenti.
func _add_study() -> void:
	var study := GameState.study
	var def := GameState.program_def(study["id"])
	var total := int(study["months_total"])
	var done := total - int(study["months_left"])
	var sub := tr("EDU_GRADUATES") % Fmt.game_date(GameState.graduation_month())
	sub = (tr("EDU_PROGRESS") % [done, total] if GameState.month >= int(study["since"]) else tr("EDU_STARTS_NEXT")) + " · " + sub
	var fee := GameState.tuition_fee()
	_education_box.add_child(_head(_program_icon(def), &"IconTileBlue", tr(def["name"]), sub,
		tr("CAREER_PER_MONTH") % Fmt.rupiah(fee) if fee > 0 else tr("EDU_FREE")))
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"XpBar"
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	bar.max_value = total
	bar.value = done
	_education_box.add_child(bar)
	var notes: Array[String] = []
	if GameState.study_sponsored():
		notes.append(tr("EDU_SPONSORED") % study["sponsor"])
	elif float(study["scholarship"]) > 0.0:
		notes.append(tr("EDU_SCHOLARSHIP") % roundi(float(study["scholarship"]) * 100.0))
	var load: Dictionary = GameState.education_data["load"]
	notes.append(tr("EDU_LOAD") % [int(load["energy"]), -int(load["happiness"])])
	_education_box.add_child(_wrap("\n".join(notes), &"SmallMutedLabel"))
	var quit := UiText.chunky_button(tr("EDU_QUIT"), &"NeutralButton", &"NeutralButtonLabel", 56.0, 20)
	quit.custom_minimum_size.x = 240
	quit.size_flags_horizontal = Control.SIZE_SHRINK_END
	quit.disabled = GameState.has_pending_event() or GameState.is_over
	quit.pressed.connect(func() -> void: quit_study_requested.emit())
	_education_box.add_child(quit)


## Satu program kuliah yang bisa diambil: lama, biaya, hasil, tombol Daftar.
func _add_program(option: Dictionary) -> void:
	var def: Dictionary = option["def"]
	var fee := int(option["fee"])
	var months := int(option["months"])
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_head(_program_icon(def), &"IconTileBlue", tr(def["name"]),
		tr("EDU_PROGRAM_SUB") % [months, def["result"]], tr("CAREER_PER_MONTH") % Fmt.rupiah(fee)))
	box.add_child(_wrap(tr(def["desc"]), &"SmallMutedLabel"))
	var load: Dictionary = GameState.education_data["load"]
	box.add_child(_wrap(tr("EDU_PROGRAM_INFO") % [Fmt.rupiah(fee * months), int(def["skill"]),
		int(load["energy"]), -int(load["happiness"])], &"SmallMutedLabel"))
	var reason := GameState.enroll_block_reason(def["id"])
	var button := UiText.chunky_button(tr("EDU_ENROLL") if reason == "" else tr(reason + "_SHORT"),
		&"PrimaryButton" if reason == "" else &"NeutralButton",
		&"PrimaryButtonLabel" if reason == "" else &"NeutralButtonLabel", 60.0, 20)
	button.custom_minimum_size.x = 200
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.disabled = reason != ""
	button.pressed.connect(func() -> void: enroll_requested.emit(def["id"]))
	box.add_child(button)
	_education_box.add_child(box)


func _program_icon(def: Dictionary) -> String:
	var icon := EDUCATION_ICON % def["id"]
	return icon if ResourceLoader.exists(icon) else ACTIVITY_ICON % "course"


func _text_chip(text: String, variation: StringName) -> PanelContainer:
	var label_variation := &"MoodLabel"
	if variation == &"SmallChipGold":
		label_variation = &"SmallChipGoldLabel"
	elif variation == &"SmallChipNeutral":
		label_variation = &"SmallChipNeutralLabel"
	return _chip(_label(text, label_variation), variation)


## 0.03 -> "3", 0.015 -> "1,5" (tanpa nol di belakang koma).
func _percent_short(ratio: float) -> String:
	var value := snappedf(ratio * 100.0, 0.1)
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return String.num(value, 1).replace(".", ",")


func _wrap(text: String, variation: StringName) -> Label:
	var label := _label(text, variation)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1
	return label


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

		var desc := _label(UiText.money(tr(def["desc"])), &"SmallMutedLabel")
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
		var cost := GameState.activity_cost(def)
		row["cost"].text = Fmt.rupiah(cost) if cost > 0 else tr("ACT_FREE")
		var used: int = GameState.activity_counts.get(def["id"], 0)
		row["used"].text = tr("ACT_ITEM_USED") % [used, int(def.get("max_per_month", 1))]
		var reason := GameState.activity_block_reason(def)
		row["reason"].text = tr(reason) if reason != "" else ""
		if reason == "ERR_ACTIVITY_COOLDOWN":
			row["reason"].text = tr(reason) % GameState.activity_cooldown_left(def)
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
