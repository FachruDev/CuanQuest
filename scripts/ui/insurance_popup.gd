extends ModalPopup
## Popup "Perlindungan" (v1.5a langkah 3): pilih asuransi kesehatan, jiwa, dan kendaraan.
## Premi dibayar otomatis tiap awal bulan; perlindungan berlaku setelah masa tunggu.
## Pilihan baru disimpan lewat GameState.insurance.set_policies() saat menekan Simpan.

var _choices: Dictionary = {}  # kategori -> id produk ("" = tanpa asuransi)


func open() -> void:
	_choices.clear()
	for category: String in GameState.insurance.data["categories"]:
		_choices[category] = GameState.insurance.policies.get(category, {}).get("id", "")
	%Title.text = tr("INS_TITLE")
	%SubtitleHolder.show()
	%Body.show()
	%Body.text = tr("INS_BODY") % int(GameState.insurance.data.get("waiting_months", 1))
	_build_rows()
	_refresh()
	_clear(%Buttons)
	var save := UiText.chunky_button(tr("INS_SAVE"), &"PrimaryButton", &"PrimaryButtonLabel", 80.0, 30)
	save.pressed.connect(func() -> void:
		GameState.insurance.set_policies(_choices)
		close())
	%Buttons.add_child(save)
	var close_button := UiText.chunky_button(tr("BTN_CLOSE"), &"NeutralButton", &"NeutralButtonLabel", 68.0, 26)
	close_button.pressed.connect(close)
	%Buttons.add_child(close_button)
	%Scroll.scroll_vertical = 0
	show()
	_fit_scroll()


## Per kategori: judul, kartu "Tanpa asuransi" + produk (seperti radio button), status polis.
func _build_rows() -> void:
	_clear(%Rows)
	for category: String in GameState.insurance.data["categories"]:
		%Rows.add_child(_label(tr("INS_CAT_" + category.to_upper()), &"ReportHeaderLabel"))
		if category == "vehicle" and GameState.dreams.vehicle() == "":
			%Rows.add_child(_label(tr("INS_NEED_VEHICLE"), &"SmallMutedLabel"))
			continue
		var group := ButtonGroup.new()
		var options: Array = [{}]
		options.append_array(GameState.insurance.products_in(category))
		for product: Dictionary in options:
			var id: String = product.get("id", "")
			var button := Button.new()
			button.toggle_mode = true
			button.button_group = group
			button.theme_type_variation = &"ChoiceCardButton"
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.custom_minimum_size = Vector2(0, 84)
			button.text = _option_text(product)
			button.button_pressed = id == _choices[category]
			button.toggled.connect(func(on: bool) -> void:
				if on:
					_choices[category] = id
					_refresh())
			%Rows.add_child(button)
		var status := _status_text(category)
		if status != "":
			%Rows.add_child(_label(status, &"SmallMutedLabel"))


func _option_text(product: Dictionary) -> String:
	if product.is_empty():
		return "%s\n%s" % [tr("INS_NONE"), tr("INS_NONE_DESC")]
	return "%s · %s\n%s" % [tr(product["name"]), tr("INS_PER_MONTH") % Fmt.rupiah(GameState.insurance.premium(product)),
		UiText.money(tr(product["desc"]))]


## "Polis aktif" atau "Masa tunggu: berlaku mulai Maret Tahun 2" untuk polis yang dimiliki.
func _status_text(category: String) -> String:
	if not GameState.insurance.policies.has(category):
		return ""
	var product := GameState.insurance.policy_product(category)
	if not GameState.insurance.active_policy(category).is_empty():
		return tr("INS_STATUS_ACTIVE") % tr(product["name"])
	var from := int(GameState.insurance.policies[category]["since"]) + int(GameState.insurance.data.get("waiting_months", 1))
	return tr("INS_STATUS_WAITING") % [tr(product["name"]), Fmt.game_date(from)]


func _refresh() -> void:
	var total := 0
	for category: String in _choices:
		var product := GameState.insurance.find_product(_choices[category])
		if not product.is_empty() and not (category == "vehicle" and GameState.dreams.vehicle() == ""):
			total += GameState.insurance.premium(product)
	%Subtitle.text = tr("INS_TOTAL") % Fmt.rupiah(total)


## Area isi di-scroll; tingginya mengikuti isi (dibatasi) setelah label selesai ditata.
func _fit_scroll() -> void:
	await get_tree().process_frame
	%Scroll.custom_minimum_size.y = minf(%Rows.get_combined_minimum_size().y, 520.0)


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
