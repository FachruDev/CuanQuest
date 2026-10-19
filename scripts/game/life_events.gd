class_name LifeEvents
extends GameModule
## Event hidup (Event Director, v1.5-0 langkah 4): menjadwalkan event tiap bulan (kalender, rantai,
## karier, acak), antrean event, keputusan pemain, efek tertunda. Daftar & syarat event ada di
## EventManager (`catalog`); efek dijalankan GameState.apply_effects() lewat tiap modul.

var catalog := EventManager.new()
var pending: Dictionary = {}  # event yang menunggu keputusan pemain
var pending_vars: Dictionary = {}  # isian teks event itu ({job}, {salary}, ...), lihat _vars_for()
var delayed: Array[Dictionary] = []  # { due, effects, text, chance, fail_text }
var queue_ids: Array[String] = []  # event bulan ini yang menunggu giliran (setelah `pending`)
var chains: Array[Dictionary] = []  # event lanjutan terjadwal: [{id, due}]
var director: Dictionary = {}  # {"quiet_months": int, "last_bad": bool}


func reset() -> void:
	catalog.setup(EventManager.load_defs())
	queue_ids.clear()
	chains.clear()
	director = _new_director()
	pending = {}
	pending_vars = {}
	delayed.clear()


func save_to(d: Dictionary) -> void:
	d.merge({"pending_event_id": pending.get("id", ""), "pending_vars": pending_vars, "delayed_effects": delayed,
		"events": catalog.to_dict(), "event_queue": queue_ids, "chain_events": chains, "director": director})


func load_from(d: Dictionary) -> void:
	catalog.setup(EventManager.load_defs())
	catalog.from_dict(d["events"])
	pending = catalog.find(d["pending_event_id"]) if d["pending_event_id"] != "" else {}
	pending_vars = d.get("pending_vars", {}).duplicate(true)
	for key: String in ["offer_index", "salary", "months", "severance"]:
		if pending_vars.has(key):
			pending_vars[key] = int(pending_vars[key])
	if pending_vars.has("offer"):
		pending_vars["offer"]["salary"] = int(pending_vars["offer"]["salary"])
	delayed.clear()
	for effect: Dictionary in d["delayed_effects"]:
		effect["due"] = int(effect["due"])
		delayed.append(effect)
	queue_ids.assign(d.get("event_queue", []))
	chains.clear()
	for chained: Dictionary in d.get("chain_events", []):
		chains.append({"id": chained["id"], "due": int(chained["due"])})
	director = _new_director().merged(d.get("director", {}), true)
	director["quiet_months"] = int(director["quiet_months"])
	if pending.is_empty() and not queue_ids.is_empty():  # jaga-jaga: antrean tanpa pending
		pending = catalog.find(queue_ids.pop_front())


## Save lama / antrean tanpa pending: isian teks dihitung setelah pasar dimuat (gaji ikut inflasi).
func restore_pending_vars() -> void:
	if not pending.is_empty() and pending_vars.is_empty():
		pending_vars = _vars_for(pending)


## Efek event: efek tertunda dan rantai event lanjutan.
func apply_effects(e: Dictionary) -> void:
	if e.has("delayed"):
		var d: Dictionary = e["delayed"].duplicate(true)
		d["due"] = gs.month + int(d["months"])
		delayed.append(d)
	if e.has("chain"):  # rantai event: jadwalkan event lanjutan beberapa bulan lagi
		var months: Array = e["chain"]["months"]
		chains.append({"id": e["chain"]["event"], "due": gs.month + gs.rng.randi_range(int(months[0]), int(months[1]))})


func off_cooldown(id: String) -> bool:
	var def := catalog.find(id)
	return not catalog.last_month.has(id) or gs.month - int(catalog.last_month[id]) >= int(def.get("cooldown", 12))


