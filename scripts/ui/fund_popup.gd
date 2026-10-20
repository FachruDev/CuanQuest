extends ModalPopup
## Popup "Dana Kelolaan" (v2c, Popup v2 bertab): Ringkasan (ubin & reputasi), Alokasi (batang + keranjang),
## Investor (investor aktif yang bisa dikembalikan dananya & tawaran baru). Dana investor terpisah dari uang pribadi.
## Analogi web: dashboard admin "akun bersama" — strategi diatur di sini, uangnya tetap milik pemiliknya.

signal accepted(investor_name: String, amount: int)
signal funds_returned(investor_name: String, payout: int)
signal allocation_applied(cost: float)

var _draft: Dictionary = {}  # alokasi yang sedang disusun (belum diterapkan)
var _confirm_uid := -1  # investor yang tombol "Kembalikan Dana"-nya sudah diketuk sekali
var _detail_uid := -1  # investor yang sedang dilihat rinciannya (langkah 3), -1 = tampilan utama
var _tab := 0  # 0 Ringkasan, 1 Alokasi, 2 Investor
var _tabs: PanelContainer
var _tab_buttons: Array[Button] = []
## Warna keranjang di batang alokasi (urutan sama dengan fund.json "baskets").
const BASKET_COLORS := {"money": Color("#00907c"), "stocks": Color("#d45a3c"), "gold": Color("#c2810f"),
	"commodities": Color("#8360d1"), "fx": Color("#4a6fb0")}
const WARNING_ICON := preload("res://assets/icons/warning_small.svg")
const PORTRAIT := "res://assets/illustrations/investors/%s.svg"  # potret investor (aset opsional)
const INVESTOR_COLORS: Array[Color] = [Color("#c7841a"), Color("#4a6fb0"), Color("#23877b"), Color("#e0644a"),
	Color("#7a4fb0")]


func open() -> void:
	_draft = GameState.fund.allocation.duplicate()
	_confirm_uid = -1
	_detail_uid = -1
	_tab = 2 if not GameState.fund.board.is_empty() and GameState.fund.investors.is_empty() else 0
	%Title.text = tr("FUND_TITLE")
	%SubtitleHolder.show()
	%Body.hide()
	%Rows.add_theme_constant_override("separation", 12)
	_build_tabs()
	_build()
	%Scroll.scroll_vertical = 0
	show()
	_fit_scroll()


func _build() -> void:
	var fund := GameState.fund
	var detail := fund.find_investor(_detail_uid)
	if not detail.is_empty():
		_tabs.hide()
		_build_detail(detail)
		_refresh_buttons()
		return
	_detail_uid = -1
	_tabs.show()
	for i in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == _tab)
	var offers := fund.board.size()
	_tab_buttons[2].text = tr("FUND_TAB_INVESTORS") + (" · %d" % offers if offers > 0 else "")
	%Subtitle.text = tr("FUND_SUBTITLE") % [Fmt.rupiah_short(fund.value()), Fmt.rupiah(fund.current_nav())]
	_clear(%Rows)
	match _tab:
		0:
			_add_summary()
		1:
			_add_allocation()
		_:
			_add_investors()
			_add_offers()
	_refresh_buttons()


## Tombol bawah: Tutup, ditambah Terapkan di tab Alokasi (desain v2: berdampingan).
func _refresh_buttons() -> void:
	_clear(%Buttons)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var close_button := UiText.chunky_button(tr("BTN_CLOSE"), &"NeutralButton", &"NeutralButtonLabel", 68.0, 24)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.pressed.connect(close)
	row.add_child(close_button)
	if _tab == 1 and _detail_uid < 0:
		var fund := GameState.fund
		var apply := UiText.chunky_button(tr("FUND_ALLOC_APPLY"), &"PrimaryButton", &"PrimaryButtonLabel", 68.0, 24)
		apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		apply.disabled = total_of(_draft) != 100 or _same(_draft, fund.allocation)
		apply.pressed.connect(func() -> void:
			var result := fund.set_allocation(_draft)
			if result["ok"]:
				_draft = fund.allocation.duplicate()
				allocation_applied.emit(float(result["cost"]))
				_rebuild())
		row.add_child(apply)
	%Buttons.add_child(row)


