extends VBoxContainer
## Tab Profil v2 (tema "Senja Cuan"): empat bagian lewat tombol segmen di atas (dulu ±12 layar gulir).
## - Ringkasan : kartu pemain, target kemenangan (cincin), perjalanan hidup per bab, statistik & daya beli,
##               profil risiko
## - Kisah     : orang terdekat, perjalanan karier, rekam jejak riset, riwayat permainan
## - Koleksi   : tampilan (bingkai avatar & gelar) dan grid lencana pencapaian (ketuk = detail)
## - Atur      : simpan & muat, pengaturan, menu lainnya, sesi bermain (hanya saat info performa aktif),
##               hapus semua data

signal glossary_requested
signal text_requested(title: String, body: String)
## Menu "Laporan Tahunan Terakhir" ditekan (v1.5d).
signal annual_requested
## Lencana di bagian Koleksi diketuk (Profil v2): buka popup detail.
signal achievement_requested(id: String)

enum Page { SUMMARY, STORY, COLLECTION, SETTINGS }
const PAGE_KEYS: Array[String] = ["PROFILE_SEG_SUMMARY", "PROFILE_SEG_STORY", "PROFILE_SEG_COLLECTION",
	"PROFILE_SEG_SETTINGS"]
const TITLE_SCENE := "res://scenes/title.tscn"
const TUTORIAL_SCENE := "res://scenes/tutorial.tscn"
const LEGAL_PATH := "res://data/legal.json"
const CHEVRON := preload("res://assets/icons/chevron_right.svg")
const LOCK := preload("res://assets/icons/lock.svg")
const HEADER_ART := preload("res://assets/illustrations/topbar_bg.svg")
const CHAPTER_ART := "res://assets/illustrations/chapters/%s.svg"  # ilustrasi bab kehidupan (aset opsional)
const GRAY := preload("res://theme/grayscale.gdshader")
const HISTORY_CHIPS := {"win": &"MoodGreen", "retired": &"MoodGold", "died": &"MoodNeutral", "lose": &"MoodRed"}
const LOG_DOTS := {"promoted": Palette.GOLD, "graduated": Palette.TEAL, "laid_off": Palette.LOSS,
	"dropped_out": Palette.LOSS}

var _page := Page.SUMMARY
var _segments: Array[Button] = []
var _pages: Array[VBoxContainer] = []
var _render: Dictionary = {}  # kunci data terakhir per bagian (UiText.changed_key)
var _save_count := 0  # naik setiap simpan manual (ringkasan slot perlu dibaca ulang)
var _confirm_reset := false
var _gray: ShaderMaterial

# --- Ringkasan
var _avatar: AvatarView
var _avatar_frame: PanelContainer
var _name_label: Label
var _title_chip: PanelContainer
var _info_chips: HFlowContainer
var _level_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _goal_box: GridContainer
var _life_side: Label
var _life_box: VBoxContainer
var _life_art: TextureRect  # sampul kartu Perjalanan Hidup: ilustrasi bab yang sedang dijalani (aset opsional)
var _stats_grid: GridContainer
var _power_label: Label
var _risk_desc: Label

# --- Kisah
var _people_grid: GridContainer
var _career_box: VBoxContainer
var _research_title: Control
var _research_box: VBoxContainer
var _history_side: Label
var _history_box: VBoxContainer

# --- Koleksi
var _style_box: VBoxContainer
var _badge_count: Label
var _badge_bar: ProgressBar
var _badge_grid: GridContainer

# --- Atur
var _slot_labels: Dictionary = {}  # slot -> Label ringkasan
var _slot_buttons: Dictionary = {}  # slot -> Button simpan/timpa
var _save_feedback: PanelContainer
var _save_feedback_label: Label
var _annual_row: Button
var _sessions_title: Control
var _sessions_box: VBoxContainer
var _reset_label: Label


func _ready() -> void:
	_gray = ShaderMaterial.new()
	_gray.shader = GRAY
	_pages = [%Summary, %Story, %Collection, %Settings]
	_build_segments()
	_build_summary()
	_build_story()
	_build_collection()
	_build_settings()
	GameState.changed.connect(_refresh)
	visibility_changed.connect(_refresh)
	show_page(Page.SUMMARY)


func show_page(page: int) -> void:
	_page = page
	for i in _pages.size():
		_pages[i].visible = i == page
		_segments[i].set_pressed_no_signal(i == page)
	%Scroll.scroll_vertical = 0
	_refresh()


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	match _page:
		Page.SUMMARY:
			_refresh_summary()
		Page.STORY:
			_refresh_story()
		Page.COLLECTION:
			_refresh_collection()
		Page.SETTINGS:
			_refresh_settings()


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


# ==================================================================================================
# Ringkasan
# ==================================================================================================

func _build_summary() -> void:
	var page: VBoxContainer = %Summary
	page.add_child(_player_card())

	_title(page, tr("PROFILE_GOALS_TITLE"))
	_goal_box = GridContainer.new()
	_goal_box.columns = 2
	_goal_box.add_theme_constant_override("h_separation", 12)
	page.add_child(_goal_box)
	page.add_child(_wrap(tr("GOAL_HINT"), &"SmallMutedLabel"))

	_life_side = _title(page, tr("PROFILE_LIFE_TITLE"))
	_life_box = _life_card(page)

	_title(page, tr("PROFILE_STATS_TITLE"))
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 3
	_stats_grid.add_theme_constant_override("h_separation", 10)
	_stats_grid.add_theme_constant_override("v_separation", 10)
	page.add_child(_stats_grid)
	var power := PanelContainer.new()
	power.theme_type_variation = &"TipCard"
	_power_label = _wrap("", &"SmallMutedLabel")
	power.add_child(_power_label)
	page.add_child(power)

	_title(page, tr("PROFILE_RISK_TITLE"))
	var track := PanelContainer.new()
	track.theme_type_variation = &"SegmentTrack"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	track.add_child(row)
	var group := ButtonGroup.new()
	for p: Dictionary in GameState.portfolio.risk_profiles():
		var id: String = p["id"]
		var button := _segment(tr(p["name"]), group, id == GameState.portfolio.risk_profile_id)
		button.pressed.connect(func() -> void:
			GameState.portfolio.set_risk_profile(id)
			_risk_desc.text = tr(GameState.portfolio.risk_profile()["desc"]))
		row.add_child(button)
	page.add_child(track)
	_risk_desc = _wrap(tr(GameState.portfolio.risk_profile()["desc"]), &"SmallMutedLabel")
	page.add_child(_risk_desc)


