extends ModalPopup
## Popup (modal) ringkasan yang muncul setiap kali pemain menekan "Lanjut".


func _ready() -> void:
	super()
	%OkButton.pressed.connect(close)


func show_report(report: Dictionary) -> void:
	%Subtitle.text = "%s  >  %s" % [Fmt.game_date(report["from_month"]), Fmt.game_date(report["to_month"])]
	var months := int(report.get("months", 1))
	%Title.text = tr("SUMMARY_TITLE_MULTI") % months if months > 1 else tr("SUMMARY_TITLE")
	MonthReport.fill(%ReportBox, report)
	show()
