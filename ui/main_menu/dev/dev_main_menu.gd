## Dev harness: the real main menu scene. Pass `-- --shot=/path.png` to capture and quit.
extends Control


func _ready() -> void:
	add_child(load("res://ui/main_menu/main_menu.tscn").instantiate())
	DevFake.shot_if_requested(self)
