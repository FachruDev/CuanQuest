extends VBoxContainer
## Tab Karier v2 (tema "Senja Cuan"): tiga bagian lewat tombol segmen di atas (dulu 7-9 layar gulir). Strip
## energi & umpan balik aksi selalu tampil di bawah segmen (tidak ikut digulir).
## - Kerja     : pekerjaan sekarang (kinerja + penanda syarat promosi, syarat promosi, BPJS), lowongan bulan ini
##               (yang bisa dilamar dulu; yang belum memenuhi syarat dilipat)
## - Aktivitas : aktivitas bulanan (ubin 2 kolom), proyek sampingan (pilih cara mengerjakan, lalu Ambil proyek)
## - Belajar   : level & XP, kuis finansial, tahap membuka instrumen, pendidikan & keahlian

## Main yang menampilkan popup kuis (lewat antrean popup), screen ini hanya meminta.
signal quiz_requested(question: Dictionary)
## Tombol "Berhenti kerja" ditekan; main menampilkan konfirmasi.
signal resign_requested
## Tombol "Daftar" program kuliah / "Berhenti kuliah" ditekan; main menampilkan konfirmasi.
signal enroll_requested(program_id: String)
signal quit_study_requested
## Proyek sampingan diterima (main menampilkan petunjuk pertama kali).
signal contract_accepted
## Penjelasan yang dibuka dari tab ini (cara kinerja dihitung, semua tahap unlock): InfoPopup.open_rich.
signal popup_requested(title: String, blocks: Array)

enum Page { WORK, ACTIVITIES, LEARN }
const PAGE_KEYS: Array[String] = ["CAREER_SEG_WORK", "CAREER_SEG_ACTIVITIES", "CAREER_SEG_LEARN"]
const BOLT_ICON := preload("res://assets/icons/bolt.svg")
const BOLT_FULL := Color("#ffc95c")
const BOLT_EMPTY := Color("#5a4e78")
const ACTIVITY_ICON := "res://assets/icons/activities/%s.svg"
const ACTIVITY_TILES := {
	"side_job": &"IconTileGold", "course": &"IconTileBlue", "self_study": &"IconTileMint",
	"exercise": &"IconTileCoral", "hangout": &"IconTilePurple", "rest": &"IconTileBlue",
	"counseling": &"IconTileMint",
}
## Cadangan ikon aktivitas yang gambarnya belum ada (mis. Konseling, v2b langkah 4).
const ACTIVITY_ICON_FALLBACK := "res://assets/icons/heart.svg"
const DIMMED := Color(1, 1, 1, 0.5)
## Ikon program kuliah (assets/icons/education/<d3|s1|s2>.svg, cadangan: ikon kursus).
const EDUCATION_ICON := "res://assets/icons/education/%s.svg"
const SHIELD_ICON := "res://assets/icons/shield.svg"
const REQ_OK := preload("res://assets/icons/req_ok.svg")
const REQ_NO := preload("res://assets/icons/req_no.svg")
## Warna chip status lowongan yang tidak bisa dilamar (alasan dari Career.apply_block_reason).
const APPLY_STATUS_CHIPS := {"ERR_JOB_APPLIED": &"MoodGold", "ERR_JOB_CURRENT": &"MoodGreen"}
## Syarat unlock yang punya angka (ditampilkan dengan bar kemajuan).
const NUMERIC_REQS := ["emergency_fund", "net_worth", "level", "quiz_topic", "research_correct", "credit_score"]
const TRACK_LINE := Color("#f4eadb")
const TRACK_TODO := Color("#fbf6ee")
const TRACK_TODO_RING := Color("#e2c79a")

var _page := Page.WORK
var _segments: Array[Button] = []
var _pages: Array[VBoxContainer] = []
var _render: Dictionary = {}  # kunci data terakhir per bagian (UiText.changed_key)

# --- Kerja
var _job_box: VBoxContainer  # isi kartu Pekerjaan
var _board_chip: PanelContainer  # "N lamaran tersisa"
var _board_chip_label: Label
var _board_box: VBoxContainer  # lowongan bulan ini
var _show_locked_jobs := false

# --- Aktivitas
## activity_id -> { button, faded: Array[Control], cost: Label, used: Label, reason: Label }
var _activity_rows: Dictionary = {}
var _reputation_label: Label
var _contract_box: VBoxContainer  # proyek sampingan: yang dikerjakan & tawaran bulan ini (v1.5d)
var _strategy_pick: Dictionary = {}  # indeks tawaran -> id cara mengerjakan yang dipilih

# --- Belajar
var _level_number: Label
var _level_label: Label
var _xp_label: Label
var _xp_bar: ProgressBar
var _xp_note: Label
var _quiz_info: Label
var _quiz_button: Button
var _topic_grid: GridContainer
var _unlock_chip_label: Label
var _unlock_box: VBoxContainer
var _education_box: VBoxContainer


func _ready() -> void:
	_pages = [%Work, %Activities, %Learn]
	_build_segments()
	_build_work()
	_build_activities()
	_build_learn()
	GameState.changed.connect(_refresh)
	visibility_changed.connect(_refresh)  # jatah kuis bisa reset karena waktu nyata berjalan
	show_page(Page.WORK)


func show_page(page: int) -> void:
	_page = page
	for i in _pages.size():
		_pages[i].visible = i == page
		_segments[i].set_pressed_no_signal(i == page)
	%FeedbackBox.hide()
	%Scroll.scroll_vertical = 0
	_refresh()


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	_refresh_energy()
	match _page:
		Page.WORK:
			_refresh_work()
		Page.ACTIVITIES:
			_refresh_activities()
			_refresh_contracts()
		Page.LEARN:
			_refresh_learn()


func _build_segments() -> void:
	var group := ButtonGroup.new()
	for i in PAGE_KEYS.size():
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = &"SegmentButton"
		button.text = tr(PAGE_KEYS[i])
		button.add_theme_font_size_override("font_size", 20)
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(show_page.bind(i))
		%Segments.get_node("Row").add_child(button)
		_segments.append(button)


## Satu ikon petir per poin energi bulan ini (kuning = tersisa, ungu redup = terpakai) + pemakai energi tetap.
func _refresh_energy() -> void:
	var activities := GameState.activities
	%EnergyTitle.text = tr("ACT_ENERGY_COUNT") % [activities.energy, activities.energy_capacity]
	var used: PackedStringArray = []
	if GameState.contracts.month_energy > 0:  # energi yang dipakai proyek sampingan bulan ini
		used.append(tr("ACT_ENERGY_PROJECTS") % GameState.contracts.month_energy)
	if GameState.life.energy_change() != 0:  # v2b: usia 60+
		used.append(tr("ACT_ENERGY_AGE") % GameState.life.energy_change())
	if GameState.fund.energy_cost() > 0:  # v2c: rapat & laporan investor dana kelolaan
		used.append(tr("ACT_ENERGY_FUND") % GameState.fund.energy_cost())
	%EnergyNote.text = (" · ".join(used) + ". " if not used.is_empty() else "") + tr("ACT_ENERGY_NOTE")
	while %EnergyIcons.get_child_count() < activities.energy_capacity:
		var bolt := TextureRect.new()
		bolt.texture = BOLT_ICON
		bolt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bolt.custom_minimum_size = Vector2(20, 26)
		%EnergyIcons.add_child(bolt)
	for i in %EnergyIcons.get_child_count():
		var bolt: TextureRect = %EnergyIcons.get_child(i)
		bolt.visible = i < activities.energy_capacity
		bolt.self_modulate = BOLT_FULL if i < activities.energy else BOLT_EMPTY


