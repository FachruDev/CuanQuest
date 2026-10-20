extends ModalPopup
## Popup informasi (Popup v2): judul, isi bertingkat (InfoBlocks: pengantar di tengah, blok rata kiri,
## bisa digulir bila panjang), tombol Oke, dan tombol kedua opsional (mis. "Selesaikan permainan").
## - open / open_warning / open_quiet : isi berupa teks biasa, dipecah otomatis jadi blok (paragraf & poin)
## - open_rich                         : isi berupa daftar blok (kartu angka, tip, meteran, kartu bantuan)

const MAX_BODY := 660.0  # tinggi maksimal isi; lebih panjang = digulir

var _on_secondary := Callable()
var _mark: Label  # tanda "!" pada lencana mode peringatan (v2a), dibuat saat pertama dipakai
var _default_icon: Texture2D  # ikon bintang bawaan lencana (diganti sementara oleh open_quiet / open_rich)
var _scroll: ScrollContainer
var _blocks: VBoxContainer
var _chip_holder: CenterContainer
var _chip_label: Label


func _ready() -> void:
	super()
	%OkButton.pressed.connect(close)
	%SecondaryButton.pressed.connect(_on_secondary_pressed)
	_default_icon = $Center/Dialog/BadgeHolder/Badge/Icon.texture
	%BodyLabel.hide()
	var box: VBoxContainer = %BodyLabel.get_parent()
	_chip_holder = CenterContainer.new()  # chip kecil di atas judul (mis. "Bab 2 dari 4")
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"MoodGold"
	_chip_label = Label.new()
	_chip_label.theme_type_variation = &"MoodLabel"
	chip.add_child(_chip_label)
	_chip_holder.add_child(chip)
	box.add_child(_chip_holder)
	box.move_child(_chip_holder, %TitleLabel.get_index())
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.add_theme_constant_override("scrollbar_h_separation", SCROLLBAR_GAP)
	_blocks = VBoxContainer.new()
	_blocks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blocks.add_theme_constant_override("separation", 12)
	_scroll.add_child(_blocks)
	_blocks.minimum_size_changed.connect(_refit)
	box.add_child(_scroll)
	box.move_child(_scroll, %BodyLabel.get_index() + 1)


## `ok_text`: label tombol utama (default "Oke"), mis. "Batal" untuk popup konfirmasi.
func open(title: String, body: String, secondary_text: String = "", on_secondary: Callable = Callable(),
		ok_text: String = "") -> void:
	_set_warning(false)
	_fill(title, InfoBlocks.from_text(body), secondary_text, on_secondary, ok_text, "")
	Sfx.play("success")


## Varian peringatan (v2a): lencana "!" merah, judul merah, bunyi peringatan. Untuk peringatan risiko
## leverage dan margin call, agar tidak terlihat seperti perayaan.
func open_warning(title: String, body: String, secondary_text: String = "", on_secondary: Callable = Callable(),
		ok_text: String = "") -> void:
	_set_warning(true)
	_fill(title, InfoBlocks.from_text(body), secondary_text, on_secondary, ok_text, "")
	Sfx.play("alert")


## Varian tenang (v2b langkah 3): lencana dengan ikon lain dan tanpa bunyi perayaan, untuk masa senja
## dan perpisahan di akhir hidup (pedoman konten sensitif: tanpa nuansa "GAME OVER").
func open_quiet(title: String, body: String, ok_text: String = "", icon: Texture2D = null) -> void:
	_set_warning(false)
	if icon != null:
		$Center/Dialog/BadgeHolder/Badge/Icon.texture = icon
	_fill(title, InfoBlocks.from_text(body), "", Callable(), ok_text, "")


## Isi terstruktur (lihat InfoBlocks). `opts`: kind ("normal" | "warning" | "quiet"), icon (Texture2D),
## chip (teks di atas judul), ok_text, secondary_text, on_secondary.
func open_rich(title: String, blocks: Array, opts: Dictionary = {}) -> void:
	var kind: String = opts.get("kind", "normal")
	_set_warning(kind == "warning")
	if opts.get("icon") != null:
		$Center/Dialog/BadgeHolder/Badge/Icon.texture = opts["icon"]
	_fill(title, blocks, opts.get("secondary_text", ""), opts.get("on_secondary", Callable()), opts.get("ok_text", ""),
		opts.get("chip", ""))
	if kind == "warning":
		Sfx.play("alert")
	elif kind == "normal":
		Sfx.play("success")


func _set_warning(on: bool) -> void:
	var badge: PanelContainer = $Center/Dialog/BadgeHolder/Badge
	badge.theme_type_variation = &"WarningBadgePanel" if on else &"BadgeGoldPanel"
	badge.get_node("Icon").visible = not on
	if _default_icon != null:
		badge.get_node("Icon").texture = _default_icon
	if on and _mark == null:
		_mark = Label.new()
		_mark.theme_type_variation = &"PopupBadgeLabel"
		_mark.text = "!"
		_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(_mark)
	if _mark != null:
		_mark.visible = on
	if on:
		%TitleLabel.add_theme_color_override("font_color", Palette.LOSS)
	else:
		%TitleLabel.remove_theme_color_override("font_color")


func _fill(title: String, blocks: Array, secondary_text: String, on_secondary: Callable, ok_text: String,
		chip: String) -> void:
	%TitleLabel.text = title
	_chip_holder.visible = chip != ""
	_chip_label.text = chip
	InfoBlocks.build(_blocks, blocks)
	%OkButton.get_child(0).text = ok_text if ok_text != "" else tr("BTN_OK")
	_on_secondary = on_secondary
	%SecondaryButton.visible = secondary_text != ""
	%SecondaryButton.get_child(0).text = secondary_text
	_scroll.custom_minimum_size.y = 0
	_scroll.scroll_vertical = 0
	show()
	_fit_scroll()


## Tinggi area isi mengikuti isinya (dibatasi MAX_BODY). Diukur ulang setiap ukuran minimum isi berubah
## (label berbungkus baru tahu tingginya setelah lebarnya ditata), jadi tidak ada celah kosong.
func _fit_scroll() -> void:
	await get_tree().process_frame
	_refit()


func _refit() -> void:
	_scroll.custom_minimum_size.y = minf(_blocks.get_combined_minimum_size().y, MAX_BODY)


## Callback dijalankan SEBELUM close(), karena close() langsung memicu popup berikutnya di antrean.
func _on_secondary_pressed() -> void:
	if _on_secondary.is_valid():
		_on_secondary.call()
	close()
