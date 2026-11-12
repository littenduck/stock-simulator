## Dev harness: emits EventBus.draft_offered. `-- --cards=4` for four cards.
extends Control


func _ready() -> void:
	add_child(load("res://ui/perk_draft/perk_draft_dialog.tscn").instantiate())
	var count := 3
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cards="):
			count = int(arg.trim_prefix("--cards="))
	await get_tree().process_frame
	EventBus.draft_offered.emit(DevFake.perks(count))
	DevFake.shot_if_requested(self)
