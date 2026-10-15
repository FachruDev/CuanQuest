class_name QuizManager
extends RefCounted
## Bank soal + jatah kuis (v1.5-0: tanpa iklan).
## - Jatah `free_per_week` soal per minggu NYATA (reset setiap Senin, jam perangkat).
## - Setiap soal yang DIBUKA memakai satu jatah, dijawab benar atau salah.
## - Soal yang sudah muncul minggu ini tidak diulang di minggu yang sama; soal yang salah
##   bisa muncul lagi minggu berikutnya.
## Sengaja tidak memakai waktu di dalam game agar pemain tidak bisa "farming" kuis
## dengan menekan Lanjut berulang kali (GDD 5.4).

var questions: Array = []
var topics: Array = []  # urutan topik untuk tampilan (quiz.json "topics")
var config: Dictionary = {}
var correct_ids: Dictionary = {}   # question_id -> true (pernah dijawab benar)
var week_id := -1
var used_this_week := 0
var shown_this_week: Dictionary = {}  # question_id -> true (sudah muncul minggu ini)


func setup(question_defs: Array, quiz_config: Dictionary, topic_order: Array = []) -> void:
	questions = question_defs
	config = quiz_config
	topics = topic_order.duplicate()
	for q: Dictionary in questions:  # topik yang belum terdaftar ikut ditampilkan di akhir
		if not q["topic"] in topics:
			topics.append(q["topic"])


## Sisa jatah minggu ini.
func free_left() -> int:
	_sync_week()
	return maxi(0, int(config["free_per_week"]) - used_this_week)


func can_start() -> bool:
	return free_left() > 0


## Memakai satu jatah lalu mengembalikan soal. {} jika jatah habis.
## Jatah dipotong saat soal DIBUKA (bukan saat dijawab) agar tidak bisa
## "intip soal lalu tutup".
## `preferred_topics`: topik yang sedang dibutuhkan untuk unlock, diprioritaskan 70%.
func start(preferred_topics: Array = []) -> Dictionary:
	if free_left() <= 0:
		return {}
	used_this_week += 1
	var question := _pick_question(preferred_topics)
	shown_this_week[question["id"]] = true
	return question


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
	return {"correct_ids": correct_ids.keys(), "week_id": week_id, "used_this_week": used_this_week,
		"shown_this_week": shown_this_week.keys()}


func from_dict(d: Dictionary) -> void:
	correct_ids.clear()
	for id: String in d.get("correct_ids", []):
		correct_ids[id] = true
	week_id = int(d.get("week_id", -1))
	used_this_week = int(d.get("used_this_week", d.get("free_used", 0)))  # "free_used" = format v1
	shown_this_week.clear()
	for id: String in d.get("shown_this_week", []):
		shown_this_week[id] = true


## Urutan prioritas pool: belum pernah benar & belum muncul minggu ini → belum muncul minggu ini
## → semua soal (bank soal habis).
func _pick_question(preferred_topics: Array) -> Dictionary:
	var fresh := questions.filter(func(q: Dictionary) -> bool:
		return not correct_ids.has(q["id"]) and not shown_this_week.has(q["id"]))
	var pool := fresh
	if pool.is_empty():
		pool = questions.filter(func(q: Dictionary) -> bool: return not shown_this_week.has(q["id"]))
	if pool.is_empty():
		pool = questions
	var preferred := pool.filter(func(q: Dictionary) -> bool: return q["topic"] in preferred_topics)
	if not preferred.is_empty() and randf() < 0.7:
		return preferred.pick_random()
	return pool.pick_random()


func _sync_week() -> void:
	var week := current_week_id()
	if week != week_id:
		week_id = week
		used_this_week = 0
		shown_this_week.clear()


## Hari ke-N sejak 1 Jan 1970 menurut zona waktu perangkat.
static func local_day() -> int:
	var bias_minutes: int = Time.get_time_zone_from_system()["bias"]
	return floori((Time.get_unix_time_from_system() + bias_minutes * 60.0) / 86400.0)


## 1 Jan 1970 adalah hari Kamis; +3 menggeser batas minggu ke hari Senin.
static func current_week_id() -> int:
	return floori((local_day() + 3) / 7.0)
