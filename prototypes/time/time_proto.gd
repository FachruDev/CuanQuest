extends Control
## Layar prototipe sistem waktu hybrid (MVP v1.5-0 langkah 1).
##
## Terpisah dari game utama: tidak memakai GameState/SaveManager, dan simpanannya ada di
## user://prototype/. Teks ditulis langsung (bukan lewat strings.csv) karena layar ini
## hanya untuk uji dan akan dibuang atau ditulis ulang saat implementasi.

const ProtoWorld := preload("res://prototypes/time/proto_world.gd")
const ProtoMarket := preload("res://prototypes/time/proto_market.gd")
const GameClock := preload("res://prototypes/time/game_clock.gd")
const ProtoMetrics := preload("res://prototypes/time/proto_metrics.gd")
const ProtoDialog := preload("res://prototypes/time/proto_dialog.gd")

const CONFIG_PATH := "res://prototypes/time/time_config.json"
const STATE_PATH := "user://prototype/state.json"
const LAUNCHER_SCENE := "res://prototypes/launcher.tscn"
const AUTOSAVE_SECONDS := 30.0
const LOG_LINES := 8
const PERIODS := [["1 Hari", 1], ["1 Minggu", 7], ["1 Bulan", 30]]
const BUY_AMOUNTS := [["Rp500 rb", 500_000], ["Rp1 jt", 1_000_000], ["Rp5 jt", 5_000_000]]
const SELL_SHARES := [["25%", 0.25], ["50%", 0.5], ["Semua", 1.0]]
const PAUSE_TEXT := {"background": "Dijeda (aplikasi di latar)", "idle": "Dijeda (tidak ada sentuhan)",
	"popup": "Dijeda (popup terbuka)", "manual": "Dijeda"}
const SHORT_DAYS := ["Sen", "Sel", "Rab", "Kam", "Jum", "Sab", "Min"]

var config: Dictionary
var world: ProtoWorld
var metrics := ProtoMetrics.new()
var dialog: ProtoDialog

var _cards := {}           # id instrumen -> {price, change, status, holding, chart, days}
var _speed_buttons := {}   # 0 (jeda), 1, 2, 4 -> Button
var _scale_buttons := {}   # detik per jam -> Button
var _log: Array[String] = []
var _last_input_msec := 0
var _since_save := 0.0
var _since_metrics := 0.0
var _chart_hour := -1
var _orders_signature := ""
var _idle_overlay: Control
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween


func _ready() -> void:
	# Hemat baterai (MVP bagian 5.2): layar hanya digambar ulang bila ada perubahan,
	# dan game berbasis UI tidak butuh lebih dari 30 FPS.
	OS.low_processor_usage_mode = true
	Engine.max_fps = 30
	config = DataLoader.load_json(CONFIG_PATH)
	metrics.load_or_create()
	_build_controls()
	_build_overlays()
	_start_world(true)
	_pause_idle(false)  # mulai dalam keadaan jeda: pemain mengetuk untuk mulai
	_last_input_msec = Time.get_ticks_msec()


func _start_world(load_saved: bool) -> void:
	world = ProtoWorld.new()
	world.setup(config, DataLoader.load_json("res://data/assets.json")["assets"],
		DataLoader.load_json("res://data/events.json")["events"], randi())
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
	_log.clear()
	%LogLabel.text = "-"
	_orders_signature = ""
	_chart_hour = -1
	_build_asset_cards()
	_speed_buttons[world.clock.speed].button_pressed = true
	for seconds: float in _scale_buttons:
		if is_equal_approx(seconds, world.clock.seconds_per_hour):
			_scale_buttons[seconds].button_pressed = true
	_refresh_all()


func _process(delta: float) -> void:
	var clock := world.clock
	metrics.add_time(delta, "jeda" if clock.is_paused() else "%dx" % clock.speed, str(clock.seconds_per_hour))
	if not clock.is_paused() and Time.get_ticks_msec() - _last_input_msec > float(config["day"]["idle_pause_seconds"]) * 1000.0:
		_pause_idle(true)
	if world.advance(delta) > 0:
		_refresh_all()
	_show_next_popup()

	if not clock.is_paused():  # saat jeda tidak ada pembaruan sama sekali
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
		# Disembunyikan di akhir frame agar ketukan ini tidak ikut menekan tombol di bawahnya.
		_idle_overlay.hide.call_deferred()
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
				_pause_idle(false)  # minta ketukan dulu sebelum waktu berjalan lagi
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

	var actions := [["Tidur", _on_sleep], ["Ke gajian", _on_skip.bind("payday")], ["Ke akhir bulan", _on_skip.bind("month_end")]]
	for item: Array in actions:
		var button := ProtoDialog.chunky(item[0], &"NeutralButton", &"NeutralButtonLabel", 80.0, 24)
		button.pressed.connect(item[1])
		%ActionRow.add_child(button)

	var scale_group := ButtonGroup.new()
	for seconds: float in config["clock"]["seconds_per_hour_options"]:
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
		%DebugRow.add_child(button)

	var cal: Dictionary = config["calendar"]
	%HintLabel.text = "Gaji tgl %d | Tagihan tgl %d | Laporan tgl %d | Bursa saham Sen-Jum %02d:00-%02d:00" % [
		int(cal["payday"]), int(cal["bill_day"]), int(cal["report_day"]), 9, 16]
	%MetricsLabel.text = metrics.report_text()


