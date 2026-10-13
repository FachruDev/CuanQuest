extends Control
## Layar prototipe B "Hari Cepat": 1 hari game sekitar 1 detik, berhenti otomatis saat ada
## keputusan. Selama bulan berjalan pemain bisa menjalankan aktivitas, mengejar misi,
## dan bereaksi terhadap pergerakan harga.
##
## Terpisah dari game utama (simpanan di user://prototype/). Teks ditulis langsung karena
## layar ini hanya untuk uji.

const DayWorld := preload("res://prototypes/day/day_world.gd")
const DayMarket := preload("res://prototypes/day/day_market.gd")
const ProtoMetrics := preload("res://prototypes/time/proto_metrics.gd")
const ProtoDialog := preload("res://prototypes/time/proto_dialog.gd")

const CONFIG_PATH := "res://prototypes/day/day_config.json"
const STATE_PATH := "user://prototype/day_state.json"
const LAUNCHER_SCENE := "res://prototypes/launcher.tscn"
const AUTOSAVE_SECONDS := 30.0
const LOG_LINES := 8
const PERIODS := [["1 Bulan", 1], ["3 Bulan", 3], ["1 Tahun", 12]]
const BUY_AMOUNTS := [["Rp500 rb", 500_000], ["Rp1 jt", 1_000_000], ["Rp5 jt", 5_000_000]]
const SELL_SHARES := [["25%", 0.25], ["50%", 0.5], ["Semua", 1.0]]
const QUICK_BUY := 1_000_000
const PAUSE_TEXT := {"background": "Dijeda (aplikasi di latar)", "idle": "Dijeda (tidak ada sentuhan)",
	"popup": "Dijeda (popup terbuka)", "manual": "Dijeda"}
const PHASE_COLORS := {"Pagi": Color("#fff1d6"), "Siang": Color("#e6f4f1"), "Sore": Color("#fde3cf"),
	"Malam": Color("#dcd6ee")}
const SHORT_DAYS := ["Sen", "Sel", "Rab", "Kam", "Jum", "Sab", "Min"]
## Umpan balik edukatif setelah memilih reaksi terhadap gerakan harga besar.
const MOVE_FEEDBACK := {
	"buy_dip": "Membeli saat harga turun bisa menurunkan harga rata-ratamu, asal asetnya tetap sehat dan dananya memang untuk jangka panjang.",
	"panic_sell": "Menjual karena panik sering mengunci kerugian. Harga yang turun hari ini belum tentu terus turun.",
	"hold": "Naik-turun harian itu wajar. Investor jangka panjang fokus pada tujuan, bukan pada pergerakan sehari.",
	"take_profit": "Mengambil sebagian untung adalah cara disiplin mengunci hasil sambil tetap memegang sisanya.",
	"fomo_buy": "Hati-hati FOMO: membeli setelah harga melonjak berarti membeli di harga yang sudah mahal.",
	"ignore": "Tidak apa-apa melewatkan peluang. Investasi yang baik dimulai dari rencana, bukan dari reaksi.",
}

var config: Dictionary
var world: DayWorld
var metrics := ProtoMetrics.new()
var dialog: ProtoDialog

var _cards := {}              # id instrumen -> {price, change, status, holding, chart, months}
var _activity_buttons := {}   # id aktivitas -> Button
var _speed_buttons := {}
var _scale_buttons := {}
var _log: Array[String] = []
var _last_input_msec := 0
var _since_save := 0.0
var _since_metrics := 0.0
var _chart_day := -1
var _idle_overlay: Control
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween


func _ready() -> void:
	OS.low_processor_usage_mode = true  # hemat baterai: gambar ulang hanya bila ada perubahan
	Engine.max_fps = 30
	config = DataLoader.load_json(CONFIG_PATH)
	metrics.path = "user://prototype/day_metrics.json"
	metrics.title = "LAPORAN UJI PROTOTIPE B (HARI CEPAT)"
	metrics.scale_unit = "dtk/hari"
	metrics.load_or_create()
	_build_controls()
	_build_overlays()
	_start_world(true)
	_pause_idle(false)
	_last_input_msec = Time.get_ticks_msec()