func _rebuild() -> void:
	var scroll: int = %Scroll.scroll_vertical
	_build()
	await get_tree().process_frame
	%Scroll.scroll_vertical = scroll


## Tombol tab di atas area gulir (dibuat sekali).
func _build_tabs() -> void:
	if _tabs != null:
		return
	_tabs = PanelContainer.new()
	_tabs.theme_type_variation = &"SegmentTrack"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_tabs.add_child(row)
	var group := ButtonGroup.new()
	for i in 3:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = &"SegmentButton"
		button.text = tr(["FUND_TAB_SUMMARY", "FUND_TAB_ALLOCATION", "FUND_TAB_INVESTORS"][i])
		button.add_theme_font_size_override("font_size", 19)
		button.custom_minimum_size = Vector2(0, 52)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			_tab = i
			_confirm_uid = -1
			_build()
			%Scroll.scroll_vertical = 0
			_fit_scroll())
		row.add_child(button)
		_tab_buttons.append(button)
	%Scroll.add_sibling(_tabs)
	%Scroll.get_parent().move_child(_tabs, %Scroll.get_index())


## Ringkasan: 4 ubin (nilai dana, NAB, profil & fee, fee bulan ini), reputasi manajer, total fee, energi, catatan.
func _add_summary() -> void:
	var fund := GameState.fund
	var start := float(fund.data["start_nav"])
	var growth := fund.current_nav() / start - 1.0
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.add_child(_tile(tr("FUND_VALUE"), Fmt.rupiah_short(fund.value()), tr("FUND_TILE_INVESTORS") % fund.investors.size()))
	grid.add_child(_tile(tr("FUND_NAV"), Fmt.rupiah(fund.current_nav()), tr("FUND_TILE_GROWTH") % Fmt.percent(growth),
		growth >= 0.0))
	grid.add_child(_tile(tr("FUND_PROFILE"), UiText.fund_profile(fund.profile_of()),
		tr("FUND_TILE_FEE") % UiText.percent_rate(fund.management_fee())))
	grid.add_child(_tile(tr("FUND_FEE_MONTH"), Fmt.rupiah_short(fund.record["month_fee"]),
		tr("FUND_TILE_TOTAL") % Fmt.rupiah_short(float(fund.record["mgmt_fees"]) + float(fund.record["perf_fees"]))))
	%Rows.add_child(grid)
	var box := _card()
	box.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	var name := _label(tr("FUND_REPUTATION"), &"AssetNameLabel")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	var score := _label("%d / 100" % fund.reputation, &"RowValueLabel")
	score.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(score)
	box.add_child(head)
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"XpBar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.value = fund.reputation
	box.add_child(bar)
	box.add_child(_label(tr("FUND_REPUTATION_HINT"), &"SmallMutedLabel"))
	_value_row(tr("FUND_FEE_TOTAL"), Fmt.rupiah(fund.record["mgmt_fees"]))
	_value_row(tr("FUND_PERF_TOTAL"), Fmt.rupiah(fund.record["perf_fees"]))
	%Rows.add_child(_label(tr("FUND_ENERGY") % [maxi(fund.energy_cost(), int(fund.data["energy"])),
		int(fund.data["investors_per_energy"])], &"SmallMutedLabel"))
	var fees: Dictionary = fund.data["management_fee"]
	var note := PanelContainer.new()
	note.theme_type_variation = &"TipBanner"
	note.add_child(_label(tr("FUND_BODY") + " " + tr("FUND_NOTE") % [UiText.percent_rate(float(fees["conservative"])),
		UiText.percent_rate(float(fees["moderate"])), UiText.percent_rate(float(fees["aggressive"])),
		UiText.percent_rate(float(fund.data["performance_fee"]))], &"SmallMutedLabel"))
	%Rows.add_child(note)


