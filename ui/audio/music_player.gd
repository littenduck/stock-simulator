## Says which background track this screen wants; the music itself is played by the shared MusicHost, so it keeps going
## across screens. Put one in every screen: the menu screens (main menu, run setup, high scores, settings) ask for the
## start-menu theme, the game screen asks for the gameplay track. A missing file is silently skipped, like AudioFeedback.
##
## "Hurry up" (the Super Mario low-time effect): once the run reaches `hurry_from_day`, or on a margin call, the same song
## keeps playing from where it is, but faster and higher (pitch_scale raises tempo and pitch together, as on the NES).
class_name MusicPlayer
extends Node

@export_file("*.wav", "*.ogg") var track: String = ""
@export var volume_db: float = -8.0
## Speed-up factor of the hurry-up state. 1.25 is about a major third higher and 25 % faster.
@export var hurry_speed: float = 1.25
## First trading day that triggers hurry-up; 0 disables the day trigger (the menu screens use 0).
@export var hurry_from_day: int = 0
@export var hurry_on_margin_call: bool = true
## Optional loop points in seconds for WAV tracks (0 = the whole file); an .ogg loops over its whole length, so cut it at the loop point before encoding.
@export var loop_begin_sec: float = 0.0
@export var loop_end_sec: float = 0.0

var hurrying: bool:
	get:
		return _host != null and _host.hurrying

var _host: MusicHost = null


func _ready() -> void:
	_host = MusicHost.ensure(get_tree())
	_host.request(track, volume_db, loop_begin_sec, loop_end_sec)
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
	if _host != null:
		_host.start_hurry(hurry_speed)


## Stops the music (game over has its own sound effects).
func stop() -> void:
	if _host != null:
		_host.stop()


func _on_day_advanced(day: int) -> void:
	if day >= hurry_from_day:
		start_hurry()


func _on_run_finished(_score: float) -> void:
	stop()
