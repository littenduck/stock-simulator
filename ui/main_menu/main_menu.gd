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
	_add_version_label()
	_add_language_toggle()
	_add_cast()
	_animate_in()


## The six characters under the menu panel (live 3D, small); they follow the panel when the window changes size.
func _add_cast() -> void:
	var cast := TitleCast.new()
	cast.name = "TitleCast"
	cast.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cast)
	var panel: Control = $Center/Panel
	var refit := func() -> void: cast.fit_under(panel)
	panel.resized.connect(refit)
	get_viewport().size_changed.connect(refit)
	await get_tree().process_frame
	await get_tree().process_frame
	refit.call()


## The language buttons in the bottom-left corner.
func _add_language_toggle() -> void:
	var toggle := LanguageToggle.new()
	toggle.name = "LanguageToggle"
	toggle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	toggle.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(toggle)


## Small muted version text in the bottom-right corner, read from project.godot (application/config/version).
func _add_version_label() -> void:
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	if version == "":
		return
	var label := Label.new()
	label.name = "VersionLabel"
	var commit := _commit_id()
	label.text = "v%s  ·  %s  ·  Prototype" % [version, commit] if commit != "" else "v%s  ·  Prototype" % version
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(label)


## Short commit id: asked from git when the game runs from the project folder, otherwise read from
## res://build_info.txt (one line, written by whoever exports a build). Empty when neither is available.
func _commit_id() -> String:
	var out: Array = []
	if not OS.has_feature("template") and OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "--short", "HEAD"], out) == 0 and not out.is_empty():
		var id := String(out[0]).strip_edges()
		# Tracked files changed since that commit: mark the build as not matching it.
		var changes: Array = []
		if OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "status", "--porcelain", "--untracked-files=no"], changes) == 0 \
				and not changes.is_empty() and String(changes[0]).strip_edges() != "":
			id += "-dirty"
		return id
	if FileAccess.file_exists("res://build_info.txt"):
		return FileAccess.get_file_as_string("res://build_info.txt").strip_edges()
	return ""


## Title bounces in, then the buttons rise one after another.
func _animate_in() -> void:
	var column: Control = $Center/Panel/Column
	await get_tree().process_frame
	UiFx.bounce_in($Center/Panel/Column/TitleLabel as Control, 0.05)
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
