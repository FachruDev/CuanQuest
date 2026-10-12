extends ModalPopup
## Popup (modal) ringkasan yang muncul setiap kali pemain menekan "Lanjut".
## Laporan panjang (banyak berita/kejadian) di-scroll; tinggi area dibatasi agar tombol Oke tetap terlihat.

const MAX_REPORT_HEIGHT := 600.0


func _ready() -> void:
	super()
	%OkButton.pressed.connect(close)


func show_report(report: Dictionary) -> void:
	%Subtitle.text = "%s  ›  %s" % [Fmt.game_date(report["from_month"]), Fmt.game_date(report["to_month"])]
	var months := int(report.get("months", 1))
	%Title.text = tr("SUMMARY_TITLE_MULTI") % months if months > 1 else tr("SUMMARY_TITLE")
	MonthReport.fill(%ReportBox, report, true)
	%ReportScroll.scroll_vertical = 0
	show()
	await get_tree().process_frame  # label yang membungkus baru tahu tingginya setelah ditata
	%ReportScroll.custom_minimum_size.y = minf(%ReportBox.get_combined_minimum_size().y, MAX_REPORT_HEIGHT)
