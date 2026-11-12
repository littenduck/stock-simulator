## An icon followed by text, e.g. "▲ 1.25%" without relying on font glyphs (see GameIcons).
class_name GameDelta
extends HBoxContainer

var _icon: TextureRect
var _label: Label


func _init(font_size: int = 14, align_end: bool = false) -> void:
	add_theme_constant_override("separation", 4)
	alignment = BoxContainer.ALIGNMENT_END if align_end else BoxContainer.ALIGNMENT_BEGIN
	mouse_filter = Control.MOUSE_FILTER_PASS
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(font_size * 0.75, font_size * 0.75)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_label = GameFmt.label("", Color.WHITE, font_size)
	add_child(_label)


## Direction icon plus the absolute percentage, coloured by sign.
func show_change(change: float) -> void:
	show_icon(GameColors.icon_name(change), GameColors.pct_value(change), GameColors.for_change(change))


func show_icon(icon_name: String, text: String, color: Color) -> void:
	_icon.texture = GameIcons.tex(icon_name)
	_icon.modulate = color
	_label.text = text
	GameFmt.tint(_label, color)
