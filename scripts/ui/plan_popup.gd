extends ModalPopup
## Popup "Rencana Gaji" (v1.5-0 langkah 2): pemain membagi gaji ke gaya hidup, dana darurat,
## dan investasi otomatis, dalam persen gaji. Perubahan disimpan di draf dan baru berlaku
## setelah "Simpan rencana". Hitungan rupiah memakai GameState.budget.preview_for(), sehingga
## angka di sini sama persis dengan yang dijalankan di awal bulan.

const MAX_ROWS_HEIGHT := 540.0
const VALUE_WIDTH := 200.0
const DREAM_PREFIX := "dream:"  # kunci baris pos impian: "dream:motor"

var _draft: Dictionary = {}
var _values: Dictionary = {}  # kunci baris ("basic", "lifestyle", "emergency", id aset) -> Label nilai
var _notes: Dictionary = {}   # kunci baris -> Label catatan di bawahnya


func _ready() -> void:
	super()
	%SaveButton.pressed.connect(_on_save)
	%CloseButton.pressed.connect(_on_close)


func open() -> void:
	_draft = GameState.budget.plan.duplicate(true)
	var first: bool = not GameState.budget.plan.get("confirmed", false)
	%CloseButton.visible = not first  # rencana pertama harus disimpan dulu
	%ReviewLabel.visible = not first and GameState.budget.needs_review()
	%Subtitle.text = tr("PLAN_SUBTITLE") % Fmt.rupiah(GameState.career.net_salary())
	_build_rows()
	_refresh()
	%Scroll.scroll_vertical = 0
	show()
	await get_tree().process_frame  # tinggi label yang membungkus baru diketahui setelah ditata
	%Scroll.custom_minimum_size.y = minf(%Rows.get_combined_minimum_size().y, MAX_ROWS_HEIGHT)


func _build_rows() -> void:
	for child in %Rows.get_children():
		%Rows.remove_child(child)
		child.queue_free()
	_values.clear()
	_notes.clear()
	%Rows.add_child(_row("basic", tr("PLAN_BASIC"), false))
	%Rows.add_child(_row("insurance", tr("PLAN_INSURANCE"), false))
	if GameState.education.is_studying():
		%Rows.add_child(_row("tuition", tr("PLAN_TUITION"), false))
	%Rows.add_child(_row("lifestyle", tr("PLAN_LIFESTYLE"), true))
	%Rows.add_child(_row("emergency", tr("PLAN_EMERGENCY"), true))

	var active := GameState.dreams.active()
	if not active.is_empty():
		%Rows.add_child(_label(tr("PLAN_DREAMS"), &"ReportHeaderLabel"))
		%Rows.add_child(_label(tr("PLAN_DREAMS_NOTE"), &"SmallMutedLabel"))
		for entry: Dictionary in active:
			%Rows.add_child(_row(DREAM_PREFIX + entry["id"], tr(GameState.dreams.find_def(entry["id"])["name"]), true))

	%Rows.add_child(_label(tr("PLAN_INVEST"), &"ReportHeaderLabel"))
	var invest_note := _label(tr("PLAN_INVEST_NOTE"), &"SmallMutedLabel")
	%Rows.add_child(invest_note)
	var assets := GameState.budget.autodebet_assets()
	for asset: MarketAsset in assets:
		%Rows.add_child(_row(asset.id, tr(asset.name_key), true))
	if assets.size() < GameState.market.assets.size():
		%Rows.add_child(_label(tr("PLAN_INVEST_LOCKED"), &"SmallMutedLabel"))


