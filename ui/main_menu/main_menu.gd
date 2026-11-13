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
	UiFx.install(get_tree())
	PanelFx.decorate_tree($Center)
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
	_animate_in()


## Title bounces in, then the buttons rise one after another.
func _animate_in() -> void:
	var column: Control = $Center/Panel/Column
	await get_tree().process_frame
	UiFx.bounce_in($Center/Panel/Column/TitleLabel as Control, 0.05)
	var tagline: Control = $Center/Panel/Column/TaglineLabel
	tagline.modulate.a = 0.0
	tagline.create_tween().tween_property(tagline, "modulate:a", 1.0, 0.4).set_delay(0.35)
	var i: int = 0
	for child in column.get_children():
		if child is Button and child.visible:
			UiFx.bounce_in(child as Control, 0.3 + 0.08 * i)
			i += 1


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
