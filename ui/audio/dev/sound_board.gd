## Dev tool: click a button to hear a sound. Top: the game events as mapped in AudioFeedback.
## Below: every file of the Kenney packs, so a different one can be picked.
## Run: godot --path . res://ui/audio/dev/sound_board.tscn
extends Control

const PACKS: Array[String] = ["interface-sounds", "ui-audio", "digital-audio", "impact-sounds"]

var _feedback: Node
var _player := AudioStreamPlayer.new()
var _label := Label.new()


func _ready() -> void:
	_feedback = load("res://ui/audio/audio_feedback.tscn").instantiate()
	add_child(_feedback)
	add_child(_player)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(_label)
	_label.text = "Click to play"
	box.add_child(_heading("Game events (as mapped now)"))
	var events := _flow(box)
	var sfx: Dictionary = _feedback.get("SFX")
	for key: StringName in sfx:
		var path: String = sfx[key]
		var b := Button.new()
		b.text = "%s  (%s)" % [key, path.get_file().get_basename()]
		b.pressed.connect(_play_path.bind(path, "%s -> %s" % [key, path.trim_prefix("res://audio/")]))
		events.add_child(b)
	for pack in PACKS:
		var dir := "res://audio/kenney_%s/Audio/" % pack
		box.add_child(_heading("kenney_" + pack))
		var flow := _flow(box)
		var names: Array[String] = []
		for f in DirAccess.get_files_at(dir):
			var n := f.trim_suffix(".import")
			if n.ends_with(".ogg") and not names.has(n):
				names.append(n)
		names.sort()
		for n in names:
			var b := Button.new()
			b.text = n.get_basename()
			b.pressed.connect(_play_path.bind(dir + n, pack + "/" + n))
			flow.add_child(b)


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = "\n" + text
	l.add_theme_font_size_override("font_size", 20)
	return l


func _flow(parent: Control) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(f)
	return f


func _play_path(path: String, caption: String) -> void:
	_label.text = "Playing: " + caption
	_player.stream = load(path)
	_player.play()
