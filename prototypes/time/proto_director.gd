extends RefCounted
## Event Director versi mini (MVP bagian 2.5):
##   1. Setiap awal bulan menentukan jumlah event acak (0-3) dari distribusi bobot.
##   2. Menjadwalkannya di jam bangun, dengan jarak minimal beberapa hari antar-event.
##   3. Event baru DIPILIH saat jatuh tempo, sehingga bisa menyesuaikan kondisi saat itu.
##   4. Anti-sial beruntun: setelah event buruk, bobot event buruk berikutnya diturunkan.
## Konteks pemain (kas, kesehatan, dll.) dan rantai event belum ada di prototipe.

var config: Dictionary
var defs: Array = []        # event dari data/events.json yang bisa dipakai di prototipe
var rng := RandomNumberGenerator.new()
var schedule: Array = []    # menit jatuh tempo, urut naik
var recent: Array = []      # id event terakhir (agar tidak berulang)
var last_bad := false
var empty_months := 0
var last_event_day := -999


func setup(events_cfg: Dictionary, all_events: Array, seed_value: int) -> void:
	config = events_cfg
	rng.seed = seed_value
	# Event yang butuh sistem v1 lain (syarat, event wajib, bulan tertentu) dilewati.
	defs = all_events.filter(func(e: Dictionary) -> bool:
		return not (e.has("requires") or e.has("guaranteed") or e.has("month_of_year")))


## Dipanggil di awal bulan. `first_minute`: event tidak boleh dijadwalkan sebelum ini
## (dipakai di bulan pertama, karena permainan dimulai pukul 07:00).
func plan_month(month_start_day: int, days_per_month: int, first_minute: int) -> int:
	var weights: Array = config["count_weights"]
	if empty_months >= int(config["drought_months"]):
		weights = config["drought_bonus_weights"]
	var count := _weighted_index(weights)
	empty_months = empty_months + 1 if count == 0 else 0

	var gap := int(config["min_gap_days"])
	var earliest := maxi(month_start_day, last_event_day + gap)
	for day_number in _pick_days(count, earliest, month_start_day + days_per_month - 1, gap):
		var hour := rng.randi_range(int(config["first_hour"]), int(config["last_hour"]))
		var at := day_number * 1440 + hour * 60 + rng.randi_range(0, 3) * 15
		if at > first_minute:
			schedule.append(at)
			last_event_day = day_number
	schedule.sort()
	return count


func is_due(now: int) -> bool:
	return not schedule.is_empty() and schedule[0] <= now


## Mengambil event yang jatuh tempo dan memilih isinya berdasarkan bobot.
func pop_event() -> Dictionary:
	schedule.pop_front()
	var no_repeat := int(config["no_repeat_last"])
	var pool := defs.filter(func(e: Dictionary) -> bool: return not recent.has(e["id"]))
	var weights: Array[float] = []
	for e: Dictionary in pool:
		var w := float(e.get("weight", 1))
		if last_bad and e.get("bad", false):
			w *= float(config["bad_weight_after_bad"])
		weights.append(w)
	var picked: Dictionary = pool[rng.rand_weighted(PackedFloat32Array(weights))]
	recent.append(picked["id"])
	if recent.size() > no_repeat:
		recent.pop_front()
	last_bad = picked.get("bad", false)
	return picked


## Hasil satu pilihan. Prototipe hanya menerapkan efek ke KAS.
## -> {"result": teks, "cash": perubahan kas}
func resolve(event: Dictionary, choice_index: int) -> Dictionary:
	var choice: Dictionary = event["choices"][choice_index]
	var cash := -float(choice.get("cost", 0))
	var picked := choice
	if choice.has("outcomes"):
		var roll := rng.randf()
		for outcome: Dictionary in choice["outcomes"]:
			picked = outcome
			roll -= float(outcome["chance"])
			if roll < 0.0:
				break
	cash += float(picked.get("effects", {}).get("cash", 0))
	return {"result": picked.get("result", ""), "cash": cash}


func find(id: String) -> Dictionary:
	for e: Dictionary in defs:
		if e["id"] == id:
			return e
	return {}


## Memilih `count` hari di [first, last] dengan jarak minimal `gap` hari.
func _pick_days(count: int, first: int, last: int, gap: int) -> Array[int]:
	var days: Array[int] = []
	if count == 0 or first > last:
		return days
	for attempt in 40:
		days.clear()
		for i in count:
			days.append(rng.randi_range(first, last))
		days.sort()
		var ok := true
		for i in range(1, days.size()):
			if days[i] - days[i - 1] < gap:
				ok = false
				break
		if ok:
			return days
	# Jarang terjadi: ambil sebanyak yang muat, dengan jarak rata.
	days.clear()
	var fit := mini(count, floori((last - first) / float(gap)) + 1)
	for i in fit:
		days.append(first + i * gap)
	return days


func _weighted_index(weights: Array) -> int:
	var floats := PackedFloat32Array()
	for w in weights:
		floats.append(float(w))
	return rng.rand_weighted(floats)


func to_dict() -> Dictionary:
	return {"rng_seed": str(rng.seed), "rng_state": str(rng.state), "schedule": schedule,
		"recent": recent, "last_bad": last_bad, "empty_months": empty_months,
		"last_event_day": last_event_day}


func load_state(d: Dictionary) -> void:
	rng.seed = str(d["rng_seed"]).to_int()
	rng.state = str(d["rng_state"]).to_int()
	schedule.clear()
	for at in d["schedule"]:
		schedule.append(int(at))
	recent = d["recent"]
	last_bad = d["last_bad"]
	empty_months = int(d["empty_months"])
	last_event_day = int(d["last_event_day"])
