extends Node3D
class_name SplatterManager

const MAX_DECALS := 220

var _albedo_texs: Array[Texture2D] = []
var _normal_texs: Array[Texture2D] = []
var _decals: Array[Node3D] = []
var _decal_idx: int = 0
var _use_quad_splatters: bool = false
var _layer_counter: int = 0

var _quad_mesh: QuadMesh
var _burst_mesh: SphereMesh
var _ring_mesh: TorusMesh


func _ready() -> void:
	# WebGL 2 (gl_compatibility) does not support Decal nodes — use crisp glossy surface-aligned quads!
	_use_quad_splatters = OS.has_feature("web") or RenderingServer.get_current_rendering_method() == "gl_compatibility"

	for i in range(4):
		var a_path := "res://assets/textures/splat_%d.png" % i
		var n_path := "res://assets/textures/splat_normal_%d.png" % i
		if ResourceLoader.exists(a_path):
			_albedo_texs.append(load(a_path))
		if ResourceLoader.exists(n_path):
			_normal_texs.append(load(n_path))

	_quad_mesh = QuadMesh.new()
	_quad_mesh.size = Vector2(1.0, 1.0)

	_burst_mesh = SphereMesh.new()
	_burst_mesh.radius = 0.085
	_burst_mesh.height = 0.17
	_burst_mesh.radial_segments = 8
	_burst_mesh.rings = 5

	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.18
	_ring_mesh.outer_radius = 0.28
	_ring_mesh.rings = 16
	_ring_mesh.ring_segments = 8


func spawn_splatter(pos: Vector3, normal: Vector3, team_color: Color, scale_mult: float = 1.0) -> void:
	if _albedo_texs.is_empty():
		return

	var n := normal.normalized()
	if n.length_squared() < 0.01:
		n = Vector3.UP

	if _use_quad_splatters:
		_spawn_quad_splatter(pos, n, team_color, scale_mult)
	else:
		_spawn_decal_splatter(pos, n, team_color, scale_mult)


func _spawn_decal_splatter(pos: Vector3, n: Vector3, team_color: Color, scale_mult: float) -> void:
	var decal: Decal
	if _decals.size() < MAX_DECALS:
		decal = Decal.new()
		decal.cull_mask = 1 | 2
		decal.upper_fade = 0.2
		decal.lower_fade = 0.25
		decal.distance_fade_enabled = true
		decal.distance_fade_begin = 60.0
		decal.distance_fade_length = 15.0
		add_child(decal)
		_decals.append(decal)
	else:
		decal = _decals[_decal_idx] as Decal
		_decal_idx = (_decal_idx + 1) % MAX_DECALS

	var tex_i := randi() % _albedo_texs.size()
	decal.texture_albedo = _albedo_texs[tex_i]
	if tex_i < _normal_texs.size():
		decal.texture_normal = _normal_texs[tex_i]
	decal.modulate = team_color
	decal.albedo_mix = 0.94
	var sz := randf_range(0.95, 1.55) * scale_mult
	decal.size = Vector3(sz, 0.75, sz)

	var up_ref := Vector3.FORWARD if abs(n.y) > 0.92 else Vector3.UP
	var x_axis := up_ref.cross(n).normalized()
	var z_axis := x_axis.cross(n).normalized()
	var basis := Basis(x_axis, n, z_axis).rotated(n, randf_range(0.0, TAU))
	decal.global_transform = Transform3D(basis, pos + n * 0.03)


