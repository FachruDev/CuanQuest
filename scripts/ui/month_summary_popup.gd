extends Control
## Popup (modal) ringkasan yang muncul setiap kali pemain menekan "Lanjut".


func _ready() -> void:
	hide()
	%OkButton.pressed.connect(hide)


func show_report(report: Dictionary) -> void:
	%Subtitle.text = "%s  >  %s" % [Fmt.game_date(report["from_month"]), Fmt.game_date(report["to_month"])]
	MonthReport.fill(%ReportBox, report)
	show()
