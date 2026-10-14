extends ModalPopup
## Popup tawaran kerja (v1.5b): lamaran yang diterima bulan ini. Pemain memilih satu tawaran
## (tawaran lain otomatis ditolak) atau menolak semuanya. Tawaran kedaluwarsa akhir bulan.

signal offer_accepted(title: String, first_salary: int)

var _selected := 0


func open() -> void:
	if GameState.job_offers.is_empty():
		closed.emit()  # tawaran sudah diambil/ditolak; lanjut ke popup berikutnya di antrean
		return
	_selected = 0  # pilihan awal: gaji tertinggi
	for i in GameState.job_offers.size():
		if GameState.job_offers[i]["salary"] > GameState.job_offers[_selected]["salary"]:
			_selected = i
	%Title.text = tr("OFFER_TITLE")
	%SubtitleHolder.show()
	%Subtitle.text = tr("OFFER_SUBTITLE") % GameState.job_offers.size()
	%Body.show()
	if GameState.is_employed():
		%Body.text = tr("OFFER_BODY_SWITCH") % [tr(GameState.current_job_def()["title"]), Fmt.rupiah(GameState.salary)]
	else:
		%Body.text = tr("OFFER_BODY")
	_clear(%Rows)
	var group := ButtonGroup.new()
	for i in GameState.job_offers.size():
		var offer: Dictionary = GameState.job_offers[i]
		var def := GameState.job_def(offer["job_id"])
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = &"ChoiceCardButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 92)
		button.text = "%s · %s\n%s · %s" % [tr(def["title"]), offer["company"],
			tr("CAREER_PER_MONTH") % Fmt.rupiah(offer["salary"]), tr(GameState.track_def(def["track"])["name"])]
		button.button_pressed = i == _selected
		button.toggled.connect(func(on: bool) -> void:
			if on:
				_selected = i)
		%Rows.add_child(button)

	_clear(%Buttons)
	var accept := UiText.chunky_button(tr("OFFER_ACCEPT"), &"PrimaryButton", &"PrimaryButtonLabel", 80.0, 30)
	accept.pressed.connect(_on_accept)
	%Buttons.add_child(accept)
	var decline := UiText.chunky_button(tr("OFFER_DECLINE"), &"NeutralButton", &"NeutralButtonLabel", 68.0, 26)
	decline.pressed.connect(func() -> void:
		GameState.decline_offers()
		close())
	%Buttons.add_child(decline)
	Sfx.play("success")
	show()
	_fit_scroll()


func _on_accept() -> void:
	var offer: Dictionary = GameState.job_offers[_selected]
	var title: String = GameState.job_def(offer["job_id"])["title"]
	var cash_before := GameState.cash
	GameState.accept_offer(_selected)
	close()
	offer_accepted.emit(title, GameState.cash - cash_before)


## Area isi di-scroll; tingginya mengikuti isi (dibatasi) setelah label selesai ditata.
func _fit_scroll() -> void:
	await get_tree().process_frame
	%Scroll.custom_minimum_size.y = minf(%Rows.get_combined_minimum_size().y, 480.0)


func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
