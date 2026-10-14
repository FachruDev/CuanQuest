extends ModalPopup
## Popup "Pilih Impian" (v1.5-0 langkah 3). Muncul di awal permainan dan saat pemain menekan
## "+ Tambah impian" di Beranda. Pemain memilih beberapa impian sekaligus (dibatasi jumlah slot).

## Impian baru dipilih; main.gd membuka Rencana Gaji agar porsinya bisa dicek.
signal dreams_picked

const MAX_LIST_HEIGHT := 620.0

var _limit := 1
var _buttons: Dictionary = {}  # dream_id -> Button (toggle)
var _confirm: Button


func open() -> void:
	var first := not GameState.dreams.asked
	var slots := int(GameState.dreams.config()["max_active"]) - GameState.dreams.active().size()
	_limit = mini(slots, int(GameState.dreams.config()["max_pick_start"])) if first else slots
	%Title.text = tr("PICKER_TITLE")
	%SubtitleHolder.hide()
	%Body.text = tr("PICKER_INTRO") % _limit
	_build_list()
	_build_buttons()
	_refresh()
	%Scroll.scroll_vertical = 0
	show()
	await get_tree().process_frame
	%Scroll.custom_minimum_size.y = minf(%Rows.get_combined_minimum_size().y, MAX_LIST_HEIGHT)


func _build_list() -> void:
	for child in %Rows.get_children():
		%Rows.remove_child(child)
		child.queue_free()
	_buttons.clear()
	var available := GameState.dreams.available()
	if available.is_empty():
		var empty := Label.new()
		empty.text = tr("PICKER_NONE")
		empty.theme_type_variation = &"MutedLabel"
		%Rows.add_child(empty)
		return
	for def: Dictionary in available:
		var button := Button.new()
		button.toggle_mode = true
		button.theme_type_variation = &"ChoiceCardButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 92)
		button.text = "%s\n%s" % [tr(def["name"]), tr("PICKER_ITEM") % [Fmt.rupiah(GameState.dreams.cost_of(def)),
			UiText.horizon_text(def["horizon"]), int(def["months"])]]
		button.tooltip_text = UiText.money(tr(def["desc"]))
		button.toggled.connect(_refresh.unbind(1))
		%Rows.add_child(button)
		_buttons[def["id"]] = button


func _build_buttons() -> void:
	for child in %Buttons.get_children():
		%Buttons.remove_child(child)
		child.queue_free()
	_confirm = UiText.chunky_button(tr("PICKER_CONFIRM"), &"PrimaryButton", &"PrimaryButtonLabel", 88.0)
	_confirm.pressed.connect(_on_confirm)
	%Buttons.add_child(_confirm)
	var later := UiText.chunky_button(tr("PICKER_LATER"), &"NeutralButton", &"NeutralButtonLabel", 72.0)
	later.pressed.connect(_on_later)
	%Buttons.add_child(later)


## Batas pilihan: tombol yang belum dipilih dinonaktifkan saat slot sudah penuh.
func _refresh() -> void:
	var chosen := _selected()
	for id: String in _buttons:
		var button: Button = _buttons[id]
		button.disabled = not button.button_pressed and chosen.size() >= _limit
	_confirm.disabled = chosen.is_empty()
	_confirm.get_child(0).modulate.a = 0.45 if chosen.is_empty() else 1.0


func _selected() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _buttons:
		if _buttons[id].button_pressed:
			ids.append(id)
	return ids


func _on_confirm() -> void:
	GameState.dreams.pick(_selected())
	Sfx.play("success")
	dreams_picked.emit()
	close()


func _on_later() -> void:
	GameState.dreams.mark_asked()
	close()
