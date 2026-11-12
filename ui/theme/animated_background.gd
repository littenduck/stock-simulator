## Full-rect scrolling coin / plus / arrow background. Drop animated_background.tscn into a scene.
class_name AnimatedBackground
extends ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Exported builds do not apply the instanced root's anchors (size stayed 0), so set them in code.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	(material as ShaderMaterial).set_shader_parameter("rect_size", size)
