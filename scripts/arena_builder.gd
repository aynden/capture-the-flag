extends Node3D
class_name ArenaBuilder

const FIELD_HALF_X := 29.0
const FIELD_HALF_Z := 18.0
const BLUE_BASE_POS := Vector3(-23.0, 0.0, 0.0)
const RED_BASE_POS := Vector3(23.0, 0.0, 0.0)

var blue_ring_mat: ShaderMaterial
var red_ring_mat: ShaderMaterial
var minimap_obstacles: Array[Dictionary] = []

var _model_cache: Dictionary = {}


func init_from_existing_scene() -> void:
	"""Rebinds references and minimap data from an already-baked Arena scene."""
	minimap_obstacles.clear()
	var bases := get_node_or_null("Bases")
	if bases:
		var b_ring := bases.get_node_or_null("BlueCaptureRing") as MeshInstance3D
		if b_ring and b_ring.material_override is ShaderMaterial:
			blue_ring_mat = b_ring.material_override
		var r_ring := bases.get_node_or_null("RedCaptureRing") as MeshInstance3D
		if r_ring and r_ring.material_override is ShaderMaterial:
			red_ring_mat = r_ring.material_override

	var cover := get_node_or_null("TacticalCover")
	if cover:
		for child in cover.get_children():
			if child is Node3D and child.has_meta("minimap_size"):
				minimap_obstacles.append({
					"pos": Vector2(child.position.x, child.position.z),
					"size": child.get_meta("minimap_size"),
					"rot": child.rotation.y,
					"color": child.get_meta("minimap_color", Color(0.85, 0.72, 0.25)),
				})

	# Remove editor-only preview flags/characters once live GameManager takes over
	var preview := get_node_or_null("EditorPreview")
	if preview:
		preview.queue_free()

	# Calibrate lighting & fog specifically for WebGL 2 (gl_compatibility) so colors & contrast match Metal Forward+!
	if OS.has_feature("web") or RenderingServer.get_current_rendering_method() == "gl_compatibility":
		_tune_for_web_compatibility()


func _tune_for_web_compatibility() -> void:
	var env_grp := get_node_or_null("Environment")
	if not env_grp:
		return
	var we := env_grp.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		var env: Environment = we.environment.duplicate()
		env.tonemap_exposure = 0.88
		env.adjustment_contrast = 1.08
		env.adjustment_saturation = 1.16
		env.glow_intensity = 0.28
		env.glow_bloom = 0.08
		env.fog_enabled = false
		we.environment = env
	var sun := env_grp.get_node_or_null("GoldenHourSun") as DirectionalLight3D
	if sun:
		sun.light_energy = 1.65


func build_arena(include_editor_preview: bool = false) -> void:
	_setup_lighting_and_sky()
	_build_turf_ground()
	_build_bases()
	_build_tactical_cover()
	_build_perimeter_walls_and_stadium()
	_build_outer_park_foliage()
	_build_ambient_dust_motes()
	if include_editor_preview:
		_build_editor_preview()


func _load_model(model_name: String) -> Node3D:
	if not _model_cache.has(model_name):
		_model_cache[model_name] = load("res://assets/models/%s.glb" % model_name)
	var scene: PackedScene = _model_cache[model_name]
	return scene.instantiate() if scene else Node3D.new()


func _get_or_create_group(group_name: String) -> Node3D:
	var g := get_node_or_null(group_name) as Node3D
	if g == null:
		g = Node3D.new()
		g.name = group_name
		add_child(g)
	return g


func _setup_lighting_and_sky() -> void:
	var env_grp := _get_or_create_group("Environment")

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.20, 0.46, 0.82)
	sky_mat.sky_horizon_color = Color(0.96, 0.72, 0.48)
	sky_mat.sky_curve = 0.14
	sky_mat.ground_bottom_color = Color(0.18, 0.28, 0.16)
	sky_mat.ground_horizon_color = Color(0.76, 0.62, 0.46)
	sky_mat.sun_angle_max = 28.0
	sky_mat.sun_curve = 0.08
	sky.sky_material = sky_mat
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.65
	env.ambient_light_energy = 0.72

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.06
	env.tonemap_white = 6.0

	env.ssao_enabled = true
	env.ssao_radius = 1.15
	env.ssao_intensity = 1.45
	env.ssao_power = 1.6

	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_strength = 0.85
	env.glow_bloom = 0.14
	env.glow_hdr_threshold = 1.08

	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.12

	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.96, 0.84, 0.68)
	env.fog_density = 0.0022
	env.fog_depth_begin = 42.0
	env.fog_depth_end = 130.0

	world_env.environment = env
	env_grp.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "GoldenHourSun"
	sun.light_color = Color(1.0, 0.90, 0.73)
	sun.light_energy = 2.05
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_max_distance = 110.0
	sun.directional_shadow_blend_splits = true
	sun.rotation_degrees = Vector3(-42.0, -34.0, 0.0)
	env_grp.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "SkyFillLight"
	fill.light_color = Color(0.56, 0.76, 1.0)
	fill.light_energy = 0.36
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-55.0, 145.0, 0.0)
	env_grp.add_child(fill)


