extends ModalPopup
## Popup (modal) ringkasan yang muncul setiap kali pemain menekan "Lanjut".
##
## Bagian sorotan di atas beranimasi: grafik kekayaan harian bulan itu tergambar dari kiri
## ke kanan, angka kekayaan berputar ke nilai baru, lalu kartu aset yang paling bergerak
## muncul. Mengetuk grafik melewati animasi.
## Laporan rinci di bawahnya di-scroll; tinggi area dibatasi agar tombol Oke tetap terlihat.

const MAX_REPORT_HEIGHT := 420.0
const REVEAL_SECONDS := 1.5
const MOVERS_FADE_SECONDS := 0.25

var _worth_after := 0.0
var _counter_tween: Tween


func _ready() -> void:
	super()
	%OkButton.pressed.connect(close)
	%WorthChart.reveal_finished.connect(_on_reveal_finished)


func show_report(report: Dictionary) -> void:
	%Subtitle.text = "%s  ›  %s" % [Fmt.game_date(report["from_month"]), Fmt.game_date(report["to_month"])]
	var months := int(report.get("months", 1))
	%Title.text = tr("SUMMARY_TITLE_MULTI") % months if months > 1 else tr("SUMMARY_TITLE")
	MonthReport.fill(%ReportBox, report, false)
	_fill_highlight(report)
	%ReportScroll.scroll_vertical = 0
	show()
	_play_animation(report)
	await get_tree().process_frame  # label yang membungkus baru tahu tingginya setelah ditata
	%ReportScroll.custom_minimum_size.y = minf(%ReportBox.get_combined_minimum_size().y, MAX_REPORT_HEIGHT)


func _fill_highlight(report: Dictionary) -> void:
	_worth_after = report["net_worth_after"]
	var change := _worth_after - float(report["net_worth_before"])
	%Highlight.theme_type_variation = &"NetWorthPanel" if change >= 0.0 else &"NetWorthNegPanel"
	%WorthValue.text = Fmt.rupiah(_worth_after)
	%WorthChange.text = MonthReport.net_worth_change_text(report)
	%WorthChange.add_theme_color_override("font_color", MonthReport.signed_color(change))

	var daily: Array[float] = []
	daily.assign(report.get("daily_worth", []))  # laporan dari save lama tidak punya data harian
	%WorthChart.visible = daily.size() >= 2
	%WorthChart.max_points = daily.size()
	%WorthChart.set_period(0)
	%WorthChart.set_data(daily)

	for child in %Movers.get_children():
		%Movers.remove_child(child)
		child.queue_free()
	for mover: Dictionary in report.get("movers", []):
		%Movers.add_child(_mover_chip(mover))
	%MoversTitle.visible = %Movers.get_child_count() > 0
	%Movers.visible = %MoversTitle.visible


func _play_animation(report: Dictionary) -> void:
	if not %WorthChart.visible:
		%SkipHint.hide()
		return
	%SkipHint.show()
	%Movers.modulate.a = 0.0
	if _counter_tween:
		_counter_tween.kill()
	_counter_tween = create_tween()
	_counter_tween.tween_method(_set_worth_text, float(report["net_worth_before"]), _worth_after, REVEAL_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	%WorthChart.play_reveal(REVEAL_SECONDS)


## Selesai (atau dilewati): angka akhir, petunjuk disembunyikan, kartu sorotan muncul.
func _on_reveal_finished() -> void:
	if _counter_tween:
		_counter_tween.kill()
	_set_worth_text(_worth_after)
	%SkipHint.hide()
	create_tween().tween_property(%Movers, "modulate:a", 1.0, MOVERS_FADE_SECONDS)


func _set_worth_text(value: float) -> void:
	%WorthValue.text = Fmt.rupiah(value)


## Kartu kecil "BSNT +6,20%" berwarna hijau/merah.
func _mover_chip(mover: Dictionary) -> PanelContainer:
	var change: float = mover["change"]
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"ChangeUp" if change > 0.0 else (&"ChangeDown" if change < 0.0 else &"ChangeFlat")
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.theme_type_variation = &"ChangeLabel"
	label.text = "%s %s" % [mover["id"], Fmt.percent(change)]
	label.add_theme_color_override("font_color", MonthReport.signed_color(change))
	chip.add_child(label)
	return chip
