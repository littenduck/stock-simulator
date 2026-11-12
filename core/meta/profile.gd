## Cross-run player data: unlocks, top 10 scores, run count. Pure data + rules, no file I/O
## (SaveManager persists it via to_dict / load_dict).
## CONTRACT: public signatures frozen. Owner of the body: meta-progression.
## Unlock conditions: docs/game-design.md section 5.
class_name Profile
extends RefCounted

const MAX_SCORES := 10

## Unlock ids. CharacterDef/CompanyDef.unlock_id refer to these. No company uses a company_* id yet (all open).
const UNLOCK_CHAR_DAY_TRADER := &"char_day_trader"        ## finish any run
const UNLOCK_CHAR_VALUE_INVESTOR := &"char_value_investor"  ## score >= VALUE_INVESTOR_SCORE in one run
const UNLOCK_COMPANY_MOON := &"company_moon"              ## finish 3 runs
const UNLOCK_COMPANY_OLDE := &"company_olde"              ## score >= 15000 in one run
const UNLOCK_COMPANY_EXTRA_1 := &"company_extra_1"        ## finish 5 runs
const UNLOCK_COMPANY_EXTRA_2 := &"company_extra_2"        ## finish 8 runs
const UNLOCK_COMPANY_EXTRA_3 := &"company_extra_3"        ## score >= 25000 in one run
const UNLOCK_DIFFICULTY_2 := &"difficulty_2"              ## finish a run on difficulty 1
const UNLOCK_DIFFICULTY_3 := &"difficulty_3"              ## finish a run on difficulty 2
const UNLOCK_DIFFICULTY_4 := &"difficulty_4"              ## finish a run on difficulty 3
const UNLOCK_DIFFICULTY_5 := &"difficulty_5"              ## finish a run on difficulty 4

const VALUE_INVESTOR_SCORE := 20000.0
const OLDE_SCORE := 15000.0
const EXTRA_3_SCORE := 25000.0

var unlocked: Dictionary = {}          ## unlock id (StringName) -> true
## Sorted best first. Entry: {"score","character","difficulty","seed","date"}
var top_scores: Array[Dictionary] = []
var total_runs: int = 0


func is_unlocked(id: StringName) -> bool:
	return id == &"" or unlocked.has(id)


## Unlock id needed to play `level` (empty for level 1).
static func difficulty_unlock_id(level: int) -> StringName:
	if level <= 1:
		return &""
	return StringName("difficulty_%d" % level)


## Records a finished run, updates top scores and unlocks. Returns ids unlocked by this run.
func record_run(score: float, config: RunConfig) -> Array[StringName]:
	total_runs += 1
	_insert_score(score, config)
	var gained: Array[StringName] = []
	_grant(UNLOCK_CHAR_DAY_TRADER, true, gained)
	_grant(UNLOCK_CHAR_VALUE_INVESTOR, score >= VALUE_INVESTOR_SCORE, gained)
	# Company unlocks are switched off: every company is available from the start. The mechanism
	# (CompanyDef.unlock_id + the ids above) stays for future locked companies; to use it, set
	# unlock_id on a company and grant the id here (for example _grant(UNLOCK_COMPANY_MOON, total_runs >= 3, gained)).
	if config.difficulty < Difficulty.MAX_LEVEL:
		_grant(difficulty_unlock_id(config.difficulty + 1), true, gained)
	return gained


func _grant(id: StringName, condition: bool, gained: Array[StringName]) -> void:
	if condition and not unlocked.has(id):
		unlocked[id] = true
		gained.append(id)


func _insert_score(score: float, config: RunConfig) -> void:
	var entry := {
		"score": score,
		"character": String(config.character.id) if config.character != null else "",
		"difficulty": config.difficulty,
		"seed": config.seed_value,
		"date": Time.get_datetime_string_from_system(),
	}
	var index := top_scores.size()
	for i in top_scores.size():
		if score > float(top_scores[i].get("score", 0.0)):
			index = i
			break
	top_scores.insert(index, entry)
	while top_scores.size() > MAX_SCORES:
		top_scores.pop_back()


func to_dict() -> Dictionary:
	return {"version": 1, "unlocked": unlocked.keys(), "top_scores": top_scores.duplicate(true), "total_runs": total_runs}


func load_dict(data: Dictionary) -> void:
	unlocked.clear()
	for id in data.get("unlocked", []):
		unlocked[StringName(id)] = true
	top_scores.assign(data.get("top_scores", []))
	total_runs = int(data.get("total_runs", 0))