func _build_turf_ground() -> void:
	var ground_body := StaticBody3D.new()
	ground_body.name = "TurfGround"
	ground_body.collision_layer = 1
	ground_body.collision_mask = 0
	add_child(ground_body)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "TurfMesh"
	var plane := PlaneMesh.new()
	plane.size = Vector2(340.0, 280.0)
	mesh_inst.mesh = plane
	mesh_inst.layers = 1

	var smat := ShaderMaterial.new()
	smat.shader = load("res://shaders/turf_arena.gdshader")
	smat.set_shader_parameter("detail_normal", load("res://assets/textures/turf_detail_normal.png"))
	smat.set_shader_parameter("noise_tex", load("res://assets/textures/turf_noise.png"))
	smat.set_shader_parameter("field_half_size", Vector2(FIELD_HALF_X, FIELD_HALF_Z))
	smat.set_shader_parameter("base_x", absf(BLUE_BASE_POS.x))
	mesh_inst.material_override = smat
	ground_body.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	col.name = "TurfCollision"
	var box := BoxShape3D.new()
	box.size = Vector3(160.0, 1.0, 130.0)
	col.shape = box
	col.position.y = -0.5
	ground_body.add_child(col)


func _build_bases() -> void:
	var bases_grp := _get_or_create_group("Bases")
	for team_idx in range(2):
		var prefix := "Blue" if team_idx == 0 else "Red"
		var pos := BLUE_BASE_POS if team_idx == 0 else RED_BASE_POS
		var model_name := "flag_pedestal_blue" if team_idx == 0 else "flag_pedestal_red"
		var ped := _load_model(model_name)
		ped.name = prefix + "BasePedestal"
		ped.position = pos
		bases_grp.add_child(ped)

		var ring := MeshInstance3D.new()
		ring.name = prefix + "CaptureRing"
		var plane := PlaneMesh.new()
		plane.size = Vector2(7.6, 7.6)
		ring.mesh = plane
		var rmat := ShaderMaterial.new()
		rmat.shader = load("res://shaders/base_ring.gdshader")
		var col := Color(0.08, 0.65, 1.0) if team_idx == 0 else Color(1.0, 0.30, 0.12)
		rmat.set_shader_parameter("ring_color", col)
		rmat.set_shader_parameter("urgency", 0.0)
		ring.material_override = rmat
		ring.position = pos + Vector3(0.0, 0.04, 0.0)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bases_grp.add_child(ring)

		if team_idx == 0:
			blue_ring_mat = rmat
		else:
			red_ring_mat = rmat

		var light := OmniLight3D.new()
		light.name = prefix + "BaseLight"
		light.light_color = col.lightened(0.2)
		light.light_energy = 1.65
		light.omni_range = 7.5
		light.position = pos + Vector3(0.0, 1.8, 0.0)
		bases_grp.add_child(light)


func _place_cover(cover_grp: Node3D, node_name: String, model_name: String, pos: Vector3, rot_deg: float, col_size: Vector3, col_type: String = "box", col_offset_y: float = 0.0, minimap_col: Color = Color(0.85, 0.72, 0.25)) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 2
	body.collision_mask = 0
	body.position = pos
	body.rotation_degrees.y = rot_deg
	var m_size := Vector2(col_size.x * 2.0 if col_type == "cylinder" else col_size.x, col_size.x * 2.0 if col_type == "cylinder" else col_size.z)
	body.set_meta("minimap_size", m_size)
	body.set_meta("minimap_color", minimap_col)
	cover_grp.add_child(body)

	var visual := _load_model(model_name)
	visual.name = "Visual"
	_set_layer_recursive(visual, 2)
	body.add_child(visual)

	var col := CollisionShape3D.new()
	col.name = "Collider"
	if col_type == "cylinder":
		var cyl := CylinderShape3D.new()
		cyl.radius = col_size.x
		cyl.height = col_size.y
		col.shape = cyl
		col.position.y = col_size.y * 0.5 + col_offset_y
	else:
		var box := BoxShape3D.new()
		box.size = col_size
		col.shape = box
		col.position.y = col_size.y * 0.5 + col_offset_y
	body.add_child(col)

	minimap_obstacles.append({
		"pos": Vector2(pos.x, pos.z),
		"size": m_size,
		"rot": deg_to_rad(rot_deg),
		"color": minimap_col,
	})