func _tile(title: String, value: String, sub: String, positive := false) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.theme_type_variation = &"StatTilePositive" if positive else &"StatTile"
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(_label(title, &"TileCapsLabel"))
	box.add_child(_label(value, &"TileValueLabel"))
	box.add_child(_label(sub, &"SmallMutedLabel"))
	tile.add_child(box)
	return tile


## Alokasi: batang warna per keranjang, lalu satu baris per keranjang (warna, nama, isi & risiko, - / +
## kelipatan allocation_step), total + profil + fee, dan peringatan mandat.
func _add_allocation() -> void:
	var fund := GameState.fund
	var step := int(fund.data["allocation_step"])
	var parts: Array = []
	for b: Dictionary in fund.baskets():
		parts.append([float(_draft.get(b["id"], 0)), BASKET_COLORS.get(b["id"], Palette.GOLD)])
	var bar := FlowBar.new()
	bar.custom_minimum_size = Vector2(0, 26)
	bar.set_parts(parts)
	%Rows.add_child(bar)
	%Rows.add_child(_label(tr("FUND_ALLOCATION_HINT") % step, &"SmallMutedLabel"))
	var card := PanelContainer.new()
	card.theme_type_variation = &"HomeCard"
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	card.add_child(list)
	%Rows.add_child(card)
	var total := total_of(_draft)
	var baskets := fund.baskets()
	for i in baskets.size():
		var id: String = baskets[i]["id"]
		var pct := int(_draft.get(id, 0))
		var available := fund.basket_available(id)
		if i > 0:
			var divider := Panel.new()
			divider.theme_type_variation = &"Divider"
			divider.custom_minimum_size = Vector2(0, 2)
			list.add_child(divider)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		if not available:
			row.modulate.a = 0.5
		row.add_child(_swatch(BASKET_COLORS.get(id, Palette.GOLD)))
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		texts.add_theme_constant_override("separation", 0)
		texts.add_child(_label(tr("FUND_BASKET_" + id.to_upper()), &"AssetNameLabel"))
		var detail := tr("FUND_BASKET_RISK") % [basket_assets(id), Fmt.number(fund.basket_risk(id), 1)]
		texts.add_child(_label(detail if available else tr("FUND_BASKET_LOCKED"), &"SmallMutedLabel"))
		row.add_child(texts)
		var minus := _small_button("−", available and pct > 0)
		minus.pressed.connect(_change.bind(id, -step))
		var value := _label("%d%%" % pct, &"AssetValueLabel")
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		value.custom_minimum_size.x = 60
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var plus := _small_button("+", available and total < 100)
		plus.pressed.connect(_change.bind(id, step))
		row.add_child(minus)
		row.add_child(value)
		row.add_child(plus)
		list.add_child(row)
	var draft_profile := fund.profile_of(_draft)
	var summary := PanelContainer.new()
	summary.theme_type_variation = &"MoodNeutral"
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	var total_label := _label(tr("FUND_ALLOC_TOTAL_SHORT") % total, &"AssetNameLabel")
	total_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if total != 100:
		total_label.add_theme_color_override("font_color", Palette.LOSS)
	line.add_child(total_label)
	var profile_chip := _chip(UiText.fund_profile(draft_profile), &"SmallChipGold")
	profile_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(profile_chip)
	var fee_chip := _chip(tr("FUND_FEE_CHIP") % UiText.percent_rate(float(fund.data["management_fee"][draft_profile])),
		&"ChipWhite")
	fee_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(fee_chip)
	summary.add_child(line)
	%Rows.add_child(summary)
	var breaches := fund.mandate_breaches(_draft)
	if not breaches.is_empty():
		var names: PackedStringArray = []
		for inv: Dictionary in breaches:
			names.append(tr(fund.def(inv["id"])["name"]))
		%Rows.add_child(_banner(tr("FUND_ALLOC_BREACH") % ", ".join(names)))