func _build_overlays() -> void:
	# Lapisan "dijeda, ketuk untuk lanjut" (diam 3 menit / kembali dari latar).
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
	var title := _label("Waktu dijeda", &"PopupTitleLabel")
	var body := _label("Ketuk di mana saja untuk melanjutkan.", &"PopupBodyLabel")
	for label in [title, body]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
	add_child(_idle_overlay)

	dialog = ProtoDialog.new()
	dialog.closed.connect(_on_dialog_closed)
	add_child(dialog)

	# Notifikasi singkat di bawah layar.
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
	_toast.hide()
	toast_center.add_child(_toast)
	_toast_label = _label("", &"PillLabel")
	_toast_label.add_theme_font_size_override("font_size", 22)
	_toast.add_child(_toast_label)
	add_child(holder)


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
		chart.empty_text_key = "Grafik muncul setelah harga bergerak."  # tr() mengembalikan teks apa adanya
		chart.custom_minimum_size = Vector2(0, 200)
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
			"chart": chart, "days": 1}


# --- Memperbarui tampilan --------------------------------------------------------------
# Hanya dipanggil saat waktu maju (sekitar 1,6 kali per detik pada 1x) atau setelah aksi,
# bukan setiap frame.

func _refresh_all() -> void:
	var clock := world.clock
	%DateLabel.text = clock.date_text()
	%TimeLabel.text = clock.time_text()
	%EnergyLabel.text = "Energi %d" % roundi(world.energy)
	%CashLabel.text = Fmt.rupiah(world.cash)
	%CashLabel.add_theme_color_override("font_color", Palette.GAIN if world.cash >= 0.0 else Palette.LOSS)
	%WorthLabel.text = "Kekayaan " + Fmt.rupiah(world.net_worth())
	var hour := clock.hour()
	%NightLabel.visible = hour >= 22 or hour < int(config["day"]["wake_hour"])
	%NightLabel.text = "Sudah lewat tengah malam! Tidur sebelum %02d:00 agar tidak pingsan." % int(config["day"]["pass_out_hour"]) \
		if hour < 12 else "Sudah malam. Tidur sebelum tengah malam agar energi besok penuh."
	_refresh_status()
	_refresh_cards()
	_refresh_orders()


func _refresh_status() -> void:
	var clock := world.clock
	var text := "Berjalan %dx\n1 jam game = %s dtk" % [clock.speed, _number_text(clock.seconds_per_hour / clock.speed)]
	for reason: String in PAUSE_TEXT:
		if clock.has_pause(reason):
			text = PAUSE_TEXT[reason]
			break
	%StatusLabel.text = text


func _refresh_cards() -> void:
	var hour_index := floori(world.clock.minutes / 60.0)
	var charts_due := hour_index != _chart_hour
	_chart_hour = hour_index
	for inst in world.market.instruments:
		var card: Dictionary = _cards[inst.id]
		card["price"].text = Fmt.rupiah(inst.price)
		var ratio := inst.price / inst.day_open_price - 1.0
		card["change"].text = "%s hari ini" % Fmt.percent(ratio)
		card["change"].add_theme_color_override("font_color", Palette.GAIN if ratio >= 0.0 else Palette.LOSS)
		card["status"].text = _session_text(inst)
		var units: float = world.holdings[inst.id]
		var text := "Kamu punya %s unit (%s)." % [Fmt.units(units), Fmt.rupiah(world.holding_value(inst.id))]
		if world.reserved_units[inst.id] > 0.0:
			text += " %s unit ditahan untuk pesanan jual." % Fmt.units(world.reserved_units[inst.id])
		card["holding"].text = text
		if charts_due:
			_refresh_chart(inst.id)


func _refresh_chart(id: String) -> void:
	var inst := world.market.find(id)
	var days: int = _cards[id]["days"]
	var points := days * inst.points_per_day()
	if inst.is_stock():  # hanya hari bursa yang punya titik
		points = maxi(1, roundi(days * 5.0 / 7.0)) * inst.points_per_day()
	var chart: PriceChart = _cards[id]["chart"]
	chart.set_data(inst.history)
	chart.set_period(points)