func _set_layer_recursive(node: Node, mask: int) -> void:
	if node is VisualInstance3D:
		node.layers = mask
	for child in node.get_children():
		_set_layer_recursive(child, mask)


func _build_tactical_cover() -> void:
	var cover_grp := _get_or_create_group("TacticalCover")
	var c_gold := Color(0.95, 0.72, 0.18)
	var c_blue := Color(0.18, 0.55, 0.96)
	var c_red := Color(0.95, 0.30, 0.18)
	var c_wood := Color(0.68, 0.46, 0.28)

	_place_cover(cover_grp, "CenterTempleGold", "bunker_temple_gold", Vector3(0.0, 0.0, 0.0), 90.0, Vector3(2.8, 2.05, 1.55), "box", 0.0, c_gold)
	_place_cover(cover_grp, "CenterDoritoNorth", "bunker_dorito_gold", Vector3(0.0, 0.0, -7.8), 180.0, Vector3(2.2, 2.0, 2.2), "box", 0.0, c_gold)
	_place_cover(cover_grp, "CenterDoritoSouth", "bunker_dorito_gold", Vector3(0.0, 0.0, 7.8), 0.0, Vector3(2.2, 2.0, 2.2), "box", 0.0, c_gold)
	_place_cover(cover_grp, "CenterSnakeNorth", "bunker_snake_gold", Vector3(0.0, 0.0, -14.2), 0.0, Vector3(3.6, 1.15, 1.15), "box", 0.0, c_gold)
	_place_cover(cover_grp, "CenterSnakeSouth", "bunker_snake_gold", Vector3(0.0, 0.0, 14.2), 0.0, Vector3(3.6, 1.15, 1.15), "box", 0.0, c_gold)

	for side: float in [-1.0, 1.0]:
		var style := "blue" if side < 0 else "red"
		var pfx := "Blue" if side < 0 else "Red"
		var mcol := c_blue if side < 0 else c_red
		var face_in := 90.0 if side < 0 else -90.0

		_place_cover(cover_grp, pfx + "CylinderNorth", "bunker_cylinder_" + style, Vector3(side * 6.8, 0.0, -4.4), 0.0, Vector3(0.88, 2.3, 0.88), "cylinder", 0.0, mcol)
		_place_cover(cover_grp, pfx + "CylinderSouth", "bunker_cylinder_" + style, Vector3(side * 6.8, 0.0, 4.4), 0.0, Vector3(0.88, 2.3, 0.88), "cylinder", 0.0, mcol)
		_place_cover(cover_grp, pfx + "BarricadeNorth", "barricade_wood", Vector3(side * 10.5, 0.0, -11.5), face_in - side * 24.0, Vector3(3.2, 1.6, 0.65), "box", 0.0, c_wood)
		_place_cover(cover_grp, pfx + "BarricadeSouth", "barricade_wood", Vector3(side * 10.5, 0.0, 11.5), face_in + side * 24.0, Vector3(3.2, 1.6, 0.65), "box", 0.0, c_wood)
		_place_cover(cover_grp, pfx + "CrateStack", "crate_stack", Vector3(side * 12.8, 0.0, 0.0), 15.0 * side, Vector3(2.45, 1.9, 1.35), "box", 0.0, c_wood)
		_place_cover(cover_grp, pfx + "DoritoNorth", "bunker_dorito_" + style, Vector3(side * 16.8, 0.0, -7.2), 30.0 * side, Vector3(2.2, 2.0, 2.2), "box", 0.0, mcol)
		_place_cover(cover_grp, pfx + "DoritoSouth", "bunker_dorito_" + style, Vector3(side * 16.8, 0.0, 7.2), -30.0 * side, Vector3(2.2, 2.0, 2.2), "box", 0.0, mcol)
		_place_cover(cover_grp, pfx + "SandbagWall", "sandbag_wall", Vector3(side * 18.2, 0.0, 0.0), -90.0 if side < 0 else 90.0, Vector3(2.8, 1.05, 1.0), "box", 0.0, c_wood)
		_place_cover(cover_grp, pfx + "SnakeNorth", "bunker_snake_" + style, Vector3(side * 20.5, 0.0, -13.2), 18.0 * side, Vector3(3.6, 1.15, 1.15), "box", 0.0, mcol)
		_place_cover(cover_grp, pfx + "SnakeSouth", "bunker_snake_" + style, Vector3(side * 20.5, 0.0, 13.2), -18.0 * side, Vector3(3.6, 1.15, 1.15), "box", 0.0, mcol)