## Investor aktif: kartu dengan inisial, kepuasan (chip + bar), setoran & nilai, chip imbal/turun/kontrak,
## peringatan, tombol Rincian & Kembalikan Dana (ketuk dua kali).
func _add_investors() -> void:
	var fund := GameState.fund
	%Rows.add_child(_caps(tr("FUND_INVESTORS_CAPS") % fund.investors.size()))
	if fund.investors.is_empty():
		%Rows.add_child(_label(tr("FUND_NO_INVESTORS"), &"MutedLabel"))
		return
	for inv: Dictionary in fund.investors:
		var d := fund.def(inv["id"])
		var box := _card()
		box.add_theme_constant_override("separation", 10)
		var satisfaction := int(inv["satisfaction"])
		var level := Fund.satisfaction_level(satisfaction)
		var head := _person(d, "%s · %s" % [tr(d["role"]), UiText.fund_profile(d["profile"])])
		var mood: StringName = &"MoodGreen" if satisfaction >= 50 else (&"MoodGold" if satisfaction >= 35 else &"MoodRed")
		var chip := _chip(tr("FUND_SAT_CHIP") % [tr("FUND_SAT_" + level.to_upper()).capitalize(), satisfaction], mood,
			&"MoodLabel")
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(chip)
		box.add_child(head)
		var bar := ProgressBar.new()
		bar.theme_type_variation = &"XpBar" if satisfaction >= 35 else &"HealthBar"
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		bar.value = satisfaction
		box.add_child(bar)
		var money := HBoxContainer.new()
		var deposit := _label(tr("FUND_DEPOSIT") % Fmt.rupiah_short(inv["deposited"]), &"InfoLabel")
		deposit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		money.add_child(deposit)
		var ret := fund.investor_return(inv)
		var value := _label("%s (%s)" % [Fmt.rupiah_short(fund.investor_value(inv)), Fmt.percent(ret)], &"RowValueLabel")
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		value.add_theme_color_override("font_color", Palette.GAIN if ret >= 0.0 else Palette.LOSS)
		money.add_child(value)
		box.add_child(money)
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 8)
		chips.add_theme_constant_override("v_separation", 6)
		chips.add_child(_chip(tr("FUND_CHIP_RETURN") % [UiText.percent_short(fund.investor_annual_return(inv)),
			UiText.percent_short(float(d["target"]))], &"SmallChipNeutral"))
		chips.add_child(_chip(tr("FUND_CHIP_DRAWDOWN") % [UiText.percent_short(fund.investor_drawdown(inv)),
			UiText.percent_short(float(d["drawdown"]))], &"SmallChipNeutral"))
		chips.add_child(_chip(tr("FUND_CHIP_CONTRACT") % Fmt.game_date(int(inv["contract_end"])), &"SmallChipNeutral"))
		box.add_child(chips)
		if fund.is_warned(inv):
			box.add_child(_warn_line(tr("FUND_INV_WARNED")))
		if not fund.mandate_ok(inv["id"]):
			box.add_child(_warn_line(tr("FUND_INV_BREACH")))
		var uid := int(inv["uid"])
		var confirm := _confirm_uid == uid
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 10)
		var details := UiText.chunky_button(tr("FUND_DETAIL_BUTTON"), &"NeutralButton", &"NeutralButtonLabel", 52.0, 19)
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.pressed.connect(func() -> void:
			_detail_uid = uid
			_build()
			%Scroll.scroll_vertical = 0)
		buttons.add_child(details)
		var button := UiText.chunky_button(tr("FUND_RETURN_CONFIRM" if confirm else "FUND_RETURN_BUTTON"),
			&"DangerButton" if confirm else &"NeutralButton", &"DangerButtonLabel" if confirm else &"NeutralButtonLabel", 52.0,
			19)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			if _confirm_uid != uid:  # ketuk dua kali agar tidak terpencet tanpa sengaja
				_confirm_uid = uid
				_rebuild()
				return
			_confirm_uid = -1
			var result := fund.return_funds(uid)
			if result["ok"]:
				funds_returned.emit(tr(d["name"]), roundi(float(result["payout"])))
			_rebuild())
		buttons.add_child(button)
		box.add_child(buttons)