## Kartu pemain: ilustrasi langit senja di atas, avatar besar berbingkai menjorok ke ilustrasi, nama,
## gelar, chip info, level & XP.
func _player_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"PlayerCard"
	var style := card.get_theme_stylebox("panel", &"PlayerCard").duplicate() as StyleBoxFlat
	if style:
		style.content_margin_left = 3
		style.content_margin_right = 3
		style.content_margin_top = 3
		card.add_theme_stylebox_override("panel", style)
	card.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", -56)
	var art := TextureRect.new()
	art.texture = HEADER_ART
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size = Vector2(0, 112)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(art)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	stack.add_child(margin)
	card.add_child(stack)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	_avatar_frame = PanelContainer.new()
	_avatar_frame.theme_type_variation = &"AvatarFrameSmall"
	_avatar_frame.custom_minimum_size = Vector2(132, 136)
	_avatar = AvatarView.new()
	_avatar.custom_minimum_size = Vector2(122, 122)
	_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avatar_frame.add_child(_avatar)
	head.add_child(_avatar_frame)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_END
	texts.add_theme_constant_override("separation", 6)
	_name_label = _label("", &"PlayerCardName")
	_name_label.add_theme_font_size_override("font_size", 40)
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(_name_label)
	_title_chip = _chip("", &"ChipTeal", &"ChipLabel")
	_title_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	texts.add_child(_title_chip)
	head.add_child(texts)
	box.add_child(head)

	_info_chips = HFlowContainer.new()
	_info_chips.add_theme_constant_override("h_separation", 8)
	_info_chips.add_theme_constant_override("v_separation", 8)
	box.add_child(_info_chips)
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 12)
	var level := PanelContainer.new()
	level.theme_type_variation = &"LevelPill"
	_level_label = _label("", &"TopChipLabel")
	level.add_child(_level_label)
	level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_row.add_child(level)
	_xp_bar = ProgressBar.new()
	_xp_bar.theme_type_variation = &"XpBar"
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(0, 14)
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_row.add_child(_xp_bar)
	_xp_label = _label("", &"SmallMutedLabel")
	level_row.add_child(_xp_label)
	box.add_child(level_row)
	return card


func _refresh_summary() -> void:
	_avatar.avatar_index = GameState.avatar
	_avatar.display_name = GameState.player_name
	UiText.apply_avatar_frame(_avatar_frame, GameState.achievements.current_frame())
	_name_label.text = GameState.player_name
	var title := GameState.achievements.current_title()
	_title_chip.visible = title != ""
	_title_chip.get_child(0).text = title
	_clear(_info_chips)
	var job := tr(GameState.career.current_job_def()["title"]) if GameState.career.is_employed() else tr("CAREER_UNEMPLOYED")
	if GameState.life.retired:
		job = tr("HOME_RETIRED_TITLE")
	_info_chips.add_child(_chip(job, &"MoodGold"))
	_info_chips.add_child(_chip(GameState.education.level_name(GameState.education.level), &"MoodNeutral"))
	_info_chips.add_child(_chip(tr("PROFILE_AGE") % GameState.age(), &"MoodNeutral"))
	_info_chips.add_child(_chip(tr("PROFILE_DIFFICULTY") % tr(GameState.difficulty["name_key"]), &"MoodNeutral"))
	_info_chips.add_child(_chip(tr("PROFILE_PLAYED") % [floori(GameState.month / 12.0), GameState.month % 12], &"MoodNeutral"))
	var per_level := int(GameState.economy["xp_per_level"])
	_level_label.text = tr("TOPBAR_LEVEL") % GameState.progress.level()
	_xp_bar.max_value = per_level
	_xp_bar.value = GameState.progress.xp_in_level()
	_xp_label.text = tr("PROFILE_XP") % [GameState.progress.xp_in_level(), per_level]

	var base := [GameState.run_id, GameState.month, Fmt.compact]
	if UiText.changed_key(_render, "goals", base + [roundi(GameState.net_worth() / 1_000_000.0)]):
		_refresh_goals()
	var life := GameState.life
	if UiText.changed_key(_render, "life", base + [life.chapter_log.size(), life.retired, GameState.insurance.policies]):
		_refresh_life()
	var s := GameState.stats
	if UiText.changed_key(_render, "stats", base + [s, GameState.quiz.correct_ids.size(), GameState.leverage.record]):
		_refresh_stats(s)


## Dua cincin target kemenangan: kekayaan bersih menuju Rp1 miliar, pendapatan pasif menutup pengeluaran.
func _refresh_goals() -> void:
	_clear(_goal_box)
	var target: float = GameState.economy["end"]["win_net_worth"]
	var worth := GameState.net_worth()
	var expenses := maxf(1.0, float(GameState.monthly_spending()))  # biaya hidup + premi + gaya hidup
	var passive := GameState.passive_income()
	_goal_box.add_child(_goal_tile(tr("ACH_MILLIONAIRE"), worth / target, Palette.GOLD,
		tr("PROFILE_GOAL_WORTH") % [Fmt.rupiah_short(worth), Fmt.rupiah_short(target)]))
	_goal_box.add_child(_goal_tile(tr("ACH_FREEDOM"), passive / expenses, Palette.TEAL,
		tr("PROFILE_GOAL_FREEDOM") % [Fmt.rupiah_short(passive), Fmt.rupiah_short(expenses)]))


func _goal_tile(title: String, ratio: float, color: Color, sub: String) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.theme_type_variation = &"HomeCard"
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var ring := CreditRing.new(112.0, 12.0, 26)
	ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ring.set_score(clampi(floori(ratio * 100.0), 0, 100), color, "%")
	box.add_child(ring)
	var name := _label(title, &"AssetNameLabel")
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name)
	var sub_label := _wrap(sub, &"SmallMutedLabel")
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub_label)
	tile.add_child(box)
	return tile