func _start_world(load_saved: bool) -> void:
	world = DayWorld.new()
	world.setup(config, DataLoader.load_json("res://data/assets.json")["assets"],
		DataLoader.load_json("res://data/events.json")["events"],
		DataLoader.load_json("res://data/activities.json")["activities"], randi())
	var loaded := false
	if load_saved and FileAccess.file_exists(STATE_PATH):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(STATE_PATH))
		loaded = saved is Dictionary and world.load_state(saved)
		if not loaded:
			world.pending.append({"kind": "info", "title": "Simpanan lama tidak kompatibel",
				"body": "Versi prototipe berubah, jadi permainan dimulai dari awal."})
	if not loaded:
		world.new_game()
	world.logged.connect(_add_log)
	world.counted.connect(metrics.count)
	world.toast.connect(_show_toast)
	_log.clear()
	%LogLabel.text = "-"
	_chart_day = -1
	_build_activity_buttons()
	_build_asset_cards()
	_speed_buttons[world.clock.speed].button_pressed = true
	for seconds: float in _scale_buttons:
		if is_equal_approx(seconds, world.seconds_per_day()):
			_scale_buttons[seconds].button_pressed = true
	_refresh_all()


func _process(delta: float) -> void:
	var clock := world.clock
	metrics.add_time(delta, "jeda" if clock.is_paused() else "%dx" % clock.speed, str(world.seconds_per_day()))
	if not clock.is_paused() and Time.get_ticks_msec() - _last_input_msec > float(config["clock"]["idle_pause_seconds"]) * 1000.0:
		_pause_idle(true)
	if world.advance(delta) > 0:
		_refresh_all()
	_show_next_popup()

	if not clock.is_paused():
		_since_save += delta
		_since_metrics += delta
		if _since_save >= AUTOSAVE_SECONDS:
			_save()
		if _since_metrics >= 2.0:
			_since_metrics = 0.0
			%MetricsLabel.text = metrics.report_text()


func _input(event: InputEvent) -> void:
	if not ((event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey) and event.is_pressed()):
		return
	_last_input_msec = Time.get_ticks_msec()
	if world != null and world.clock.has_pause("idle"):
		world.clock.resume("idle")
		_idle_overlay.hide.call_deferred()  # akhir frame, agar ketukan ini tidak menekan tombol di bawahnya
		get_viewport().set_input_as_handled()
		_refresh_status()


func _notification(what: int) -> void:
	if world == null:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if not world.clock.has_pause("background"):
				world.clock.pause("background")
				metrics.count_auto_pause("background")
			_save()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			if world.clock.has_pause("background"):
				world.clock.resume("background")
				_pause_idle(false)
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			_save()


# --- Membangun UI ------------------------------------------------------------------------

func _build_controls() -> void:
	var group := ButtonGroup.new()
	for item: Array in [["Jeda", 0], ["1x", 1], ["2x", 2], ["4x", 4]]:
		var button := _segment(item[0], group)
		button.pressed.connect(_on_speed.bind(item[1]))
		%SpeedRow.add_child(button)
		_speed_buttons[item[1]] = button

	var scale_group := ButtonGroup.new()
	for seconds: float in config["clock"]["seconds_per_day_options"]:
		var button := _segment("%s dtk" % _number_text(seconds), scale_group)
		button.pressed.connect(_on_scale.bind(seconds))
		%ScaleRow.add_child(button)
		_scale_buttons[seconds] = button

	for item: Array in [["Salin laporan", _on_copy_report], ["Mulai ulang", _on_restart],
			["Reset metrik", _on_reset_metrics], ["Ganti prototipe", _on_switch_prototype]]:
		var button := Button.new()
		button.theme_type_variation = &"PeriodButton"
		button.add_theme_font_size_override("font_size", 20)
		button.text = item[0]
		button.custom_minimum_size = Vector2(0, 60)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(item[1])
		%DebugGrid.add_child(button)
	%MetricsLabel.text = metrics.report_text()


func _build_overlays() -> void:
	_idle_overlay = Control.new()
	_idle_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Palette.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_idle_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_idle_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DialogPanel"
	center.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	for item: Array in [["Waktu dijeda", &"PopupTitleLabel"], ["Ketuk di mana saja untuk melanjutkan.", &"PopupBodyLabel"]]:
		var label := _label(item[0], item[1])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
	add_child(_idle_overlay)

	dialog = ProtoDialog.new()
	dialog.closed.connect(_on_dialog_closed)
	add_child(dialog)

	var holder := VBoxContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.offset_bottom = -40.0
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var toast_center := CenterContainer.new()
	toast_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(toast_center)
	_toast = PanelContainer.new()
	_toast.theme_type_variation = &"PillPanel"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.custom_minimum_size.x = 0
	_toast.hide()
	toast_center.add_child(_toast)
	_toast_label = _label("", &"PillLabel")
	_toast_label.add_theme_font_size_override("font_size", 20)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.custom_minimum_size.x = 560
	_toast.add_child(_toast_label)
	add_child(holder)


