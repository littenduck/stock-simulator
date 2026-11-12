## Dev harness: the real settings screen on a throw-away settings file.
## `-- --margin` pre-enables margin, `-- --shot=/path.png` captures and quits.
extends Control


func _ready() -> void:
	GameSettings.path = "user://dev_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.path))
	GameSettings.reload()
	if "--margin" in OS.get_cmdline_user_args():
		GameSettings.set_margin_enabled(true)
	add_child(load("res://ui/main_menu/settings.tscn").instantiate())
	DevFake.shot_if_requested(self)