## Garis waktu 4 bab + saran bab sekarang + skor warisan sementara, pensiun, dan efek usia.
func _refresh_life() -> void:
	_clear(_life_box)
	var life := GameState.life
	var chapters: Array = life.data["chapters"]
	var current := life.chapter if life.chapter != "" else str(chapters[0]["id"])
	var current_index := 0
	for i in chapters.size():
		if chapters[i]["id"] == current:
			current_index = i
	var items: Array = []
	for i in chapters.size():
		var id: String = chapters[i]["id"]
		var ages := life.chapter_ages(id)
		items.append({"name": tr("CHAPTER_" + id.to_upper()),
			"ages": ("%d–%d" % ages if ages[1] >= 0 else "%d+" % ages[0]),
			"state": "done" if i < current_index else ("now" if i == current_index else "todo")})
	_life_side.text = tr("PROFILE_LIFE_CHAPTER") % [current_index + 1, chapters.size()]
	var art_path := CHAPTER_ART % current
	_life_art.visible = ResourceLoader.exists(art_path)
	if _life_art.visible:
		_life_art.texture = load(art_path)
	var track := ChapterTrack.new()
	track.set_chapters(items, GameState.age())
	_life_box.add_child(track)
	var tip := PanelContainer.new()
	tip.theme_type_variation = &"TipBanner"
	tip.add_child(_wrap(tr("CHAPTER_" + current.to_upper()) + ": " + tr("CHAPTER_TIP_" + current.to_upper()), &"SmallMutedLabel"))
	_life_box.add_child(tip)
	_life_box.add_child(_value_row(tr("PROFILE_LEGACY_NOW"), tr("LEGACY_POINTS") % [GameState.legacy_score(), 1000]))  # v2b langkah 5
	if life.retired:
		_life_box.add_child(_wrap(tr("PROFILE_LIFE_RETIRED") % [Fmt.rupiah(life.retirement_info.get("jht", 0)),
			Fmt.rupiah(life.pension_payment())], &"SmallMutedLabel"))
	var aging := UiText.aging_lines()  # v2b langkah 2
	if not aging.is_empty():
		_life_box.add_child(_wrap(tr("PROFILE_AGING_TITLE") % GameState.age() + "\n• " + "\n• ".join(aging), &"SmallMutedLabel"))


## Ubin statistik 3 kolom; ubin tambahan hanya muncul jika fiturnya pernah dipakai.
func _refresh_stats(s: Dictionary) -> void:
	_clear(_stats_grid)
	_stats_grid.add_child(_stat_tile(tr("PROFILE_STAT_PEAK"), Fmt.rupiah_short(s["peak_net_worth"])))
	_stats_grid.add_child(_stat_tile(tr("PROFILE_STAT_REAL"), Fmt.rupiah_short(GameState.real_value(GameState.net_worth()))))
	_stats_grid.add_child(_stat_tile(tr("PROFILE_STAT_EVENTS"), str(int(s["events"]))))
	_stats_grid.add_child(_stat_tile(tr("PROFILE_STAT_QUIZ"), str(GameState.quiz.correct_ids.size())))
	_stats_grid.add_child(_stat_tile(tr("PROFILE_STAT_PROMOTIONS"), str(int(s["promotions"]))))
	_stats_grid.add_child(_stat_tile(tr("PROFILE_STAT_COSTS"), Fmt.rupiah_short(float(s["total_taxes"]) + float(s["total_fees"]))))
	if int(s["months_unemployed"]) > 0:
		_stats_grid.add_child(_stat_tile(tr("PROFILE_STAT_UNEMPLOYED"), str(int(s["months_unemployed"]))))
	var best: Dictionary = s["best_trade"]
	if not best.is_empty():
		_stats_grid.add_child(_stat_tile(tr("PROFILE_STAT_BEST"), Fmt.signed_rupiah(best["value"]), tr(best["asset_key"])))
	if int(s.get("projects_done", 0)) + int(s.get("projects_failed", 0)) > 0:
		_stats_grid.add_child(_stat_tile(tr("PROFILE_STAT_PROJECTS"), tr("PROFILE_STAT_PROJECTS_VALUE") % [
			int(s.get("projects_done", 0)), int(s.get("projects_failed", 0))]))
		_stats_grid.add_child(_stat_tile(tr("PROFILE_STAT_PROJECT_INCOME"), Fmt.rupiah_short(float(s.get("project_income", 0)))))
	var lev := GameState.leverage.record
	if int(lev["opened"]) > 0:  # leverage (v2a): jumlah posisi & likuidasi, untung/rugi terealisasi
		_stats_grid.add_child(_stat_tile(tr("PROFILE_STAT_LEVERAGE"), tr("PROFILE_STAT_LEVERAGE_VALUE") % [
			int(lev["opened"]), int(lev["liquidated"])]))
		_stats_grid.add_child(_stat_tile(tr("PROFILE_STAT_LEVERAGE_PNL"), Fmt.signed_rupiah(lev["pnl"])))
	var market := GameState.market
	var savings := GameState.savings_rate()
	_power_label.text = tr("PROFILE_POWER_LINE") % [Fmt.percent_plain(market.inflation), Fmt.percent_plain(savings),
		Fmt.percent_plain(market.policy_rate), Fmt.percent(GameState.price_level() - 1.0)] + "\n" \
		+ tr("POWER_HINT_LOSING" if savings < market.inflation else "POWER_HINT_OK")


# ==================================================================================================
# Kisah
# ==================================================================================================

func _build_story() -> void:
	var page: VBoxContainer = %Story
	var side := _title(page, tr("PROFILE_PEOPLE_TITLE"))
	side.text = tr("PROFILE_PEOPLE_SIDE")
	_people_grid = GridContainer.new()
	_people_grid.columns = 2
	_people_grid.add_theme_constant_override("h_separation", 12)
	_people_grid.add_theme_constant_override("v_separation", 12)
	page.add_child(_people_grid)
	page.add_child(_wrap(tr("PROFILE_PEOPLE_NOTE"), &"SmallMutedLabel"))
	_title(page, tr("PROFILE_CAREER_TITLE"))
	_career_box = _card(page, &"HomeCard", 0)
	_research_title = _title(page, tr("PROFILE_RESEARCH_TITLE")).get_parent()
	_research_box = VBoxContainer.new()
	_research_box.add_theme_constant_override("separation", 10)
	page.add_child(_research_box)
	_history_side = _title(page, tr("PROFILE_HISTORY_TITLE"))
	_history_box = _card(page, &"HomeCard", 0)


