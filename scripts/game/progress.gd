class_name Progress
extends GameModule
## XP, level, tahap unlock instrumen, dan hadiah kuis. Data: data/unlocks.json.

const UNLOCKS_PATH := "res://data/unlocks.json"

var stage_defs: Array = []  # isi data/unlocks.json
var xp: int = 0
var unlocked_stages: Array[int] = []


func load_data() -> void:
	stage_defs = DataLoader.load_json(UNLOCKS_PATH).get("stages", [])


func reset() -> void:
	xp = 0
	unlocked_stages.clear()


func save_to(d: Dictionary) -> void:
	d.merge({"xp": xp, "unlocked_stages": unlocked_stages})


func load_from(d: Dictionary) -> void:
	xp = int(d["xp"])
	unlocked_stages.clear()
	for stage in d["unlocked_stages"]:
		unlocked_stages.append(int(stage))


func apply_effects(e: Dictionary) -> void:
	xp += int(e.get("xp", 0))


func level() -> int:
	return floori(xp / float(gs.economy["xp_per_level"])) + 1


## XP yang sudah dikumpulkan di level saat ini (untuk progress bar).
func xp_in_level() -> int:
	return xp % int(gs.economy["xp_per_level"])


func stage_def(stage: int) -> Dictionary:
	for def: Dictionary in stage_defs:
		if int(def["stage"]) == stage:
			return def
	return {}


func is_stage_unlocked(stage: int) -> bool:
	return stage in unlocked_stages


func is_asset_unlocked(asset_id: String) -> bool:
	return is_stage_unlocked(gs.market.get_asset(asset_id).stage)


## Status satu syarat unlock: { "met": bool, "current": float, "target": float }
func requirement_status(req: Dictionary) -> Dictionary:
	var current := 0.0
	var target := 0.0
	match req["type"]:
		"tutorial":
			current = 1.0 if gs.tutorial_done else 0.0
			target = 1.0
		"emergency_fund":
			current = gs.portfolio.liquid_assets()
			target = gs.monthly_expenses() * float(req["months"])
		"net_worth":
			current = gs.net_worth()
			target = req["min"]
		"level":
			current = level()
			target = req["min"]
		"quiz_topic":
			current = gs.quiz.correct_in_topic(req["topic"])
			target = req["correct"]
	return {"met": current >= target, "current": current, "target": target}


## Unlock bersifat permanen: sekali terbuka, tidak tertutup lagi walau syarat turun.
func check_unlocks(notify: bool) -> void:
	var any := false
	for def: Dictionary in stage_defs:
		var stage := int(def["stage"])
		if is_stage_unlocked(stage):
			continue
		var all_met := true
		for req: Dictionary in def["requirements"]:
			if not requirement_status(req)["met"]:
				all_met = false
				break
		if all_met:
			unlocked_stages.append(stage)
			any = true
			if notify:
				gs.emit_later(gs.stage_unlocked, def)
	if any:
		gs.changed.emit()


## Memakai satu jatah kuis. Mengembalikan soal, atau {} jika jatah habis.
func start_quiz() -> Dictionary:
	var question := gs.quiz.start(_needed_quiz_topics())
	gs.changed.emit()
	gs.player_changed.emit()
	return question


## Topik kuis yang dibutuhkan untuk tahap terkunci TERDEKAT (fokus satu tahap dulu).
func _needed_quiz_topics() -> Array:
	for def: Dictionary in stage_defs:
		if is_stage_unlocked(int(def["stage"])):
			continue
		var topics := []
		for req: Dictionary in def["requirements"]:
			if req["type"] == "quiz_topic" and not requirement_status(req)["met"]:
				topics.append(req["topic"])
		if not topics.is_empty():
			return topics
	return []


## Mengembalikan { "correct": bool, "reward": int, "xp": int }
func answer_quiz(question: Dictionary, option_index: int) -> Dictionary:
	var cfg: Dictionary = gs.economy["quiz"]
	var is_correct := gs.quiz.answer(question, option_index)
	var reward := gs.nominal(cfg["reward_correct"]) if is_correct else 0
	var gained := int(cfg["xp_correct"]) if is_correct else int(cfg["xp_wrong"])
	gs.cash += reward
	xp += gained
	if is_correct:
		gs.targets.progress("quiz", 1.0)
	gs.changed.emit()
	gs.player_changed.emit()
	check_unlocks(true)
	return {"correct": is_correct, "reward": reward, "xp": gained}
