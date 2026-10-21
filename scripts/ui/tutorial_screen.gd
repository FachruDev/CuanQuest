extends Control
## Tutorial singkat 5 halaman (GDD 4.1 & 5.12), tema "Senja Cuan".
## Tiap halaman: ilustrasi (SVG tanpa teks + label Godot di atasnya agar bisa diterjemahkan),
## judul, isi, dan kotak tips (paragraf kedua TUT_n_BODY, dipisah baris kosong).
## Selesai/lewati -> menandai tutorial selesai (syarat Tahap 2) lalu masuk ke layar utama.

const MAIN_SCENE := "res://scenes/main.tscn"
const PAGE_COUNT := 5
const ART_PATH := "res://assets/illustrations/tutorial_%d.svg"
const ARROW_ICON := preload("res://assets/icons/arrow_badge.svg")
const PLAY_ICON := preload("res://assets/icons/play_badge.svg")

var _page := 0
var _art_pages: Array[Control] = []
var _dots: Array[Panel] = []


func _ready() -> void:
	Music.play("title")
	%NextButton.pressed.connect(_on_next)
	%PrevButton.pressed.connect(func() -> void: _show_page(_page - 1))
	%SkipButton.pressed.connect(_finish)
	for i in PAGE_COUNT:
		_art_pages.append(_build_art(i + 1))
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(14, 14)
		_dots.append(dot)
		%Dots.add_child(dot)
	_show_page(0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _page > 0:
		_show_page(_page - 1)
		get_viewport().set_input_as_handled()


func _show_page(index: int) -> void:
	_page = clampi(index, 0, PAGE_COUNT - 1)
	for i in PAGE_COUNT:
		_art_pages[i].visible = i == _page
		_dots[i].theme_type_variation = &"DotActive" if i == _page else (&"DotDone" if i < _page else &"DotTodo")
		_dots[i].custom_minimum_size.x = 44 if i == _page else 14
	%PageLabel.text = tr("TUT_PAGE") % [_page + 1, PAGE_COUNT]
	%PageTitle.text = tr("TUT_%d_TITLE" % (_page + 1))
	var parts := tr("TUT_%d_BODY" % (_page + 1)).split("\n\n", false, 1)
	%PageBody.text = parts[0]
	%TipBox.visible = parts.size() > 1
	if parts.size() > 1:
		%PageTip.text = parts[1]
	%PrevButton.visible = _page > 0
	var last := _page == PAGE_COUNT - 1
	%NextLabel.text = tr("TUT_FINISH" if last else "TUT_NEXT")
	%NextIcon.texture = PLAY_ICON if last else ARROW_ICON
	%NextBox.move_child(%NextIcon, 0 if last else -1)  # ikon play di depan, panah di belakang


func _on_next() -> void:
	if _page == PAGE_COUNT - 1:
		_finish()
	else:
		_show_page(_page + 1)


func _finish() -> void:
	GameState.mark_tutorial_done()
	get_tree().change_scene_to_file(MAIN_SCENE)


# ---------------------------------------------------------------- ilustrasi

## Satu halaman ilustrasi 624x470: gambar SVG + label teks pada posisi yang sudah ditentukan.
func _build_art(page: int) -> Control:
	var art := Control.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var picture := TextureRect.new()
	picture.texture = load(ART_PATH % page)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(picture)
	if page == 1:  # karakter pilihan pemain di dalam bingkai bulat
		var avatar := AvatarView.new()
		avatar.avatar_index = GameState.avatar
		avatar.position = Vector2(198, 52)
		avatar.size = Vector2(228, 228)
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(avatar)
	for item: Array in _art_labels(page):
		_add_label(art, item[0], item[1], item[2], item[3] if item.size() > 3 else 0.0)
	%Art.add_child(art)
	return art


## [teks, kotak (x, y, w, h) dalam koordinat ilustrasi, variasi tema, rotasi derajat].
func _art_labels(page: int) -> Array:
	match page:
		1:
			return [
				["Rp", Rect2(390, 40, 76, 76), &"CoinLabel"],
				[tr("TUT_ART_VIRTUAL"), Rect2(176, 328, 286, 52), &"ArtBadgeLabel", -2.0],
			]
		2:
			return [
				[tr("TUT_ART_MONTH"), Rect2(212, 96, 200, 40), &"ArtWhiteCaps"],
				["2", Rect2(212, 140, 200, 150), &"ArtBigNumber"],
				[tr("TUT_ART_SALARY"), Rect2(6, 118, 124, 44), &"ArtChipGreen"],
				[tr("TUT_ART_COSTS"), Rect2(446, 214, 176, 44), &"ArtChipRed"],
				[tr("BTN_NEXT_MONTH"), Rect2(172, 344, 340, 72), &"ArtButtonLabel"],
			]
		3:
			return [[tr("TUT_ART_EMERGENCY"), Rect2(368, 372, 200, 34), &"ArtPillCaps"]]
		4:
			return [
				[tr("TUT_ART_STAGE") % 1, Rect2(40, 344, 136, 30), &"ArtStepLabel"],
				[tr("TUT_ART_STAGE") % 2, Rect2(176, 284, 136, 30), &"ArtStepLabel"],
				[tr("TUT_ART_STAGE") % 3, Rect2(312, 220, 136, 30), &"ArtStepLabel"],
				[tr("TUT_ART_STAGE") % 4, Rect2(448, 154, 136, 30), &"ArtStepLabel"],
				[tr("TUT_ART_RISK"), Rect2(150, 168, 220, 36), &"ArtRiskLabel", -14.0],
			]
		5:
			return [
				["?", Rect2(268, 42, 88, 88), &"ArtQuizBadge"],
				["A", Rect2(172, 227, 30, 30), &"ArtLetterMuted"],
				["B", Rect2(172, 293, 30, 30), &"ArtLetterWhite"],
				["+20 XP", Rect2(450, 90, 100, 40), &"ArtXpLabel"],
				["?", Rect2(36, 330, 62, 62), &"CoinLabel"],
				[tr("GLOSSARY_TITLE"), Rect2(108, 346, 130, 34), &"ArtPillLabel"],
			]
	return []


func _add_label(parent: Control, text: String, rect: Rect2, variation: StringName, degrees: float) -> void:
	var label := Label.new()
	label.text = text
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # teks sudah diterjemahkan
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = rect.position
	label.size = rect.size
	label.pivot_offset = rect.size / 2.0
	label.rotation_degrees = degrees
	parent.add_child(label)
