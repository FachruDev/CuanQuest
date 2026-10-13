extends Control
## Layar prototipe C "Sesi Pasar": hidup berjalan per bulan lewat tombol manual,
## sementara grafik bulan ini berjalan sendiri dan pemain bisa trading langsung.
##
## Terpisah dari game utama (simpanan di user://prototype/). Teks ditulis langsung karena
## layar ini hanya untuk uji.

const SessionWorld := preload("res://prototypes/session/session_world.gd")
const ProtoMetrics := preload("res://prototypes/time/proto_metrics.gd")
const ProtoDialog := preload("res://prototypes/time/proto_dialog.gd")

const CONFIG_PATH := "res://prototypes/session/session_config.json"
const STATE_PATH := "user://prototype/session_state.json"
const LAUNCHER_SCENE := "res://prototypes/launcher.tscn"
const AUTOSAVE_SECONDS := 30.0
const LOG_LINES := 8
const PERIODS := [["Bulan ini", 0], ["3 Bulan", 3], ["1 Tahun", 12]]
const BUY_AMOUNTS := [["Rp500 rb", 500_000], ["Rp1 jt", 1_000_000], ["Rp5 jt", 5_000_000], ["Semua", -1]]
const SELL_SHARES := [["25%", 0.25], ["50%", 0.5], ["Semua", 1.0]]
const PAUSE_TEXT := {"background": "Dijeda (aplikasi di latar)", "idle": "Dijeda (tidak ada sentuhan)",
	"popup": "Dijeda (popup terbuka)", "manual": "Dijeda"}

var config: Dictionary
var world: SessionWorld
var metrics := ProtoMetrics.new()
var dialog: ProtoDialog

var _selected := ""           # id aset yang tampil di grafik
var _period_months := 0       # 0 = bulan ini
var _chart: PriceChart
var _asset_buttons := {}
var _speed_buttons := {}
var _scale_buttons := {}
var _buy_buttons: Array[Button] = []
var _sell_buttons: Array[Button] = []
var _next_button: Button
var _log: Array[String] = []
var _last_input_msec := 0
var _since_save := 0.0
var _since_metrics := 0.0
var _was_over := false
var _idle_overlay: Control
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween


func _ready() -> void:
	OS.low_processor_usage_mode = true  # hemat baterai: gambar ulang hanya bila ada perubahan
	Engine.max_fps = 30
	config = DataLoader.load_json(CONFIG_PATH)
	metrics.path = "user://prototype/session_metrics.json"
	metrics.title = "LAPORAN UJI PROTOTIPE C (SESI PASAR)"
	metrics.scale_unit = "dtk/tick"
	metrics.load_or_create()
	_build_controls()
	_build_overlays()
	_start_world(true)
	_pause_idle(false)
	_last_input_msec = Time.get_ticks_msec()


func _start_world(load_saved: bool) -> void:
	world = SessionWorld.new()
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
		world.pending.append({"kind": "info", "title": "Selamat datang",
			"body": "Setiap bulan, grafik berjalan sekitar 90 detik. Beli dan jual kapan saja lewat tombol cepat.\n\nTekan \"Bulan berikutnya\" kapan pun kamu siap. Gaji masuk dan tagihan dibayar setiap ganti bulan."})
	world.logged.connect(_add_log)
	world.counted.connect(metrics.count)
	world.flash.connect(_on_flash)
	_log.clear()
	%LogLabel.text = "-"
	%NewsBanner.hide()
	_was_over = world.session_over()
	_build_asset_buttons()
	_speed_buttons[world.speed].button_pressed = true
	for seconds: float in _scale_buttons:
		if is_equal_approx(seconds, world.seconds_per_tick):
			_scale_buttons[seconds].button_pressed = true
	_refresh_all()


func _process(delta: float) -> void:
	metrics.add_time(delta, "jeda" if world.is_paused() or world.session_over() else "%dx" % world.speed,
		_number_text(world.seconds_per_tick))
	var running := not world.is_paused() and not world.session_over()
	if running and Time.get_ticks_msec() - _last_input_msec > float(config["session"]["idle_pause_seconds"]) * 1000.0:
		_pause_idle(true)
	if world.advance(delta) > 0:
		_refresh_all()
	if world.session_over() and not _was_over:
		metrics.count("session_watched_full")
		_show_toast("Pasar bulan ini tutup. Tekan \"Bulan berikutnya\".")
		_refresh_all()
	_was_over = world.session_over()
	_show_next_popup()

	if running:
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
	if world != null and world.has_pause("idle"):
		world.resume("idle")
		_idle_overlay.hide.call_deferred()  # akhir frame, agar ketukan ini tidak menekan tombol di bawahnya
		get_viewport().set_input_as_handled()
		_refresh_status()


