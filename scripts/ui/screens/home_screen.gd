extends ScrollContainer
## Tab Beranda (tema "Senja Cuan"): ringkasan karier, kondisi karakter, impian, target,
## perlindungan, utang & kredit, arus kas bulanan (sesuai rencana gaji), dan pilihan biaya hidup.

signal plan_requested
signal dream_requested(dream_id: String)
signal add_dream_requested
signal insurance_requested
## Tombol di kartu Karier: buka tab Karier (lowongan / pekerjaan).
signal career_requested
## Kartu Utang & Kredit (v1.5c): ajukan pinjaman baru / buka rincian pinjaman.
signal loan_requested(product_id: String)
signal loan_detail_requested(loan_id: int)

var _food_buttons: Dictionary = {}     # option_id -> Button
var _housing_buttons: Dictionary = {}
var _plan_values: Dictionary = {}      # "lifestyle" | "emergency" | "dreams" | "invest" -> Label nilai
var _dreams_box: VBoxContainer         # isi kartu Impian (dibangun ulang saat data berubah)
var _targets_box: VBoxContainer        # isi kartu Target Bulan Ini
var _insurance_box: VBoxContainer      # isi kartu Perlindungan (asuransi)
var _career_box: VBoxContainer         # isi kartu Karier (v1.5b langkah 4)
var _debt_box: VBoxContainer           # isi kartu Utang & Kredit (v1.5c)
var _workload_label: Label             # catatan beban kerja di kartu Kondisi


func _ready() -> void:
	_food_buttons = _build_options(%FoodOptions, GameState.economy["food"], GameState.set_food)
	_housing_buttons = _build_options(%HousingOptions, GameState.economy["housing"], GameState.set_housing)
	_build_plan_rows()
	_build_goal_cards()
	_build_career_card()
	_workload_label = _wrap_label("", &"SmallMutedLabel")  # kenapa kondisi berubah tiap bulan
	$VBox/WellbeingCard/VBox.add_child(_workload_label)
	GameState.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	%HealthBar.value = GameState.health
	%HappinessBar.value = GameState.happiness
	%HealthValue.text = "%d / 100" % GameState.health
	%HappinessValue.text = "%d / 100" % GameState.happiness

	var expenses := GameState.monthly_expenses()
	var unemployed := not GameState.career.is_employed() or GameState.career.unpaid_months > 0
	var income := 0 if unemployed else GameState.career.net_salary()
	var salary_tax := 0 if unemployed else GameState.income_tax(GameState.career.salary)
	var preview := GameState.budget.preview_for(GameState.budget.plan, income)
	var surplus: int = preview["surplus"]
	_plan_values["debt"].text = Fmt.signed_rupiah(-preview["debt"])
	_plan_values["debt"].get_parent().visible = preview["debt"] > 0
	_plan_values["insurance"].text = Fmt.signed_rupiah(-preview["insurance"])
	_plan_values["tuition"].text = Fmt.signed_rupiah(-preview["tuition"])
	_plan_values["tuition"].get_parent().visible = GameState.education.is_studying()
	_plan_values["lifestyle"].text = Fmt.signed_rupiah(-preview["lifestyle"])
	_plan_values["emergency"].text = Fmt.rupiah(preview["emergency"])
	_plan_values["dreams"].text = Fmt.rupiah(preview["dreams_total"])
	_plan_values["invest"].text = Fmt.rupiah(preview["invest_total"])
	var volatility := GameState.career.income_volatility()

	%SalaryName.text = tr("HOME_INCOME_AVG_LABEL" if volatility > 0.0 else
		("HOME_NET_SALARY_LABEL" if salary_tax > 0 else "HOME_SALARY_LABEL"))
	%SalaryValue.text = Fmt.signed_rupiah(income)
	%SalaryValue.add_theme_color_override("font_color", Palette.LOSS if unemployed else Palette.GAIN)
	%SalaryNote.visible = unemployed or volatility > 0.0 or salary_tax > 0
	if unemployed:
		%SalaryNote.text = tr("HOME_UNEMPLOYED") if not GameState.career.is_employed() \
			else tr("HOME_UNPAID") % GameState.career.unpaid_months
		%SalaryNote.add_theme_color_override("font_color", Palette.LOSS)
	elif volatility > 0.0:
		%SalaryNote.text = tr("HOME_INCOME_VARIES") % roundi(volatility * 100)
		%SalaryNote.remove_theme_color_override("font_color")
	elif salary_tax > 0:
		%SalaryNote.text = tr("HOME_SALARY_TAX_NOTE") % [Fmt.rupiah(GameState.career.salary), Fmt.rupiah(salary_tax)]
		%SalaryNote.remove_theme_color_override("font_color")

	%ExpenseValue.text = Fmt.signed_rupiah(-expenses)
	%ExpenseValue.add_theme_color_override("font_color", Palette.LOSS)
	%SurplusValue.text = Fmt.signed_rupiah(surplus)
	%SurplusValue.add_theme_color_override("font_color", Palette.GAIN if surplus >= 0 else Palette.LOSS)
	%SurplusBox.theme_type_variation = &"SurplusPositive" if surplus >= 0 else &"SurplusNegative"

	_refresh_career()
	_refresh_workload()
	_refresh_dreams()
	_refresh_targets()
	_refresh_insurance()
	_refresh_debt()

	for id: String in _food_buttons:
		_food_buttons[id].set_pressed_no_signal(id == GameState.food_id)
	for id: String in _housing_buttons:
		_housing_buttons[id].set_pressed_no_signal(id == GameState.housing_id)
	%FoodDesc.text = _effect_text(GameState.food_option())
	%HousingDesc.text = _effect_text(GameState.housing_option())