## Tawaran baru: kartu kuning (ActionCard) dengan syarat sebagai chip, peringatan mandat, Terima / Tolak.
func _add_offers() -> void:
	var fund := GameState.fund
	%Rows.add_child(_caps(tr("FUND_OFFERS_CAPS") % fund.board.size()))
	if fund.board.is_empty():
		%Rows.add_child(_label(tr("FUND_NO_OFFERS"), &"MutedLabel"))
		return
	for offer: Dictionary in fund.board:
		var d := fund.def(offer["id"])
		var box := _card(&"ActionCard")
		box.add_theme_constant_override("separation", 10)
		box.add_child(_person(d, tr("FUND_OFFER_SUB") % [tr(d["role"]), Fmt.game_date(int(offer["expires"]) - 1)]))
		var desc := _label(tr(d["desc"]), &"InfoLabel")
		desc.add_theme_color_override("font_color", Color("#5e3f08"))
		box.add_child(desc)
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 8)
		chips.add_theme_constant_override("v_separation", 6)
		chips.add_child(_chip(Fmt.rupiah_short(offer["amount"]), &"ChipWhite"))
		chips.add_child(_chip(UiText.fund_profile(d["profile"]), &"ChipWhite"))
		chips.add_child(_chip(tr("FUND_CHIP_TARGET") % UiText.percent_short(float(d["target"])), &"ChipWhite"))
		chips.add_child(_chip(tr("FUND_CHIP_LIMIT") % UiText.percent_short(float(d["drawdown"])), &"ChipWhite"))
		box.add_child(chips)
		if not fund.mandate_ok(offer["id"]):
			box.add_child(_warn_line(tr("FUND_OFFER_BREACH") % [UiText.fund_profile(fund.profile_of()),
				UiText.fund_profile(d["profile"])]))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var uid := int(offer["uid"])
		var accept := UiText.chunky_button(tr("FUND_ACCEPT"), &"PrimaryButton", &"PrimaryButtonLabel", 56.0, 21)
		accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		accept.pressed.connect(func() -> void:
			var result := fund.accept(uid)
			if result["ok"]:
				accepted.emit(tr(d["name"]), roundi(float(result["amount"])))
			_rebuild())
		var decline := UiText.chunky_button(tr("FUND_DECLINE"), &"NeutralButton", &"NeutralButtonLabel", 56.0, 21)
		decline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		decline.pressed.connect(func() -> void:
			fund.decline(uid)
			_rebuild())
		row.add_child(accept)
		row.add_child(decline)
		box.add_child(row)


## Kepala kartu investor: potret (assets/illustrations/investors/<id>.svg; cadangan: lingkaran inisial
## berwarna), nama, dan keterangan.
func _person(d: Dictionary, sub: String) -> HBoxContainer:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var person_name := tr(d["name"])
	var portrait := PORTRAIT % d.get("id", "")
	if ResourceLoader.exists(portrait):
		var image := TextureRect.new()
		image.texture = load(portrait)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(56, 56)
		image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(image)
	else:
		head.add_child(_initial_circle(person_name))
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 0)
	texts.add_child(_label(person_name, &"AssetNameLabel"))
	texts.add_child(_label(sub, &"SmallMutedLabel"))
	head.add_child(texts)
	return head


