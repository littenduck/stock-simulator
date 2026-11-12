## Number formatting shared by the game screen widgets.
class_name GameFmt
extends RefCounted


## "$12,345.67" / "-$3.00".
static func money(value: float, decimals: int = 2) -> String:
	var factor: int = int(pow(10.0, decimals))
	var scaled: int = int(roundf(absf(value) * factor))
	@warning_ignore("integer_division")
	var whole: int = scaled / factor
	var text: String = _group(whole)
	if decimals > 0:
		text += ".%0*d" % [decimals, scaled % factor]
	return ("-$" if value < 0.0 and scaled > 0 else "$") + text


static func price(value: float) -> String:
	return "%.2f" % value


## Signed money: "+$12.00" / "-$12.00".
static func signed_money(value: float) -> String:
	var sign_text: String = "+" if value > 0.0 else ""
	return sign_text + money(value)


static func _group(whole: int) -> String:
	var digits: String = str(whole)
	var out: String = ""
	var count: int = 0
	for i in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = digits[i] + out
		count += 1
	return out


## A Label with an optional colour and font size. Mouse-transparent.
static func label(text: String = "", color: Color = Color.WHITE, size: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if color != Color.WHITE:
		l.add_theme_color_override("font_color", color)
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	return l


## Colours a label, or restores the theme colour when `color` is Color.WHITE (= "no special colour").
static func tint(l: Label, color: Color) -> void:
	if color == Color.WHITE:
		l.remove_theme_color_override("font_color")
	else:
		l.add_theme_color_override("font_color", color)


## Button that never keeps keyboard focus, so Space always means "next day" and never re-presses it.
static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	return b