func _show_feedback(ok: bool, text: String) -> void:
	%FeedbackBox.show()
	%ActivityFeedback.text = text
	%FeedbackBox.theme_type_variation = &"FeedbackGood" if ok else &"FeedbackBad"
	%ActivityFeedback.add_theme_color_override("font_color", Color("#1e5e45") if ok else Palette.LOSS)
	if ok:
		Sfx.play("success")


# ==================================================================================================
# Kerja
# ==================================================================================================

func _build_work() -> void:
	var page: VBoxContainer = %Work
	var job_card := _card(12)
	_job_box = job_card.get_child(0)
	page.add_child(job_card)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var title := _wrap(tr("CAREER_BOARD_TITLE"), &"SubSectionLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_board_chip_label = _label("", &"MoodLabel")
	_board_chip = _chip(_board_chip_label, &"MoodNeutral")
	_board_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_board_chip)
	page.add_child(head)
	_board_box = VBoxContainer.new()
	_board_box.add_theme_constant_override("separation", 12)
	page.add_child(_board_box)


func _refresh_work() -> void:
	var career := GameState.career
	var busy := [GameState.events.has_pending(), GameState.is_over, GameState.activities.energy]
	var base := [GameState.run_id, GameState.month, Fmt.compact] + busy
	if UiText.changed_key(_render, "job", base + [GameState.life.retired, career.job, roundi(career.performance),
			floori(career.skill), career.salary, career.unpaid_months, career.applications.size(),
			GameState.contracts.active.size(), GameState.education.level, GameState.characters.rel_of("coworker")]):
		_refresh_job()
	if UiText.changed_key(_render, "board", base + [career.job_board, career.applications.size(), floori(career.skill),
			GameState.education.level, career.experience, career.job, career.salary, _show_locked_jobs]):
		_refresh_board()


## Pekerjaan sekarang (atau masa pensiun / belum bekerja) dan lamaran yang sudah dikirim.
func _refresh_job() -> void:
	_clear(_job_box)
	var career := GameState.career
	var life := GameState.life
	if life.retired:  # v2b: masa pensiun
		var title := _label(tr("CAREER_RETIRED"), &"AssetNameLabel")
		title.add_theme_color_override("font_color", Palette.GAIN)
		_job_box.add_child(title)
		var info: Dictionary = life.retirement_info
		_job_box.add_child(_wrap(tr("CAREER_RETIRED_INFO") % [Fmt.game_date(life.retired_month),
			Fmt.rupiah(life.pension_payment()), Fmt.rupiah(info.get("jht", 0))], &"SmallMutedLabel"))
		_job_box.add_child(_wrap(tr("CAREER_RETIRED_HINT"), &"SmallMutedLabel"))
	elif career.is_employed():
		var def := career.current_job_def()
		var track := career.track_def(def["track"])
		_job_box.add_child(_head(UiText.track_icon(def["track"]), UiText.track_tile(def["track"]), tr(def["title"]),
			"%s · %s" % [career.job["company"], tr(track["name"])], Fmt.rupiah(career.salary), tr("CAREER_PER_MONTH_SUB"), 56.0))
		var hired := int(career.job.get("hired", career.job["since"]))
		var chips := _flow()
		if career.is_career():
			chips.add_child(_small_chip(tr("CAREER_LEVEL") % int(def["level"])))
		chips.add_child(_small_chip(tr("CAREER_SINCE_CHIP") % [Fmt.game_date(hired), GameState.month - hired]))
		if career.income_volatility() > 0.0:
			chips.add_child(_small_chip(tr("HOME_INCOME_VARIES") % roundi(career.income_volatility() * 100)))
		if career.unpaid_months > 0:
			chips.add_child(_chip(_label(tr("CAREER_UNPAID") % career.unpaid_months, &"MoodLabel"), &"MoodRed"))
		_job_box.add_child(chips)
		if career.is_career():
			_add_performance()
			_job_box.add_child(_divider())
			_add_promotion()
			_job_box.add_child(_divider())
			_add_bpjs()
		else:
			_job_box.add_child(_wrap(tr("CAREER_GIG_NOTE"), &"SmallMutedLabel"))
		var resign := UiText.chunky_button(tr("CAREER_RESIGN"), &"NeutralButton", &"NeutralButtonLabel", 50.0, 18)
		resign.custom_minimum_size.x = 210
		resign.size_flags_horizontal = Control.SIZE_SHRINK_END
		resign.disabled = GameState.events.has_pending() or GameState.is_over
		resign.pressed.connect(func() -> void: resign_requested.emit())
		_job_box.add_child(resign)
	else:
		var title := _label(tr("CAREER_UNEMPLOYED"), &"AssetNameLabel")
		title.add_theme_color_override("font_color", Palette.LOSS)
		_job_box.add_child(title)
		_job_box.add_child(_wrap(tr("CAREER_UNEMPLOYED_HINT"), &"SmallMutedLabel"))
	if not career.applications.is_empty():
		var sent: Array[String] = []
		for application: Dictionary in career.applications:
			sent.append(tr("CAREER_SENT_ITEM") % [tr(career.job_def(application["job_id"])["title"]),
				roundi(float(application["chance"]) * 100)])
		_job_box.add_child(_wrap(tr("CAREER_SENT") % ", ".join(sent), &"InfoLabel"))


