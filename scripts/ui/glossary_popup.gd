extends ModalPopup
## Glosarium istilah keuangan dengan kolom pencarian. Bisa dibuka kapan saja (tombol "?").

const GLOSSARY_PATH := "res://data/glossary.json"

var _terms: Array = []


func _ready() -> void:
	super()
	_terms = DataLoader.load_json(GLOSSARY_PATH).get("terms", [])
	%CloseButton.pressed.connect(close)
	%SearchEdit.text_changed.connect(_filter)


func open() -> void:
	%SearchEdit.text = ""
	_filter("")
	show()


func _filter(query: String) -> void:
	for child in %TermList.get_children():
		%TermList.remove_child(child)
		child.queue_free()
	query = query.strip_edges().to_lower()
	for entry: Dictionary in _terms:
		var term := tr(entry["term"])
		var definition := tr(entry["definition"])
		if query != "" and not (query in term.to_lower() or query in definition.to_lower()):
			continue
		var box := VBoxContainer.new()
		var term_label := Label.new()
		term_label.text = term
		term_label.modulate = Color("#5dade2")
		term_label.add_theme_font_size_override("font_size", 24)
		var def_label := Label.new()
		def_label.text = definition
		def_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		def_label.add_theme_font_size_override("font_size", 20)
		box.add_child(term_label)
		box.add_child(def_label)
		%TermList.add_child(box)
	if %TermList.get_child_count() == 0:
		var empty := Label.new()
		empty.text = tr("GLOSSARY_NOT_FOUND")
		empty.modulate = MonthReport.MUTED
		%TermList.add_child(empty)
