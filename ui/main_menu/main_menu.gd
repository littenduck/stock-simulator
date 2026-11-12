## Main menu: New Run, Continue (only with a saved run), High Scores, Settings, Quit (hidden on the web).
extends Control

const SETTINGS_SCENE := "res://ui/main_menu/settings.tscn"

@onready var _new_run_button: Button = %NewRunButton
@onready var _continue_button: Button = %ContinueButton
@onready var _high_scores_button: Button = %HighScoresButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	GameSettings.apply_once()
	_settings_button.pressed.connect(_on_settings_button_pressed)
	_new_run_button.pressed.connect(_on_new_run_button_pressed)
	_continue_button.pressed.connect(_on_continue_button_pressed)
	_high_scores_button.pressed.connect(_on_high_scores_button_pressed)
	_quit_button.pressed.connect(_on_quit_button_pressed)
	_continue_button.visible = GameManager.has_saved_run()
	_quit_button.visible = not OS.has_feature("web")
	# Continue is the natural default when it exists.
	if _continue_button.visible:
		_continue_button.grab_focus()
	else:
		_new_run_button.grab_focus()


func _on_new_run_button_pressed() -> void:
	GameManager.open_scene(GameManager.RUN_SETUP_SCENE)


func _on_continue_button_pressed() -> void:
	if not GameManager.continue_run():
		# The save was unreadable: fall back to a fresh run.
		_continue_button.hide()
		_new_run_button.grab_focus()


func _on_high_scores_button_pressed() -> void:
	GameManager.open_scene(GameManager.HIGH_SCORES_SCENE)


func _on_settings_button_pressed() -> void:
	GameManager.open_scene(SETTINGS_SCENE)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