## Kinerja (angka, predikat, bar dengan penanda syarat promosi) + tautan penjelasan cara kinerja dihitung.
func _add_performance() -> void:
	var career := GameState.career
	var value := roundi(career.performance)
	var need := 0
	if not career.next_job_def().is_empty():
		for req: Dictionary in career.promotion_requirements():
			if req["type"] == "performance":
				need = int(req["need"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := _label(tr("CAREER_PERFORMANCE") % [value, tr(career.performance_label())], &"AssetNameLabel")
	label.add_theme_color_override("font_color", Palette.GAIN if value >= 60 else (Palette.INK if value >= 40 else Palette.LOSS))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	if need > 0:
		var target := _label(tr("CAREER_PROMO_NEEDS") % need, &"SmallMutedLabel")
		target.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(target)
	_job_box.add_child(row)
	_job_box.add_child(_marked_bar(value / 100.0, need / 100.0))
	var link := Button.new()
	link.flat = true
	link.focus_mode = Control.FOCUS_NONE
	link.text = tr("CAREER_PERF_HOW") + "  ›"
	link.alignment = HORIZONTAL_ALIGNMENT_LEFT
	link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	link.add_theme_font_size_override("font_size", 16)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		link.add_theme_color_override(state, Palette.MUTED)
	link.pressed.connect(func() -> void: popup_requested.emit(tr("CAREER_PERF_HOW"), _performance_blocks()))
	_job_box.add_child(link)


## Isi popup "Cara kinerja dihitung": penyusun target kinerja dan aturan kenaikan prestasi tahunan.
func _performance_blocks() -> Array:
	var career := GameState.career
	var factors := career.performance_factors()
	var merit: Array[String] = []
	for item: Array in career.data["merit_raise"]["by_performance"]:
		if float(item[1]) > 0.0:
			merit.append(tr("CAREER_MERIT_ITEM") % [UiText.percent_short(float(item[1])).trim_suffix("%"), int(item[0])])
	var info := tr("CAREER_PERFORMANCE_INFO") % [roundi(factors["target"]), roundi(factors["skill"]),
		roundi(factors["wellbeing"]), ", ".join(merit)]
	if float(factors["team"]) > 0.0:  # rekan kerja yang dekat (v1.5d)
		info += " " + tr("CAREER_TEAM_BONUS") % [GameState.characters.name_of("coworker"), roundi(factors["team"])]
	if float(factors["side"]) > 0.0:  # terlalu banyak proyek sampingan (v1.5d)
		info += " " + tr("CAREER_SIDE_PENALTY") % roundi(factors["side"])
	return [{"lead": tr("CAREER_PERFORMANCE") % [roundi(career.performance), tr(career.performance_label())]},
		{"text": info}]


## Jabatan berikutnya: judul + gaji, jumlah syarat terpenuhi, dan kotak syarat 2 kolom (atau jenjang tertinggi).
func _add_promotion() -> void:
	var career := GameState.career
	var next := career.next_job_def()
	if next.is_empty():
		_job_box.add_child(_wrap(tr("CAREER_PROMOTION_TOP"), &"SmallMutedLabel"))
		return
	var reqs := career.promotion_requirements()
	var met := reqs.filter(func(r: Dictionary) -> bool: return r["met"]).size()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	texts.add_child(_label(tr("CAREER_PROMO_CAPS").to_upper(), &"TileCapsLabel"))
	texts.add_child(_wrap(tr("CAREER_PROMO_HEAD") % [tr(next["title"]), Fmt.rupiah(career.promotion_salary())], &"AssetNameLabel"))
	head.add_child(texts)
	var progress := _chip(_label(tr("CAREER_PROMO_PROGRESS") % [met, reqs.size()], &"MoodLabel"),
		&"MoodGreen" if met == reqs.size() else &"MoodGold")
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(progress)
	_job_box.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for req: Dictionary in reqs:
		grid.add_child(_req_tile(_requirement_text(req, next), req["met"]))
	_job_box.add_child(grid)
	if career.promotion_ready():
		var ready := _wrap(tr("CAREER_PROMOTION_READY"), &"SmallMutedLabel")
		ready.add_theme_color_override("font_color", Palette.GAIN)
		_job_box.add_child(ready)


## Kotak satu syarat: hijau muda + centang (terpenuhi) atau merah muda + silang (belum).
func _req_tile(text: String, met: bool) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f1faf5") if met else Color("#fdebe4")
	style.set_corner_radius_all(14)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	tile.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.texture = REQ_OK if met else REQ_NO
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(18, 22)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var label := _wrap(text, &"ReqLabel")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color("#1e6b4e") if met else Color("#a63a20"))
	row.add_child(label)
	tile.add_child(row)
	return tile


## BPJS Ketenagakerjaan: saldo JHT dan masa iuran Jaminan Pensiun (bar menuju minimal 15 tahun).
func _add_bpjs() -> void:
	var life := GameState.life
	var min_years := int(life.data["retirement"]["jp_min_years"])
	var years := floori(life.jp_months / 12.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UiText.icon_tile(SHIELD_ICON, &"IconTileMint", 40.0))
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	var name_label := _label(tr("CAREER_BPJS_TITLE"), &"RowValueLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	head.add_child(_label(tr("CAREER_BPJS_JHT") % Fmt.rupiah(roundi(life.jht)), &"RowLabel"))
	box.add_child(head)
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"XpBar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.max_value = min_years
	bar.value = mini(years, min_years)
	box.add_child(bar)
	var pension := life.projected_pension()
	box.add_child(_wrap(tr("CAREER_BPJS_JP_READY") % Fmt.rupiah(pension) if pension > 0
		else tr("CAREER_BPJS_JP") % [years, min_years], &"SmallMutedLabel"))
	row.add_child(box)
	_job_box.add_child(row)


## Lowongan: yang syaratnya terpenuhi lebih dulu, yang belum dilipat di balik satu tombol.
func _refresh_board() -> void:
	_clear(_board_box)
	var career := GameState.career
	_board_chip.visible = not GameState.life.retired
	if GameState.life.retired:  # v2b: tidak melamar kerja lagi
		_board_box.add_child(_wrap(tr("CAREER_RETIRED_BOARD"), &"SmallMutedLabel"))
		return
	var left := maxi(0, int(career.data["applications_per_month"]) - career.applications.size())
	_board_chip_label.text = tr("CAREER_BOARD_LEFT") % left
	_board_box.add_child(_wrap(tr("CAREER_BOARD_HINT") % [int(career.data["applications_per_month"]),
		int(career.data["apply_energy"])], &"SmallMutedLabel"))
	if GameState.life.hire_mult() < 1.0:  # v2b: usia 50+
		_board_box.add_child(_wrap(tr("CAREER_AGE_HINT") % roundi((1.0 - GameState.life.hire_mult()) * 100.0), &"SmallMutedLabel"))
	var locked: Array[int] = []
	for i in career.job_board.size():
		var def := career.job_def(career.job_board[i]["job_id"])
		if career.meets_requirements(def):
			_board_box.add_child(_job_card(i))
		else:
			locked.append(i)
	if locked.is_empty():
		return
	var toggle := UiText.chunky_button(tr("CAREER_BOARD_LOCKED") % locked.size() + ("  ▴" if _show_locked_jobs else "  ▾"),
		&"NeutralButton", &"NeutralButtonLabel", 54.0, 18)
	toggle.pressed.connect(func() -> void:
		_show_locked_jobs = not _show_locked_jobs
		_refresh_board())
	_board_box.add_child(toggle)
	if _show_locked_jobs:
		for i in locked:
			_board_box.add_child(_job_card(i))


## Kartu satu lowongan: kepala, syarat ✓/✗, chip peluang & selisih gaji, tombol Lamar (atau chip status).
func _job_card(index: int) -> PanelContainer:
	var career := GameState.career
	var opening: Dictionary = career.job_board[index]
	var def := career.job_def(opening["job_id"])
	var track := career.track_def(def["track"])
	var card := _card(10)
	var box: VBoxContainer = card.get_child(0)
	var sub := "%s · %s" % [tr(track["name"]), opening["company"]]
	if def["track"] != "gig":
		sub = "%s · %s" % [tr("CAREER_LEVEL") % int(def["level"]), sub]
	box.add_child(_head(UiText.track_icon(def["track"]), UiText.track_tile(def["track"]), tr(def["title"]), sub,
		tr("CAREER_PER_MONTH") % Fmt.rupiah(opening["salary"]), "", 44.0))
	var reqs := _flow(12, 2)
	for req: Dictionary in career.requirements(def):
		reqs.add_child(UiText.requirement_row(_requirement_text(req, def), req["met"], false))
	if reqs.get_child_count() == 0:
		reqs.add_child(UiText.requirement_row(tr("CAREER_NO_REQUIREMENTS"), true, false))
	box.add_child(reqs)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	var chips := _flow(6, 6)
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var chance := career.hire_chance(def)
	chips.add_child(_chip(_label(tr("CAREER_CHANCE") % roundi(chance * 100), &"MoodLabel"),
		&"MoodGreen" if chance >= 0.7 else (&"MoodGold" if chance > 0.0 else &"MoodRed")))
	if float(def.get("volatility", 0.0)) > 0.0:
		chips.add_child(_chip(_label(tr("CAREER_VARIES") % roundi(float(def["volatility"]) * 100), &"MoodLabel"), &"MoodNeutral"))
	if career.is_employed() and career.salary > 0:  # selisih gaji dengan pekerjaan sekarang
		var diff := roundi((float(opening["salary"]) / float(career.salary) - 1.0) * 100.0)
		if diff != 0:
			chips.add_child(_chip(_label(tr("CAREER_SALARY_DIFF") % ("%+d%%" % diff), &"MoodLabel"),
				&"MoodGreen" if diff > 0 else &"MoodRed"))
	footer.add_child(chips)
	var reason := career.apply_block_reason(index)
	if reason == "":
		var button := UiText.chunky_button(tr("CAREER_APPLY"), &"PrimaryButton", &"PrimaryButtonLabel", 52.0, 20)
		button.custom_minimum_size.x = 140
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_on_apply.bind(index))
		footer.add_child(button)
	else:  # tidak bisa melamar: cukup chip status (tombol nonaktif bertulisan panjang jadi dua baris)
		var status := _chip(_label(tr(reason + "_SHORT"), &"MoodLabel"), APPLY_STATUS_CHIPS.get(reason, &"MoodNeutral"))
		status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		footer.add_child(status)
	box.add_child(footer)
	return card


func _requirement_text(req: Dictionary, def: Dictionary) -> String:
	match req["type"]:
		"education":
			return tr("CAREER_REQ_EDUCATION") % GameState.education.level_name(int(req["need"]))
		"skill":
			return tr("CAREER_REQ_SKILL") % [int(req["need"]), floori(req["have"])]
		"experience":
			return tr("CAREER_REQ_EXPERIENCE") % [int(req["need"]), tr(GameState.career.track_def(def["track"])["name"]), int(req["have"])]
		"tenure":
			return tr("CAREER_REQ_TENURE") % [int(req["need"]), int(req["have"])]
		"performance":
			return tr("CAREER_REQ_PERFORMANCE") % [int(req["need"]), int(req["have"])]
	return ""


func _on_apply(index: int) -> void:
	var result := GameState.career.apply_job(index)
	if result["ok"]:
		var opening: Dictionary = GameState.career.job_board[index]
		_show_feedback(true, tr("CAREER_APPLIED") % tr(GameState.career.job_def(opening["job_id"])["title"]))
	else:
		_show_feedback(false, tr(result["error"]))


# ==================================================================================================
# Aktivitas
# ==================================================================================================

func _build_activities() -> void:
	var page: VBoxContainer = %Activities
	page.add_child(_label(tr("ACT_ENERGY_TITLE"), &"SubSectionLabel"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	page.add_child(grid)
	for def: Dictionary in GameState.activities.defs():
		grid.add_child(_activity_tile(def))

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var title := _wrap(tr("CONTRACT_TITLE"), &"SubSectionLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_reputation_label = _label("", &"MoodLabel")
	var reputation := _chip(_reputation_label, &"MoodGreen")
	reputation.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(reputation)
	page.add_child(head)
	_contract_box = VBoxContainer.new()
	_contract_box.add_theme_constant_override("separation", 12)
	page.add_child(_contract_box)


## Ubin satu aktivitas: ikon + chip energi | nama | deskripsi | chip biaya & jumlah dipakai | alasan terkunci.
func _activity_tile(def: Dictionary) -> Button:
	var id: String = def["id"]
	var button := ChunkyButton.new()
	button.theme_type_variation = &"ActivityRowButton"
	button.press_depth = 5.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_activity.bind(id))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_bottom = -5  # bibir bawah tombol
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	var top := HBoxContainer.new()
	var icon_path := ACTIVITY_ICON % id
	if not ResourceLoader.exists(icon_path):
		icon_path = ACTIVITY_ICON_FALLBACK
	var tile := UiText.icon_tile(icon_path, ACTIVITY_TILES.get(id, &"IconTileGold"), 46.0)
	top.add_child(tile)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var energy := _energy_chip(int(def["energy"]))
	energy.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(energy)
	box.add_child(top)
	var name_label := _wrap(tr(def["name"]), &"AssetNameLabel")
	box.add_child(name_label)
	var desc := _wrap(UiText.money(tr(def["desc"])), &"SmallMutedLabel")
	box.add_child(desc)
	var chips := _flow(6, 4)
	var cost_label := _label("", &"SmallChipGoldLabel")
	chips.add_child(_chip(cost_label, &"SmallChipGold"))
	var used_label := _label("", &"SmallChipNeutralLabel")
	chips.add_child(_chip(used_label, &"SmallChipNeutral"))
	box.add_child(chips)
	var reason := _wrap("", &"ReasonLabel")
	box.add_child(reason)
	_ignore_mouse(margin)  # klik diteruskan ke Button
	button.add_child(margin)
	UiText.fit_to_content(button, margin, 5.0)
	_activity_rows[id] = {"button": button, "faded": [top, name_label, desc, chips], "cost": cost_label, "used": used_label,
		"reason": reason}
	return button


func _refresh_activities() -> void:
	for def: Dictionary in GameState.activities.defs():
		var row: Dictionary = _activity_rows[def["id"]]
		row["button"].visible = GameState.activities.is_shown(def)  # Konseling hanya saat suasana hati rendah (v2b)
		var cost := GameState.activities.cost(def)
		row["cost"].text = Fmt.rupiah(cost) if cost > 0 else tr("ACT_FREE")
		var used: int = GameState.activities.counts.get(def["id"], 0)
		row["used"].text = tr("ACT_ITEM_USED") % [used, int(def.get("max_per_month", 1))]
		var reason := GameState.activities.block_reason(def)
		row["reason"].text = tr(reason) if reason != "" else ""
		if reason == "ERR_ACTIVITY_COOLDOWN":
			row["reason"].text = tr(reason) % GameState.activities.cooldown_left(def)
		row["reason"].visible = reason != ""
		row["button"].disabled = reason != ""
		for node: Control in row["faded"]:
			node.modulate = DIMMED if reason != "" else Color.WHITE


func _on_activity(activity_id: String) -> void:
	var result := GameState.activities.perform(activity_id)
	if result["ok"]:
		_show_feedback(true, tr("ACT_DONE") % UiText.changes_text(result["changes"]))
	else:
		_show_feedback(false, tr(result["error"]))


## Proyek sampingan (v1.5d): reputasi, proyek yang sedang dikerjakan, lalu tawaran bulan ini.
func _refresh_contracts() -> void:
	var contracts := GameState.contracts
	var key := [GameState.run_id, GameState.month, Fmt.compact, GameState.activities.energy, contracts.reputation,
		contracts.active, contracts.board, floori(GameState.career.skill), GameState.events.has_pending(), _strategy_pick]
	if not UiText.changed_key(_render, "contracts", key):
		return
	_clear(_contract_box)
	_reputation_label.text = tr("CONTRACT_REPUTATION_CHIP") % [contracts.reputation, roundi(contracts.reputation_bonus() * 100.0)]
	_contract_box.add_child(_wrap(tr("CONTRACT_ACTIVE_HINT") % [contracts.active.size(), int(contracts.data["max_active"])],
		&"SmallMutedLabel"))
	for c: Dictionary in contracts.active:
		_contract_box.add_child(_active_contract_card(c))
	if contracts.board.is_empty():
		_contract_box.add_child(_wrap(tr("CONTRACT_NONE"), &"InfoLabel"))
	for i in contracts.board.size():
		_contract_box.add_child(_offer_card(i))


## Proyek yang sedang dikerjakan: kartu hijau dengan sisa bulan, peluang berhasil, dan energi per bulan.
func _active_contract_card(c: Dictionary) -> PanelContainer:
	var contracts := GameState.contracts
	var card := PanelContainer.new()
	card.theme_type_variation = &"UnlockOpenCard"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var head := _head(UiText.track_icon(c["track"]), UiText.track_tile(c["track"]), tr("CONTRACT_" + str(c["id"]).to_upper()),
		"%s · %s" % [c["client"], tr("CONTRACT_STRATEGY_" + str(c["strategy"]).to_upper())],
		Fmt.rupiah(contracts.pay_for(c, c["strategy"])), "", 44.0)
	var caps := _label(tr("CONTRACT_ACTIVE_CAPS").to_upper(), &"TileCapsLabel")
	caps.add_theme_color_override("font_color", Palette.GAIN)
	head.get_child(1).add_child(caps)
	head.get_child(1).move_child(caps, 0)
	box.add_child(head)
	var cfg: Dictionary = contracts.data["chance"]
	var chance := float(c["chance"])
	if c["revision"]:
		chance += float(cfg["revision_bonus"])
	if c["short"]:
		chance += float(cfg["short_energy"])
	chance = clampf(chance, float(cfg["min"]), float(cfg["max"]))
	var chips := _flow(8, 6)
	chips.add_child(_chip(_label(tr("CONTRACT_CHANCE_CHIP") % roundi(chance * 100.0), &"MoodLabel"), &"MoodGreen"))
	chips.add_child(_small_chip(tr("CONTRACT_LEFT_CHIP") % [int(c["months_left"]),
		Fmt.game_date(GameState.month + int(c["months_left"]))]))
	chips.add_child(_small_chip(tr("CONTRACT_ENERGY_CHIP") % int(contracts.strategy_def(c["strategy"])["energy"])))
	box.add_child(chips)
	if c["revision"]:
		box.add_child(_wrap(tr("CONTRACT_REVISING"), &"SmallMutedLabel"))
	if c["short"]:
		box.add_child(_wrap(tr("CONTRACT_SHORT"), &"SmallMutedLabel"))
	return card


## Tawaran: kepala, deskripsi, keahlian disarankan & catatan pasar, pilihan cara mengerjakan (energi · peluang),
## penjelasan cara yang dipilih, dan tombol Ambil proyek.
func _offer_card(index: int) -> PanelContainer:
	var contracts := GameState.contracts
	var offer: Dictionary = contracts.board[index]
	var def := contracts.project_def(offer["id"])
	var card := _card(10)
	var box: VBoxContainer = card.get_child(0)
	box.add_child(_head(UiText.track_icon(offer["track"]), UiText.track_tile(offer["track"]),
		tr("CONTRACT_" + str(offer["id"]).to_upper()), tr("CONTRACT_OFFER_SUB") % [offer["client"], int(offer["months"])],
		Fmt.rupiah(offer["pay"]), "", 44.0))
	box.add_child(_wrap(tr("CONTRACT_%s_DESC" % str(offer["id"]).to_upper()), &"SmallMutedLabel"))
	var notes := _flow(8, 6)
	var need := int(contracts.tier_def(int(offer["tier"]))["skill"])
	var skilled := GameState.career.skill >= need
	notes.add_child(_chip(_label(tr("CONTRACT_SKILL") % [need, floori(GameState.career.skill)], &"MoodLabel"),
		&"MoodGreen" if skilled else &"MoodRed"))
	if float(offer.get("regime_mult", 1.0)) > 1.0:
		notes.add_child(_small_chip(tr("CONTRACT_MARKET_UP") % roundi((float(offer["regime_mult"]) - 1.0) * 100.0)))
	elif float(offer.get("regime_mult", 1.0)) < 1.0:
		notes.add_child(_small_chip(tr("CONTRACT_MARKET_DOWN") % roundi((1.0 - float(offer["regime_mult"])) * 100.0)))
	if def.has("pay_asset"):
		notes.add_child(_small_chip(tr("CONTRACT_TOKEN") % def["pay_asset"]))
	box.add_child(notes)

	var pick: String = _strategy_pick.get(index, "")
	if pick == "":
		pick = "careful"
		if contracts.accept_block_reason(index, pick) != "":  # cara teliti tidak bisa: pilih cara lain yang bisa
			for strategy: Dictionary in contracts.strategies():
				if contracts.accept_block_reason(index, strategy["id"]) == "":
					pick = strategy["id"]
					break
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for strategy: Dictionary in contracts.strategies():
		var id: String = strategy["id"]
		var option := Button.new()
		option.toggle_mode = true
		option.button_group = group
		option.theme_type_variation = &"PeriodButton"
		option.text = "%s\n%s · %d%%" % [tr("CONTRACT_STRATEGY_" + id.to_upper()), tr("RESEARCH_ENERGY") % int(strategy["energy"]),
			roundi(contracts.chance_for(offer, id) * 100.0)]
		option.add_theme_font_size_override("font_size", 16)
		option.custom_minimum_size = Vector2(0, 66)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.button_pressed = id == pick
		option.pressed.connect(func() -> void:
			_strategy_pick[index] = id
			_refresh_contracts())
		options.add_child(option)
	box.add_child(options)
	var desc := tr("CONTRACT_STRATEGY_%s_DESC" % pick.to_upper())
	if pick == "team":
		desc = desc % roundi(float(contracts.strategy_def("team")["pay_share"]) * 100.0)
	box.add_child(_wrap(tr("CONTRACT_PICK_NOTE") % [tr("CONTRACT_STRATEGY_" + pick.to_upper()), desc], &"SmallMutedLabel"))
	var reason := contracts.accept_block_reason(index, pick)
	var take := UiText.chunky_button(tr("CONTRACT_TAKE") % tr("CONTRACT_STRATEGY_" + pick.to_upper()),
		&"PrimaryButton" if reason == "" else &"NeutralButton", &"PrimaryButtonLabel" if reason == "" else &"NeutralButtonLabel",
		58.0, 20)
	take.disabled = reason != ""
	take.pressed.connect(_on_accept_contract.bind(index, pick))
	box.add_child(take)
	if reason != "":
		box.add_child(_wrap(tr(reason), &"ReasonLabel"))
	return card


func _on_accept_contract(index: int, strategy_id: String) -> void:
	var offer: Dictionary = GameState.contracts.board[index].duplicate()
	var result := GameState.contracts.accept(index, strategy_id)
	if result["ok"]:
		_strategy_pick.clear()  # indeks tawaran bergeser setelah satu diambil
		_show_feedback(true, tr("CONTRACT_ACCEPTED") % [tr("CONTRACT_" + str(offer["id"]).to_upper()),
			Fmt.game_date(GameState.month + int(offer["months"]))])
		contract_accepted.emit()
	else:
		_show_feedback(false, tr(result["error"]))


# ==================================================================================================
# Belajar
# ==================================================================================================

func _build_learn() -> void:
	var page: VBoxContainer = %Learn
	var level_card := PanelContainer.new()
	level_card.theme_type_variation = &"HomeCard"
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 14)
	var badge := PanelContainer.new()
	badge.theme_type_variation = &"LevelBadge"
	badge.custom_minimum_size = Vector2(56, 56)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_level_number = _label("", &"LevelBadgeLabel")
	_level_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(_level_number)
	level_row.add_child(badge)
	var stat := VBoxContainer.new()
	stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	_level_label = _label("", &"StatNameLabel")
	_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_level_label)
	_xp_label = _label("", &"MutedLabel")
	head.add_child(_xp_label)
	stat.add_child(head)
	_xp_bar = ProgressBar.new()
	_xp_bar.theme_type_variation = &"XpBar"
	_xp_bar.custom_minimum_size = Vector2(0, 14)
	_xp_bar.show_percentage = false
	stat.add_child(_xp_bar)
	_xp_note = _wrap("", &"SmallMutedLabel")
	stat.add_child(_xp_note)
	level_row.add_child(stat)
	level_card.add_child(level_row)
	page.add_child(level_card)

	page.add_child(_label(tr("ACT_QUIZ_TITLE"), &"SubSectionLabel"))
	var quiz := _card(12)
	var quiz_box: VBoxContainer = quiz.get_child(0)
	var quiz_head := HBoxContainer.new()
	quiz_head.add_theme_constant_override("separation", 14)
	var mark_tile := PanelContainer.new()
	mark_tile.theme_type_variation = &"IconTileTeal"
	mark_tile.custom_minimum_size = Vector2(48, 48)
	mark_tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var mark := _label("?", &"TileMarkLabel")
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark_tile.add_child(mark)
	quiz_head.add_child(mark_tile)
	var quiz_texts := VBoxContainer.new()
	quiz_texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quiz_texts.add_theme_constant_override("separation", 2)
	_quiz_info = _wrap("", &"AssetNameLabel")
	quiz_texts.add_child(_quiz_info)
	quiz_texts.add_child(_wrap(tr("CAREER_QUIZ_NOTE"), &"SmallMutedLabel"))
	quiz_head.add_child(quiz_texts)
	quiz_box.add_child(quiz_head)
	_quiz_button = UiText.chunky_button(tr("ACT_START_QUIZ"), &"PrimaryButton", &"PrimaryButtonLabel", 64.0, 24)
	_quiz_button.pressed.connect(_on_start_quiz)
	quiz_box.add_child(_quiz_button)
	quiz_box.add_child(_label(tr("ACT_TOPIC_TITLE").to_upper(), &"TileCapsLabel"))
	_topic_grid = GridContainer.new()
	_topic_grid.columns = 2
	_topic_grid.add_theme_constant_override("h_separation", 24)
	_topic_grid.add_theme_constant_override("v_separation", 4)
	quiz_box.add_child(_topic_grid)
	page.add_child(quiz)

	var unlock_head := HBoxContainer.new()
	unlock_head.add_theme_constant_override("separation", 12)
	var unlock_title := _wrap(tr("ACT_UNLOCK_TITLE"), &"SubSectionLabel")
	unlock_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlock_head.add_child(unlock_title)
	_unlock_chip_label = _label("", &"MoodLabel")
	var unlock_chip := _chip(_unlock_chip_label, &"MoodNeutral")
	unlock_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	unlock_head.add_child(unlock_chip)
	page.add_child(unlock_head)
	var unlock := _card(14)
	_unlock_box = unlock.get_child(0)
	page.add_child(unlock)

	page.add_child(_label(tr("EDU_TITLE"), &"SubSectionLabel"))
	var education := _card(12)
	_education_box = education.get_child(0)
	page.add_child(education)


func _refresh_learn() -> void:
	var progress := GameState.progress
	var per_level := int(GameState.economy["xp_per_level"])
	_level_number.text = str(progress.level())
	_level_label.text = tr("ACT_LEVEL") % progress.level()
	_xp_label.text = tr("ACT_XP_SHORT") % [progress.xp_in_level(), per_level]
	_xp_note.text = tr("ACT_XP_NOTE") % progress.xp
	_xp_bar.max_value = per_level
	_xp_bar.value = progress.xp_in_level()

	var quiz := GameState.quiz
	var per_week := int(GameState.economy["quiz"]["free_per_week"])
	_quiz_info.text = tr("CAREER_QUIZ_LEFT") % [quiz.free_left(), per_week]
	_quiz_button.disabled = not quiz.can_start()
	_quiz_button.get_child(0).modulate = DIMMED if _quiz_button.disabled else Color.WHITE
	if UiText.changed_key(_render, "topics", [GameState.run_id, quiz.correct_ids.size(), quiz.topics]):
		_clear(_topic_grid)
		for topic: String in quiz.topics:
			var count := quiz.correct_in_topic(topic)
			var row := HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var name_label := _label(tr("TOPIC_" + topic.to_upper()), &"RowLabel")
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var count_label := _label(str(count), &"RowValueLabel")
			if count == 0:
				name_label.add_theme_color_override("font_color", Palette.MUTED)
				count_label.add_theme_color_override("font_color", Palette.MUTED)
			row.add_child(name_label)
			row.add_child(count_label)
			_topic_grid.add_child(row)
	if UiText.changed_key(_render, "unlocks", [GameState.run_id, progress.unlocked_stages, progress.level(),
			roundi(GameState.net_worth() / 100_000.0), roundi(GameState.budget.emergency_balance() / 100_000.0),
			quiz.correct_ids.size(), GameState.tutorial_done, GameState.debt.credit_score, Fmt.compact]):
		_fill_unlocks()
	if UiText.changed_key(_render, "education", [GameState.run_id, GameState.month, Fmt.compact, GameState.education.level,
			GameState.education.study, floori(GameState.career.skill), GameState.career.experience, roundi(GameState.cash),
			GameState.events.has_pending(), GameState.is_over]):
		_fill_education()


## Tahap membuka instrumen: garis 7 tahap, tahap berikutnya + syarat dengan bar kemajuan, tombol semua tahap.
func _fill_unlocks() -> void:
	_clear(_unlock_box)
	var progress := GameState.progress
	var stages := progress.stage_defs
	var opened := 0
	var next: Dictionary = {}
	for stage: Dictionary in stages:
		if progress.is_stage_unlocked(int(stage["stage"])):
			opened += 1
		elif next.is_empty():
			next = stage
	_unlock_chip_label.text = tr("UNLOCK_COUNT") % [opened, stages.size()]
	_unlock_box.add_child(_stage_track(stages, int(next.get("stage", -1))))
	if next.is_empty():
		_unlock_box.add_child(_wrap(tr("UNLOCK_ALL_DONE"), &"InfoLabel"))
	else:
		var texts := VBoxContainer.new()
		texts.add_theme_constant_override("separation", 2)
		texts.add_child(_label(tr("UNLOCK_NEXT_CAPS").to_upper(), &"TileCapsLabel"))
		var name_label := _wrap(tr(next["name_key"]), &"AssetNameLabel")
		name_label.add_theme_font_size_override("font_size", 21)
		texts.add_child(name_label)
		texts.add_child(_wrap(UiText.stage_assets_text(int(next["stage"])), &"SmallMutedLabel"))
		_unlock_box.add_child(texts)
		for req: Dictionary in next["requirements"]:
			var status := progress.requirement_status(req)
			var item := VBoxContainer.new()
			item.add_theme_constant_override("separation", 4)
			item.add_child(UiText.requirement_row(UiText.requirement_text(req, status), status["met"]))
			if req["type"] in NUMERIC_REQS and float(status["target"]) > 0.0:
				var bar := ProgressBar.new()
				bar.theme_type_variation = &"XpBar"
				bar.show_percentage = false
				bar.custom_minimum_size = Vector2(0, 10)
				bar.max_value = 1.0
				bar.step = 0.001
				bar.value = clampf(float(status["current"]) / float(status["target"]), 0.0, 1.0)
				item.add_child(bar)
			_unlock_box.add_child(item)
	var all := UiText.chunky_button(tr("UNLOCK_SEE_ALL"), &"NeutralButton", &"NeutralButtonLabel", 54.0, 18)
	all.pressed.connect(func() -> void: popup_requested.emit(tr("ACT_UNLOCK_TITLE"), _stage_blocks()))
	_unlock_box.add_child(all)


## Garis tahap: bulatan per tahap (terbuka = teal + centang, berikutnya = emas + nomor, terkunci = krem + nomor)
## dengan garis penghubung yang terisi sampai tahap terakhir yang terbuka.
func _stage_track(stages: Array, next_stage: int) -> Control:
	var progress := GameState.progress
	var states: Array[String] = []
	for stage: Dictionary in stages:
		var number := int(stage["stage"])
		states.append("done" if progress.is_stage_unlocked(number) else ("next" if number == next_stage else "todo"))
	var track := Control.new()
	track.custom_minimum_size = Vector2(0, 56)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.draw.connect(_draw_track.bind(track, states, get_theme_font("font", &"LevelBadgeLabel")))
	return track


func _draw_track(track: Control, states: Array[String], font: Font) -> void:
	var count := states.size()
	if count < 2:
		return
	var y := track.size.y / 2.0
	var x0 := 26.0
	var step := (track.size.x - 52.0) / float(count - 1)
	track.draw_line(Vector2(x0, y), Vector2(x0 + step * (count - 1), y), TRACK_LINE, 6.0)
	var last_done := states.rfind("done")
	if last_done > 0:
		track.draw_line(Vector2(x0, y), Vector2(x0 + step * last_done, y), Palette.TEAL, 6.0)
	for i in count:
		var center := Vector2(x0 + step * i, y)
		if states[i] == "done":
			track.draw_circle(center, 20.0, Palette.INK)
			track.draw_circle(center, 17.0, Palette.TEAL)
			track.draw_polyline(PackedVector2Array([center + Vector2(-7, 0), center + Vector2(-2, 5), center + Vector2(7, -5)]),
				Color.WHITE, 3.0, true)
		elif states[i] == "next":
			track.draw_circle(center, 24.0, Palette.INK)
			track.draw_circle(center, 21.0, Palette.GOLD)
			_draw_number(track, font, center, str(i + 1), Palette.INK)
		else:
			track.draw_circle(center, 20.0, TRACK_TODO_RING)
			track.draw_circle(center, 17.0, TRACK_TODO)
			_draw_number(track, font, center, str(i + 1), Palette.MUTED)


func _draw_number(canvas: Control, font: Font, center: Vector2, text: String, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	canvas.draw_string(font, Vector2(center.x - text_size.x / 2.0, center.y + font.get_ascent(18) / 2.0 - 2.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)


## Isi popup "semua tahap": nama & status, instrumen yang dibuka, dan syarat (terpenuhi / belum) per tahap.
func _stage_blocks() -> Array:
	var progress := GameState.progress
	var blocks: Array = []
	for stage: Dictionary in progress.stage_defs:
		var number := int(stage["stage"])
		var opened := progress.is_stage_unlocked(number)
		blocks.append({"caps": "%s · %s" % [tr(stage["name_key"]), tr("UNLOCK_OPEN" if opened else "UNLOCK_LOCKED")]})
		blocks.append({"text": UiText.stage_assets_text(number)})
		if opened:
			continue
		var met: Array = []
		var missing: Array = []
		for req: Dictionary in stage["requirements"]:
			var status := progress.requirement_status(req)
			if status["met"]:
				met.append(UiText.requirement_text(req, status))
			else:
				missing.append(UiText.requirement_text(req, status))
		if not met.is_empty():
			blocks.append({"bullets": met, "dot": Palette.TEAL})
		if not missing.is_empty():
			blocks.append({"bullets": missing, "dot": Palette.LOSS})
	return blocks


func _on_start_quiz() -> void:
	var question := GameState.progress.start_quiz()
	if not question.is_empty():
		quiz_requested.emit(question)


## Bekal pemain (pendidikan, keahlian, pengalaman), lalu kuliah yang sedang berjalan atau program yang bisa diambil.
func _fill_education() -> void:
	_clear(_education_box)
	var career := GameState.career
	var total_months := 0
	var parts: PackedStringArray = []
	for track: Dictionary in career.data["tracks"]:
		var months := int(career.experience.get(track["id"], 0))
		if months > 0:
			total_months += months
			parts.append(tr("CAREER_EXPERIENCE") % [tr(track["name"]), months])
	var tiles := GridContainer.new()
	tiles.columns = 3
	tiles.add_theme_constant_override("h_separation", 10)
	for item: Array in [[tr("EDU_TILE_EDUCATION"), GameState.education.level_name(GameState.education.level)],
			[tr("EDU_TILE_SKILL"), str(floori(career.skill))], [tr("EDU_TILE_EXPERIENCE"), tr("EDU_MONTHS") % total_months]]:
		var tile := PanelContainer.new()
		tile.theme_type_variation = &"StatTile"
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		box.add_child(_label(item[0], &"TileCapsLabel"))
		box.add_child(_label(item[1], &"TileValueLabel"))
		tile.add_child(box)
		tiles.add_child(tile)
	_education_box.add_child(tiles)
	var factor := pow(maxf(1.0 - career.skill / 100.0, 0.0), float(career.data.get("skill_curve", 1.0)))
	var note := tr("EDU_SKILL_NOTE") % roundi(factor * 100.0)
	if not parts.is_empty():
		note = " · ".join(parts) + ". " + note
	_education_box.add_child(_wrap(note, &"SmallMutedLabel"))
	_education_box.add_child(_divider())
	if GameState.education.is_studying():
		_add_study()
		return
	var options := GameState.education.available_programs()
	if options.is_empty():
		_education_box.add_child(_wrap(tr("EDU_TOP") % GameState.education.level_name(GameState.education.level), &"InfoLabel"))
	for i in options.size():
		if i > 0:
			_education_box.add_child(_divider())
		_add_program(options[i])


## Kuliah yang sedang berjalan: kemajuan, uang kuliah, beasiswa, beban, tombol berhenti.
func _add_study() -> void:
	var education := GameState.education
	var study := education.study
	var def := education.program_def(study["id"])
	var total := int(study["months_total"])
	var done := total - int(study["months_left"])
	var sub := tr("EDU_GRADUATES") % Fmt.game_date(education.graduation_month())
	sub = (tr("EDU_PROGRESS") % [done, total] if GameState.month >= int(study["since"]) else tr("EDU_STARTS_NEXT")) + " · " + sub
	var fee := education.tuition_fee()
	_education_box.add_child(_head(_program_icon(def), &"IconTileBlue", tr(def["name"]), sub,
		Fmt.rupiah(fee) if fee > 0 else tr("EDU_FREE"), tr("CAREER_PER_MONTH_SUB") if fee > 0 else "", 44.0))
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"XpBar"
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	bar.max_value = total
	bar.value = done
	_education_box.add_child(bar)
	var notes: Array[String] = []
	if education.study_sponsored():
		notes.append(tr("EDU_SPONSORED") % study["sponsor"])
	elif float(study["scholarship"]) > 0.0:
		notes.append(tr("EDU_SCHOLARSHIP") % roundi(float(study["scholarship"]) * 100.0))
	var load: Dictionary = education.data["load"]
	notes.append(tr("EDU_LOAD") % [int(load["energy"]), -int(load["happiness"])])
	_education_box.add_child(_wrap("\n".join(notes), &"SmallMutedLabel"))
	var quit := UiText.chunky_button(tr("EDU_QUIT"), &"NeutralButton", &"NeutralButtonLabel", 50.0, 18)
	quit.custom_minimum_size.x = 210
	quit.size_flags_horizontal = Control.SIZE_SHRINK_END
	quit.disabled = GameState.events.has_pending() or GameState.is_over
	quit.pressed.connect(func() -> void: quit_study_requested.emit())
	_education_box.add_child(quit)


## Satu program kuliah: kepala (lama & hasil, biaya per bulan), deskripsi, chip total/keahlian/beban, tombol Daftar.
func _add_program(option: Dictionary) -> void:
	var def: Dictionary = option["def"]
	var fee := int(option["fee"])
	var months := int(option["months"])
	_education_box.add_child(_head(_program_icon(def), &"IconTileBlue", tr(def["name"]),
		tr("EDU_PROGRAM_SUB") % [months, def["result"]], Fmt.rupiah(fee), tr("CAREER_PER_MONTH_SUB"), 44.0))
	_education_box.add_child(_wrap(tr(def["desc"]), &"SmallMutedLabel"))
	var load: Dictionary = GameState.education.data["load"]
	var chips := _flow(8, 6)
	chips.add_child(_small_chip(tr("EDU_CHIP_TOTAL") % Fmt.rupiah(fee * months)))
	chips.add_child(_small_chip(tr("EDU_CHIP_SKILL") % int(def["skill"])))
	chips.add_child(_small_chip(tr("EDU_CHIP_LOAD") % [int(load["energy"]), -int(load["happiness"])]))
	_education_box.add_child(chips)
	var reason := GameState.education.enroll_block_reason(def["id"])
	var button := UiText.chunky_button(tr("EDU_ENROLL") if reason == "" else tr(reason + "_SHORT"),
		&"PrimaryButton" if reason == "" else &"NeutralButton",
		&"PrimaryButtonLabel" if reason == "" else &"NeutralButtonLabel", 56.0, 20)
	button.disabled = reason != ""
	button.pressed.connect(func() -> void: enroll_requested.emit(def["id"]))
	_education_box.add_child(button)


func _program_icon(def: Dictionary) -> String:
	var icon := EDUCATION_ICON % def["id"]
	return icon if ResourceLoader.exists(icon) else ACTIVITY_ICON % "course"


# ==================================================================================================
# Bantuan
# ==================================================================================================

## Kartu putih (HomeCard) berisi VBox dengan jarak `gap`; isi lewat get_child(0).
func _card(gap: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"HomeCard"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	card.add_child(box)
	return card


## Baris kepala kartu: ikon | judul & keterangan | nilai di kanan (+ keterangan kecil di bawah nilai).
func _head(icon: String, tile: StringName, title: String, sub: String, value: String, value_sub := "",
		tile_size := 48.0) -> HBoxContainer:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var icon_tile := UiText.icon_tile(icon, tile, tile_size)
	icon_tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(icon_tile)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 0)
	var title_label := _wrap(title, &"AssetNameLabel")
	if tile_size >= 56.0:
		title_label.add_theme_font_size_override("font_size", 22)
	texts.add_child(title_label)
	texts.add_child(_wrap(sub, &"SmallMutedLabel"))
	head.add_child(texts)
	var right := VBoxContainer.new()
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_theme_constant_override("separation", 0)
	var value_label := _label(value, &"AssetValueLabel")
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(value_label)
	if value_sub != "":
		var sub_label := _label(value_sub, &"SmallMutedLabel")
		sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(sub_label)
	head.add_child(right)
	return head


## Bar 0-1 dengan penanda tegak di `marker` (0 = tanpa penanda), mis. kinerja & syarat promosi.
func _marked_bar(value: float, marker: float) -> Control:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 22)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		var track_rect := Rect2(0, 4, bar.size.x, 14)
		var back := StyleBoxFlat.new()
		back.bg_color = TRACK_LINE
		back.set_corner_radius_all(7)
		bar.draw_style_box(back, track_rect)
		if value > 0.0:
			var fill := StyleBoxFlat.new()
			fill.bg_color = Palette.TEAL
			fill.set_corner_radius_all(7)
			bar.draw_style_box(fill, Rect2(0, 4, maxf(14.0, bar.size.x * clampf(value, 0.0, 1.0)), 14))
		if marker > 0.0:
			bar.draw_rect(Rect2(bar.size.x * marker - 2.0, 0, 4, 22), Palette.INK))
	return bar


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


func _small_chip(text: String) -> PanelContainer:
	var label := _label(text, &"SmallChipNeutralLabel")
	label.add_theme_color_override("font_color", Palette.INK)
	return _chip(label, &"SmallChipNeutral")


func _flow(h_gap := 8, v_gap := 6) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", h_gap)
	flow.add_theme_constant_override("v_separation", v_gap)
	return flow


func _divider() -> Panel:
	var line := Panel.new()
	line.theme_type_variation = &"Divider"
	line.custom_minimum_size = Vector2(0, 2)
	return line


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label


func _wrap(text: String, variation: StringName) -> Label:
	var label := _label(text, variation)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1
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
