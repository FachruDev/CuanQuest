extends ModalPopup
## Laporan tahunan (v1.5d langkah 4): tampil setiap Januari setelah laporan bulanan, dan bisa
## dibuka lagi dari Profil. Isinya diisi MonthReport.fill_annual().


func _ready() -> void:
	super()
	%CloseButton.pressed.connect(close)


func open(report: Dictionary) -> void:
	%TitleLabel.text = tr("ANNUAL_TITLE") % int(report["year"])
	MonthReport.fill_annual(%Rows, report)
	%Scroll.scroll_vertical = 0
	show()
