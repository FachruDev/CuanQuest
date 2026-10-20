extends VBoxContainer
## Menu Rumah & Kendaraan (Beranda v2): semua aset "hidup" dalam satu layar dengan tiga tab, dibuka dari
## Beranda (ketuk ilustrasi, kartu di bagian Gaya Hidup). Tombol kembali ke Beranda.
## - Hunian    : tempat tinggal sekarang (ilustrasi besar), pindah ke tempat sewa, huni rumah milik sendiri
## - Kendaraan : isi garasi; tiap unit punya tombol Jual yang langsung terlihat + rincian; showroom
## - Properti  : status, untung/rugi nilai, pemakaian (dihuni / disewakan / kosong), pasang atau batalkan
##               iklan jual; daftar properti dijual
## Popup (rincian, konfirmasi jual, showroom) dibuka main.gd lewat signal, seperti tab lain.

signal back_requested
signal vehicle_market_requested
signal vehicle_detail_requested(uid: int)
signal vehicle_sell_requested(uid: int)
signal property_market_requested
signal property_detail_requested(uid: int)
signal property_sell_requested(uid: int)
## Rumah sendiri mulai dihuni dari tab Hunian (main.gd: cerita "rumah pertama").
signal moved_in

const TABS: Array[String] = ["home", "vehicles", "properties"]
const TAB_KEYS: Array[String] = ["ASSETS_TAB_HOME", "ASSETS_TAB_VEHICLES", "ASSETS_TAB_PROPERTIES"]
const USES: Array[String] = ["live", "rent", "empty"]
const THUMB_SIZE := Vector2(206, 146)

var _tab := 0
var _segments: Array[Button] = []


func _ready() -> void:
	%BackButton.pressed.connect(back_requested.emit)
	var group := ButtonGroup.new()
	for i in TAB_KEYS.size():
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = &"SegmentButton"
		button.text = tr(TAB_KEYS[i])
		button.add_theme_font_size_override("font_size", 22)
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			_tab = i
			%Scroll.scroll_vertical = 0
			_refresh())
		%Segments.get_node("Row").add_child(button)
		_segments.append(button)
	GameState.changed.connect(_refresh)
	visibility_changed.connect(_refresh)


## Dibuka dari Beranda di tab `tab` ("home" | "vehicles" | "properties").
func open(tab: String) -> void:
	_tab = maxi(0, TABS.find(tab))
	for i in _segments.size():
		_segments[i].set_pressed_no_signal(i == _tab)
	%Scroll.scroll_vertical = 0
	_refresh()


func _refresh() -> void:
	if not is_visible_in_tree():
		return
	var monthly := GameState.option_cost(GameState.housing_option()) + GameState.vehicles.running_cost() \
		+ GameState.properties.running_cost()
	%Summary.text = tr("ASSETS_SUMMARY") % [Fmt.rupiah_short(GameState.vehicles.total_value()
		+ GameState.properties.total_value()), Fmt.rupiah_short(monthly)]
	_clear(%Page)
	match _tab:
		0:
			_build_home()
		1:
			_build_vehicles()
		2:
			_build_properties()


# --- Hunian -----------------------------------------------------------------------------------------

