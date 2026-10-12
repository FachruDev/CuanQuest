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
		button.custom_minimum_size = Vector2(0, 76)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 22)
		button.text = "%s. %s" % [char(65 + i), tr(options[i])]  # A. B. C. D.
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
			_buttons[i].modulate = MonthReport.GREEN
		elif i == index:
			_buttons[i].modulate = MonthReport.RED

	if result["correct"]:
		%ResultLabel.text = tr("QUIZ_CORRECT") % [Fmt.rupiah(result["reward"]), result["xp"]]
		%ResultLabel.modulate = MonthReport.GREEN
	else:
		%ResultLabel.text = tr("QUIZ_WRONG") % result["xp"]
		%ResultLabel.modulate = MonthReport.RED
	%ExplainLabel.text = tr(_question["explain"])
	%ResultBox.show()
