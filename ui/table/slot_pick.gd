## The arcade pick: a frame jumps from cell to cell, fast at first and slower and slower, and stops on the target.
class_name SlotPick
extends RefCounted

const FAST := 0.035
const SLOW := 0.17


## Moves `frame` over `cells` (Controls) and lands it on `cells[target]`. `open` are the indices that may be passed over
## (the target must be one of them). With few cells the frame walks them in order, with many it jumps around.
## `skipped` is polled between hops; when it returns true the frame goes straight to the target.
static func run(host: Node, frame: Control, cells: Array, open: Array, target: int, duration: float, skipped: Callable) -> void:
	var hops := maxi(4, roundi(duration / (FAST + (SLOW - FAST) / 3.0)))
	var path: Array[int] = []
	if open.size() <= 8:
		var at: int = open.find(target)
		for i in hops:
			path.append(open[posmod(at - hops + 1 + i, open.size())])
	else:
		var prev := -1
		for i in hops - 1:
			var pick: int = open[randi() % open.size()]
			while pick == prev or pick == target:
				pick = open[randi() % open.size()]
			path.append(pick)
			prev = pick
		path.append(target)
	frame.visible = true
	for i in path.size():
		_place(frame, cells[path[i]])
		TableFx.sfx(&"slot_tick")
		if skipped.call():
			break
		var k := float(i) / float(maxi(path.size() - 1, 1))
		await host.get_tree().create_timer(lerpf(FAST, SLOW, k * k)).timeout
	_place(frame, cells[target])
	TableFx.sfx(&"slot_land")


static func _place(frame: Control, cell: Control) -> void:
	var pad := Vector2(5, 5)
	frame.global_position = cell.global_position - pad
	frame.size = cell.size + pad * 2.0
	frame.pivot_offset = frame.size * 0.5


## A hollow square frame in the pixel style (no rounded corners).
static func make_frame(color: Color, width: int = 5) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_meta("no_fx", true)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.12)
	sb.border_color = color
	sb.set_border_width_all(width)
	p.add_theme_stylebox_override("panel", sb)
	return p
