## Soft drop shadow behind a PanelContainer and a faint top-to-bottom sheen over its background.
## `PanelFx.decorate(panel)` adds two mouse-transparent children; `decorate_tree(root)` does it for every
## plain panel under `root`. The Kenney 9-slice art stays the look, this only adds depth.
class_name PanelFx
extends Control

enum Kind { SHADOW, SHEEN }

var kind: Kind = Kind.SHADOW


static func decorate(panel: PanelContainer) -> void:
	if panel.has_meta("panel_fx"):
		return
	panel.set_meta("panel_fx", true)
	var shadow := PanelFx.new()
	shadow.kind = Kind.SHADOW
	shadow.show_behind_parent = true
	panel.add_child(shadow)
	var sheen := PanelFx.new()
	sheen.kind = Kind.SHEEN
	panel.add_child(sheen)
	panel.move_child(shadow, 0)
	panel.move_child(sheen, 1)


static func decorate_tree(root: Node) -> void:
	if root is PanelContainer and not root.has_meta("no_fx"):
		var variation: StringName = (root as PanelContainer).theme_type_variation
		if variation != &"ChartPanel":
			decorate(root as PanelContainer)
	for child in root.get_children():
		if not (child is PanelFx):
			decorate_tree(child)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _enter_tree() -> void:
	var parent := get_parent() as Control
	if parent != null and not parent.resized.is_connected(queue_redraw):
		parent.resized.connect(queue_redraw)


## The panel's full rectangle in this node's coordinates (the container lays this node out inside the
## panel's content margins, so use the parent's size instead of ours).
func _panel_rect() -> Rect2:
	var parent := get_parent() as Control
	return Rect2(-position, parent.size if parent != null else size)


func _draw() -> void:
	var panel: Rect2 = _panel_rect()
	match kind:
		Kind.SHADOW:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.08, 0.04, 0.16, 0.5)
			sb.set_corner_radius_all(8)
			sb.shadow_color = Color(0.08, 0.04, 0.16, 0.35)
			sb.shadow_size = 10
			sb.shadow_offset = Vector2(0, 5)
			draw_style_box(sb, Rect2(panel.position + Vector2(2, 4), panel.size - Vector2(4, 4)))
		Kind.SHEEN:
			var r := Rect2(panel.position + Vector2(5, 5), panel.size - Vector2(10, 10))
			if r.size.x <= 0.0 or r.size.y <= 0.0:
				return
			var top := Color(1, 1, 1, 0.28)
			var mid := Color(1, 1, 1, 0.0)
			var band: float = minf(r.size.y * 0.45, 60.0)
			draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y + band), Vector2(r.position.x, r.position.y + band)]), PackedColorArray([top, top, mid, mid]))
