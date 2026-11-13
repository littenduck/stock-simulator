## Dev tool: renders the six table characters as transparent 192x192 busts from the Kenney Mini Characters pack
## (CC0, https://kenney.nl/assets/mini-characters) into ui/theme/portraits/<character id>.png.
##   godot --path . --script res://tools/kenney_portraits.gd -- <glb folder> <output folder> [sheet.png]
## Each character is the pack model that looks most like the role, used as it is. The only changes: Saving Son gets the
## light skin tone of the other default characters, and Goldfish Gus is painted goldfish orange with red block fins.
extends SceneTree

const CELL := 192
const ORDER := ["saving_son", "double_dan", "goldfish_gus", "hodl_hana", "copilot_cody", "insider_inu"]
const MODELS := {
	"saving_son": "character-male-a",
	"double_dan": "character-male-e",
	"goldfish_gus": "character-male-b",
	"hodl_hana": "character-female-e",
	"copilot_cody": "character-robot",
	"insider_inu": "character-male-d",
}

var _dir := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	_run.call_deferred(a[0], a[1], a[2] if a.size() > 2 else "")


func _run(dir_path: String, out_dir: String, sheet_path: String) -> void:
	_dir = dir_path
	DirAccess.make_dir_recursive_absolute(out_dir)
	var sheet := Image.create(3 * CELL, 2 * CELL, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#d9d2bd"))
	for i in ORDER.size():
		var id: String = ORDER[i]
		var img := await _bust(id)
		if img == null:
			continue
		img.save_png("%s/%s.png" % [out_dir, id])
		sheet.blend_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i((i % 3) * CELL, (i / 3) * CELL))
		print("saved ", id)
	if sheet_path != "":
		sheet.save_png(sheet_path)
	quit()


func _load(name: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file("%s/%s.glb" % [_dir, name], state) != OK:
		print("cannot load ", name)
		return null
	return doc.generate_scene(state)


## Matte colour with a little self-light, so the added blocks sit next to the pack's palette-lit models.
func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.metallic_specular = 0.0
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.2
	return m


func _box(parent: Node3D, mat: Material, pos: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.material_override = mat
	mi.position = pos
	mi.scale = size
	parent.add_child(mi)


## Repaints cells of the shared 8x8 colour grid (64 px cells) of one mesh, for this model only.
func _repaint(model: Node3D, parts: Array, paint: Dictionary, copy: Dictionary = {}) -> void:
	for part: String in parts:
		var mi: MeshInstance3D = model.find_child(part, true, false)
		var mat := (mi.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		var img: Image = mat.albedo_texture.get_image()
		if img.is_compressed():
			img.decompress()
		for cell: Vector2i in copy:
			var src: Vector2i = copy[cell]
			img.fill_rect(Rect2i(cell.x * 64, cell.y * 64, 64, 64), img.get_pixel(src.x * 64 + 32, src.y * 64 + 32))
		for cell: Vector2i in paint:
			img.fill_rect(Rect2i(cell.x * 64, cell.y * 64, 64, 64), paint[cell])
		mat.albedo_texture = ImageTexture.create_from_image(img)
		mi.set_surface_override_material(0, mat)


## Saving Son: cells (1,4) and (1,5) are the dark skin tone and its shadow; copy the light tone of (2,4) and (2,5).
func _light_skin(model: Node3D) -> void:
	_repaint(model, ["head-mesh", "body-mesh"], {}, {Vector2i(1, 4): Vector2i(2, 4), Vector2i(1, 5): Vector2i(2, 5)})


## Goldfish Gus: his own head painted goldfish orange (the beard becomes a fat chin), with red block fins that touch the
## head. Only the head is painted, so his arms and body stay as they are.
func _goldfish(model: Node3D) -> void:
	_repaint(model, ["head-mesh"], {Vector2i(2, 4): Color("#ff9244"), Vector2i(2, 5): Color("#ff7c44"),
		Vector2i(0, 5): Color("#ffa75a"), Vector2i(1, 5): Color("#ff7c44")})
	var red := _flat(Color("#f36744"))
	var deep := _flat(Color("#cf534f"))
	_box(model, red, Vector3(0, 0.685, 0.0), Vector3(0.07, 0.07, 0.22))      # crest, three steps
	_box(model, red, Vector3(0, 0.745, -0.04), Vector3(0.07, 0.07, 0.15))
	_box(model, deep, Vector3(0, 0.8, -0.07), Vector3(0.07, 0.06, 0.09))
	for s in [-1.0, 1.0]:
		_box(model, red, Vector3(0.2 * s, 0.56, 0.0), Vector3(0.07, 0.17, 0.15))     # side fins at the ears
		_box(model, deep, Vector3(0.235 * s, 0.53, -0.02), Vector3(0.05, 0.1, 0.1))


func _bust(id: String) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL, CELL)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var model := _load(MODELS[id])
	if model == null:
		return null
	vp.add_child(model)
	if id == "saving_son":
		_light_skin(model)
	elif id == "goldfish_gus":
		_goldfish(model)
	var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if anim != null and anim.has_animation("idle"):
		anim.play("idle")
		anim.seek(0.4, true)
		anim.pause()
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.8
	vp.add_child(cam)
	cam.position = Vector3(0, 0.52, 3)
	cam.look_at(Vector3(0, 0.52, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 20, 0)
	vp.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.72, 0.72, 0.78)
	vp.add_child(env)
	for k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img
