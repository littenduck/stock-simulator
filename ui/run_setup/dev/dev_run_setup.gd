## Dev harness: run setup with one locked character and unlocked difficulty 1-2.
extends Control


func _ready() -> void:
	SaveManager.profile.unlocked[&"difficulty_2"] = true
	var scene: Control = load("res://ui/run_setup/run_setup.tscn").instantiate()
	scene.characters_override.assign([
		DevFake.character("rookie", 10000.0),
		DevFake.character("day_trader", 8000.0, "day_trader"),
		DevFake.character("value_investor", 12000.0, "value_investor"),
	])
	SaveManager.profile.unlocked[&"day_trader"] = true
	add_child(scene)
	DevFake.shot_if_requested(self)