func _refresh_story() -> void:
	var base := [GameState.run_id, GameState.month]
	var characters := GameState.characters
	if UiText.changed_key(_render, "people", base + [characters.rel, characters.met, characters.work_company]):
		_refresh_people()
	if UiText.changed_key(_render, "career", base + [GameState.career.history.size()]):
		_refresh_career_log()
	var research := GameState.research
	if UiText.changed_key(_render, "research", base + [research.record, research.has_rumor()]):
		_refresh_research()
	if UiText.changed_key(_render, "history", [GameState.history.size(), GameState.legacy_best]):
		_refresh_history()


## Kartu per tokoh yang sudah dikenal: potret anime, nama & peran, tingkat kedekatan, bar.
func _refresh_people() -> void:
	_clear(_people_grid)
	var characters := GameState.characters
	for id: String in characters.known():
		var card := PanelContainer.new()
		card.theme_type_variation = &"HomeCard"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 12)
		var portrait := CharacterPortrait.new(72.0)
		portrait.character_id = id
		head.add_child(portrait)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		texts.add_theme_constant_override("separation", 0)
		texts.add_child(_wrap(characters.name_of(id), &"AssetNameLabel"))
		texts.add_child(_wrap(tr(characters.def(id)["role"]), &"SmallMutedLabel"))
		head.add_child(texts)
		box.add_child(head)
		var value := characters.rel_of(id)
		var level := _value_row(tr(characters.level_key(value)), str(value), Palette.INK, &"SmallMutedLabel")
		box.add_child(level)
		var bar := ProgressBar.new()
		bar.theme_type_variation = &"HealthBar"
		bar.custom_minimum_size = Vector2(0, 12)
		bar.show_percentage = false
		bar.max_value = 100
		bar.value = value
		box.add_child(bar)
		card.add_child(box)
		_people_grid.add_child(card)


## Garis waktu karier: titik berwarna (emas = promosi, teal = lulus, merah = PHK/berhenti kuliah), tanggal,
## lalu isi catatan. Terbaru di atas, maksimal 8.
func _refresh_career_log() -> void:
	_clear(_career_box)
	var entries := GameState.career.history.duplicate()
	entries.reverse()
	if entries.is_empty():
		_career_box.add_child(_wrap(tr("CAREER_LOG_EMPTY"), &"SmallMutedLabel"))
		return
	entries = entries.slice(0, 8)
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var rail := Control.new()  # titik + garis ke catatan berikutnya, digambar sendiri
		rail.custom_minimum_size = Vector2(22, 0)
		var dot_color: Color = LOG_DOTS.get(entry["kind"], Color.WHITE)
		var has_line := i < entries.size() - 1
		rail.draw.connect(func() -> void:
			if has_line:
				rail.draw_rect(Rect2(rail.size.x / 2.0 - 1.5, 18.0, 3.0, rail.size.y - 12.0), Color("#d9c3a0"))
			rail.draw_circle(Vector2(rail.size.x / 2.0, 12.0), 10.0, Palette.INK)
			rail.draw_circle(Vector2(rail.size.x / 2.0, 12.0), 7.0, dot_color))
		row.add_child(rail)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 0)
		texts.add_child(_label(Fmt.game_date(int(entry["month"])), &"SmallMutedLabel"))
		var body := _wrap(UiText.career_log_body(entry), &"AssetNameLabel")
		if entry["kind"] in ["laid_off", "dropped_out"]:
			body.add_theme_color_override("font_color", Palette.LOSS)
		elif entry["kind"] == "graduated":
			body.add_theme_color_override("font_color", Palette.GAIN)
		texts.add_child(body)
		if i < entries.size() - 1:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 14)
			texts.add_child(gap)
		row.add_child(texts)
		_career_box.add_child(row)


## Rekam jejak riset: tiga ubin (rumor, tepat, biaya) dan akurasi per tingkat riset. Tampil setelah rumor
## pertama beredar.
func _refresh_research() -> void:
	var research := GameState.research
	var record := research.record
	var shown := int(record["rumors"]) > 0 or research.has_rumor()
	_research_title.visible = shown
	_research_box.visible = shown
	if not shown:
		return
	_clear(_research_box)
	var done := 0
	var hits := 0
	for level: String in Research.LEVELS:
		done += int(record[level][0])
		hits += int(record[level][1])
	var tiles := GridContainer.new()
	tiles.columns = 3
	tiles.add_theme_constant_override("h_separation", 10)
	tiles.add_child(_stat_tile(tr("PROFILE_RESEARCH_RUMORS"), str(int(record["rumors"])),
		tr("PROFILE_RESEARCH_TRUE") % int(record["true"])))
	var hit_tile := _stat_tile(tr("PROFILE_RESEARCH_HIT"), "%d / %d" % [hits, done],
		"%d%%" % roundi(100.0 * hits / done) if done > 0 else "-")
	hit_tile.theme_type_variation = &"StatTilePositive" if done > 0 else &"StatTile"
	tiles.add_child(hit_tile)
	tiles.add_child(_stat_tile(tr("PROFILE_RESEARCH_COSTS"), Fmt.rupiah_short(record["costs"])))
	_research_box.add_child(tiles)
	var card := PanelContainer.new()
	card.theme_type_variation = &"HomeCard"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	for level: String in Research.LEVELS:
		var level_done: Array = record[level]
		var value := "-"
		if int(level_done[0]) > 0:
			value = tr("PROFILE_RESEARCH_VALUE") % [int(level_done[1]), int(level_done[0]),
				roundi(100.0 * level_done[1] / level_done[0])]
		box.add_child(_value_row(tr("RESEARCH_" + level.to_upper()) + " · "
			+ tr("RESEARCH_ACCURACY") % roundi(research.accuracy(level) * 100.0), value))
	box.add_child(_wrap(tr("PROFILE_RESEARCH_NOTE"), &"SmallMutedLabel"))
	card.add_child(box)
	_research_box.add_child(card)


