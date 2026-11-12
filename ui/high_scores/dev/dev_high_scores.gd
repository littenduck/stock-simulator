## Dev harness: high scores with 10 fake entries (`-- --empty` for none).
extends Control


func _ready() -> void:
	if not "--empty" in OS.get_cmdline_user_args():
		var scores: Array[Dictionary] = []
		for i in 10:
			scores.append({"score": 42000.0 - i * 3150.5, "character": "rookie", "difficulty": 1 + i % 3,
				"seed": i, "date": "2026-11-%02d" % (i + 1)})
		SaveManager.profile.top_scores = scores
	add_child(load("res://ui/high_scores/high_scores.tscn").instantiate())
	DevFake.shot_if_requested(self)
