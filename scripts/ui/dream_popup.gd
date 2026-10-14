extends ModalPopup
## Popup satu impian (v1.5-0 langkah 3), dengan dua mode:
## - Detail : progres, tenggat, saran setoran, petunjuk instrumen, setor manual, lepaskan.
## - Terlewat: tenggat sudah lewat; pemain wajib memilih memperpanjang atau melepas.

var _dream_id := ""
var _release_armed := false  # ketukan pertama "Lepaskan" hanya meminta konfirmasi
var _release_button: Button


## Mode detail, dibuka dari kartu impian di Beranda.
func open_detail(dream_id: String) -> void:
	_dream_id = dream_id
	_release_armed = false
	_fill_detail()
	show()
	_fit_scroll()


## Mode tenggat terlewat. `view` = GameState.dreams.view_of(entri).
func open_overdue(view: Dictionary) -> void:
	_dream_id = view["id"]
	var def: Dictionary = view["def"]
	var cfg := GameState.dreams.config()
	%Title.text = tr("DREAM_OVERDUE_TITLE")
	%SubtitleHolder.show()
	%Subtitle.text = tr(def["name"])
	%Body.text = tr("DREAM_OVERDUE_BODY") % [tr(def["name"]), Fmt.rupiah(view["saved"]), Fmt.rupiah(view["cost"])]
	_clear(%Rows)
	%Rows.add_child(_progress_bar(view["ratio"]))
	_clear(%Buttons)
	var extend := UiText.chunky_button(tr("DREAM_EXTEND") % [int(cfg["extend_months"]), int(cfg["extend_happiness"])],
		&"PrimaryButton", &"PrimaryButtonLabel", 88.0, 24)
	extend.pressed.connect(func() -> void:
		GameState.dreams.extend(_dream_id)
		close())
	%Buttons.add_child(extend)
	var release := UiText.chunky_button(tr("DREAM_RELEASE_OVERDUE") % int(cfg["release_happiness"]),
		&"DangerButton", &"DangerButtonLabel", 88.0, 22)
	release.pressed.connect(func() -> void:
		GameState.dreams.release(_dream_id)
		close())
	%Buttons.add_child(release)
	Sfx.play("alert")
	show()
	_fit_scroll()


func _fill_detail() -> void:
	var entry := GameState.dreams.get_active(_dream_id)
	if entry.is_empty():
		close()
		return
	var view := GameState.dreams.view_of(entry)
	var def: Dictionary = view["def"]
	%Title.text = tr(def["name"])
	%SubtitleHolder.show()
	%Subtitle.text = UiText.horizon_text(def["horizon"])
	%Body.text = UiText.money(tr(def["desc"]))

	_clear(%Rows)
	%Rows.add_child(_progress_bar(view["ratio"]))
	%Rows.add_child(_label(tr("DREAM_PROGRESS") % [Fmt.rupiah(view["saved"]), Fmt.rupiah(view["cost"])], &"RowValueLabel"))
	var months_left := int(entry["deadline"]) - GameState.month
	%Rows.add_child(_label(tr("DREAM_DEADLINE") % [Fmt.game_date(entry["deadline"]), months_left], &"InfoLabel"))
	%Rows.add_child(_label(tr("DREAM_NEEDED") % Fmt.rupiah(GameState.dreams.needed_monthly(entry)), &"InfoLabel"))
	%Rows.add_child(_label(tr("DREAM_HINT_" + str(def["horizon"]).to_upper()), &"SmallMutedLabel"))
	if def.has("vehicle"):
		%Rows.add_child(_label(tr("DREAM_VEHICLE_HINT"), &"SmallMutedLabel"))

	%Rows.add_child(_label(tr("DREAM_DEPOSIT"), &"ReportHeaderLabel"))
	var deposit_row := HBoxContainer.new()
	deposit_row.add_theme_constant_override("separation", 8)
	for amount: int in GameState.dreams.config()["deposit_amounts"]:
		var button := Button.new()
		button.theme_type_variation = &"QuickButton"
		button.text = UiText.amount_short(amount)
		button.custom_minimum_size = Vector2(0, 60)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = amount > GameState.cash
		button.pressed.connect(_on_deposit.bind(amount))
		deposit_row.add_child(button)
	%Rows.add_child(deposit_row)

	_clear(%Buttons)
	_release_button = UiText.chunky_button(tr("DREAM_RELEASE"), &"DangerButton", &"DangerButtonLabel", 72.0)
	_release_button.pressed.connect(_on_release)
	%Buttons.add_child(_release_button)
	var close_button := UiText.chunky_button(tr("BTN_CLOSE"), &"NeutralButton", &"NeutralButtonLabel", 72.0)
	close_button.pressed.connect(close)
	%Buttons.add_child(close_button)


func _on_deposit(amount: int) -> void:
	if GameState.dreams.deposit(_dream_id, amount):
		Sfx.play("coin")
	if GameState.dreams.get_active(_dream_id).is_empty():
		close()  # dananya cukup: impian terwujud, perayaan muncul lewat antrean popup
	else:
		_fill_detail()
		_fit_scroll()


func _on_release() -> void:
	if not _release_armed:
		_release_armed = true
		var label: Label = _release_button.get_child(0)
		label.text = tr("DREAM_RELEASE_CONFIRM") % int(GameState.dreams.config()["release_happiness"])
		label.add_theme_font_size_override("font_size", 20)
		return
	GameState.dreams.release(_dream_id)
	close()


## Area isi di-scroll; tingginya mengikuti isi (dibatasi) setelah label selesai ditata.
func _fit_scroll() -> void:
	await get_tree().process_frame
	%Scroll.custom_minimum_size.y = minf(%Rows.get_combined_minimum_size().y, 560.0)


func _progress_bar(ratio: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"XpBar"
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = ratio
	return bar


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1
	return label


func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
