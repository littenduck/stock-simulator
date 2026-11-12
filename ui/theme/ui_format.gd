## Small text helpers shared by the flow screens.
class_name UiFormat
extends RefCounted


## 12345.6 -> "$12,346"
static func money(value: float) -> String:
	var digits := str(absi(int(round(value))))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = digits[i] + out
		count += 1
	return ("-$" if value < 0.0 and out != "0" else "$") + out