func _notification(what: int) -> void:
	if world == null:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if not world.has_pause("background"):
				world.pause("background")
				metrics.count_auto_pause("background")
			_save()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			if world.has_pause("background"):
				world.resume("background")
				_pause_idle(false)
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			_save()


# --- Membangun UI ------------------------------------------------------------------------

func _build_controls() -> void:
	_chart = PriceChart.new()
	_chart.light_style = true
	_chart.empty_text_key = "Grafik bergerak setelah pasar dibuka."
	_chart.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	%ChartHolder.add_child(_chart)

	var period_group := ButtonGroup.new()
	for period: Array in PERIODS:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = period_group
		button.theme_type_variation = &"PeriodButton"
		button.text = period[0]
		button.custom_minimum_size = Vector2(0, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.button_pressed = period[1] == 0
		button.pressed.connect(_on_period.bind(period[1]))
		%PeriodRow.add_child(button)

	for amount: Array in BUY_AMOUNTS:
		var button := _trade_button(amount[0])
		button.pressed.connect(_on_buy.bind(float(amount[1])))
		%BuyRow.add_child(button)
		_buy_buttons.append(button)
	for share: Array in SELL_SHARES:
		var button := _trade_button(share[0])
		button.pressed.connect(_on_sell.bind(float(share[1])))
		%SellRow.add_child(button)
		_sell_buttons.append(button)

	var speed_group := ButtonGroup.new()
	for item: Array in [["Jeda", 0], ["1x", 1], ["2x", 2], ["4x", 4]]:
		var button := _segment(item[0], speed_group)
		button.pressed.connect(_on_speed.bind(item[1]))
		%SpeedRow.add_child(button)
		_speed_buttons[item[1]] = button

	_next_button = ProtoDialog.chunky("Bulan berikutnya", &"PrimaryButton", &"PrimaryButtonLabel", 84.0, 30)
	_next_button.pressed.connect(_on_next_month)
	%NextHolder.add_child(_next_button)

	var scale_group := ButtonGroup.new()
	for seconds: float in config["session"]["seconds_per_tick_options"]:
		var button := _segment("%d dtk" % roundi(seconds * int(config["session"]["ticks_per_month"])), scale_group)
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


func _build_asset_buttons() -> void:
	for child in %AssetRow.get_children():
		%AssetRow.remove_child(child)
		child.queue_free()
	_asset_buttons.clear()
	var group := ButtonGroup.new()
	for inst in world.instruments:
		var button := _segment(inst.id, group)
		button.pressed.connect(_on_select_asset.bind(inst.id))
		%AssetRow.add_child(button)
		_asset_buttons[inst.id] = button
	if _selected == "" or not _asset_buttons.has(_selected):
		_selected = world.instruments[0].id
	_asset_buttons[_selected].button_pressed = true


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
	for item: Array in [["Pasar dijeda", &"PopupTitleLabel"], ["Ketuk di mana saja untuk melanjutkan.", &"PopupBodyLabel"]]:
		var label := _label(item[0], item[1])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
	add_child(_idle_overlay)

	dialog = ProtoDialog.new()
	dialog.closed.connect(_on_dialog_closed)
	add_child(dialog)

	var holder := VBoxContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.offset_bottom = -200.0
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
	_toast_label.add_theme_font_size_override("font_size", 20)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.custom_minimum_size.x = 560
	_toast.add_child(_toast_label)
	add_child(holder)


# --- Memperbarui tampilan --------------------------------------------------------------
# Dipanggil saat harga bergerak (setiap tick, sekitar 1,3 kali per detik pada 1x) atau
# setelah aksi, bukan setiap frame.

func _refresh_all() -> void:
	%MonthLabel.text = "%s Th %d" % [world.month_name(), world.year()]
	%DayLabel.text = "Tgl %d" % world.day_of_month()
	%SessionBar.max_value = world.ticks_per_month
	%SessionBar.value = world.tick
	%CashLabel.text = Fmt.rupiah(world.cash)
	%CashLabel.add_theme_color_override("font_color", Palette.GAIN if world.cash >= 0.0 else Palette.LOSS)
	%WorthLabel.text = "Kekayaan " + Fmt.rupiah(world.net_worth())
	_refresh_status()
	_refresh_chart()
	_refresh_trade_buttons()
	_refresh_month_stats()


func _refresh_status() -> void:
	var text := "Pasar berjalan %dx | sesi bulan ini sekitar %d dtk" % [world.speed,
		roundi(world.seconds_per_tick * world.ticks_per_month / world.speed)]
	if world.session_over():
		text = "Pasar bulan ini tutup. Kamu masih bisa trading di harga penutupan."
	else:
		for reason: String in PAUSE_TEXT:
			if world.has_pause(reason):
				text = PAUSE_TEXT[reason]
				break
	%StatusLabel.text = text


func _refresh_chart() -> void:
	var inst := world.find(_selected)
	%AssetName.text = inst.name
	%Price.text = Fmt.rupiah(inst.price)
	var ratio := inst.price / inst.month_open - 1.0
	%MonthChange.text = "%s bulan ini" % Fmt.percent(ratio)
	%MonthChange.add_theme_color_override("font_color", Palette.GAIN if ratio >= 0.0 else Palette.LOSS)
	_chart.set_data(inst.history)
	# "Bulan ini" = titik sejak awal sesi (+ harga pembukaan); periode lain dalam bulan penuh.
	_chart.set_period(maxi(world.tick, 1) if _period_months == 0 else _period_months * world.ticks_per_month)
	var units: float = world.holdings[_selected]
	if units > 0.0:
		%Position.text = "Kamu punya %s unit (%s), untung/rugi %s." % [Fmt.units(units),
			Fmt.rupiah(world.holding_value(_selected)), Fmt.percent(world.unrealized_ratio(_selected))]
	else:
		%Position.text = "Kamu belum punya %s." % _selected


func _refresh_trade_buttons() -> void:
	for i in BUY_AMOUNTS.size():
		var amount: int = BUY_AMOUNTS[i][1]
		_buy_buttons[i].disabled = world.cash <= 0.0 if amount < 0 else float(amount) > world.cash
	for button in _sell_buttons:
		button.disabled = world.holdings[_selected] <= 0.0


func _refresh_month_stats() -> void:
	var edge := world.trading_edge()
	var lines: Array[String] = ["%d transaksi | fee %s" % [world.month_trades, Fmt.rupiah(world.month_fees)]]
	if world.month_trades > 0:
		lines.append("Dibanding kalau hanya menahan: %s" % Fmt.signed_rupiah(edge))
	lines.append("Total sejak awal permainan: %s" % Fmt.signed_rupiah(world.total_edge + edge))
	%MonthStats.text = "\n".join(lines)


func _add_log(text: String) -> void:
	_log.push_front("Tgl %d %s  %s" % [world.day_of_month(), world.month_name().left(3), text])
	if _log.size() > LOG_LINES:
		_log.resize(LOG_LINES)
	%LogLabel.text = "\n".join(_log)


func _on_flash(text: String) -> void:
	%NewsLabel.text = "KABAR KILAT (tgl %d): %s" % [world.day_of_month(), text]
	%NewsBanner.show()
	Sfx.vibrate()


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
		"report":
			dialog.open(item["title"], item["body"])
			dialog.add_primary("Mulai bulan berikutnya", _on_report_closed)
		_:
			dialog.open(item["title"], item["body"])
			dialog.add_primary("Oke", dialog.close)


func _pause_for_popup() -> void:
	if not world.has_pause("popup"):
		world.pause("popup")
		metrics.count_auto_pause("popup")
	_refresh_status()


func _on_dialog_closed() -> void:
	world.resume("popup")
	_refresh_all()


func _on_report_closed() -> void:
	world.start_next_month()
	_was_over = false
	%NewsBanner.hide()
	_save()
	dialog.close()


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


# --- Aksi pemain -----------------------------------------------------------------------

func _on_buy(amount: float) -> void:
	var rupiah := world.cash if amount < 0.0 else amount
	if world.buy(_selected, rupiah):
		_show_toast("Beli %s %s" % [_selected, Fmt.rupiah_short(rupiah)])
	_refresh_all()


func _on_sell(share: float) -> void:
	if world.sell(_selected, world.holdings[_selected] * share):
		_show_toast("Jual %s %d%%" % [_selected, roundi(share * 100.0)])
	_refresh_all()


func _on_select_asset(id: String) -> void:
	_selected = id
	_refresh_all()


func _on_period(months: int) -> void:
	_period_months = months
	_refresh_chart()


func _on_next_month() -> void:
	world.finish_month()
	_refresh_all()


func _on_speed(value: int) -> void:
	if value == 0:
		if not world.has_pause("manual"):
			metrics.count("manual_pauses")
		world.pause("manual")
	else:
		world.resume("manual")
		world.speed = value
	_refresh_status()


func _on_scale(seconds: float) -> void:
	world.seconds_per_tick = seconds
	_refresh_status()
	_show_toast("Sesi per bulan sekitar %d detik" % roundi(seconds * world.ticks_per_month))


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
	if not world.has_pause("idle"):
		world.pause("idle")
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


func _trade_button(text: String) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"PeriodButton"
	button.add_theme_font_size_override("font_size", 22)
	button.text = text
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


func _segment(text: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = group
	button.theme_type_variation = &"SegmentButton"
	button.text = text
	button.custom_minimum_size = Vector2(0, 60)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label


## 0.75 -> "0,75" | 1.0 -> "1"
func _number_text(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return str(snappedf(value, 0.01)).replace(".", ",")
