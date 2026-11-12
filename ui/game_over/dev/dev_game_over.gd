## Dev harness: emits EventBus.run_finished after faking a profile with a new unlock.
extends Control


func _ready() -> void:
	var dialog: Control = load("res://ui/game_over/game_over_dialog.tscn").instantiate()
	add_child(dialog)
	await get_tree().process_frame
	var scores: Array[Dictionary] = [{"score": 23456.0, "character": "rookie", "difficulty": 1, "seed": 1, "date": "2026-11-11"}]
	SaveManager.profile.top_scores = scores
	SaveManager.profile.unlocked[&"day_trader"] = true
	EventBus.run_finished.emit(23456.0)
	DevFake.shot_if_requested(self)
