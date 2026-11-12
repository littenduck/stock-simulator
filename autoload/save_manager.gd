## Reads and writes user://run.json (current run) and user://profile.json (Profile).
## CONTRACT: public signatures frozen. Owner of the body: session-integration.
## Autoload scripts must not declare class_name.
## STUB: nothing is persisted yet.
extends Node

const RUN_PATH := "user://run.json"
const PROFILE_PATH := "user://profile.json"

var profile: Profile = Profile.new()


func save_run(_session: GameSession) -> void:
	pass


func has_run() -> bool:
	return false


## Saved run data, or {} if none / unreadable.
func load_run_data() -> Dictionary:
	return {}


func delete_run() -> void:
	pass


func save_profile() -> void:
	pass


func reset_profile() -> void:
	profile = Profile.new()
