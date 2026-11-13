## Player preferences, stored in user://settings.cfg (separate from the profile and run saves).
## Static helper: no autoload needed. Buying and selling are never switchable; only margin is.
class_name GameSettings
extends RefCounted

const PATH := "user://settings.cfg"
const SECTION := "settings"
const VOLUME_STEP := 0.1

## Dev/test seam: point at another file.
static var path: String = PATH

static var _config: ConfigFile = null
static var _applied: bool = false


static func margin_enabled() -> bool:
	return bool(_get_value("margin_enabled", false))


## Table mode: after the bets are revealed the day resolves by itself. Off by default: you press Next at every step.
static func auto_reveal() -> bool:
	return bool(_get_value("auto_reveal", false))


static func set_auto_reveal(value: bool) -> void:
	_set_value("auto_reveal", value)


## Table mode: the 25-second opening of a new run (Space skips it). On by default.
static func opening_enabled() -> bool:
	return bool(_get_value("opening_enabled", true))


static func set_opening_enabled(value: bool) -> void:
	_set_value("opening_enabled", value)


## Trading fees in table mode (off by default).
static func fees_enabled() -> bool:
	return bool(_get_value("fees_enabled", false))


static func set_fees_enabled(value: bool) -> void:
	_set_value("fees_enabled", value)


static func volume() -> float:
	return clampf(float(_get_value("volume", 0.8)), 0.0, 1.0)


static func fullscreen() -> bool:
	return bool(_get_value("fullscreen", false))


static func set_margin_enabled(value: bool) -> void:
	_set_value("margin_enabled", value)


static func set_volume(value: float) -> void:
	_set_value("volume", snappedf(clampf(value, 0.0, 1.0), 0.05))
	apply_audio()


static func set_fullscreen(value: bool) -> void:
	_set_value("fullscreen", value)
	apply_display()


## Applies stored audio and display settings once per launch (called by the main menu).
static func apply_once() -> void:
	if _applied:
		return
	_applied = true
	apply_audio()
	apply_display()


static func apply_audio() -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	if bus < 0:
		return
	var v := volume()
	AudioServer.set_bus_mute(bus, v <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.0001)))


static func apply_display() -> void:
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen() else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


## Forget the cache so the next read reloads the file (tests, dev harness).
static func reload() -> void:
	_config = null
	_applied = false


static func _load() -> ConfigFile:
	if _config == null:
		_config = ConfigFile.new()
		_config.load(path)  # a missing or broken file simply yields defaults
	return _config


static func _get_value(key: String, default: Variant) -> Variant:
	return _load().get_value(SECTION, key, default)


static func _set_value(key: String, value: Variant) -> void:
	var config := _load()
	config.set_value(SECTION, key, value)
	config.save(path)
