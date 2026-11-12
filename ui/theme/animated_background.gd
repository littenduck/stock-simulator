## Full-rect scrolling coin / plus / arrow background. Drop animated_background.tscn into a scene.
class_name AnimatedBackground
extends ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	(material as ShaderMaterial).set_shader_parameter("rect_size", size)