## Baris rencana gaji (gaya hidup, dana darurat, investasi otomatis) disisipkan sebelum
## kotak "Sisa ke kas", lalu tombol "Atur rencana gaji" di bawahnya.
func _build_plan_rows() -> void:
	var card: VBoxContainer = %SurplusBox.get_parent()
	var index := %SurplusBox.get_index()
	for item: Array in [["debt", "PLAN_DEBT", Palette.LOSS], ["insurance", "PLAN_INSURANCE", Palette.LOSS],
			["tuition", "PLAN_TUITION", Palette.LOSS],
			["lifestyle", "PLAN_LIFESTYLE", Palette.LOSS], ["emergency", "PLAN_EMERGENCY", Palette.TEAL],
			["dreams", "PLAN_DREAMS", Palette.TEAL], ["invest", "PLAN_INVEST", Palette.TEAL]]:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = tr(item[1])
		name_label.theme_type_variation = &"RowLabel"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := Label.new()
		value.theme_type_variation = &"RowValueLabel"
		value.add_theme_color_override("font_color", item[2])
		row.add_child(name_label)
		row.add_child(value)
		card.add_child(row)
		card.move_child(row, index)
		index += 1
		_plan_values[item[0]] = value

	var button := ChunkyButton.new()
	button.theme_type_variation = &"NeutralButton"
	button.custom_minimum_size = Vector2(0, 72)
	var label := Label.new()
	label.text = tr("HOME_PLAN_BUTTON")
	label.theme_type_variation = &"NeutralButtonLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_bottom = -7.0
	button.add_child(label)
	button.pressed.connect(plan_requested.emit)
	card.add_child(button)


## Kartu Impian, Target Bulan Ini, Perlindungan, dan Utang & Kredit disisipkan tepat setelah
## kartu Kondisi.
func _build_goal_cards() -> void:
	var page: VBoxContainer = $VBox
	var index := page.get_node("WellbeingCard").get_index() + 1
	for item: Array in [["DREAMS_TITLE", "_dreams_box"], ["TARGETS_TITLE", "_targets_box"],
			["INS_TITLE", "_insurance_box"], ["DEBT_TITLE", "_debt_box"]]:
		var title := Label.new()
		title.text = tr(item[0])
		title.theme_type_variation = &"SubSectionLabel"
		var card := PanelContainer.new()
		card.theme_type_variation = &"HomeCard"
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
		card.add_child(box)
		page.add_child(title)
		page.move_child(title, index)
		page.add_child(card)
		page.move_child(card, index + 1)
		index += 2
		set(item[1], box)