func _initial_circle(person_name: String) -> Control:
	var words := person_name.split(" ", false)
	var initial := words[-1].substr(0, 1).to_upper() if not words.is_empty() else "?"
	var color: Color = INVESTOR_COLORS[absi(hash(person_name)) % INVESTOR_COLORS.size()]
	var circle := Control.new()
	circle.custom_minimum_size = Vector2(48, 48)
	circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var font := get_theme_font("font", &"LevelBadgeLabel")
	circle.draw.connect(func() -> void:
		circle.draw_circle(Vector2(24, 24), 24.0, Palette.INK)
		circle.draw_circle(Vector2(24, 24), 21.0, color)
		var text_size := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		circle.draw_string(font, Vector2(24.0 - text_size.x / 2.0, 24.0 + font.get_ascent(22) / 2.0 - 2.0), initial,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE))
	return circle


func _chip(text: String, variation: StringName, label_variation: StringName = &"") -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = variation
	if variation == &"ChipWhite":  # chip putih polos (desain v2), tanpa bingkai teal bawaan ChipWhite
		var style := StyleBoxFlat.new()
		style.bg_color = Color.WHITE
		style.set_corner_radius_all(999)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 2
		style.content_margin_bottom = 4
		style.anti_aliasing_size = 1.0
		chip.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	if label_variation != &"":
		label.theme_type_variation = label_variation
	elif variation == &"SmallChipGold":
		label.theme_type_variation = &"SmallChipGoldLabel"
	else:
		label.theme_type_variation = &"SmallChipNeutralLabel"
		label.add_theme_color_override("font_color", Palette.INK)
	chip.add_child(label)
	return chip


func _swatch(color: Color) -> Control:
	var swatch := Control.new()
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.draw.connect(func() -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(4)
		swatch.draw_style_box(box, Rect2(Vector2.ZERO, swatch.size)))
	return swatch


func _caps(text: String) -> Label:
	return _label(text.to_upper(), &"TileCapsLabel")


func _banner(text: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"AlertCard"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon := TextureRect.new()
	icon.texture = WARNING_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(22, 22)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var label := _label(text, &"InfoLabel")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color("#8a3b26"))
	row.add_child(label)
	card.add_child(row)
	return card


func _warn_line(text: String) -> Label:
	var label := _label(text, &"SmallMutedLabel")
	label.add_theme_color_override("font_color", Color("#a63a20"))
	return label


## Rincian satu investor (langkah 3): grafik nilai investasinya tiap bulan, setoran, untung/rugi, imbal hasil
## vs target, penurunan vs batas, kepuasan, fee kinerja, evaluasi terakhir, dan kontrak.
func _build_detail(inv: Dictionary) -> void:
	var fund := GameState.fund
	var d := fund.def(inv["id"])
	%Subtitle.text = "%s · %s" % [tr(d["name"]), tr(d["role"])]
	_clear(%Rows)
	var back := UiText.chunky_button(tr("FUND_BACK"), &"NeutralButton", &"NeutralButtonLabel", 52.0, 20)
	back.pressed.connect(func() -> void:
		_detail_uid = -1
		_rebuild())
	%Rows.add_child(back)
	%Rows.add_child(_label(tr(d["desc"]), &"SmallMutedLabel"))
	%Rows.add_child(_caps(tr("FUND_DETAIL_CHART")))
	var chart := PriceChart.new()
	chart.light_style = true
	chart.max_points = Fund.MAX_VALUES
	chart.custom_minimum_size = Vector2(0, 170)
	var series: Array[float] = []
	series.assign(inv.get("values", []))
	chart.set_data(series)
	%Rows.add_child(chart)
	%Rows.add_child(_caps(tr("FUND_DETAIL_NUMBERS")))
	var value := fund.investor_value(inv)
	var gain := value - float(inv["deposited"])
	_value_row(tr("FUND_DETAIL_DEPOSITED"), Fmt.rupiah(inv["deposited"]))
	_value_row(tr("FUND_DETAIL_VALUE"), Fmt.rupiah(value))
	_value_row(tr("FUND_DETAIL_GAIN"), "%s (%s)" % [Fmt.signed_rupiah(gain), Fmt.percent(fund.investor_return(inv))])
	_value_row(tr("FUND_DETAIL_ANNUAL"), tr("FUND_DETAIL_VS") % [UiText.percent_short(fund.investor_annual_return(inv)),
		UiText.percent_short(float(d["target"]))])
	_value_row(tr("FUND_DETAIL_DRAWDOWN"), tr("FUND_DETAIL_LIMIT") % [UiText.percent_short(fund.investor_drawdown(inv)),
		UiText.percent_short(float(d["drawdown"]))])
	var satisfaction := int(inv["satisfaction"])
	_value_row(tr("FUND_DETAIL_SAT"), "%d/100 · %s" % [satisfaction, tr("FUND_SAT_" + Fund.satisfaction_level(satisfaction).to_upper())])
	_value_row(tr("FUND_DETAIL_MANDATE"), "%s · %s" % [UiText.fund_profile(d["profile"]),
		tr("FUND_MANDATE_OK" if fund.mandate_ok(inv["id"]) else "FUND_MANDATE_BREACH")])
	_value_row(tr("FUND_DETAIL_PERF"), Fmt.rupiah(inv["perf_paid"]))
	_value_row(tr("FUND_DETAIL_LAST_EVAL"), Fmt.percent(inv["last_eval"]) if inv.has("last_eval") else "-")
	_value_row(tr("FUND_DETAIL_JOINED"), Fmt.game_date(int(inv["joined"])))
	_value_row(tr("FUND_DETAIL_CONTRACT"), Fmt.game_date(int(inv["contract_end"])))
	if fund.is_warned(inv):
		var warned := _label(tr("FUND_INV_WARNED"), &"SmallMutedLabel")
		warned.add_theme_color_override("font_color", Palette.LOSS)
		%Rows.add_child(warned)