func _spawn_quad_splatter(pos: Vector3, n: Vector3, team_color: Color, scale_mult: float) -> void:
	var quad: MeshInstance3D
	var mat: StandardMaterial3D
	if _decals.size() < MAX_DECALS:
		quad = MeshInstance3D.new()
		quad.mesh = _quad_mesh
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.16
		mat.metallic = 0.05
		mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		quad.material_override = mat
		add_child(quad)
		_decals.append(quad)
	else:
		quad = _decals[_decal_idx] as MeshInstance3D
		mat = quad.material_override as StandardMaterial3D
		_decal_idx = (_decal_idx + 1) % MAX_DECALS

	var tex_i := randi() % _albedo_texs.size()
	mat.albedo_texture = _albedo_texs[tex_i]
	if tex_i < _normal_texs.size():
		mat.normal_enabled = true
		mat.normal_texture = _normal_texs[tex_i]
		mat.normal_scale = 0.85
	mat.albedo_color = Color(team_color.r, team_color.g, team_color.b, 0.94)

	var is_ground := n.y > 0.72
	# On curved bunkers/sandbags in WebGL 2, drop the splatter cleanly onto the turf at the base so edges never float!
	var final_pos := pos
	var final_n := n
	if not is_ground:
		final_pos = Vector3(pos.x + n.x * 0.35, 0.02, pos.z + n.z * 0.35)
		final_n = Vector3.UP
		is_ground = true

	var sz := randf_range(1.0, 1.62) * scale_mult

	# Subtle incremental offset prevents z-fighting between overlapping paint splatters
	_layer_counter = (_layer_counter + 1) % 60
	var offset_dist := 0.024 + float(_layer_counter) * 0.0005

	# QuadMesh faces +Z by default, so align local +Z with surface normal `final_n`
	var up_ref := Vector3.FORWARD if abs(final_n.y) > 0.92 else Vector3.UP
	var x_axis := up_ref.cross(final_n).normalized()
	var y_axis := final_n.cross(x_axis).normalized()
	var basis := Basis(x_axis, y_axis, final_n).rotated(final_n, randf_range(0.0, TAU)).scaled(Vector3(sz, sz, 1.0))
	quad.global_transform = Transform3D(basis, final_pos + final_n * offset_dist)


func spawn_paint_burst(pos: Vector3, normal: Vector3, team_color: Color, count: int = 12, spread_scale: float = 1.0) -> void:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.94
	particles.amount = count
	particles.lifetime = randf_range(0.32, 0.52)
	particles.mesh = _burst_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = team_color
	mat.roughness = 0.12
	mat.emission_enabled = true
	mat.emission = team_color
	mat.emission_energy_multiplier = 0.85
	particles.material_override = mat

	var n := normal.normalized()
	if n.length_squared() < 0.01:
		n = Vector3.UP
	particles.direction = (n + Vector3(0, 0.45, 0)).normalized()
	particles.spread = 72.0
	particles.initial_velocity_min = 3.2 * spread_scale
	particles.initial_velocity_max = 7.8 * spread_scale
	particles.gravity = Vector3(0, -15.5, 0)
	particles.scale_amount_min = 0.45 * spread_scale
	particles.scale_amount_max = 1.25 * spread_scale

	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.65, 0.85))
	curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = curve

	add_child(particles)
	particles.global_position = pos + n * 0.08
	particles.emitting = true

	# Brief juicy splash flash ring
	var ring := MeshInstance3D.new()
	ring.mesh = _ring_mesh
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color(team_color.r, team_color.g, team_color.b, 0.9)
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.emission_enabled = true
	rmat.emission = team_color
	rmat.emission_energy_multiplier = 1.6
	ring.material_override = rmat
	add_child(ring)

	var up_ref := Vector3.FORWARD if abs(n.y) > 0.92 else Vector3.UP
	var x_axis := up_ref.cross(n).normalized()
	var z_axis := x_axis.cross(n).normalized()
	ring.global_transform = Transform3D(Basis(x_axis, n, z_axis), pos + n * 0.06)
	ring.scale = Vector3.ONE * 0.25 * spread_scale

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * 1.9 * spread_scale, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(rmat, "albedo_color:a", 0.0, 0.22)
	tw.chain().tween_callback(ring.queue_free)

	get_tree().create_timer(particles.lifetime + 0.15).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)


func spawn_capture_celebration(pos: Vector3, team_color: Color) -> void:
	for i in range(3):
		var delay := i * 0.12
		get_tree().create_timer(delay).timeout.connect(func():
			if not is_inside_tree():
				return
			spawn_paint_burst(pos + Vector3(randf_range(-0.8, 0.8), 1.4, randf_range(-0.8, 0.8)), Vector3.UP, team_color, 26, 1.85)
			spawn_paint_burst(pos + Vector3(randf_range(-0.6, 0.6), 1.6, randf_range(-0.6, 0.6)), Vector3.UP, Color(1.0, 0.86, 0.22), 16, 1.55)
		)
	for k in range(6):
		var a := k * TAU / 6.0 + randf_range(-0.2, 0.2)
		var p := pos + Vector3(cos(a) * randf_range(2.4, 3.8), 0.05, sin(a) * randf_range(2.4, 3.8))
		spawn_splatter(p, Vector3.UP, team_color, 1.45)