## Riwayat permainan: avatar kecil, nama & hasil, lama bermain, kekayaan & tanggal, chip skor warisan.
func _refresh_history() -> void:
	_clear(_history_box)
	var best := GameState.legacy_best
	_history_side.text = tr("PROFILE_HISTORY_BEST_SIDE") % int(best["score"]) if not best.is_empty() else ""
	if GameState.history.is_empty():
		_history_box.add_child(_padded(_wrap(tr("HISTORY_EMPTY"), &"MutedLabel"), 12))
		return
	for i in GameState.history.size():
		var record: Dictionary = GameState.history[i]
		if i > 0:
			_history_box.add_child(_divider())
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var frame := PanelContainer.new()
		frame.theme_type_variation = &"AvatarFrameSmall"
		frame.custom_minimum_size = Vector2(58, 60)
		frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var avatar := AvatarView.new()
		avatar.custom_minimum_size = Vector2(50, 50)
		avatar.avatar_index = int(record.get("avatar", 0))
		avatar.display_name = record["name"]
		frame.add_child(avatar)
		row.add_child(frame)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		texts.add_theme_constant_override("separation", 2)
		texts.add_child(_wrap("%s · %s" % [record["name"], tr("END_TITLE_" + str(record["type"]).to_upper())],
			&"AssetNameLabel"))
		var t := Time.get_date_dict_from_unix_time(int(record.get("date", 0)))
		var meta := tr("HISTORY_META") % [tr("END_REASON_SHORT_" + str(record["reason"]).to_upper()), int(record["months"])]
		meta += " · " + Fmt.rupiah_short(record["net_worth"]) + " · %02d/%02d/%d" % [t["day"], t["month"], t["year"]]
		texts.add_child(_wrap(meta, &"SmallMutedLabel"))
		row.add_child(texts)
		if int(record.get("score_v", 0)) == 2:  # skor warisan v2 (permainan sebelum v2b langkah 5 tidak punya)
			var chip := _chip(str(int(record["score"])), HISTORY_CHIPS.get(record["type"], &"MoodNeutral"))
			chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(chip)
		_history_box.add_child(_padded(row, 0, 12))


# ==================================================================================================
# Koleksi
# ==================================================================================================

func _build_collection() -> void:
	var page: VBoxContainer = %Collection
	_style_box = _card(page, &"HomeCard", 12)
	var side := _title(page, tr("PROFILE_BADGES_TITLE"))
	side.text = tr("PROFILE_BADGES_SIDE")
	var progress := HBoxContainer.new()
	progress.add_theme_constant_override("separation", 12)
	_badge_bar = ProgressBar.new()
	_badge_bar.theme_type_variation = &"HappinessBar"
	_badge_bar.show_percentage = false
	_badge_bar.custom_minimum_size = Vector2(0, 14)
	_badge_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_badge_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.add_child(_badge_bar)
	_badge_count = _label("", &"RowValueLabel")
	progress.add_child(_badge_count)
	page.add_child(progress)
	_badge_grid = GridContainer.new()
	_badge_grid.columns = 4
	_badge_grid.add_theme_constant_override("h_separation", 10)
	_badge_grid.add_theme_constant_override("v_separation", 10)
	page.add_child(_badge_grid)


func _refresh_collection() -> void:
	var achievements := GameState.achievements
	if not UiText.changed_key(_render, "collection", [achievements.unlocked_count(), achievements.frame,
			achievements.title, GameState.month, GameState.run_id, GameState.quiz.correct_ids.size()]):
		return
	_refresh_style()
	var total := achievements.defs().size()
	_badge_bar.max_value = total
	_badge_bar.value = achievements.unlocked_count()
	_badge_count.text = "%d / %d" % [achievements.unlocked_count(), total]
	_clear(_badge_grid)
	for d: Dictionary in achievements.defs():
		_badge_grid.add_child(_badge_cell(d))


## Satu lencana: gambar (abu-abu & redup jika terkunci, dengan gembok), nama, bar progres kecil.
func _badge_cell(d: Dictionary) -> Button:
	var achievements := GameState.achievements
	var id: String = d["id"]
	var open := achievements.is_unlocked(id)
	var button := Button.new()
	button.theme_type_variation = &"AssetRowButton"
	if not open:
		var locked := StyleBoxFlat.new()
		locked.bg_color = Color("#f6efe3")
		locked.border_color = Color("#e6d8c2")
		locked.set_border_width_all(3)
		locked.border_width_bottom = 8
		locked.set_corner_radius_all(22)
		for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
			button.add_theme_stylebox_override(state, locked)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(achievement_requested.emit.bind(id))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 8
	box.offset_bottom = -14
	box.offset_left = 4
	box.offset_right = -4
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()  # lencana + gembok di pojok kanan bawah
	holder.custom_minimum_size = Vector2(96, 96)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := achievements.icon(id)
	var badge := TextureRect.new()
	badge.texture = load(icon) if icon != "" else LOCK
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not open:
		badge.material = _gray
		badge.modulate = Color(1, 1, 1, 0.45)
	holder.add_child(badge)
	if not open:
		var lock := PanelContainer.new()
		lock.theme_type_variation = &"NumberBadge"
		lock.custom_minimum_size = Vector2(32, 32)
		lock.position = Vector2(64, 64)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lock_icon := TextureRect.new()
		lock_icon.texture = LOCK
		lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock_icon.custom_minimum_size = Vector2(16, 16)
		lock_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lock_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lock_icon.self_modulate = Palette.GOLD
		lock.add_child(lock_icon)
		holder.add_child(lock)
	box.add_child(holder)
	var name := _wrap(tr("ACH_" + id.to_upper()), &"SmallMutedLabel" if not open else &"MoodLabel")
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 15)
	box.add_child(name)
	if not open:
		var target := achievements.target(d)
		if target > 1.0:
			var value := minf(achievements.value(d), target)
			var bar := ProgressBar.new()
			bar.theme_type_variation = &"XpBar"
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0, 8)
			bar.max_value = target
			bar.value = value
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(bar)
			var text := _label("%s / %s" % [UiText.achievement_progress(d, value), UiText.achievement_progress(d, target)],
				&"SmallMutedLabel")
			text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			text.add_theme_font_size_override("font_size", 13)
			box.add_child(text)
	button.add_child(box)
	UiText.fit_to_content(button, box, 24.0)
	return button


