extends ModalPopup
## Satu soal kuis pilihan ganda. Setelah menjawab: jawaban benar ditandai hijau,
## pilihan salah merah, lalu tampil penjelasan & hadiah.

var _question: Dictionary = {}
var _buttons: Array[Button] = []


func _ready() -> void:
	super()
	%CloseButton.pressed.connect(close)


func open(question: Dictionary) -> void:
	_question = question
	%TopicLabel.text = tr("TOPIC_" + str(question["topic"]).to_upper())
	%QuestionLabel.text = tr(question["q"])

	for child in %Options.get_children():
		%Options.remove_child(child)
		child.queue_free()
	_buttons.clear()
	var options: Array = question["options"]
	for i in options.size():
		var button := Button.new()
		button.theme_type_variation = &"QuizOptionButton"
		button.custom_minimum_size = Vector2(0, 70)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s.  %s" % [char(65 + i), tr(options[i])]  # A. B. C. D.
		button.pressed.connect(_on_answer.bind(i))
		%Options.add_child(button)
		_buttons.append(button)

	%ResultBox.hide()
	show()


func _on_answer(index: int) -> void:
	var result := GameState.answer_quiz(_question, index)
	var correct_index := int(_question["answer"])
	for i in _buttons.size():
		_buttons[i].disabled = true
		if i == correct_index:
			_buttons[i].theme_type_variation = &"QuizCorrectButton"
		elif i == index:
			_buttons[i].theme_type_variation = &"QuizWrongButton"

	Sfx.play("success" if result["correct"] else "fail")
	if result["correct"]:
		%ResultLabel.text = tr("QUIZ_CORRECT") % [Fmt.rupiah(result["reward"]), result["xp"]]
		%ResultLabel.add_theme_color_override("font_color", Palette.GAIN)
	else:
		%ResultLabel.text = tr("QUIZ_WRONG") % result["xp"]
		%ResultLabel.add_theme_color_override("font_color", Palette.LOSS)
	%ExplainLabel.text = tr(_question["explain"])
	%ResultBox.show()