## Isian teks event yang bergantung kondisi pemain, dari modul pemilik event (Career, Education).
## Dihitung saat event mulai tampil dan ikut disimpan, agar teks, efek, dan hasilnya konsisten
## (mis. gaji promosi, pesangon).
func _vars_for(def: Dictionary) -> Dictionary:
	for module: GameModule in gs.modules:
		var vars := module.event_vars(def.get("id", ""))
		if not vars.is_empty():
			return vars
	return {}


## Event di antrean masih relevan saat gilirannya tiba? (mis. event kerja batal setelah PHK,
## penagih utang batal setelah tunggakan dilunasi event sebelumnya)
func _still_valid(def: Dictionary) -> bool:
	if def.get("id", "") in Career.SCHEDULED_EVENTS:
		return gs.career.scheduled_event_valid(def["id"])
	if def.get("id", "") in Debt.SCHEDULED_EVENTS:
		return gs.debt.scheduled_event_valid(def["id"])
	if def.get("id", "") in Life.SCHEDULED_EVENTS:
		return gs.life.scheduled_event_valid(def["id"])
	if def.get("id", "") in Mental.SCHEDULED_EVENTS:
		return gs.mental.scheduled_event_valid(def["id"])
	return catalog.requires_met(def, gs)


## Biaya pilihan event (harga hari ini). "cost_vehicle" = persen dari nilai pasar kendaraan utama;
## "cost_property" = persen dari nilai pasar properti yang dituju event; "cost_var" = angka dari
## isian event (mis. tunggakan atau biaya take over KPR yang dihitung modul Debt). Biaya berobat
## ("claim": "medical") dikali pengali usia (Life.medical_mult, v2b).
func choice_cost(choice: Dictionary) -> int:
	if choice.has("cost_vehicle"):
		return roundi(gs.vehicles.repair_base() * float(choice["cost_vehicle"]) / 1000.0) * 1000
	if choice.has("cost_property"):
		return gs.properties.event_cost(float(choice["cost_property"]))
	if choice.has("cost_var"):
		return int(pending_vars.get(choice["cost_var"], 0))
	if choice.get("claim", "") == "medical" and gs.life.medical_mult() != 1.0:  # biaya berobat naik seiring usia (v2b)
		return roundi(gs.nominal(choice.get("cost", 0)) * gs.life.medical_mult() / 1000.0) * 1000
	return gs.nominal(choice.get("cost", 0))


func has_pending() -> bool:
	return not pending.is_empty()


func _new_director() -> Dictionary:
	return {"quiet_months": 0, "last_bad": false}


func roll() -> void:
	var cfg: Dictionary = gs.economy["event_director"]
	var queue: Array[Dictionary] = []
	var guaranteed := catalog.pick_guaranteed(gs)  # event kalender, di luar jatah acak
	if not guaranteed.is_empty():
		queue.append(guaranteed)
	for chained: Dictionary in chains.duplicate():  # rantai event, juga di luar jatah
		if int(chained["due"]) > gs.month:
			continue
		chains.erase(chained)
		var def := catalog.find(chained["id"])
		if not def.is_empty() and catalog.requires_met(def, gs):  # mis. lanjutan yang butuh kedekatan
			queue.append(def)
	queue.append_array(gs.career.scheduled_events())  # wawancara / PHK / promosi, juga di luar jatah
	queue.append_array(gs.debt.scheduled_events())  # penagih utang / bunga KPR mengambang, juga di luar jatah
	queue.append_array(gs.life.scheduled_events())  # perawatan saat status Kritis dimulai (v2b), di luar jatah
	queue.append_array(gs.mental.scheduled_events())  # tawaran bantuan saat Depresi dimulai (v2b), di luar jatah

	var context := context_flags()
	var picked := 0
	for i in _roll_event_count():
		# Anti-sial beruntun: setelah event buruk, event buruk berikutnya lebih jarang.
		var bad_mult := float(gs.difficulty["bad_event_mult"])
		if director["last_bad"]:
			bad_mult *= float(cfg["bad_after_bad"])
		var taken := queue.map(func(e: Dictionary) -> String: return e["id"])
		var event := catalog.pick_random(gs, gs.rng, bad_mult, context, taken)
		if event.is_empty():
			break
		queue.append(event)
		director["last_bad"] = event.get("bad", false)
		picked += 1
	director["quiet_months"] = int(director["quiet_months"]) + 1 if picked == 0 else 0
	gs.stats["events_rolled"] = int(gs.stats.get("events_rolled", 0)) + picked

	if queue.is_empty():
		return
	for event: Dictionary in queue:
		catalog.mark_shown(event, gs.month)
	pending = queue[0]
	pending_vars = _vars_for(pending)
	queue_ids.clear()
	for event: Dictionary in queue.slice(1):
		queue_ids.append(event["id"])
	gs.changed.emit()
	gs.emit_later(gs.event_triggered, pending)