func _change(id: String, delta: int) -> void:
	var pct := clampi(int(_draft.get(id, 0)) + delta, 0, 100)
	if delta > 0 and total_of(_draft) + delta > 100:
		return
	_draft[id] = pct
	_rebuild()


static func total_of(alloc: Dictionary) -> int:
	var total := 0
	for id: String in alloc:
		total += int(alloc[id])
	return total


## Nama aset dalam keranjang; saham cukup kodenya, mis. "BSNT, MPGN, NUSA, BARA".
static func basket_assets(id: String) -> String:
	var names: PackedStringArray = []
	for asset_id: String in GameState.fund.basket(id)["assets"]:
		var asset := GameState.market.get_asset(asset_id)
		names.append(asset_id if asset.asset_class == "stock" else TranslationServer.translate(asset.name_key))  # saham: kode saja
	return ", ".join(names)


func _same(a: Dictionary, b: Dictionary) -> bool:
	for id: String in GameState.fund.data["baskets"].map(func(x: Dictionary) -> String: return x["id"]):
		if int(a.get(id, 0)) != int(b.get(id, 0)):
			return false
	return true


func _card(variation := &"HomeCard") -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = variation
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	%Rows.add_child(panel)
	return box


func _small_button(text: String, enabled: bool) -> Button:
	var button := UiText.chunky_button(text, &"NeutralButton", &"NeutralButtonLabel", 46.0, 24)
	button.custom_minimum_size.x = 48
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.disabled = not enabled
	return button


func _value_row(name: String, value: String) -> void:
	var row := HBoxContainer.new()
	var name_label := _label(name, &"RowLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value_label := _label(value, &"RowValueLabel")
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	%Rows.add_child(row)


## Area isi di-scroll; tingginya mengikuti isi (dibatasi). Diukur ulang setiap ukuran minimum isi berubah,
## karena label berbungkus baru tahu tingginya setelah lebarnya ditata.
func _fit_scroll() -> void:
	if not %Rows.minimum_size_changed.is_connected(_refit):
		%Rows.minimum_size_changed.connect(_refit)
	await get_tree().process_frame
	_refit()


func _refit() -> void:
	%Scroll.custom_minimum_size.y = minf(%Rows.get_combined_minimum_size().y, 560.0)


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