## Satu baris: nama, (tombol − dan +), nilai "10% · Rp550.000", dan catatan opsional di bawahnya.
func _row(key: String, title: String, adjustable: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label := _label(title, &"RowLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value := _label("", &"RowValueLabel")
	value.custom_minimum_size.x = VALUE_WIDTH
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if adjustable else HORIZONTAL_ALIGNMENT_RIGHT
	if adjustable:
		row.add_child(_step_button("−", key, -1))
		row.add_child(value)
		row.add_child(_step_button("+", key, 1))
	else:
		row.add_child(value)
	box.add_child(row)
	_values[key] = value
	if key in ["basic", "insurance", "tuition", "lifestyle", "emergency"] or key.begins_with(DREAM_PREFIX):
		var note := _label("", &"SmallMutedLabel")
		box.add_child(note)
		_notes[key] = note
	return box


func _step_button(text: String, key: String, direction: int) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"QuickButton"
	button.text = text
	button.custom_minimum_size = Vector2(60, 56)
	button.pressed.connect(_on_step.bind(key, direction))
	return button


func _on_step(key: String, direction: int) -> void:
	var cfg := GameState.budget.config()
	var step := float(cfg["step"])
	var limit := float(cfg["invest_max_each"])
	if key == "lifestyle":
		limit = float(cfg["lifestyle_max"])
	elif key == "emergency":
		limit = float(cfg["emergency_max"])
	var share := clampf(snappedf(_share(key) + direction * step, step), 0.0, limit)
	if key in ["lifestyle", "emergency"]:
		_draft[key] = share
	elif key.begins_with(DREAM_PREFIX):
		_draft["dreams"][key.trim_prefix(DREAM_PREFIX)] = share
	else:
		_draft["invest"][key] = share
	_refresh()


func _share(key: String) -> float:
	if key in ["lifestyle", "emergency"]:
		return float(_draft[key])
	if key.begins_with(DREAM_PREFIX):
		return float(_draft["dreams"].get(key.trim_prefix(DREAM_PREFIX), 0.0))
	return float(_draft["invest"].get(key, 0.0))


func _refresh() -> void:
	var income := GameState.career.net_salary()  # rencana dihitung dari gaji setelah PPh 21
	var preview := GameState.budget.preview_for(_draft, income)
	_values["basic"].text = Fmt.rupiah(preview["basic"])
	_notes["basic"].text = tr("PLAN_BASIC_NOTE")
	_values["insurance"].text = Fmt.rupiah(preview["insurance"])
	_notes["insurance"].text = tr("PLAN_INSURANCE_NOTE")
	if _values.has("tuition"):
		_values["tuition"].text = Fmt.rupiah(preview["tuition"])
		_notes["tuition"].text = tr("PLAN_TUITION_NOTE")

	_values["lifestyle"].text = _share_text(_share("lifestyle"), preview["lifestyle"])
	_notes["lifestyle"].text = tr("PLAN_LIFESTYLE_NOTE") % GameState.budget.lifestyle_happiness(_share("lifestyle"))

	_values["emergency"].text = _share_text(_share("emergency"), preview["emergency"])
	if float(preview["emergency_room"]) <= 0.0:
		_notes["emergency"].text = tr("PLAN_EMERGENCY_DONE")
	else:
		var asset := GameState.market.get_asset(GameState.budget.emergency_asset_id())
		_notes["emergency"].text = tr("PLAN_EMERGENCY_NOTE") % [tr(asset.name_key),
			Fmt.rupiah(GameState.budget.emergency_balance()), Fmt.rupiah(GameState.budget.emergency_target()),
			int(GameState.budget.config()["emergency_target_months"])]

	for key: String in _values:
		if key in ["basic", "lifestyle", "emergency"]:
			continue
		var amount := 0
		var id := key.trim_prefix(DREAM_PREFIX)
		for item: Dictionary in preview["dreams" if key.begins_with(DREAM_PREFIX) else "invest"]:
			if item["id"] == id:
				amount = item["amount"]
		_values[key].text = _share_text(_share(key), amount)
		if key.begins_with(DREAM_PREFIX):
			_notes[key].text = tr("PLAN_DREAM_NEEDED") % Fmt.rupiah(
				GameState.dreams.needed_monthly(GameState.dreams.get_active(id)))

	var surplus: int = preview["surplus"]
	%SurplusValue.text = Fmt.signed_rupiah(surplus)
	%SurplusValue.add_theme_color_override("font_color", Palette.GAIN if surplus >= 0 else Palette.LOSS)
	%SurplusBox.theme_type_variation = &"SurplusPositive" if surplus >= 0 else &"SurplusNegative"
	%OverLabel.visible = surplus < 0
	%SaveButton.disabled = surplus < 0
	%SaveButton.get_child(0).modulate.a = 0.45 if surplus < 0 else 1.0


func _share_text(share: float, amount: int) -> String:
	return tr("PLAN_SHARE") % [roundi(share * 100.0), Fmt.rupiah(amount)]


func _on_save() -> void:
	GameState.budget.set_plan(_draft)
	Sfx.play("success")
	close()


## Ditutup tanpa menyimpan: perubahan gaji dianggap sudah dilihat agar popup tidak muncul terus.
func _on_close() -> void:
	GameState.budget.acknowledge_review()
	close()


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1
	return label