func _refresh_orders() -> void:
	var signature := str(world.orders.map(func(o: Dictionary) -> int: return int(o["id"])))
	if signature == _orders_signature:
		return
	_orders_signature = signature
	for child in %OrdersList.get_children():
		%OrdersList.remove_child(child)
		child.queue_free()
	if world.orders.is_empty():
		var empty := _label("Tidak ada pesanan. Pesanan saham di luar jam bursa akan menunggu di sini.", &"SmallMutedLabel")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size.x = 1
		%OrdersList.add_child(empty)
		return
	for order: Dictionary in world.orders:
		var row := HBoxContainer.new()
		var amount: String = Fmt.rupiah(order["amount"]) if order["side"] == "buy" else "%s unit" % Fmt.units(order["amount"])
		var label := _label("%s %s %s\nMenunggu bursa buka" % ["Beli" if order["side"] == "buy" else "Jual", order["asset"], amount], &"InfoLabel")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var cancel := Button.new()
		cancel.theme_type_variation = &"PeriodButton"
		cancel.add_theme_font_size_override("font_size", 20)
		cancel.text = "Batal"
		cancel.custom_minimum_size = Vector2(120, 56)
		cancel.pressed.connect(_on_cancel_order.bind(int(order["id"])))
		row.add_child(cancel)
		%OrdersList.add_child(row)


func _session_text(inst: ProtoMarket.Instrument) -> String:
	if not inst.is_stock():
		return "Buka 24 jam"
	var clock := world.clock
	if world.is_open(inst.id):
		return "Bursa buka, tutup %02d:00" % inst.close_hour
	var next_day := clock.day()
	if clock.is_weekend() or clock.hour() >= inst.open_hour:
		next_day += 1
		while next_day % 7 >= 5:
			next_day += 1
	var when: String = "hari ini" if next_day == clock.day() else "besok" if next_day == clock.day() + 1 \
		else GameClock.DAY_NAMES[next_day % 7]
	return "Bursa tutup, buka %s %02d:00" % [when, inst.open_hour]


func _add_log(text: String) -> void:
	var clock := world.clock
	_log.push_front("%s %d/%d %s  %s" % [SHORT_DAYS[clock.weekday()], clock.day_of_month(), clock.month_of_year(),
		clock.time_text(), text])
	if _log.size() > LOG_LINES:
		_log.resize(LOG_LINES)
	%LogLabel.text = "\n".join(_log)


# --- Popup -------------------------------------------------------------------------------

func _show_next_popup() -> void:
	if dialog.visible or world.pending.is_empty():
		return
	var item: Dictionary = world.pending.pop_front()
	if item["kind"] == "event":
		var event := world.director.find(item["event_id"])
		if event.is_empty():
			return
		_pause_for_popup()
		_show_event(event)
		return
	_pause_for_popup()
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
	var body: String = outcome["result"]
	if not is_zero_approx(outcome["cash"]):
		body += "\n\nKas %s" % Fmt.signed_rupiah(outcome["cash"])
	dialog.open(event["title"], body)
	dialog.add_primary("Oke", dialog.close)
	_refresh_all()


func _open_trade(id: String, side: String) -> void:
	var inst := world.market.find(id)
	var body := "Harga sekarang %s." % Fmt.rupiah(inst.price)
	if not world.is_open(id):
		body += "\nBursa sedang tutup: pesanan masuk antrean dan dieksekusi di harga pembukaan berikutnya, yang bisa berbeda dari harga ini."
	_pause_for_popup()
	var items := []
	if side == "buy":
		dialog.open("Beli %s" % id, body + "\nKas: %s" % Fmt.rupiah(world.cash))
		for amount: Array in BUY_AMOUNTS:
			items.append({"text": amount[0], "value": float(amount[1]), "disabled": amount[1] > world.cash})
		items.append({"text": "Semua", "value": world.cash, "disabled": world.cash <= 0.0})
	else:
		var units := world.available_units(id)
		dialog.open("Jual %s" % id, body + "\nBisa dijual: %s unit (%s)" % [Fmt.units(units), Fmt.rupiah(units * inst.price)])
		for share: Array in SELL_SHARES:
			items.append({"text": share[0], "value": units * share[1], "disabled": units <= 0.0})
	dialog.add_button_row(items, _on_trade_amount.bind(id, side))
	dialog.add_button("Batal", dialog.close)


func _on_trade_amount(value: float, id: String, side: String) -> void:
	var status := world.buy(id, value) if side == "buy" else world.sell(id, value)
	dialog.close()
	match status:
		"filled":
			_show_toast("Transaksi berhasil")
		"queued":
			_show_toast("Bursa tutup, pesanan masuk antrean")
		_:
			_show_toast("Transaksi gagal")


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


func _on_sleep() -> void:
	world.sleep()
	_after_jump()


func _on_skip(target: String) -> void:
	if target == "payday":
		world.skip_to_payday()
	else:
		world.skip_to_month_end()
	_after_jump()


func _after_jump() -> void:
	_refresh_all()
	_save()
	%MetricsLabel.text = metrics.report_text()


func _on_period(id: String, days: int) -> void:
	_cards[id]["days"] = days
	_refresh_chart(id)


func _on_cancel_order(order_id: int) -> void:
	world.cancel_order(order_id)
	_refresh_all()


func _on_scale(seconds: float) -> void:
	world.clock.seconds_per_hour = seconds
	_refresh_status()
	_show_toast("1 jam game = %s detik" % _number_text(seconds))


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
	_toast_tween.tween_interval(1.6)
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


## 2.5 -> "2,5" | 5.0 -> "5"
func _number_text(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return str(snappedf(value, 0.01)).replace(".", ",")
