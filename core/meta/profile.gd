## Cross-run player data: unlocks, top 10 scores, run count. Pure data + rules, no file I/O
## (SaveManager persists it via to_dict / load_dict).
## CONTRACT: public signatures frozen. Owner of the body: meta-progression.
## Unlock conditions: docs/game-design.md section 5.
class_name Profile
extends RefCounted

const MAX_SCORES := 10

var unlocked: Dictionary = {}          ## unlock id (StringName) -> true
## Sorted best first. Entry: {"score","character","difficulty","seed","date"}
var top_scores: Array[Dictionary] = []
var total_runs: int = 0


func is_unlocked(id: StringName) -> bool:
	return id == &"" or unlocked.has(id)


## Records a finished run, updates top scores and unlocks. Returns ids unlocked by this run.
func record_run(_score: float, _config: RunConfig) -> Array[StringName]:
	total_runs += 1
	return []


func to_dict() -> Dictionary:
	return {"version": 1, "unlocked": unlocked.keys(), "top_scores": top_scores.duplicate(true), "total_runs": total_runs}


func load_dict(data: Dictionary) -> void:
	unlocked.clear()
	for id in data.get("unlocked", []):
		unlocked[StringName(id)] = true
	top_scores.assign(data.get("top_scores", []))
	total_runs = int(data.get("total_runs", 0))