func _build_perimeter_walls_and_stadium() -> void:
	var stadium_grp := _get_or_create_group("StadiumPerimeter")

	var wall_body := StaticBody3D.new()
	wall_body.name = "PerimeterWalls"
	wall_body.collision_layer = 1
	wall_body.collision_mask = 0
	stadium_grp.add_child(wall_body)

	for z_sign: float in [-1.0, 1.0]:
		var z_pos: float = z_sign * (FIELD_HALF_Z + 0.65)
		var rot_y: float = 180.0 if z_sign < 0 else 0.0
		for ix in range(-4, 5):
			var seg := _load_model("arena_wall_segment")
			seg.position = Vector3(ix * 6.4, 0.0, z_pos)
			seg.scale.x = 1.07
			seg.rotation_degrees.y = rot_y
			_set_layer_recursive(seg, 1)
			wall_body.add_child(seg)

		var c := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(60.0, 3.6, 1.0)
		c.shape = b
		c.position = Vector3(0.0, 1.8, z_pos)
		wall_body.add_child(c)

	for x_sign: float in [-1.0, 1.0]:
		var x_pos: float = x_sign * (FIELD_HALF_X + 0.65)
		var rot_y: float = -90.0 if x_sign < 0 else 90.0
		for iz in range(-2, 3):
			var seg := _load_model("arena_wall_segment")
			seg.position = Vector3(x_pos, 0.0, iz * 6.4)
			seg.scale.x = 1.22
			seg.rotation_degrees.y = rot_y
			_set_layer_recursive(seg, 1)
			wall_body.add_child(seg)

		var c := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(1.0, 3.6, 38.0)
		c.shape = b
		c.position = Vector3(x_pos, 1.8, 0.0)
		wall_body.add_child(c)

	for cx_s: float in [-1.0, 1.0]:
		for cz_s: float in [-1.0, 1.0]:
			var pylon := _load_model("arena_corner_tower")
			pylon.position = Vector3(cx_s * (FIELD_HALF_X + 0.65), 0.0, cz_s * (FIELD_HALF_Z + 0.65))
			stadium_grp.add_child(pylon)

	var glow_tex: Texture2D = load("res://assets/textures/glow_soft.png")
	var corners := [
		Vector3(-31.2, 0.0, -20.2),
		Vector3(31.2, 0.0, -20.2),
		Vector3(-31.2, 0.0, 20.2),
		Vector3(31.2, 0.0, 20.2),
	]
	for cp: Vector3 in corners:
		var tower := _load_model("floodlight_tower")
		stadium_grp.add_child(tower)
		tower.position = cp
		tower.rotation.y = atan2(-cp.x, -cp.z)

		var halo := Sprite3D.new()
		halo.texture = glow_tex
		halo.modulate = Color(1.0, 0.90, 0.65, 0.55)
		halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		halo.pixel_size = 0.022
		halo.position = cp + Vector3(0.0, 9.8, 0.0)
		stadium_grp.add_child(halo)

	for bx: float in [-17.5, -5.8, 5.8, 17.5]:
		var bl := _load_model("spectator_bleacher")
		bl.position = Vector3(bx, 0.0, -(FIELD_HALF_Z + 4.4))
		bl.rotation_degrees.y = 180.0
		stadium_grp.add_child(bl)


