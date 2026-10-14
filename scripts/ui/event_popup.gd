extends ModalPopup
## Kartu event hidup: judul, cerita, 2-3 pilihan. Setelah memilih, tampil hasil & perubahannya.


func _ready() -> void:
	super()
	%OkButton.pressed.connect(close)


func open(event: Dictionary) -> void:
	%CategoryLabel.text = tr("EVENT_CAT_" + str(event["category"]).to_upper())
	%TitleLabel.text = tr(event["title"])
	%BodyLabel.text = UiText.money(tr(event["text"]))

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
		var text := UiText.money(tr(choice["label"]))
		var cost := GameState.choice_cost(choice)
		var covered := GameState.insurance_cover(choice)
		if covered > 0:
			text += " " + tr("EVENT_COST_COVERED") % [Fmt.rupiah(cost - covered), Fmt.rupiah(covered)]
		elif cost > 0:
			text += " (%s)" % Fmt.rupiah(cost)
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
	var text := UiText.money(tr(result["result"]))
	for claim: Dictionary in result.get("claims", []):
		text += "\n" + tr("EVENT_CLAIM_" + str(claim["category"]).to_upper()) % Fmt.rupiah(claim["amount"])
	%ResultLabel.text = text
	%ChangesLabel.text = UiText.changes_text(result["changes"])
	%ResultBox.show()