## Jumlah event acak bulan ini (bobot sesuai tingkat kesulitan). Setelah beberapa bulan
## tenang, bulan berikutnya pasti ada event (quiet_counts).
func _roll_event_count() -> int:
	var cfg: Dictionary = gs.economy["event_director"]
	var weights: Array = gs.difficulty["event_counts"]
	if int(director["quiet_months"]) >= int(cfg["quiet_months"]):
		weights = cfg["quiet_counts"]
	var floats := PackedFloat32Array()
	for w in weights:
		floats.append(float(w))
	var count := gs.rng.rand_weighted(floats)
	if gs.fast_forwarding and gs.rng.randf() >= float(gs.economy.get("fast_forward_event_mult", 1.0)):
		count = 0  # lompat waktu (masa pensiun nanti) tetap bermakna, tidak terus terpotong
	return count


## Kondisi pemain untuk tag "context" di data event (data/events/*.json).
func context_flags() -> Dictionary:
	var cfg: Dictionary = gs.economy["event_director"]
	var expenses := float(maxi(gs.monthly_expenses(), 1))
	var risky := false
	var crypto := false
	for asset_id: String in gs.portfolio.holdings:
		var asset_class := gs.market.get_asset(asset_id).asset_class
		risky = risky or asset_class in ["stock", "crypto", "commodity"]
		crypto = crypto or asset_class == "crypto"
	risky = risky or not gs.leverage.positions.is_empty()  # posisi leverage (v2a)
	return {
		"cash_rich": gs.cash >= expenses * float(cfg["cash_rich_months"]),
		"cash_poor": gs.cash < expenses * float(cfg["cash_poor_months"]),
		"low_happiness": gs.happiness < int(cfg["low_happiness"]),
		"low_health": gs.health < int(cfg["low_health"]),
		"holds_risky": risky,
		"holds_crypto": crypto,
		"unemployed": not gs.career.is_employed() and not gs.life.retired,
	}


## Event berikutnya di antrean bulan ini (setelah event sebelumnya diputuskan).
func _next_queued() -> void:
	while not queue_ids.is_empty():
		var def := catalog.find(queue_ids.pop_front())
		if def.is_empty() or not _still_valid(def):
			continue
		pending = def
		pending_vars = _vars_for(def)
		gs.changed.emit()
		gs.event_triggered.emit(def)
		return


## Pilihan dengan biaya di muka hanya bisa dipilih jika kas cukup.
## Pilihan gratis selalu bisa dipilih, termasuk saat kas minus, agar game tidak macet.
func can_choose(choice: Dictionary) -> bool:
	var cost := choice_cost(choice) - gs.insurance.cover(choice)  # yang ditanggung asuransi tidak perlu dibayar
	return cost == 0 or cost <= gs.cash


