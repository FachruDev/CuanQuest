extends ModalPopup
## Detail satu lencana pencapaian (Profil v2 > Koleksi): lencana besar, status (terbuka + tanggal, atau
## terkunci + progres), syarat, hadiah (gelar / bingkai), lalu tombol Tutup dan "Pakai gelar" /
## "Pakai bingkai" bila hadiahnya sudah bisa dipakai.

const LOCK_ICON := preload("res://assets/icons/lock.svg")
const GRAY := preload("res://theme/grayscale.gdshader")

var _id := ""
var _gray: ShaderMaterial


func _ready() -> void:
	super()
	_gray = ShaderMaterial.new()
	_gray.shader = GRAY
	$Dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close())


func open(id: String) -> void:
	_id = id
	var achievements := GameState.achievements
	var d := achievements.def(id)
	var open := achievements.is_unlocked(id)
	var icon := achievements.icon(id)
	%Badge.texture = load(icon) if icon != "" else LOCK_ICON
	%Badge.material = null if open else _gray
	%Badge.modulate = Color.WHITE if open else Color(1, 1, 1, 0.6)
	var box: VBoxContainer = %VBox
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)  # ruang di bawah lencana yang menjorok ke kartu
	box.add_child(gap)

	var status := ""
	if open:
		var record: Dictionary = achievements.unlocked[id]
		var t := Time.get_date_dict_from_unix_time(int(record["date"]))
		status = tr("ACH_DETAIL_OPEN") % ["%02d/%02d/%d" % [t["day"], t["month"], t["year"]], record.get("name", "")]
	else:
		var target := achievements.target(d)
		status = tr("ACH_DETAIL_LOCKED") % [UiText.achievement_progress(d, minf(achievements.value(d), target)),
			UiText.achievement_progress(d, target)] if target > 1.0 else tr("ACH_LOCKED")
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"MoodGreen" if open else &"MoodNeutral"
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.add_child(_label(status, &"MoodLabel"))
	box.add_child(chip)
	var title := _label(tr("ACH_" + id.to_upper()), &"PopupTitleLabel")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var desc := _label(tr("ACH_%s_DESC" % id.to_upper()), &"PopupBodyLabel")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)
	if not open and achievements.target(d) > 1.0:
		var bar := ProgressBar.new()
		bar.theme_type_variation = &"XpBar"
		bar.custom_minimum_size = Vector2(0, 14)
		bar.show_percentage = false
		bar.max_value = achievements.target(d)
		bar.value = minf(achievements.value(d), achievements.target(d))
		box.add_child(bar)

	var rewards := VBoxContainer.new()
	rewards.add_theme_constant_override("separation", 8)
	if d.get("title", false):
		rewards.add_child(_reward_row(tr("TITLE_" + id.to_upper()), &"ChipTeal", tr("ACH_DETAIL_TITLE_NOTE")))
	if d.has("frame"):
		rewards.add_child(_reward_row(tr("FRAME_" + str(d["frame"]).to_upper()), &"MoodGold", tr("ACH_DETAIL_FRAME_NOTE")))
	if rewards.get_child_count() > 0:
		var card := PanelContainer.new()
		card.theme_type_variation = &"StatTile"
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 8)
		var caps := _label(tr("ACH_DETAIL_REWARD"), &"TileCapsLabel")
		caps.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		inner.add_child(caps)
		inner.add_child(rewards)
		card.add_child(inner)
		box.add_child(card)
	var note := _label(tr("ACH_DETAIL_NOTE"), &"SmallMutedLabel")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	var close_button := UiText.chunky_button(tr("BTN_CLOSE"), &"NeutralButton", &"NeutralButtonLabel", 76.0, 24)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.pressed.connect(close)
	buttons.add_child(close_button)
	var action := _action_for(d, open)
	if action != "":
		var use := UiText.chunky_button(tr(action), &"PrimaryButton", &"PrimaryButtonLabel", 76.0, 24)
		use.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		use.pressed.connect(func() -> void:
			if action == "ACH_USE_TITLE":
				GameState.achievements.set_title(_id)
			else:
				GameState.achievements.set_frame(str(d["frame"]))
			close())
		buttons.add_child(use)
	box.add_child(buttons)
	Sfx.play("coin" if open else "click")
	show()


## Tombol hadiah: pakai gelar (jika belum dipakai), selain itu pakai bingkai (jika belum dipakai).
func _action_for(d: Dictionary, open: bool) -> String:
	if not open:
		return ""
	var achievements := GameState.achievements
	if d.get("title", false) and achievements.title != _id:
		return "ACH_USE_TITLE"
	if d.has("frame") and achievements.current_frame()["id"] != d["frame"]:
		return "ACH_USE_FRAME"
	return ""


func _reward_row(text: String, chip_variation: StringName, note: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var chip := PanelContainer.new()
	chip.theme_type_variation = chip_variation
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(_label(text, &"ChipLabel" if chip_variation == &"ChipTeal" else &"MoodLabel"))
	row.add_child(chip)
	var note_label := _label(note, &"RowLabel")
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	note_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label.custom_minimum_size.x = 1
	row.add_child(note_label)
	return row


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
