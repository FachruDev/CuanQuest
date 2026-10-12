extends Control
## Tutorial singkat 5 layar (GDD 4.1 & 5.12). Selesai/lewati -> menandai tutorial selesai
## (syarat Tahap 2) lalu masuk ke layar utama.

const MAIN_SCENE := "res://scenes/main.tscn"
const PAGE_COUNT := 5

var _page := 0


func _ready() -> void:
	%NextButton.pressed.connect(_on_next)
	%PrevButton.pressed.connect(func() -> void: _show_page(_page - 1))
	%SkipButton.pressed.connect(_finish)
	_show_page(0)


func _show_page(index: int) -> void:
	_page = clampi(index, 0, PAGE_COUNT - 1)
	%PageTitle.text = tr("TUT_%d_TITLE" % (_page + 1))
	%PageBody.text = tr("TUT_%d_BODY" % (_page + 1))
	%PageIndicator.text = "%d / %d" % [_page + 1, PAGE_COUNT]
	%PrevButton.disabled = _page == 0
	%NextButton.text = tr("TUT_FINISH") if _page == PAGE_COUNT - 1 else tr("TUT_NEXT")


func _on_next() -> void:
	if _page == PAGE_COUNT - 1:
		_finish()
	else:
		_show_page(_page + 1)


func _finish() -> void:
	GameState.mark_tutorial_done()
	get_tree().change_scene_to_file(MAIN_SCENE)