func _build_activity_buttons() -> void:
	for child in %ActivityGrid.get_children():
		%ActivityGrid.remove_child(child)
		child.queue_free()
	_activity_buttons.clear()
	for def: Dictionary in world.activity_defs:
		var button := Button.new()
		button.theme_type_variation = &"ChoiceCardButton"
		button.add_theme_font_size_override("font_size", 18)
		button.custom_minimum_size = Vector2(0, 84)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_activity.bind(def["id"]))
		%ActivityGrid.add_child(button)
		_activity_buttons[def["id"]] = button


func _build_asset_cards() -> void:
	for child in %AssetCards.get_children():
		%AssetCards.remove_child(child)
		child.queue_free()
	_cards.clear()
	for inst in world.market.instruments:
		var card := PanelContainer.new()
		card.theme_type_variation = &"CardPanel"
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		card.add_child(box)

		var header := HBoxContainer.new()
		box.add_child(header)
		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(left)
		left.add_child(_label(inst.name, &"AssetNameLabel"))
		var status := _label("", &"SmallMutedLabel")
		left.add_child(status)
		var right := VBoxContainer.new()
		header.add_child(right)
		var price := _label("", &"NetWorthValueLabel")
		var change := _label("", &"ChangeLabel")
		for label in [price, change]:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			right.add_child(label)

		var chart := PriceChart.new()
		chart.light_style = true
		chart.empty_text_key = "Grafik muncul setelah harga bergerak."
		chart.custom_minimum_size = Vector2(0, 180)
		box.add_child(chart)

		var periods := HBoxContainer.new()
		periods.add_theme_constant_override("separation", 8)
		var group := ButtonGroup.new()
		for period: Array in PERIODS:
			var button := Button.new()
			button.toggle_mode = true
			button.button_group = group
			button.theme_type_variation = &"PeriodButton"
			button.text = period[0]
			button.custom_minimum_size = Vector2(0, 48)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.button_pressed = period[1] == 1
			button.pressed.connect(_on_period.bind(inst.id, period[1]))
			periods.add_child(button)
		box.add_child(periods)

		var holding := _label("", &"InfoLabel")
		holding.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		holding.custom_minimum_size.x = 1
		box.add_child(holding)

		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 10)
		var buy := ProtoDialog.chunky("Beli", &"PrimaryButton", &"PrimaryButtonLabel", 76.0, 28)
		buy.pressed.connect(_open_trade.bind(inst.id, "buy"))
		var sell := ProtoDialog.chunky("Jual", &"NeutralButton", &"NeutralButtonLabel", 76.0, 28)
		sell.pressed.connect(_open_trade.bind(inst.id, "sell"))
		actions.add_child(buy)
		actions.add_child(sell)
		box.add_child(actions)

		%AssetCards.add_child(card)
		_cards[inst.id] = {"price": price, "change": change, "status": status, "holding": holding,
			"chart": chart, "months": 1}


# --- Memperbarui tampilan --------------------------------------------------------------
# Dipanggil saat waktu maju (4 kali per hari game) atau setelah aksi, bukan setiap frame.

func _refresh_all() -> void:
	var clock := world.clock
	var phase := world.phase()
	%Background.color = PHASE_COLORS[phase]
	%DateLabel.text = clock.date_text()
	%PhaseLabel.text = phase
	%CashLabel.text = Fmt.rupiah(world.cash)
	%CashLabel.add_theme_color_override("font_color", Palette.GAIN if world.cash >= 0.0 else Palette.LOSS)
	%WorthLabel.text = "Kekayaan " + Fmt.rupiah(world.net_worth())
	%HealthLabel.text = "Kesehatan %d" % roundi(world.health)
	%HealthBar.value = world.health
	%HappinessLabel.text = "Kebahagiaan %d" % roundi(world.happiness)
	%HappinessBar.value = world.happiness
	%EnergyLabel.text = "Energi %d" % world.energy
	_refresh_status()
	_refresh_activity()
	_refresh_missions()
	_refresh_cards()


