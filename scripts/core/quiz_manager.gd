class_name QuizManager
extends RefCounted
## Bank soal + jatah kuis.
## - Gratis `free_per_week` kali per minggu NYATA (reset setiap Senin, jam perangkat).
## - Kuis tambahan didapat dengan menonton iklan rewarded (maks `ads_per_day` per hari).
## Sengaja tidak memakai waktu di dalam game agar pemain tidak bisa "farming" kuis
## dengan menekan Lanjut berulang kali (GDD 5.4).

var questions: Array = []
var config: Dictionary = {}
var correct_ids: Dictionary = {}   # question_id -> true (pernah dijawab benar)
var week_id := -1
var free_used := 0
var day_id := -1
var ads_used := 0
var bonus_credits := 0             # kuis tambahan hasil menonton iklan


func setup(question_defs: Array, quiz_config: Dictionary) -> void:
	questions = question_defs
	config = quiz_config


func free_left() -> int:
	_sync_clock()
	return maxi(0, int(config["free_per_week"]) - free_used)


func ads_left() -> int:
	_sync_clock()
	return maxi(0, int(config["ads_per_day"]) - ads_used)


func can_start() -> bool:
	return free_left() > 0 or bonus_credits > 0


func add_bonus_credit() -> void:
	_sync_clock()
	ads_used += 1
	bonus_credits += 1


## Memakai satu jatah lalu mengembalikan soal. {} jika jatah habis.
## Jatah dipotong saat soal DIBUKA (bukan saat dijawab) agar tidak bisa
## "intip soal lalu tutup".
## `preferred_topics`: topik yang sedang dibutuhkan untuk unlock, diprioritaskan 70%.
func start(preferred_topics: Array = []) -> Dictionary:
	if free_left() > 0:
		free_used += 1
	elif bonus_credits > 0:
		bonus_credits -= 1
	else:
		return {}
	return _pick_question(preferred_topics)


func answer(question: Dictionary, option_index: int) -> bool:
	var is_correct := option_index == int(question["answer"])
	if is_correct:
		correct_ids[question["id"]] = true
	return is_correct


## Jumlah soal BERBEDA yang pernah dijawab benar di satu topik (syarat unlock).
func correct_in_topic(topic: String) -> int:
	var count := 0
	for q: Dictionary in questions:
		if q["topic"] == topic and correct_ids.has(q["id"]):
			count += 1
	return count


## Disimpan di user://player.json (global, bukan per slot save).
func to_dict() -> Dictionary:
	return {"correct_ids": correct_ids.keys(), "week_id": week_id, "free_used": free_used,
		"day_id": day_id, "ads_used": ads_used, "bonus_credits": bonus_credits}


func from_dict(d: Dictionary) -> void:
	correct_ids.clear()
	for id: String in d.get("correct_ids", []):
		correct_ids[id] = true
	week_id = int(d.get("week_id", -1))
	free_used = int(d.get("free_used", 0))
	day_id = int(d.get("day_id", -1))
	ads_used = int(d.get("ads_used", 0))
	bonus_credits = int(d.get("bonus_credits", 0))


func _pick_question(preferred_topics: Array) -> Dictionary:
	var pool := questions.filter(func(q: Dictionary) -> bool: return not correct_ids.has(q["id"]))
	if pool.is_empty():
		pool = questions  # semua sudah benar: ulangi dari seluruh bank soal
	var preferred := pool.filter(func(q: Dictionary) -> bool: return q["topic"] in preferred_topics)
	if not preferred.is_empty() and randf() < 0.7:
		return preferred.pick_random()
	return pool.pick_random()


func _sync_clock() -> void:
	var week := current_week_id()
	if week != week_id:
		week_id = week
		free_used = 0
	var day := local_day()
	if day != day_id:
		day_id = day
		ads_used = 0


## Hari ke-N sejak 1 Jan 1970 menurut zona waktu perangkat.
static func local_day() -> int:
	var bias_minutes: int = Time.get_time_zone_from_system()["bias"]
	return floori((Time.get_unix_time_from_system() + bias_minutes * 60.0) / 86400.0)


## 1 Jan 1970 adalah hari Kamis; +3 menggeser batas minggu ke hari Senin.
static func current_week_id() -> int:
	return floori((local_day() + 3) / 7.0)
