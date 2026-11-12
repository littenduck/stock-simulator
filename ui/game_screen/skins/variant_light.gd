## Game screen variant: light skin. Same behaviour as game_screen.gd, different theme and layout.
extends "res://ui/game_screen/game_screen.gd"


func _init() -> void:
	theme = GameSkins.light()
