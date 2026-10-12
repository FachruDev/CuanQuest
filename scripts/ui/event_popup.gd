extends ModalPopup
## Kartu event hidup: judul, cerita, 2-3 pilihan. Setelah memilih, tampil hasil & perubahannya.


func _ready() -> void:
	super()
	%OkButton.pressed.connect(close)


func open(event: Dictionary) -> void:
	%CategoryLabel.text = tr("EVENT_CAT_" + str(event["category"]).to_upper())
	%TitleLabel.text = tr(event["title"])
	%BodyLabel.text = tr(event["text"])

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
		var text := tr(choice["label"])
		if int(choice.get("cost", 0)) > 0:
			text += " (%s)" % Fmt.rupiah(choice["cost"])
		if not GameState.can_choose(choice):
			button.disabled = true
			text += "\n" + tr("EVENT_NOT_ENOUGH_CASH")
		button.text = text
		button.pressed.connect(_on_choice.bind(i))
		%Choices.add_child(button)

	%Choices.show()
	%ResultBox.hide()
	show()
	Sfx.play("alert")
	Sfx.vibrate()


func _on_choice(index: int) -> void:
	var result := GameState.resolve_event(index)
	%Choices.hide()
	%ResultLabel.text = tr(result["result"])
	%ChangesLabel.text = UiText.changes_text(result["changes"])
	%ResultBox.show()