func _refresh_status() -> void:
	var clock := world.clock
	var text := "Berjalan %dx | 1 hari game = %s dtk" % [clock.speed, _number_text(world.seconds_per_day() / clock.speed)]
	for reason: String in PAUSE_TEXT:
		if clock.has_pause(reason):
			text = PAUSE_TEXT[reason]
			break
	%StatusLabel.text = text


func _refresh_activity() -> void:
	var running := world.activity
	%ActivityProgress.visible = not running.is_empty()
	if running.is_empty():
		%ActivityStatus.text = "Tidak ada aktivitas berjalan. Pilih satu di bawah (energi diisi ulang tiap awal bulan)."
	else:
		var def := world.activity_def(running["id"])
		var days: int = running["days"]
		var left: int = running["days_left"]
		%ActivityStatus.text = "Sedang: %s (sisa %d hari)" % [def["name"], left]
		%ActivityProgress.max_value = days
		%ActivityProgress.value = days - left
	for id: String in _activity_buttons:
		var def := world.activity_def(id)
		var detail := "%d energi | %d hari" % [int(def["energy"]), world.activity_days(id)]
		if float(def.get("cost", 0)) > 0.0:
			detail += " | " + Fmt.rupiah_short(def["cost"])
		var reason := world.activity_block_reason(id)
		var button: Button = _activity_buttons[id]
		# Saat ada aktivitas berjalan semua tombol nonaktif; detail tetap tampil agar bisa direncanakan.
		var shown := detail if reason == "" or not running.is_empty() else reason
		button.text = "%s\n%s" % [def["name"], shown]
		button.disabled = reason != ""


func _refresh_missions() -> void:
	var signature := str(world.missions)
	if %MissionList.get_meta("signature", "") == signature:
		return
	%MissionList.set_meta("signature", signature)
	for child in %MissionList.get_children():
		%MissionList.remove_child(child)
		child.queue_free()
	for mission: Dictionary in world.missions:
		var mark: String = {"open": "[ ]", "done": "[v]", "failed": "[x]"}[mission["state"]]
		var text: String = "%s %s" % [mark, mission["text"]]
		if mission["type"] == "invest" and mission["state"] == "open":
			text += " (%s / %s)" % [Fmt.rupiah_short(world.month_buys), Fmt.rupiah_short(mission["target"])]
		var label := _label(text, &"InfoLabel")
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 1
		if mission["state"] != "open":
			label.add_theme_color_override("font_color", Palette.GAIN if mission["state"] == "done" else Palette.LOSS)
		%MissionList.add_child(label)


func _refresh_cards() -> void:
	var charts_due := world.clock.day() != _chart_day
	_chart_day = world.clock.day()
	for inst in world.market.instruments:
		var card: Dictionary = _cards[inst.id]
		card["price"].text = Fmt.rupiah(inst.price)
		card["change"].text = "%s hari ini" % Fmt.percent(inst.last_change)
		card["change"].add_theme_color_override("font_color", Palette.GAIN if inst.last_change >= 0.0 else Palette.LOSS)
		card["status"].text = "Bergerak setiap hari bursa (Senin-Jumat)" if inst.is_stock() else "Bergerak setiap hari"
		var units: float = world.holdings[inst.id]
		var text := "Kamu punya %s unit (%s)" % [Fmt.units(units), Fmt.rupiah(world.holding_value(inst.id))]
		if units > 0.0:
			text += ", untung/rugi %s" % Fmt.percent(world.unrealized_ratio(inst.id))
		card["holding"].text = text + "."
		if charts_due:
			_refresh_chart(inst.id)


func _refresh_chart(id: String) -> void:
	var inst := world.market.find(id)
	var chart: PriceChart = _cards[id]["chart"]
	chart.set_data(inst.history)
	chart.set_period(int(_cards[id]["months"]) * inst.points_per_month())


func _add_log(text: String) -> void:
	var clock := world.clock
	_log.push_front("%s %d/%d  %s" % [SHORT_DAYS[clock.weekday()], clock.day_of_month(), clock.month_of_year(), text])
	if _log.size() > LOG_LINES:
		_log.resize(LOG_LINES)
	%LogLabel.text = "\n".join(_log)


# --- Popup -------------------------------------------------------------------------------

func _show_next_popup() -> void:
	if dialog.visible or world.pending.is_empty():
		return
	var item: Dictionary = world.pending.pop_front()
	_pause_for_popup()
	match item["kind"]:
		"event":
			var event := world.director.find(item["event_id"])
			if event.is_empty():
				dialog.close()
				return
			_show_event(event)
		"payday":
			_show_payday()
		"move":
			_show_move(item["id"], item["change"])
		_:
			dialog.open(item["title"], item["body"])
			dialog.add_primary("Oke", dialog.close)