## Menjalankan pilihan pemain. Mengembalikan { "result": teks, "changes": perubahan }.
func resolve(choice_index: int) -> Dictionary:
	var event := pending
	var choice: Dictionary = event["choices"][choice_index]
	var before := gs.snapshot()
	var had_unaffordable := false
	for c: Dictionary in event["choices"]:
		if not can_choose(c):
			had_unaffordable = true
	var cost := choice_cost(choice)
	var covered := gs.insurance.cover(choice)
	gs.cash -= cost - covered
	var claims: Array[Dictionary] = []
	if covered > 0:
		claims.append({"category": gs.insurance.claim_category(choice), "amount": covered})
	elif choice.get("claim", "") == "medical":
		gs.stats["uninsured_medical"] += cost
	if event.get("critical", false):  # asuransi jiwa: uang pertanggungan penyakit kritis
		var life := gs.insurance.active_policy("life")
		if not life.is_empty():
			var payout := gs.nominal(life["critical_payout"])
			gs.cash += payout
			claims.append({"category": "life", "amount": payout})
	for claim: Dictionary in claims:
		gs.stats["insurance_claims"] += claim["amount"]
	var outcome := choice
	if choice.has("outcomes"):
		outcome = _pick_outcome(choice["outcomes"])
	var effects: Dictionary = outcome.get("effects", {})
	var offers_before := gs.career.job_offers.size()
	var title_before: String = gs.career.current_job_def().get("title", "")
	if event.has("character"):
		gs.characters.meet(event["character"])
	gs.apply_effects(effects)
	var vars := pending_vars
	pending = {}
	pending_vars = {}
	var result := {"result": outcome.get("result", ""), "changes": gs.diff(before), "claims": claims, "vars": vars}
	var cash_change: float = result["changes"].get("cash", 0.0)
	gs.stats["events"] += 1
	if had_unaffordable:
		gs.stats["unaffordable_choices"] += 1
	if event["category"] == "scam" and cash_change < 0:
		gs.stats["scam_loss"] += -cash_change
	# Menolak penipuan (pencapaian Kebal Tipu, v1.5d): pilihan tanpa biaya, tanpa uang masuk/keluar.
	if event["category"] == "scam" and not event.get("chain_only", false) and not choice.has("cost") \
			and not choice.has("outcomes") and float(effects.get("cash", 0)) == 0.0 and cash_change >= 0.0:
		gs.stats["scams_avoided"] = int(gs.stats.get("scams_avoided", 0)) + 1
	gs.record_extreme("best_event", "worst_event", cash_change, {"title": event["title"]})
	gs.changed.emit()
	gs.progress.check_unlocks(true)
	if effects.get("promote", false):
		gs.career_changed.emit("promoted", gs.career.current_job_def()["title"])
	if effects.get("layoff", false):
		gs.career_changed.emit("laid_off", title_before)
	# Tawaran kerja (setelah wawancara / dari headhunter) tampil sebelum event berikutnya.
	if not gs.career.job_offers.is_empty() and (event["id"] == "interview" or gs.career.job_offers.size() > offers_before):
		gs.job_offers_received.emit(gs.career.job_offers)
	_next_queued()  # sebelum autosave, agar event yang tersisa ikut tersimpan sebagai pending
	gs.state_committed.emit()
	return result


func _pick_outcome(outcomes: Array) -> Dictionary:
	var weights := PackedFloat32Array()
	for o: Dictionary in outcomes:
		weights.append(o["chance"])
	return outcomes[gs.rng.rand_weighted(weights)]


## Efek tertunda yang jatuh tempo bulan ini. Mengembalikan teks-teksnya untuk laporan.
func resolve_delayed() -> Array[String]:
	var texts: Array[String] = []
	for d: Dictionary in delayed.duplicate():
		if d["due"] > gs.month:
			continue
		delayed.erase(d)
		if gs.rng.randf() < float(d.get("chance", 1.0)):
			gs.apply_effects(d["effects"])
			texts.append(d["text"])
		elif d.has("fail_text"):
			texts.append(d["fail_text"])
	return texts
