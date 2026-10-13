extends Control
## Menu pembuka APK prototipe: memilih prototipe C (sesi pasar), B (hari cepat), atau
## A (waktu per jam).

const ProtoDialog := preload("res://prototypes/time/proto_dialog.gd")
const CHOICES := [
	["C: Sesi Pasar", "Hidup berjalan per bulan lewat tombol. Di dalam bulan, grafik berjalan sekitar 90 detik dan kamu bisa trading langsung, dengan berita kilat dan event hidup.",
		"res://prototypes/session/session_proto.tscn", &"PrimaryButton", &"PrimaryButtonLabel"],
	["B: Hari Cepat", "1 hari sekitar 1 detik. Berhenti saat ada keputusan: event, gajian, laporan, harga bergerak besar. Ada aktivitas, misi bulanan, kesehatan & kebahagiaan.",
		"res://prototypes/day/day_proto.tscn", &"NeutralButton", &"NeutralButtonLabel"],
	["A: Waktu per Jam", "1 jam game = 2,5 detik. Jam bursa, antrean pesanan, tidur & begadang, lompat ke gajian.",
		"res://prototypes/time/time_proto.tscn", &"NeutralButton", &"NeutralButtonLabel"],
]


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("#fff8ec")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	margin.add_child(box)

	var title := Label.new()
	title.theme_type_variation = &"PopupTitleLabel"
	title.text = "Prototipe Waktu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var intro := Label.new()
	intro.theme_type_variation = &"BodyLabel"
	intro.text = "Pilih prototipe yang ingin dicoba. Simpanan dan laporan uji keduanya terpisah."
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)

	for choice: Array in CHOICES:
		var card := PanelContainer.new()
		card.theme_type_variation = &"CardPanel"
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 10)
		card.add_child(inner)
		var desc := Label.new()
		desc.theme_type_variation = &"InfoLabel"
		desc.text = choice[1]
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x = 1
		inner.add_child(desc)
		var button := ProtoDialog.chunky(choice[0], choice[3], choice[4], 84.0, 30)
		button.pressed.connect(get_tree().change_scene_to_file.bind(choice[2]))
		inner.add_child(button)
		box.add_child(card)