## Pratinjau tampilan (avatar berbingkai + gelar), pilihan bingkai, dan pilihan gelar.
func _refresh_style() -> void:
	_clear(_style_box)
	var achievements := GameState.achievements
	var frame := achievements.current_frame()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	var avatar_frame := PanelContainer.new()
	avatar_frame.theme_type_variation = &"AvatarFrameSmall"
	avatar_frame.custom_minimum_size = Vector2(108, 112)
	var avatar := AvatarView.new()
	avatar.custom_minimum_size = Vector2(98, 98)
	avatar.avatar_index = GameState.avatar
	avatar.display_name = GameState.player_name
	avatar_frame.add_child(avatar)
	UiText.apply_avatar_frame(avatar_frame, frame)
	head.add_child(avatar_frame)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 6)
	texts.add_child(_label(tr("PROFILE_STYLE_CAPS"), &"TileCapsLabel"))
	texts.add_child(_wrap(tr("FRAME_" + str(frame["id"]).to_upper()), &"CardTitleLabel"))
	var title := achievements.current_title()
	if title != "":
		var chip := _chip(title, &"ChipTeal", &"ChipLabel")
		chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		texts.add_child(chip)
	head.add_child(texts)
	_style_box.add_child(head)

	_style_box.add_child(_label(tr("PROFILE_FRAME_CAPS"), &"TileCapsLabel"))
	var swatches := HFlowContainer.new()
	swatches.add_theme_constant_override("h_separation", 12)
	swatches.add_theme_constant_override("v_separation", 12)
	for f: Dictionary in achievements.frames():
		swatches.add_child(_frame_swatch(f, f["id"] == frame["id"], achievements.frame_unlocked(f["id"])))
	_style_box.add_child(swatches)

	_style_box.add_child(_label(tr("PROFILE_TITLE_CAPS"), &"TileCapsLabel"))
	var titles := HFlowContainer.new()
	titles.add_theme_constant_override("h_separation", 8)
	titles.add_theme_constant_override("v_separation", 8)
	var options: Array[String] = [""]
	options.append_array(achievements.titles_unlocked())
	for id: String in options:
		var selected := achievements.title == id or (id == "" and achievements.current_title() == "")
		var button := Button.new()
		button.theme_type_variation = &"PeriodButton"
		button.toggle_mode = true
		button.button_pressed = selected
		button.focus_mode = Control.FOCUS_NONE
		button.text = tr("PROFILE_NO_TITLE") if id == "" else tr("TITLE_" + id.to_upper())
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(achievements.set_title.bind(id))
		titles.add_child(button)
	_style_box.add_child(titles)
	if options.size() == 1:
		_style_box.add_child(_wrap(tr("PROFILE_STYLE_HINT"), &"SmallMutedLabel"))


## Lingkaran contoh bingkai: terpilih = cincin tinta di luar; terkunci = abu-abu dengan gembok.
func _frame_swatch(f: Dictionary, selected: bool, unlocked: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(56, 56)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tr("FRAME_" + str(f["id"]).to_upper())
	var style := StyleBoxFlat.new()
	style.bg_color = Color(f["bg"]) if unlocked else Color("#f4eadb")
	style.border_color = Color(f["border"]) if unlocked else Color("#c9b497")
	style.set_border_width_all(6)
	style.set_corner_radius_all(28)
	style.anti_aliasing_size = 1.0
	if selected:
		style.expand_margin_left = 6
		style.expand_margin_right = 6
		style.expand_margin_top = 6
		style.expand_margin_bottom = 6
		style.shadow_color = Palette.INK
		style.shadow_size = 3
	elif f.has("glow") and unlocked:
		style.shadow_color = Color(Color(f["glow"]), 0.6)
		style.shadow_size = 4
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, style)
	button.disabled = not unlocked
	if not unlocked:
		button.icon = LOCK
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_constant_override("icon_max_width", 18)
		button.add_theme_color_override("icon_disabled_color", Palette.MUTED)
	button.pressed.connect(GameState.achievements.set_frame.bind(f["id"]))
	return button


# ==================================================================================================
# Atur
# ==================================================================================================