func _pause_for_popup() -> void:
	if not world.clock.has_pause("popup"):
		world.clock.pause("popup")
		metrics.count_auto_pause("popup")
	_refresh_status()


func _on_dialog_closed() -> void:
	world.clock.resume("popup")
	_refresh_all()


func _show_event(event: Dictionary) -> void:
	dialog.open(event["title"], event["text"])
	var choices: Array = event["choices"]
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var text: String = choice["label"]
		if float(choice.get("cost", 0)) > 0.0:
			text += " (%s)" % Fmt.rupiah(choice["cost"])
		var affordable := world.can_afford(choice)
		if not affordable:
			text += "\nKas tidak cukup"
		dialog.add_button(text, _on_event_choice.bind(event, i), &"ChoiceCardButton", not affordable)
	Sfx.play("alert")
	Sfx.vibrate()


func _on_event_choice(event: Dictionary, index: int) -> void:
	var outcome := world.resolve_event(event, index)
	var changes := {}
	if not is_zero_approx(outcome["cash"]):
		changes["cash"] = outcome["cash"]
	for key: String in ["health", "happiness"]:
		if outcome["effects"].has(key):
			changes[key] = outcome["effects"][key]
	var body: String = outcome["result"]
	if not changes.is_empty():
		body += "\n\n" + DayWorld.changes_text(changes)
	dialog.open(event["title"], body)
	dialog.add_primary("Oke", dialog.close)
	_refresh_all()


## Gajian: kesempatan "bayar diri sendiri dulu".
func _show_payday() -> void:
	var share := float(config["money"]["payday_invest_share"])
	var amount := roundf(world.salary * share)
	dialog.open("Gajian!", "Gaji %s masuk. Kas sekarang %s.\n\nPrinsip \"bayar diri sendiri dulu\": sisihkan sebagian gaji untuk investasi sebelum dibelanjakan." % [
		Fmt.rupiah(world.salary), Fmt.rupiah(world.cash)])
	for inst in world.market.instruments:
		dialog.add_button("Sisihkan %d%% (%s) ke %s" % [roundi(share * 100.0), Fmt.rupiah(amount), inst.id],
			_on_payday_invest.bind(inst.id, amount), &"ChoiceCardButton", amount > world.cash)
	dialog.add_button("Nanti saja", dialog.close)
	Sfx.play("success")


func _on_payday_invest(id: String, amount: float) -> void:
	world.buy(id, amount)
	metrics.count("payday_invest")
	dialog.close()
	_show_toast("%s diinvestasikan ke %s" % [Fmt.rupiah(amount), id])


## Harga bergerak besar: pemain memilih reaksi, lalu mendapat umpan balik singkat.
func _show_move(id: String, change: float) -> void:
	var inst := world.market.find(id)
	var down := change < 0.0
	var units: float = world.holdings[id]
	var body := "Harga sekarang %s." % Fmt.rupiah(inst.price)
	if units > 0.0:
		body += "\nKamu punya %s unit (%s), untung/rugi %s." % [Fmt.units(units), Fmt.rupiah(world.holding_value(id)),
			Fmt.percent(world.unrealized_ratio(id))]
	dialog.open("%s %s %s hari ini" % [id, "anjlok" if down else "melonjak", Fmt.percent_plain(absf(change))], body)
	var options: Array = []
	if down:
		options.append(["buy_dip", "Beli Rp1 jt (harga lebih murah)", world.cash < QUICK_BUY])
		if units > 0.0:
			options.append(["panic_sell", "Jual semua (takut turun lagi)", false])
	else:
		if units > 0.0:
			options.append(["take_profit", "Ambil untung: jual setengah", false])
		options.append(["fomo_buy", "Beli Rp1 jt (ikut naik)", world.cash < QUICK_BUY])
	options.append(["hold" if units > 0.0 else "ignore", "Tahan, ini investasi jangka panjang" if units > 0.0 else "Abaikan", false])
	for option: Array in options:
		dialog.add_button(option[1], _on_move_choice.bind(id, option[0]), &"ChoiceCardButton", option[2])


