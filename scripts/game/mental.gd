class_name Mental
extends GameModule
## Kesehatan mental (v2b langkah 4): status Depresi ("sedang tidak baik-baik saja") saat kebahagiaan
## sangat rendah berbulan-bulan, efeknya (energi, kesehatan perlahan, Nongkrong tidak tersedia),
## bantuan yang selalu tersedia, dan pemulihan. Depresi tidak pernah mengakhiri permainan; aturan
## lama "kebahagiaan 0 selama 3 bulan = kalah" dihapus. Wajib mengikuti docs/PEDOMAN_KONTEN_SENSITIF.md.
## Data: data/mental_health.json. Analogi web: seperti status akun "perlu perhatian" yang membuka
## halaman bantuan, bukan memblokir akun.

const DATA_PATH := "res://data/mental_health.json"
## Event yang dijadwalkan modul ini (bukan undian): tawaran bantuan di bulan Depresi dimulai.
const SCHEDULED_EVENTS := ["mental_support"]

var data: Dictionary = {}  # isi data/mental_health.json
var depressed := false
var since := -1  # bulan status Depresi terakhir dimulai
var count := 0  # berapa kali masuk status Depresi
var months := 0  # jumlah bulan dalam status Depresi sepanjang permainan
var low_months := 0  # bulan berturut-turut kebahagiaan di bawah enter_below (sebelum Depresi)
var high_months := 0  # bulan berturut-turut kebahagiaan di atas exit_above (selama Depresi)
var support_shown := false  # pesan dukungan (pedoman bagian 2) sudah tampil di permainan ini


func load_data() -> void:
	data = DataLoader.load_json(DATA_PATH)


func reset() -> void:
	depressed = false
	since = -1
	count = 0
	months = 0
	low_months = 0
	high_months = 0
	support_shown = false


func save_to(d: Dictionary) -> void:
	d["mental"] = {"depressed": depressed, "since": since, "count": count, "months": months,
		"low_months": low_months, "high_months": high_months, "support_shown": support_shown}


## Save sebelum v2b langkah 4: belum ada kunci "mental", semua mulai dari nol.
func load_from(d: Dictionary) -> void:
	reset()
	var m: Dictionary = d.get("mental", {})
	depressed = bool(m.get("depressed", false))
	since = int(m.get("since", -1))
	count = int(m.get("count", 0))
	months = int(m.get("months", 0))
	low_months = int(m.get("low_months", 0))
	high_months = int(m.get("high_months", 0))
	support_shown = bool(m.get("support_shown", false))


# --- Alur bulanan (dipanggil GameState.advance_month setelah kondisi bulan ini dihitung) -----------

## Depresi dimulai setelah kebahagiaan < enter_below selama enter_months bulan, berakhir setelah
## kebahagiaan > exit_above selama exit_months bulan. Mengembalikan bahan laporan.
func month_check() -> Dictionary:
	var report := {}
	if depressed:
		months += 1
		high_months = high_months + 1 if gs.happiness > int(data["exit_above"]) else 0
		if high_months >= int(data["exit_months"]):
			depressed = false
			high_months = 0
			report["depression_ended"] = true
		else:
			report["depressed"] = {"happiness": gs.happiness}
		return report
	low_months = low_months + 1 if gs.happiness < int(data["enter_below"]) else 0
	if low_months >= int(data["enter_months"]):
		depressed = true
		since = gs.month
		count += 1
		low_months = 0
		high_months = 0
		var info := {"first": not support_shown, "happiness": gs.happiness}
		support_shown = true
		report["depression_started"] = info
		report["depressed"] = {"happiness": gs.happiness}
		gs.queue_after_report(func() -> void: gs.depression_started.emit(info))
	elif low_months > 0:
		report["low_mood"] = low_months
	return report


## Perubahan energi maksimal bulanan selama Depresi.
func energy_change() -> int:
	return int(data["effects"]["energy"]) if depressed else 0


## Penurunan kesehatan bulan ini (poin, positif) selama Depresi; berhenti di health_floor agar Depresi
## tidak pernah membawa pemain ke kondisi kritis dengan sendirinya.
func health_drain() -> int:
	if not depressed:
		return 0
	return clampi(-int(data["effects"]["health"]), 0, maxi(gs.health - int(data["health_floor"]), 0))


func activity_blocked(activity_id: String) -> bool:
	return depressed and activity_id in data.get("blocked_activities", [])


## Bantuan (aktivitas "show_when": "low_mood") tampil saat suasana hati rendah atau sedang Depresi.
func help_visible() -> bool:
	return depressed or gs.happiness < int(data["help_visible_below"])


# --- Event bantuan --------------------------------------------------------------------------------

func scheduled_events() -> Array[Dictionary]:
	var picked: Array[Dictionary] = []
	if scheduled_event_valid("mental_support"):
		var def := gs.events.catalog.find("mental_support")
		if not def.is_empty():
			picked.append(def)
	return picked


func scheduled_event_valid(id: String) -> bool:
	return id == "mental_support" and depressed and since == gs.month