func _build_settings() -> void:
	var page: VBoxContainer = %Settings
	_title(page, tr("PROFILE_SAVE_TITLE"))
	var auto := PanelContainer.new()
	auto.theme_type_variation = &"FeedbackGood"
	auto.add_child(_wrap(tr("PROFILE_AUTOSAVE_SHORT"), &"FeedbackLabel"))
	page.add_child(auto)
	var slots := _card(page, &"HomeCard", 0)
	for i in SaveManager.MANUAL_SLOTS.size():
		if i > 0:
			slots.add_child(_divider())
		slots.add_child(_slot_row(SaveManager.MANUAL_SLOTS[i], str(i + 1)))
	slots.add_child(_divider())
	slots.add_child(_slot_row(SaveManager.CHAPTER_SLOT, ""))
	_save_feedback = PanelContainer.new()
	_save_feedback.hide()
	_save_feedback_label = _wrap("", &"FeedbackLabel")
	_save_feedback.add_child(_save_feedback_label)
	page.add_child(_save_feedback)

	_title(page, tr("SETTINGS_TITLE"))
	var settings := _card(page, &"HomeCard", 4)
	settings.add_child(_switch(tr("SETTINGS_SFX"), Settings.sfx_enabled, Settings.set_sfx))
	settings.add_child(_switch(tr("SETTINGS_VIBRATION"), Settings.vibration_enabled, Settings.set_vibration))
	settings.add_child(_switch(tr("SETTINGS_COMPACT"), Settings.compact_numbers, func(on: bool) -> void:
		Settings.set_compact_numbers(on)
		GameState.changed.emit()))  # gambar ulang semua angka
	settings.add_child(_divider())
	settings.add_child(_padded(_label(tr("SETTINGS_LANGUAGE").to_upper(), &"TileCapsLabel"), 0, 6))
	var track := PanelContainer.new()
	track.theme_type_variation = &"SegmentTrack"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	track.add_child(row)
	var group := ButtonGroup.new()
	for code: String in Settings.LANGUAGES:
		var button := _segment(tr("LANG_" + code.to_upper()), group, code == Settings.language)
		button.pressed.connect(func() -> void:
			if code == Settings.language:
				return
			Settings.set_language(code)
			SaveManager.save_slot(SaveManager.AUTO_SLOT)
			get_tree().reload_current_scene())  # semua teks dibuat ulang dalam bahasa baru
		row.add_child(button)
	settings.add_child(track)
	settings.add_child(_padded(_wrap(tr("SETTINGS_LANGUAGE_NOTE"), &"SmallMutedLabel"), 0, 6))

	_title(page, tr("PROFILE_OTHER_TITLE"))
	var menu := _card(page, &"HomeCard", 0)
	_annual_row = _menu_row(menu, "PROFILE_ANNUAL", "res://assets/icons/calendar_badge.svg", &"IconTileGold",
		func() -> void: annual_requested.emit())
	_menu_row(menu, "PROFILE_GLOSSARY", "res://assets/icons/book.svg", &"IconTileTeal", func() -> void: glossary_requested.emit())
	_menu_row(menu, "PROFILE_TUTORIAL", "res://assets/icons/lightbulb.svg", &"IconTileGold", _leave_to.bind(TUTORIAL_SCENE))
	_menu_row(menu, "PROFILE_SUPPORT", "res://assets/icons/heart.svg", &"IconTileMint", func() -> void:  # v2b langkah 4
		var cfg: Dictionary = GameState.mental.data
		text_requested.emit(tr("PROFILE_SUPPORT"), tr("SUPPORT_MESSAGE") + "\n\n" + tr("SUPPORT_GAME_INFO") % [
			int(cfg["enter_below"]), int(cfg["enter_months"]), int(cfg["exit_above"])]))
	_menu_row(menu, "SETTINGS_PRIVACY", "res://assets/icons/shield.svg", &"IconTileInk", _show_legal.bind("privacy"))
	_menu_row(menu, "SETTINGS_TERMS", "res://assets/icons/news.svg", &"IconTileInk", _show_legal.bind("terms"))
	_menu_row(menu, "SETTINGS_LICENSES", "res://assets/icons/book.svg", &"IconTileInk", _show_legal.bind("licenses"))
	_menu_row(menu, "PROFILE_TO_TITLE", "res://assets/icons/nav_home.svg", &"IconTileTeal", _leave_to.bind(TITLE_SCENE), true)

	var perf := _switch(tr("SETTINGS_PERF"), Settings.perf_overlay, func(on: bool) -> void:
		Settings.set_perf_overlay(on)
		_refresh_settings())
	page.add_child(_padded(perf, 6))
	_sessions_title = _title(page, tr("PROFILE_SESSIONS_TITLE")).get_parent()
	_sessions_box = _card(page, &"HomeCard", 6)

	var reset := UiText.chunky_button(tr("SETTINGS_RESET"), &"DangerButton", &"DangerButtonLabel", 80.0, 21)
	_reset_label = reset.get_node("Content")
	reset.pressed.connect(_on_reset)
	page.add_child(reset)
	var disclaimer := _wrap(tr("DISCLAIMER"), &"SmallMutedLabel")
	disclaimer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(disclaimer)


func _refresh_settings() -> void:
	_annual_row.visible = not GameState.annual.reports.is_empty()
	if UiText.changed_key(_render, "slots", [GameState.run_id, GameState.month, _save_count, Fmt.compact]):
		for slot: String in _slot_labels:  # query database hanya bila perlu
			var used := SaveManager.has_slot(slot)
			_slot_labels[slot].text = SaveManager.slot_summary(slot)
			if _slot_buttons.has(slot):
				_slot_buttons[slot].get_node("Content").text = tr("SAVE_OVERWRITE" if used else "SAVE_BUTTON")
	var show_sessions := Settings.perf_overlay and not GameState.sessions.sessions.is_empty()
	_sessions_title.visible = show_sessions
	_sessions_box.get_parent().visible = show_sessions
	var sessions := GameState.sessions.sessions
	if show_sessions and UiText.changed_key(_render, "sessions", [sessions.size(), sessions[-1]]):
		_refresh_sessions()


## Satu baris slot: nomor (atau ikon bab), ringkasan, tombol Muat & Simpan/Timpa (slot bab hanya Muat).
func _slot_row(slot: String, number: String) -> MarginContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	if number != "":
		var badge := PanelContainer.new()
		badge.theme_type_variation = &"NumberBadge"
		badge.custom_minimum_size = Vector2(46, 46)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var label := _label(number, &"NumberLabel")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(label)
		row.add_child(badge)
	else:
		row.add_child(UiText.icon_tile("res://assets/icons/save.svg", &"IconTilePurple", 46.0))
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 0)
	texts.add_child(_label(tr("SAVE_SLOT") % int(number) if number != "" else tr("SAVE_CHAPTER_SLOT"), &"AssetNameLabel"))
	var info := _wrap("", &"SmallMutedLabel")
	texts.add_child(info)
	_slot_labels[slot] = info
	row.add_child(texts)
	var load_button := UiText.chunky_button(tr("LOAD_BUTTON"), &"NeutralButton", &"NeutralButtonLabel", 54.0, 18)
	load_button.custom_minimum_size.x = 92
	load_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	load_button.pressed.connect(_on_load.bind(slot))
	row.add_child(load_button)
	if number != "":
		var save_button := UiText.chunky_button(tr("SAVE_BUTTON"), &"SecondaryButton", &"SecondaryButtonLabel", 54.0, 18)
		save_button.custom_minimum_size.x = 100
		save_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		save_button.pressed.connect(_on_save.bind(slot))
		row.add_child(save_button)
		_slot_buttons[slot] = save_button
	return _padded(row, 0, 12)


func _switch(text: String, on: bool, on_toggle: Callable) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.theme_type_variation = &"SenjaSwitch"
	toggle.text = text
	toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toggle.custom_minimum_size = Vector2(0, 56)
	toggle.button_pressed = on
	toggle.toggled.connect(on_toggle)
	return toggle


## Satu baris menu: ikon | judul | panah. `last` = tanpa garis pemisah di bawahnya.
func _menu_row(menu: VBoxContainer, key: String, icon: String, tile: StringName, on_press: Callable, last := false) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 72)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UiText.icon_tile(icon, tile, 46.0))
	var title := _label(tr(key), &"RowLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	row.add_child(_chevron())
	button.add_child(row)
	button.pressed.connect(on_press)
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 0)
	holder.add_child(button)
	if not last:
		holder.add_child(_divider())
	menu.add_child(holder)
	return button


