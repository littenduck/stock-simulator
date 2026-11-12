## Reads and writes user://run.json (current run) and user://profile.json (Profile).
## CONTRACT: public signatures frozen. Owner of the body: session-integration.
## Autoload scripts must not declare class_name.
extends Node

const RUN_PATH := "user://run.json"
const PROFILE_PATH := "user://profile.json"

var profile: Profile = Profile.new()


func _ready() -> void:
	_load_profile()


func save_run(session: GameSession) -> void:
	if session == null:
		return
	_write_json(RUN_PATH, session.to_dict())


func has_run() -> bool:
	return not load_run_data().is_empty()


## Saved run data, or {} if none / unreadable.
func load_run_data() -> Dictionary:
	return GameSession.migrate(_read_json(RUN_PATH))


func delete_run() -> void:
	if FileAccess.file_exists(RUN_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_PATH))


func save_profile() -> void:
	_write_json(PROFILE_PATH, profile.to_dict())


func reset_profile() -> void:
	profile = Profile.new()
	save_profile()


func _load_profile() -> void:
	var data := _migrate_profile(_read_json(PROFILE_PATH))
	if not data.is_empty():
		profile.load_dict(data)


## Brings an older profile dictionary up to version 1. Returns {} when unusable.
func _migrate_profile(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	var v := int(data.get("version", 1))
	if v < 1 or v > 1:
		return {}
	return data


func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(data))
	f.close()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}