func _build_outer_park_foliage() -> void:
	var foliage_grp := _get_or_create_group("ParkFoliage")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261119

	var tree_spots: Array[Vector3] = []
	for x in range(-58, 60, 5):
		tree_spots.append(Vector3(float(x) + rng.randf_range(-1.6, 1.6), 0.0, -28.0 + rng.randf_range(-3.0, 1.2)))
		if rng.randf() < 0.85:
			tree_spots.append(Vector3(float(x) + rng.randf_range(-2.0, 2.0), 0.0, -35.0 + rng.randf_range(-3.0, 2.0)))
		if rng.randf() < 0.72:
			tree_spots.append(Vector3(float(x) + rng.randf_range(-2.5, 2.5), 0.0, -43.5 + rng.randf_range(-3.5, 2.5)))

	for x_sign: float in [-1.0, 1.0]:
		for z in range(-32, 34, 5):
			tree_spots.append(Vector3(x_sign * (35.5 + rng.randf_range(0.0, 5.5)), 0.0, float(z) + rng.randf_range(-1.8, 1.8)))
			if rng.randf() < 0.78:
				tree_spots.append(Vector3(x_sign * (43.0 + rng.randf_range(0.0, 6.5)), 0.0, float(z) + rng.randf_range(-2.0, 2.0)))

	for x in range(-48, 50, 9):
		tree_spots.append(Vector3(float(x) + rng.randf_range(-2.0, 2.0), 0.0, 32.5 + rng.randf_range(1.0, 5.5)))

	for tp in tree_spots:
		var use_oak := rng.randf() < 0.36
		var tree := _load_model("stylized_oak" if use_oak else "stylized_pine")
		tree.position = tp
		var sc := rng.randf_range(0.88, 1.42)
		tree.scale = Vector3(sc, sc * rng.randf_range(0.92, 1.18), sc)
		tree.rotation_degrees.y = rng.randf_range(0.0, 360.0)
		foliage_grp.add_child(tree)

	for x in range(-32, 34, 5):
		for z_s: float in [-1.0, 1.0]:
			if z_s < 0 and abs(x) < 22:
				continue
			var bush := _load_model("stylized_bush")
			bush.position = Vector3(float(x) + rng.randf_range(-1.2, 1.2), 0.0, z_s * (FIELD_HALF_Z + 4.8 + rng.randf_range(0.0, 1.8)))
			var bsc := rng.randf_range(0.75, 1.25)
			bush.scale = Vector3.ONE * bsc
			bush.rotation_degrees.y = rng.randf_range(0.0, 360.0)
			foliage_grp.add_child(bush)


func _build_ambient_dust_motes() -> void:
	var env_grp := _get_or_create_group("Environment")
	var motes := CPUParticles3D.new()
	motes.name = "GoldenHourMotes"
	var q := QuadMesh.new()
	q.size = Vector2(0.28, 0.28)
	motes.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = load("res://assets/textures/glow_soft.png")
	mat.albedo_color = Color(1.0, 0.90, 0.62, 0.20)
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	motes.material_override = mat
	motes.amount = 45
	motes.lifetime = 8.0
	motes.preprocess = 4.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(26.0, 3.2, 16.0)
	motes.position = Vector3(0.0, 4.2, 0.0)
	motes.gravity = Vector3(0.14, 0.03, 0.06)
	motes.initial_velocity_min = 0.12
	motes.initial_velocity_max = 0.32
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	env_grp.add_child(motes)


func _build_editor_preview() -> void:
	"""Visual-only flags & sample players visible in Godot Editor (automatically cleared at runtime)."""
	var prev := _get_or_create_group("EditorPreview")

	var bf := _load_model("flag_blue")
	bf.name = "BlueFlagPreview"
	bf.position = BLUE_BASE_POS + Vector3(0.0, 0.56, 0.0)
	bf.rotation_degrees.y = 90.0
	prev.add_child(bf)

	var rf := _load_model("flag_red")
	rf.name = "RedFlagPreview"
	rf.position = RED_BASE_POS + Vector3(0.0, 0.56, 0.0)
	rf.rotation_degrees.y = -90.0
	prev.add_child(rf)

	var p_blue := _load_model("player_blue")
	p_blue.name = "CobaltPlayerPreview"
	p_blue.position = Vector3(-16.0, 0.0, 2.2)
	p_blue.rotation_degrees.y = -90.0
	prev.add_child(p_blue)

	var p_red := _load_model("player_red")
	p_red.name = "EmberPlayerPreview"
	p_red.position = Vector3(16.0, 0.0, -2.2)
	p_red.rotation_degrees.y = 90.0
	prev.add_child(p_red)