## Judul + kartu Karier di paling atas Beranda.
func _build_career_card() -> void:
	var page: VBoxContainer = $VBox
	var title := Label.new()
	title.text = tr("HOME_CAREER_TITLE")
	title.theme_type_variation = &"SubSectionLabel"
	var card := PanelContainer.new()
	card.theme_type_variation = &"HomeCard"
	_career_box = VBoxContainer.new()
	_career_box.add_theme_constant_override("separation", 8)
	card.add_child(_career_box)
	page.add_child(title)
	page.move_child(title, 0)
	page.add_child(card)
	page.move_child(card, 1)


## Menganggur: peringatan, sisa modal dalam bulan, lamaran terkirim, tombol Lihat Lowongan.
## Bekerja: jabatan, kinerja & promosi berikutnya. Keduanya menampilkan kuliah yang berjalan.
func _refresh_career() -> void:
	_clear(_career_box)
	if not GameState.career.is_employed():
		var title := _wrap_label(tr("HOME_JOBLESS_TITLE"), &"AssetNameLabel")
		title.add_theme_color_override("font_color", Palette.LOSS)
		_career_box.add_child(title)
		var runway := GameState.runway_months()
		var runway_label := _wrap_label(tr("HOME_RUNWAY") % runway if runway > 0 else tr("HOME_RUNWAY_LOW"), &"RowLabel")
		if runway < 2:
			runway_label.add_theme_color_override("font_color", Palette.LOSS)
		_career_box.add_child(runway_label)
		var hint := tr("HOME_JOBLESS_HINT")
		if not GameState.career.applications.is_empty():
			hint = tr("HOME_APPLIED") % GameState.career.applications.size()
		_career_box.add_child(_wrap_label(hint, &"SmallMutedLabel"))
	else:
		var def := GameState.career.current_job_def()
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 12)
		head.add_child(UiText.icon_tile(UiText.track_icon(def["track"]), UiText.track_tile(def["track"])))
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 0)
		texts.add_child(_wrap_label(tr(def["title"]), &"AssetNameLabel"))
		var sub: String = GameState.career.job["company"]
		if GameState.career.is_career():
			sub = tr("CAREER_LEVEL") % int(def["level"]) + " · " + sub
		texts.add_child(_wrap_label(sub, &"SmallMutedLabel"))
		head.add_child(texts)
		_career_box.add_child(head)
		if GameState.career.unpaid_months > 0:
			var leave := _wrap_label(tr("HOME_UNPAID") % GameState.career.unpaid_months, &"RowLabel")
			leave.add_theme_color_override("font_color", Palette.LOSS)
			_career_box.add_child(leave)
		if GameState.career.is_career():
			_career_box.add_child(_wrap_label(_promotion_summary(), &"RowLabel"))
	if GameState.education.is_studying():
		var study := GameState.education.study
		var program := tr(GameState.education.program_def(study["id"])["name"])
		var total := int(study["months_total"])
		var text := tr("HOME_STUDY_STARTS") % program if GameState.month < int(study["since"]) \
			else tr("HOME_STUDYING") % [program, total - int(study["months_left"]), total]
		_career_box.add_child(_wrap_label(text, &"SmallMutedLabel"))
	var employed := GameState.career.is_employed()
	var button := UiText.chunky_button(tr("HOME_OPEN_CAREER") if employed else tr("HOME_SEE_OPENINGS"),
		&"NeutralButton" if employed else &"PrimaryButton",
		&"NeutralButtonLabel" if employed else &"PrimaryButtonLabel", 68.0)
	button.pressed.connect(career_requested.emit)
	_career_box.add_child(button)


## "Kinerja 72 · Baik · Promosi berikutnya: Developer (2 syarat lagi)".
func _promotion_summary() -> String:
	var text := tr("CAREER_PERFORMANCE") % [roundi(GameState.career.performance), tr(GameState.career.performance_label())]
	var next := GameState.career.next_job_def()
	if next.is_empty():
		return text
	var missing := GameState.career.promotion_requirements().filter(func(r: Dictionary) -> bool: return not r["met"]).size()
	if missing == 0:
		return text + " · " + tr("HOME_PROMOTION_READY") % tr(next["title"])
	return text + " · " + tr("HOME_NEXT_PROMOTION") % [tr(next["title"]), missing]


