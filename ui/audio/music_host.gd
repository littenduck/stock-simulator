## The one background-music player of the whole game. It lives under the root window (created by the first MusicPlayer
## node), so the music keeps playing, instead of stopping or restarting, while the game moves between screens.
## MusicPlayer nodes in the scenes only say which track their screen wants; asking for the track that is already
## playing changes nothing.
##
## Web: browsers keep audio suspended until the first click or key press (see tools/release/web-audio.md), so on the web
## the music starts at the first press instead of right away. The desktop game and tests start at once.
class_name MusicHost
extends Node

## True once a press has been seen, so a track requested later (the next screen) starts immediately.
static var _gesture_seen: bool = false
static var _instance: MusicHost = null

var current_track: String = ""
var hurrying: bool = false

var _music := AudioStreamPlayer.new()
var _waiting: bool = false
var _request: Dictionary = {}


## The shared host, created on first use. It is added to the root deferred because a scene's _ready can run while the
## root is still busy adding that scene.
static func ensure(tree: SceneTree) -> MusicHost:
	if _instance == null or not is_instance_valid(_instance):
		_instance = MusicHost.new()
		_instance.name = "MusicHost"
		tree.root.add_child.call_deferred(_instance)
	return _instance


## True when the music must wait for the first user press: only on the web, and only until one has been seen.
static func needs_gesture(web: bool, gesture_seen: bool) -> bool:
	return web and not gesture_seen


## A press that unlocks browser audio: a key, mouse button, touch or gamepad button going down (not releases or motion).
static func is_user_gesture(event: InputEvent) -> bool:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton:
		return event.is_pressed()
	return false


## A request for a different track, or for the same one while nothing is playing, starts it; the same track keeps going.
static func should_restart(current: String, requested: String, active: bool) -> bool:
	return requested != current or not active


func _ready() -> void:
	add_child(_music)
	set_process_input(false)
	_apply()


## Asks for `track` (an .ogg is cut at its loop point when encoded; a .wav may carry loop points in seconds).
func request(track: String, volume_db: float, loop_begin_sec: float, loop_end_sec: float) -> void:
	_request = {"track": track, "volume_db": volume_db, "begin": loop_begin_sec, "end": loop_end_sec}
	if is_inside_tree():
		_apply()


## Starts the hurry-up state once for the current track: faster and higher (pitch_scale moves tempo and pitch together).
func start_hurry(speed: float) -> void:
	if hurrying:
		return
	hurrying = true
	_music.pitch_scale = speed


## Stops the music; the next request starts its track from the beginning.
func stop() -> void:
	current_track = ""
	_waiting = false
	set_process_input(false)
	_music.stop()


func _input(event: InputEvent) -> void:
	if not _waiting or not is_user_gesture(event):
		return
	_gesture_seen = true
	_waiting = false
	set_process_input(false)
	_music.play()


func _apply() -> void:
	if _request.is_empty():
		return
	var req: Dictionary = _request
	_request = {}
	var track: String = req["track"]
	if not should_restart(current_track, track, _music.playing or _waiting):
		return
	if not ResourceLoader.exists(track):
		return
	current_track = track
	hurrying = false
	_music.pitch_scale = 1.0
	_music.volume_db = req["volume_db"]
	_music.stream = _looped(load(track), req["begin"], req["end"])
	_waiting = needs_gesture(OS.has_feature("web"), _gesture_seen)
	set_process_input(_waiting)
	if _waiting:
		_music.stop()
	else:
		_music.play()


## Returns a copy of a WAV stream set to loop between the given points; an .ogg loops over its whole length.
func _looped(stream: AudioStream, begin_sec: float, end_sec: float) -> AudioStream:
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
	wav.loop_begin = clampi(roundi(begin_sec * wav.mix_rate), 0, total - 1)
	var end: int = roundi(end_sec * wav.mix_rate) if end_sec > 0.0 else total
	wav.loop_end = clampi(end, wav.loop_begin + 1, total)
	return wav