## Rata-rata bulan per sesi, lalu 5 sesi terakhir: tanggal & jam mulai, lama, jumlah bulan.
func _refresh_sessions() -> void:
	var sessions := GameState.sessions
	_clear(_sessions_box)
	_sessions_box.add_child(_value_row(tr("PROFILE_SESSIONS_AVERAGE") % mini(sessions.sessions.size(), 10),
		tr("PROFILE_SESSIONS_MONTHS") % Fmt.number(sessions.average_months(10), 1)))
	var bias := int(Time.get_time_zone_from_system()["bias"]) * 60
	var recent := sessions.sessions.slice(-5)
	recent.reverse()
	for s: Dictionary in recent:
		var t := Time.get_datetime_dict_from_unix_time(int(s["start"]) + bias)
		var when := "%02d/%02d %02d:%02d" % [t["day"], t["month"], t["hour"], t["minute"]]
		_sessions_box.add_child(_value_row(tr("PROFILE_SESSION_ROW") % [when, PlaySessions.minutes(s)],
			tr("PROFILE_SESSIONS_MONTHS") % str(int(s["months"]))))
	_sessions_box.add_child(_wrap(tr("PROFILE_SESSIONS_NOTE"), &"SmallMutedLabel"))


func _show_legal(key: String) -> void:
	var doc: Dictionary = DataLoader.load_json(LEGAL_PATH)[key]
	text_requested.emit(tr(doc["title"]), tr(doc["body"]))


## Tekan dua kali untuk konfirmasi, lalu hapus semua simpanan & kembali ke layar judul.
func _on_reset() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_reset_label.text = tr("SETTINGS_RESET_CONFIRM")
		_reset_label.add_theme_font_size_override("font_size", 17)
		return
	SaveManager.reset_all()
	get_tree().change_scene_to_file(TITLE_SCENE)


func _on_save(slot: String) -> void:
	var ok := SaveManager.save_slot(slot)
	_save_count += 1
	_show_save_feedback(tr("SAVE_OK") if ok else tr("SAVE_FAILED"), ok)
	_refresh()


func _on_load(slot: String) -> void:
	if not SaveManager.has_slot(slot):
		_show_save_feedback(tr("SAVE_EMPTY"), false)
		return
	if SaveManager.load_slot(slot):
		get_tree().reload_current_scene()  # bangun ulang semua layar dari state yang dimuat
	else:
		_show_save_feedback(SaveManager.load_error_text(slot), false)


func _show_save_feedback(text: String, ok: bool) -> void:
	_save_feedback.show()
	_save_feedback.theme_type_variation = &"FeedbackGood" if ok else &"FeedbackBad"
	_save_feedback_label.text = text
	_save_feedback_label.add_theme_color_override("font_color", Color("#1e5e45") if ok else Palette.LOSS)


## Simpan otomatis dulu sebelum meninggalkan layar utama.
func _leave_to(scene: String) -> void:
	SaveManager.save_slot(SaveManager.AUTO_SLOT)
	get_tree().change_scene_to_file(scene)


# ==================================================================================================
# Alat bantu
# ==================================================================================================

## Judul bagian + keterangan kecil di kanan; mengembalikan label kanan.
func _title(page: Container, text: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var title := _label(text, &"SubSectionLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var side := _label("", &"SmallMutedLabel")
	side.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(side)
	page.add_child(row)
	return side


## Kartu Perjalanan Hidup: sampul ilustrasi bab menempel ke tepi kartu (dipotong sudut bulat seperti kartu
## pemain), lalu isi kartu dengan jarak tepi biasa.
func _life_card(page: Container) -> VBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"HomeCard"
	var style := card.get_theme_stylebox("panel", &"HomeCard").duplicate() as StyleBoxFlat
	var pad := Vector4(20, 18, 20, 18)
	if style:
		pad = Vector4(style.content_margin_left, style.content_margin_top, style.content_margin_right, style.content_margin_bottom)
		style.content_margin_left = 3
		style.content_margin_right = 3
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		card.add_theme_stylebox_override("panel", style)
	card.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	_life_art = TextureRect.new()
	_life_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_life_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_life_art.custom_minimum_size = Vector2(0, 168)
	_life_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_life_art)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(pad.x) - 3)
	margin.add_theme_constant_override("margin_top", int(pad.y) - 3)
	margin.add_theme_constant_override("margin_right", int(pad.z) - 3)
	margin.add_theme_constant_override("margin_bottom", int(pad.w) - 3)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	stack.add_child(margin)
	card.add_child(stack)
	page.add_child(card)
	return box


func _card(page: Container, variation: StringName, separation: int) -> VBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = variation
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	card.add_child(box)
	page.add_child(card)
	return box


func _segment(text: String, group: ButtonGroup, pressed: bool) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = group
	button.theme_type_variation = &"SegmentButton"
	button.text = text
	button.add_theme_font_size_override("font_size", 20)
	button.custom_minimum_size = Vector2(0, 56)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.button_pressed = pressed
	return button


func _stat_tile(title: String, value: String, sub := "") -> PanelContainer:
	var tile := PanelContainer.new()
	tile.theme_type_variation = &"StatTile"
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var caps := _wrap(title, &"TileCapsLabel")
	box.add_child(caps)
	var value_label := _wrap(value, &"TileValueLabel")
	box.add_child(value_label)
	if sub != "":
		box.add_child(_wrap(sub, &"SmallMutedLabel"))
	tile.add_child(box)
	return tile


func _value_row(name: String, value: String, color := Palette.INK, name_variation := &"RowLabel") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := _wrap(name, name_variation)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value_label := _label(value, &"RowValueLabel")
	value_label.add_theme_color_override("font_color", color)
	row.add_child(value_label)
	return row


func _chip(text: String, variation: StringName, label_variation := &"MoodLabel") -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = variation
	chip.add_child(_label(text, label_variation))
	return chip


func _chevron() -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = CHEVRON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(12, 20)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _divider() -> Panel:
	var line := Panel.new()
	line.theme_type_variation = &"Divider"
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _padded(control: Control, side: int, vertical := 0) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", side)
	margin.add_theme_constant_override("margin_right", side)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_bottom", vertical)
	margin.add_child(control)
	return margin


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


func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