## Penyebab perubahan kesehatan & kebahagiaan tiap bulan: beban kerja, stres mencari kerja,
## cuti, dan beban kuliah.
func _refresh_workload() -> void:
	var text := ""
	if not GameState.career.is_employed():
		var unemployed: Dictionary = GameState.economy["monthly_drift"].get("unemployed", {})
		text = tr("HOME_JOBLESS_NOTE") % int(unemployed.get("happiness", 0))
	elif GameState.career.unpaid_months > 0:
		text = tr("HOME_LEAVE_NOTE")
	else:
		var def := GameState.career.current_job_def()
		var workload: Dictionary = def.get("workload", {})
		text = tr("HOME_WORKLOAD_NOTE") % [tr(def["title"]), int(workload.get("health", 0)), int(workload.get("happiness", 0))]
	if GameState.education.is_studying():
		var load: Dictionary = GameState.education.data["load"]
		text += " " + tr("HOME_STUDY_NOTE") % [int(load["energy"]), -int(load["happiness"])]
	_workload_label.text = text


## Kartu Perlindungan: status asuransi per kategori + tombol "Atur asuransi".
func _refresh_insurance() -> void:
	_clear(_insurance_box)
	for category: String in GameState.insurance.data["categories"]:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = tr("INS_NAME_" + category.to_upper())
		name_label.theme_type_variation = &"RowLabel"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := Label.new()
		value.theme_type_variation = &"RowValueLabel"
		var product := GameState.insurance.policy_product(category)
		if product.is_empty():
			value.text = tr("HOME_INS_NONE")
			value.add_theme_color_override("font_color", Palette.MUTED)
		elif GameState.insurance.active_policy(category).is_empty():
			value.text = tr("HOME_INS_WAITING") % tr(product["name"])
			value.add_theme_color_override("font_color", Palette.MUTED)
		else:
			value.text = tr(product["name"])
			value.add_theme_color_override("font_color", Palette.TEAL)
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size.x = 300
		row.add_child(name_label)
		row.add_child(value)
		_insurance_box.add_child(row)
	var button := UiText.chunky_button(tr("HOME_INS_BUTTON"), &"NeutralButton", &"NeutralButtonLabel", 68.0)
	button.pressed.connect(insurance_requested.emit)
	_insurance_box.add_child(button)


