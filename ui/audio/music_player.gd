## Loops one background track. Instanced inside a scene (main menu, game screen), so the music
## follows the scene. A missing file is silently skipped, like AudioFeedback.
##
## "Hurry up" (the Super Mario low-time effect): once the run reaches `hurry_from_day`, or on a
## margin call, the same song keeps playing from where it is, but faster and higher
## (pitch_scale raises tempo and pitch together, as on the NES).
##
## Web: browsers keep audio suspended until the first click or key press (see tools/release/web-audio.md), so on
## the web the music starts at the first press instead of in _ready(). The desktop game and tests start right away.
class_name MusicPlayer
extends Node

@export_file("*.wav", "*.ogg") var track: String = ""
@export var volume_db: float = -8.0
## Speed-up factor of the hurry-up state. 1.25 is about a major third higher and 25 % faster.
@export var hurry_speed: float = 1.25
## First trading day that triggers hurry-up; 0 disables the day trigger (the menu uses 0).
@export var hurry_from_day: int = 0
@export var hurry_on_margin_call: bool = true
## Optional loop points in seconds for WAV tracks (0 = the whole file); an .ogg loops over its whole length, so cut it at the loop point before encoding.
@export var loop_begin_sec: float = 0.0
@export var loop_end_sec: float = 0.0
## On the web, wait for the first click/key press before playing (set false to always start immediately).
@export var wait_for_input_on_web: bool = true

var hurrying: bool = false

## True once a player has seen the first press; players created after that (the next scene) start immediately.
static var _gesture_seen: bool = false

var _music := AudioStreamPlayer.new()
var _waiting: bool = false


func _ready() -> void:
	add_child(_music)
	_music.volume_db = volume_db
	if ResourceLoader.exists(track):
		_music.stream = _looped(load(track))
		_waiting = needs_gesture(OS.has_feature("web") and wait_for_input_on_web, _gesture_seen)
		if not _waiting:
			_music.play()
	set_process_input(_waiting)
	if is_inside_tree():
		bind_bus(get_node_or_null("/root/EventBus"))


## Connects to an EventBus-shaped node (tests pass their own instance).
func bind_bus(bus: Node) -> void:
	if bus == null:
		return
	if hurry_from_day > 0:
		bus.connect("day_advanced", _on_day_advanced)
	if hurry_on_margin_call:
		bus.connect("margin_called", start_hurry)
	bus.connect("run_finished", _on_run_finished)


## Starts the hurry-up state once; calling it again does nothing.
func start_hurry() -> void:
	if hurrying:
		return
	hurrying = true
	_music.pitch_scale = hurry_speed


## Stops the music (game over has its own sound effects).
func stop() -> void:
	_waiting = false
	set_process_input(false)
	_music.stop()


## True when the music must wait for the first user press: only on the web, and only until one has been seen.
static func needs_gesture(web: bool, gesture_seen: bool) -> bool:
	return web and not gesture_seen


## A press that unlocks browser audio: a key, mouse button, touch or gamepad button going down (not releases or motion).
static func is_user_gesture(event: InputEvent) -> bool:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton:
		return event.is_pressed()
	return false


func _input(event: InputEvent) -> void:
	if not _waiting or not is_user_gesture(event):
		return
	_gesture_seen = true
	_waiting = false
	set_process_input(false)
	_music.play()


func _on_day_advanced(day: int) -> void:
	if day >= hurry_from_day:
		start_hurry()


func _on_run_finished(_score: float) -> void:
	stop()


## Returns a copy of a WAV stream set to loop over its whole length; other stream types pass through.
func _looped(stream: AudioStream) -> AudioStream:
	var wav := stream as AudioStreamWAV
	if wav == null:
		var ogg := stream as AudioStreamOggVorbis
		if ogg != null:
			ogg.loop = true
		return stream
	wav = wav.duplicate()
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	# Length x rate works for every import format (PCM, ADPCM, QOA), unlike data.size().
	var total: int = roundi(wav.get_length() * wav.mix_rate)
	wav.loop_begin = clampi(roundi(loop_begin_sec * wav.mix_rate), 0, total - 1)
	var end: int = roundi(loop_end_sec * wav.mix_rate) if loop_end_sec > 0.0 else total
	wav.loop_end = clampi(end, wav.loop_begin + 1, total)
	return wav
