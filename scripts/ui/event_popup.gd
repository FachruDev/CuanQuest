extends ModalPopup
## Kartu event hidup: judul, tokoh (v1.5d), cerita, 2-3 pilihan. Setelah memilih, tampil hasil &
## perubahannya.

var _speaker: HBoxContainer  # baris tokoh: potret + nama + peran & kedekatan
var _portrait: CharacterPortrait
var _speaker_name: Label
var _speaker_info: Label
var _quiet_icon: TextureRect  # ikon hati untuk event bertanda "quiet" (v2b langkah 4)

const QUIET_ICON := preload("res://assets/icons/heart.svg")


func _ready() -> void:
	super()
	%OkButton.pressed.connect(close)
	_build_speaker()


func _build_speaker() -> void:
	_speaker = HBoxContainer.new()
	_speaker.alignment = BoxContainer.ALIGNMENT_CENTER
	_speaker.add_theme_constant_override("separation", 12)
	_portrait = CharacterPortrait.new(56.0)
	_speaker.add_child(_portrait)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	_speaker_name = Label.new()
	_speaker_name.theme_type_variation = &"AssetNameLabel"
	_speaker_info = Label.new()
	_speaker_info.theme_type_variation = &"SmallMutedLabel"
	texts.add_child(_speaker_name)
	texts.add_child(_speaker_info)
	_speaker.add_child(texts)
	var box := %BodyLabel.get_parent()
	box.add_child(_speaker)
	box.move_child(_speaker, %BodyLabel.get_index())


## Tokoh event: nama, peran, dan kedekatan sekarang ("Sahabat · Akrab (60)").
func _show_speaker(id: String) -> void:
	_speaker.visible = id != ""
	if id == "":
		return
	var characters := GameState.characters
	_portrait.character_id = id
	_speaker_name.text = characters.name_of(id)
	var value := characters.rel_of(id)
	_speaker_info.text = tr("CHAR_INFO") % [tr(characters.def(id).get("role", "")), tr(characters.level_key(value)), value]


func open(event: Dictionary) -> void:
	%CategoryLabel.text = tr("EVENT_CAT_" + str(event["category"]).to_upper())
	var vars := GameState.events.pending_vars  # isian event karier ({job}, {salary}, ...)
	%TitleLabel.text = UiText.event_text(tr(event["title"]), vars)
	%BodyLabel.text = UiText.event_text(tr(event["text"]), vars)
	_show_speaker(event.get("character", ""))

	for child in %Choices.get_children():
		%Choices.remove_child(child)
		child.queue_free()
	var choices: Array = event["choices"]
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var button := Button.new()
		button.theme_type_variation = &"ChoiceCardButton"
		button.custom_minimum_size = Vector2(0, 84)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var text := UiText.event_text(tr(choice["label"]), vars)
		var cost := GameState.events.choice_cost(choice)
		var covered := GameState.insurance.cover(choice)
		if covered > 0:
			text += " " + tr("EVENT_COST_COVERED") % [Fmt.rupiah(cost - covered), Fmt.rupiah(covered)]
		elif cost > 0:
			text += " (%s)" % Fmt.rupiah(cost)
		if not GameState.events.can_choose(choice):
			button.disabled = true
			text += "\n" + tr("EVENT_NOT_ENOUGH_CASH")
		button.text = text
		button.pressed.connect(_on_choice.bind(i))
		%Choices.add_child(button)

	%Choices.show()
	%ResultBox.hide()
	var quiet: bool = event.get("quiet", false)
	_set_quiet(quiet)
	show()
	if not quiet:  # event "quiet" (mis. kesehatan mental): tanpa bunyi peringatan & getar, sesuai pedoman
		Sfx.play("alert")
		Sfx.vibrate()


## Event bertanda "quiet": true (event Depresi, pedoman konten sensitif) tampil tenang: lencana emas
## dengan ikon hati, bukan tanda seru merah.
func _set_quiet(on: bool) -> void:
	var badge: PanelContainer = $Center/Dialog/BadgeHolder/Badge
	badge.theme_type_variation = &"BadgeGoldPanel" if on else &"WarningBadgePanel"
	badge.get_node("Mark").visible = not on
	if on and _quiet_icon == null:
		_quiet_icon = TextureRect.new()
		_quiet_icon.texture = QUIET_ICON
		_quiet_icon.custom_minimum_size = Vector2(56, 56)
		_quiet_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_quiet_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_quiet_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_quiet_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_quiet_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.add_child(_quiet_icon)
	if _quiet_icon != null:
		_quiet_icon.visible = on


func _on_choice(index: int) -> void:
	var result := GameState.events.resolve(index)
	%Choices.hide()
	var text := UiText.event_text(tr(result["result"]), result.get("vars", {}))
	for claim: Dictionary in result.get("claims", []):
		text += "\n" + tr("EVENT_CLAIM_" + str(claim["category"]).to_upper()) % Fmt.rupiah(claim["amount"])
	%ResultLabel.text = text
	%ChangesLabel.text = UiText.changes_text(result["changes"])
	if _speaker.visible:  # kedekatan setelah memilih
		_show_speaker(_portrait.character_id)
	%ResultBox.show()