## Kartu Utang & Kredit: skor kredit, pinjaman aktif (ketuk untuk rincian & pelunasan), tombol
## Ajukan pinjaman.
func _refresh_debt() -> void:
	_clear(_debt_box)
	var debt := GameState.debt
	var row := HBoxContainer.new()
	var name_label := _wrap_label(tr("CREDIT_SCORE"), &"RowLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value := _wrap_label(tr("CREDIT_SCORE_VALUE") % [debt.credit_score, tr(debt.grade()["key"])], &"RowValueLabel")
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.add_theme_color_override("font_color", UiText.credit_color(debt.credit_score))
	row.add_child(value)
	_debt_box.add_child(row)
	if debt.loans.is_empty():
		_debt_box.add_child(_wrap_label(tr("DEBT_EMPTY"), &"SmallMutedLabel"))
	for loan: Dictionary in debt.loans:
		_debt_box.add_child(_loan_row(loan))
	var button := UiText.chunky_button(tr("DEBT_APPLY"), &"NeutralButton", &"NeutralButtonLabel", 68.0)
	button.pressed.connect(loan_requested.emit.bind("kta"))
	_debt_box.add_child(button)


## Satu pinjaman: nama & cicilan, bar porsi pokok yang sudah lunas, sisa utang atau tunggakan.
func _loan_row(loan: Dictionary) -> Button:
	var debt := GameState.debt
	var button := Button.new()
	button.theme_type_variation = &"AssetRowButton"
	button.custom_minimum_size = Vector2(0, 104)
	button.pressed.connect(loan_detail_requested.emit.bind(int(loan["id"])))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_right = -16
	box.offset_top = 10
	box.offset_bottom = -10
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := _wrap_label(tr(debt.product(loan["product"])["name"]), &"AssetNameLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var payment := _wrap_label(tr("DEBT_PER_MONTH") % Fmt.rupiah(debt.installment(loan)), &"AssetValueLabel")
	payment.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(payment)
	box.add_child(top)
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"XpBar"
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = 1.0 - float(loan["balance"]) / maxf(1.0, float(loan["principal"]))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	var sub := _wrap_label(UiText.loan_status(loan), &"AssetSubLabel")
	if int(loan["missed"]) > 0:
		sub.add_theme_color_override("font_color", Palette.LOSS)
	box.add_child(sub)
	button.add_child(box)
	UiText.fit_to_content(button, box, 20.0)
	return button


func _refresh_dreams() -> void:
	_clear(_dreams_box)
	var active := GameState.dreams.active()
	if active.is_empty():
		_dreams_box.add_child(_wrap_label(tr("DREAMS_EMPTY"), &"MutedLabel"))
	for entry: Dictionary in active:
		_dreams_box.add_child(_dream_row(GameState.dreams.view_of(entry)))
	if GameState.dreams.can_add() and not GameState.dreams.available().is_empty():
		var add := UiText.chunky_button(tr("DREAMS_ADD"), &"NeutralButton", &"NeutralButtonLabel", 68.0)
		add.pressed.connect(add_dream_requested.emit)
		_dreams_box.add_child(add)


## Satu impian: nama, terkumpul/biaya, progress bar, tenggat. Diketuk membuka detail.
func _dream_row(view: Dictionary) -> Button:
	var def: Dictionary = view["def"]
	var button := Button.new()
	button.theme_type_variation = &"AssetRowButton"
	button.custom_minimum_size = Vector2(0, 104)
	button.pressed.connect(dream_requested.emit.bind(view["id"]))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_right = -16
	box.offset_top = 10
	box.offset_bottom = -10
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := _wrap_label(tr(def["name"]), &"AssetNameLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var percent := _wrap_label("%d%%" % roundi(view["ratio"] * 100.0), &"AssetValueLabel")
	percent.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(percent)
	box.add_child(top)
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"XpBar"
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = view["ratio"]
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	var months_left := int(view["deadline"]) - GameState.month
	var sub := tr("DREAM_PROGRESS") % [Fmt.rupiah_short(view["saved"]), Fmt.rupiah_short(view["cost"])]
	if months_left >= 0:
		sub += " · " + tr("DREAM_DEADLINE") % [Fmt.game_date(view["deadline"]), months_left]
	else:
		sub += " · " + tr("DREAM_DEADLINE_PASSED") % Fmt.game_date(view["deadline"])
	box.add_child(_wrap_label(sub, &"AssetSubLabel"))
	button.add_child(box)
	UiText.fit_to_content(button, box, 20.0)  # Button tidak ikut membesar mengikuti isinya
	return button


func _refresh_targets() -> void:
	_clear(_targets_box)
	for target: Dictionary in GameState.targets.items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var text := UiText.target_text(target)
		if target["type"] in ["invest", "dream_deposit"] and target["state"] == "open":
			text += " (%s)" % Fmt.rupiah_short(target["progress"])
		var label := _wrap_label(text, &"RowLabel")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var status := UiText.target_status(target)
		var status_label := _wrap_label(status["text"], &"RowValueLabel")
		status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		status_label.add_theme_color_override("font_color", status["color"])
		row.add_child(status_label)
		_targets_box.add_child(row)
	var cfg := GameState.targets.config()
	_targets_box.add_child(_wrap_label(tr("TARGETS_REWARD") % [int(cfg["reward_happiness"]), int(cfg["reward_xp"])],
		&"SmallMutedLabel"))


func _wrap_label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


## Membuat tombol pilihan (segmented control) dari data JSON.
## Setiap tombol berisi 2 baris: nama pilihan & biayanya.
func _build_options(container: HBoxContainer, options: Array, on_select: Callable) -> Dictionary:
	var group := ButtonGroup.new()
	var buttons := {}
	for option: Dictionary in options:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = &"ChoiceButton"
		button.custom_minimum_size = Vector2(0, 84)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(on_select.bind(option["id"]))

		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_bottom = -5  # bibir bawah tombol
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 0)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE  # klik diteruskan ke Button
		content.add_child(_make_label(tr(option["name_key"]), &"ChoiceNameLabel"))
		content.add_child(_make_label(Fmt.rupiah(GameState.option_cost(option)), &"ChoiceCostLabel"))
		button.add_child(content)

		container.add_child(button)
		buttons[option["id"]] = button
	return buttons


func _make_label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _effect_text(option: Dictionary) -> String:
	return tr("HOME_EFFECT") % [tr(option["name_key"]), int(option["health"]), int(option["happiness"])]