func _build_home() -> void:
	var page: VBoxContainer = %Page
	var hero := _card(page, &"HeroCard", 14)
	var scene := HomeScene.new()
	scene.custom_minimum_size = Vector2(0, 258)
	hero.add_child(scene)
	scene.refresh()
	var own := GameState.properties.home()
	var option := GameState.housing_option()
	var now := HBoxContainer.new()
	now.add_theme_constant_override("separation", 12)
	var texts := _texts()
	texts.add_child(_label(tr("ASSETS_HOME_NOW"), &"TileCapsLabel"))
	var name := tr(GameState.properties.def(own["id"])["name"]) if not own.is_empty() else tr(option["name_key"])
	texts.add_child(_wrap(&"CardTitleLabel", name))
	var cost := GameState.option_cost(option)
	var sub := tr("ASSETS_OWN_SUB") if not own.is_empty() else tr("ASSETS_RENT_SUB") % Fmt.rupiah_short(cost)
	texts.add_child(_wrap(&"SmallMutedLabel", sub + " · " + _effects(option)))
	now.add_child(texts)
	now.add_child(_chip(tr("ASSETS_CURRENT"), &"MoodGreen"))
	hero.add_child(_padded(now, 6))

	# Rumah milik sendiri yang bisa dihuni tapi sedang tidak dihuni.
	var homes := GameState.properties.owned.filter(func(e: Dictionary) -> bool:
		return GameState.properties.def(e["id"]).get("livable", false) and e["use"] != "live")
	if not homes.is_empty():
		_title(page, tr("ASSETS_OWN_HOMES"))
		for entry: Dictionary in homes:
			var uid := int(entry["uid"])
			var button := UiText.chunky_button(tr("ASSETS_LIVE_HERE"), &"PrimaryButton", &"PrimaryButtonLabel", 60.0, 20)
			button.pressed.connect(func() -> void:
				if GameState.properties.set_use(uid, "live"):
					moved_in.emit())
			_choice_card(page, HomeScene.home_art(entry["id"]), tr(GameState.properties.def(entry["id"])["name"]),
				UiText.property_status(entry), button)

	_title(page, tr("ASSETS_RENTALS"))
	for rental: Dictionary in GameState.economy["housing"]:
		var current: bool = own.is_empty() and rental["id"] == GameState.housing_id
		var action: Control
		if current:
			action = _chip(tr("ASSETS_CURRENT"), &"MoodGreen")
		else:
			var id: String = rental["id"]
			action = UiText.chunky_button(tr("ASSETS_MOVE"), &"NeutralButton", &"NeutralButtonLabel", 60.0, 20)
			action.pressed.connect(GameState.set_housing.bind(id))
		_choice_card(page, HomeScene.home_art(rental["id"]), tr(rental["name_key"]),
			tr("CAREER_PER_MONTH") % Fmt.rupiah_short(GameState.option_cost(rental)) + " · " + _effects(rental), action)
	page.add_child(_wrap(&"SmallMutedLabel", tr("ASSETS_MOVE_NOTE") if not own.is_empty() else tr("HOME_CHOICE_HINT")))