func _on_move_choice(id: String, choice: String) -> void:
	match choice:
		"buy_dip", "fomo_buy":
			world.buy(id, QUICK_BUY)
		"panic_sell":
			world.sell(id, world.holdings[id])
		"take_profit":
			world.sell(id, world.holdings[id] * 0.5)
	metrics.count("move_" + choice)
	dialog.open("Catatan", MOVE_FEEDBACK[choice])
	dialog.add_primary("Oke", dialog.close)
	_refresh_all()


func _open_trade(id: String, side: String) -> void:
	var inst := world.market.find(id)
	var body := "Harga terakhir %s. Harga berubah sekali sehari." % Fmt.rupiah(inst.price)
	if inst.is_stock() and world.clock.is_weekend():
		body += "\nBursa libur akhir pekan; transaksi memakai harga penutupan Jumat."
	_pause_for_popup()
	var items := []
	if side == "buy":
		dialog.open("Beli %s" % id, body + "\nKas: %s" % Fmt.rupiah(world.cash))
		for amount: Array in BUY_AMOUNTS:
			items.append({"text": amount[0], "value": float(amount[1]), "disabled": amount[1] > world.cash})
		items.append({"text": "Semua", "value": world.cash, "disabled": world.cash <= 0.0})
	else:
		var units: float = world.holdings[id]
		dialog.open("Jual %s" % id, body + "\nKamu punya %s unit (%s)." % [Fmt.units(units), Fmt.rupiah(units * inst.price)])
		for share: Array in SELL_SHARES:
			items.append({"text": share[0], "value": units * share[1], "disabled": units <= 0.0})
	dialog.add_button_row(items, _on_trade_amount.bind(id, side))
	dialog.add_button("Batal", dialog.close)


func _on_trade_amount(value: float, id: String, side: String) -> void:
	var ok := world.buy(id, value) if side == "buy" else world.sell(id, value)
	dialog.close()
	_show_toast("Transaksi berhasil" if ok else "Transaksi gagal")


# --- Aksi pemain -----------------------------------------------------------------------

func _on_speed(value: int) -> void:
	var clock := world.clock
	if value == 0:
		if not clock.has_pause("manual"):
			metrics.count("manual_pauses")
		clock.pause("manual")
	else:
		clock.resume("manual")
		clock.speed = value
	_refresh_status()


func _on_activity(id: String) -> void:
	if world.start_activity(id):
		_show_toast("Mulai %s" % world.activity_def(id)["name"])
	_refresh_all()


func _on_period(id: String, months: int) -> void:
	_cards[id]["months"] = months
	_refresh_chart(id)


func _on_scale(seconds: float) -> void:
	world.set_seconds_per_day(seconds)
	_refresh_status()
	_show_toast("1 hari game = %s detik" % _number_text(seconds))


func _on_copy_report() -> void:
	metrics.save()
	DisplayServer.clipboard_set(metrics.report_text())
	_show_toast("Laporan disalin, tempel di chat")


func _on_restart() -> void:
	_pause_for_popup()
	dialog.open("Mulai ulang?", "Permainan prototipe dimulai dari awal. Laporan uji tidak dihapus.")
	dialog.add_primary("Mulai ulang", _restart)
	dialog.add_button("Batal", dialog.close)


func _restart() -> void:
	if FileAccess.file_exists(STATE_PATH):
		DirAccess.remove_absolute(STATE_PATH)
	_start_world(false)
	dialog.close()


func _on_reset_metrics() -> void:
	metrics.reset()
	%MetricsLabel.text = metrics.report_text()
	_show_toast("Metrik direset")


func _on_switch_prototype() -> void:
	_save()
	get_tree().change_scene_to_file(LAUNCHER_SCENE)


func _pause_idle(count: bool) -> void:
	if not world.clock.has_pause("idle"):
		world.clock.pause("idle")
		if count:
			metrics.count_auto_pause("idle")
	_idle_overlay.show()
	_refresh_status()


# --- Bantuan ---------------------------------------------------------------------------

func _save() -> void:
	DirAccess.make_dir_recursive_absolute(STATE_PATH.get_base_dir())
	var tmp_path := STATE_PATH + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(world.to_dict(), "", false, true))
		file.close()
		DirAccess.rename_absolute(tmp_path, STATE_PATH)
	metrics.save()
	_since_save = 0.0


func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.show()
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(_toast.hide)


func _segment(text: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = group
	button.theme_type_variation = &"SegmentButton"
	button.text = text
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label


## 0.5 -> "0,5" | 1.0 -> "1"
func _number_text(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return str(snappedf(value, 0.01)).replace(".", ",")
