extends Node3D
class_name FlagController

enum State { AT_BASE, CARRIED, DROPPED }

var team: int = 0 # 0 = Blue Flag (lives at Blue Base), 1 = Red Flag (lives at Red Base)
var state: int = State.AT_BASE
var home_position: Vector3 = Vector3.ZERO
var carrier: Node3D = null
var drop_timer: float = 0.0
const DROP_AUTO_RETURN := 15.0

var _cloth_mat: ShaderMaterial
var _beacon_mesh: MeshInstance3D
var _drop_ring: MeshInstance3D
var _trail_particles: CPUParticles3D
var _flag_visual: Node3D
var _team_color: Color = Color(0.1, 0.55, 1.0)


func initialize(p_team: int, p_home: Vector3) -> void:
	team = p_team
	home_position = p_home
	_team_color = Color(0.08, 0.56, 1.0) if team == 0 else Color(1.0, 0.28, 0.12)

	var model_path := "res://assets/models/flag_blue.glb" if team == 0 else "res://assets/models/flag_red.glb"
	var scene: PackedScene = load(model_path)
	if scene:
		_flag_visual = scene.instantiate()
		add_child(_flag_visual)
		_apply_cloth_shader(_flag_visual)

	# Vertical holographic beacon beam (only shown when DROPPED so players spot it instantly!)
	_beacon_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.42
	cyl.height = 11.0
	cyl.radial_segments = 16
	_beacon_mesh.mesh = cyl
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bmat.albedo_color = Color(_team_color.r, _team_color.g, _team_color.b, 0.34)
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beacon_mesh.material_override = bmat
	_beacon_mesh.position.y = 5.5
	_beacon_mesh.visible = false
	_beacon_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beacon_mesh)

	# Ground pulse ring when dropped
	_drop_ring = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.6, 3.6)
	_drop_ring.mesh = plane
	var rmat := ShaderMaterial.new()
	rmat.shader = load("res://shaders/base_ring.gdshader")
	rmat.set_shader_parameter("ring_color", _team_color)
	rmat.set_shader_parameter("urgency", 0.85)
	_drop_ring.material_override = rmat
	_drop_ring.position.y = 0.08
	_drop_ring.visible = false
	add_child(_drop_ring)

	# Glowing ribbon sparkles when carried!
	_trail_particles = CPUParticles3D.new()
	var pm := SphereMesh.new()
	pm.radius = 0.11
	pm.height = 0.22
	_trail_particles.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = _team_color.lightened(0.3)
	pmat.emission_enabled = true
	pmat.emission = _team_color
	pmat.emission_energy_multiplier = 2.0
	_trail_particles.material_override = pmat
	_trail_particles.amount = 20
	_trail_particles.lifetime = 0.55
	_trail_particles.direction = Vector3(0, 0.6, 0)
	_trail_particles.spread = 35.0
	_trail_particles.initial_velocity_min = 0.5
	_trail_particles.initial_velocity_max = 1.6
	_trail_particles.gravity = Vector3(0, -1.0, 0)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.0))
	_trail_particles.scale_amount_curve = curve
	_trail_particles.position.y = 2.4
	_trail_particles.emitting = false
	add_child(_trail_particles)

	reset_to_base()


func _apply_cloth_shader(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.name.contains("FlagCloth"):
			_cloth_mat = ShaderMaterial.new()
			_cloth_mat.shader = load("res://shaders/flag_cloth.gdshader")
			var tex_path := "res://assets/textures/flag_blue.png" if team == 0 else "res://assets/textures/flag_red.png"
			_cloth_mat.set_shader_parameter("flag_albedo", load(tex_path))
			_cloth_mat.set_shader_parameter("backlight_tint", Color(0.55, 0.80, 1.0) if team == 0 else Color(1.0, 0.68, 0.45))
			child.material_override = _cloth_mat
		_apply_cloth_shader(child)


func reset_to_base() -> void:
	state = State.AT_BASE
	carrier = null
	drop_timer = 0.0
	global_position = home_position
	rotation = Vector3(0, PI * 0.5 if team == 0 else -PI * 0.5, 0)
	scale = Vector3.ONE
	if _beacon_mesh:
		_beacon_mesh.visible = false
	if _drop_ring:
		_drop_ring.visible = false
	if _trail_particles:
		_trail_particles.emitting = false
	if _cloth_mat:
		_cloth_mat.set_shader_parameter("runner_speed", 0.0)


func pickup_by(character: Node3D) -> void:
	state = State.CARRIED
	carrier = character
	drop_timer = 0.0
	scale = Vector3.ONE * 0.88
	if _beacon_mesh:
		_beacon_mesh.visible = false
	if _drop_ring:
		_drop_ring.visible = false
	if _trail_particles:
		_trail_particles.emitting = true


func drop_at(world_pos: Vector3) -> void:
	state = State.DROPPED
	carrier = null
	drop_timer = DROP_AUTO_RETURN
	global_position = Vector3(world_pos.x, 0.05, world_pos.z)
	rotation = Vector3(0.08, randf_range(0, TAU), 0.06)
	scale = Vector3.ONE
	if _beacon_mesh:
		_beacon_mesh.visible = true
	if _drop_ring:
		_drop_ring.visible = true
	if _trail_particles:
		_trail_particles.emitting = false
	if _cloth_mat:
		_cloth_mat.set_shader_parameter("runner_speed", 0.4)


func _process(delta: float) -> void:
	if state == State.CARRIED:
		if is_instance_valid(carrier) and carrier.get("is_alive"):
			var anchor: Node3D = carrier.get("flag_anchor")
			if is_instance_valid(anchor):
				global_position = anchor.global_position - Vector3(0, 0.35, 0)
				# Align flag trailing behind runner's facing direction with heroic backward tilt!
				var fwd: Vector3 = -anchor.global_transform.basis.z
				fwd.y = 0.0
				if fwd.length_squared() > 0.001:
					var yaw := atan2(-fwd.x, -fwd.z)
					rotation = Vector3(-0.28, yaw, 0.0)
			else:
				global_position = carrier.global_position + Vector3(0, 1.0, 0)

			var spd: float = carrier.velocity.length() if carrier is CharacterBody3D else 5.0
			if _cloth_mat:
				_cloth_mat.set_shader_parameter("runner_speed", spd)
		else:
			drop_at(global_position)
	elif state == State.DROPPED:
		drop_timer -= delta
		if _beacon_mesh:
			var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.008)
			_beacon_mesh.scale = Vector3(pulse, 1.0, pulse)
		if drop_timer <= 0.0:
			reset_to_base()
			if get_parent().has_method("on_flag_auto_returned"):
				get_parent().on_flag_auto_returned(self)
	else:
		# Gentle heroic idle sway on base pedestal
		if _cloth_mat:
			_cloth_mat.set_shader_parameter("runner_speed", 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.0015))