## Kartu pilihan tempat tinggal: potongan ilustrasi, nama, keterangan, dan tombol/chip di bawahnya.
func _choice_card(page: VBoxContainer, art: String, title: String, sub: String, action: Control) -> void:
	var box := _card(page, &"HomeCard", 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.add_child(ArtThumb.new(art, HomeScene.HOME_CROP, Vector2(150, 106)))
	var texts := _texts()
	texts.add_child(_wrap(&"AssetNameLabel", title))
	texts.add_child(_wrap(&"SmallMutedLabel", sub))
	action.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if action is Button:
		action.custom_minimum_size.x = 190
	texts.add_child(action)
	row.add_child(texts)
	box.add_child(row)


# --- Kendaraan --------------------------------------------------------------------------------------

func _build_vehicles() -> void:
	var page: VBoxContainer = %Page
	var vehicles := GameState.vehicles
	var side := _title(page, tr("ASSETS_GARAGE"))
	side.text = tr("ASSETS_GARAGE_COUNT") % [vehicles.owned.size(), vehicles.max_owned()]
	if not vehicles.has_any():
		var empty := _card(page, &"TipCard", 0)
		empty.add_child(_wrap(&"InfoLabel", tr("VEHICLE_EMPTY")))
	for entry: Dictionary in vehicles.owned:
		_vehicle_card(page, entry)
	var showroom := UiText.chunky_button(tr("ASSETS_SHOWROOM"), &"PrimaryButton", &"PrimaryButtonLabel", 76.0)
	showroom.pressed.connect(vehicle_market_requested.emit)
	page.add_child(showroom)
	if vehicles.is_full():
		page.add_child(_wrap(&"SmallMutedLabel", tr("ASSETS_GARAGE_FULL")))


func _vehicle_card(page: VBoxContainer, entry: Dictionary) -> void:
	var vehicles := GameState.vehicles
	var def := vehicles.def(entry["id"])
	var uid := int(entry["uid"])
	var box := _card(page, &"HomeCard", 14)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.add_child(ArtThumb.new(HomeScene.vehicle_art(entry["id"]), HomeScene.VEHICLE_CROP, THUMB_SIZE))
	var texts := _texts()
	texts.add_child(_wrap(&"AssetNameLabel", tr(def["name"])))
	var chips := _chips()
	chips.add_child(_chip(tr(vehicles.category_name(vehicles.category_of(entry["id"]))), &"MoodNeutral"))
	var loan := vehicles.loan_of(entry)
	if not loan.is_empty():
		chips.add_child(_chip(tr("ASSETS_ON_CREDIT"), &"MoodGold"))
	texts.add_child(chips)
	var value := vehicles.value(entry)
	texts.add_child(_label(Fmt.rupiah(value), &"TileValueLabel"))
	var drop := _wrap(&"SmallMutedLabel", tr("ASSETS_SINCE_BOUGHT") % [Fmt.signed_rupiah(value - int(entry["paid"])),
		Fmt.game_date(int(entry["since"]))])
	drop.add_theme_color_override("font_color", Palette.LOSS if value < int(entry["paid"]) else Palette.GAIN)
	texts.add_child(drop)
	top.add_child(texts)
	box.add_child(top)
	var sub := tr("VEHICLE_ROW_SUB") % [Fmt.rupiah_short(vehicles.cost_of(entry)), int(def["happiness"])] \
		if vehicles.counts_happiness(entry) else tr("VEHICLE_ROW_SUB_SHARED") % Fmt.rupiah_short(vehicles.cost_of(entry))
	if not loan.is_empty():
		sub += " · " + tr("VEHICLE_ROW_LOAN") % Fmt.rupiah_short(GameState.debt.installment(loan))
	box.add_child(_wrap(&"SmallMutedLabel", sub))
	var q := vehicles.sell_quote(uid)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	var detail := UiText.chunky_button(tr("ASSETS_DETAIL"), &"NeutralButton", &"NeutralButtonLabel", 64.0, 21)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.pressed.connect(vehicle_detail_requested.emit.bind(uid))
	buttons.add_child(detail)
	var sell := UiText.chunky_button(tr("ASSETS_SELL") % Fmt.rupiah_short(q["net"]), &"DangerButton", &"DangerButtonLabel",
		64.0, 21)
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell.pressed.connect(vehicle_sell_requested.emit.bind(uid))
	buttons.add_child(sell)
	box.add_child(buttons)


# --- Properti ---------------------------------------------------------------------------------------

func _build_properties() -> void:
	var page: VBoxContainer = %Page
	var properties := GameState.properties
	var side := _title(page, tr("PROPERTY_TITLE"))
	if properties.rent_income() > 0:
		side.text = tr("ASSETS_RENT_TOTAL") % Fmt.rupiah_short(properties.rent_income())
	if properties.owned.is_empty():
		var empty := _card(page, &"TipCard", 0)
		empty.add_child(_wrap(&"InfoLabel", tr("PROPERTY_EMPTY")))
	for entry: Dictionary in properties.owned:
		_property_card(page, entry)
	var market := UiText.chunky_button(tr("PROPERTY_BUY_BUTTON"), &"PrimaryButton", &"PrimaryButtonLabel", 76.0)
	market.pressed.connect(property_market_requested.emit)
	page.add_child(market)


func _property_card(page: VBoxContainer, entry: Dictionary) -> void:
	var properties := GameState.properties
	var def := properties.def(entry["id"])
	var uid := int(entry["uid"])
	var box := _card(page, &"HomeCard", 14)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.add_child(ArtThumb.new(HomeScene.home_art(entry["id"]), HomeScene.HOME_CROP, THUMB_SIZE))
	var texts := _texts()
	texts.add_child(_wrap(&"AssetNameLabel", tr(def["name"])))
	var chips := _chips()
	var status := UiText.property_chip(entry)
	chips.add_child(_chip(status[0], status[1]))
	if not properties.loan_of(entry).is_empty():
		chips.add_child(_chip(tr("ASSETS_ON_KPR"), &"MoodGold"))
	texts.add_child(chips)
	var value := properties.value(entry)
	texts.add_child(_label(Fmt.rupiah_short(value), &"TileValueLabel"))
	var gain := value - int(entry["paid"])
	var change := _wrap(&"SmallMutedLabel", tr("ASSETS_SINCE_BOUGHT") % [Fmt.signed_rupiah(gain),
		Fmt.game_date(int(entry["since"]))])
	change.add_theme_color_override("font_color", Palette.GAIN if gain >= 0 else Palette.LOSS)
	texts.add_child(change)
	top.add_child(texts)
	box.add_child(top)

	var sub := UiText.property_status(entry) + " · " + tr("ASSETS_UPKEEP") % Fmt.rupiah_short(properties.cost_of(entry))
	var loan := properties.loan_of(entry)
	if not loan.is_empty():
		sub += " · " + tr("VEHICLE_ROW_LOAN") % Fmt.rupiah_short(GameState.debt.installment(loan))
	box.add_child(_wrap(&"SmallMutedLabel", sub))
	if entry["use"] == "empty" and int(entry["selling_left"]) <= 0 and properties.can_rent(entry["id"]):
		var tip := PanelContainer.new()
		tip.theme_type_variation = &"TipBanner"
		tip.add_child(_wrap(&"SmallMutedLabel", tr("ASSETS_EMPTY_TIP") % Fmt.rupiah_short(properties.rent_net(entry["id"]))))
		box.add_child(tip)

	var uses := HBoxContainer.new()
	uses.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for use: String in USES:
		if (use == "live" and not def.get("livable", false)) or (use == "rent" and not properties.can_rent(entry["id"])):
			continue
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = &"SegmentButton"
		button.text = tr("PROPERTY_USE_" + use.to_upper())
		button.add_theme_font_size_override("font_size", 19)
		button.custom_minimum_size = Vector2(0, 50)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.button_pressed = entry["use"] == use
		button.pressed.connect(func() -> void:
			if entry["use"] != use and GameState.properties.set_use(uid, use) and use == "live":
				moved_in.emit())
		uses.add_child(button)
	if uses.get_child_count() > 1:
		var track := PanelContainer.new()
		track.theme_type_variation = &"SegmentTrack"
		track.add_child(uses)
		box.add_child(track)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	var detail := UiText.chunky_button(tr("ASSETS_DETAIL"), &"NeutralButton", &"NeutralButtonLabel", 64.0, 21)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.pressed.connect(property_detail_requested.emit.bind(uid))
	buttons.add_child(detail)
	if int(entry["selling_left"]) > 0:
		var cancel := UiText.chunky_button(tr("PROPERTY_CANCEL_SALE"), &"NeutralButton", &"NeutralButtonLabel", 64.0, 21)
		cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cancel.pressed.connect(GameState.properties.cancel_sale.bind(uid))
		buttons.add_child(cancel)
	else:
		var sell := UiText.chunky_button(tr("PROPERTY_LIST_BUTTON"), &"DangerButton", &"DangerButtonLabel", 64.0, 21)
		sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sell.pressed.connect(property_sell_requested.emit.bind(uid))
		buttons.add_child(sell)
	box.add_child(buttons)
	if int(entry["selling_left"]) > 0:
		box.add_child(_wrap(&"SmallMutedLabel", tr("PROPERTY_SELLING") % int(entry["selling_left"])))


# --- Alat bantu -------------------------------------------------------------------------------------

func _effects(option: Dictionary) -> String:
	return tr("ASSETS_EFFECTS") % [int(option["health"]), int(option["happiness"])]


func _title(page: Container, text: String) -> Label:
	var row := HBoxContainer.new()
	var title := _label(text, &"SubSectionLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var side := _label("", &"SmallMutedLabel")
	side.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(side)
	page.add_child(row)
	return side


func _card(page: Container, variation: StringName, separation: int) -> VBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = variation
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	card.add_child(box)
	page.add_child(card)
	return box


func _texts() -> VBoxContainer:
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 6)
	return texts


func _chips() -> HFlowContainer:
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 6)
	return chips


func _chip(text: String, variation: StringName) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = variation
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(_label(text, &"MoodLabel"))
	return chip


func _padded(control: Control, side: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", side)
	margin.add_theme_constant_override("margin_right", side)
	margin.add_child(control)
	return margin


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label


func _wrap(variation: StringName, text := "") -> Label:
	var label := _label(text, variation)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1
	return label


func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
