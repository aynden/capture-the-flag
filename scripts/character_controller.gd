extends CharacterBody3D
class_name CharacterController

signal hit_landed(attacker: CharacterController, victim: CharacterController, eliminated: bool)
signal player_damaged(victim: CharacterController, amount: float)

const MOVE_SPEED := 9.2
const CARRY_SPEED_MULT := 0.93
const DASH_SPEED := 21.5
const DASH_DURATION := 0.22
const DASH_COOLDOWN := 1.65
const MAX_HP := 100.0
const HOPPER_MAX := 24
const FIRE_INTERVAL := 0.145
const AI_FIRE_INTERVAL := 0.32
const RELOAD_TIME := 1.15
const PAINTBALL_SPEED := 38.0
const AI_PAINTBALL_SPEED := 32.0
const PLAYER_DAMAGE := 20.0
const AI_DAMAGE := 9.0
const PLAYER_RESPAWN_TIME := 4.5
const AI_RESPAWN_TIME := 7.5
const REGEN_DELAY := 3.5
const REGEN_RATE := 14.0

var team: int = 0 # 0 = Blue (Cobalt), 1 = Red (Ember)
var is_player: bool = false
var display_name: String = "Runner"
var spawn_pos: Vector3 = Vector3.ZERO

var hp: float = MAX_HP
var is_alive: bool = true
var respawn_timer: float = 0.0
var shield_timer: float = 0.0
var _time_since_hit: float = 99.0

var ammo: int = HOPPER_MAX
var is_reloading: bool = false
var reload_timer: float = 0.0
var fire_cooldown: float = 0.0

var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_dir: Vector3 = Vector3.ZERO

var carrying_flag: FlagController = null
var paint_color: Color = Color(0.08, 0.64, 1.0)
var accent_color: Color = Color(0.04, 0.88, 1.0)

# Inputs driven by PlayerInput or AIBrain
var move_input: Vector3 = Vector3.ZERO
var aim_point: Vector3 = Vector3.ZERO
var wants_fire: bool = false
var wants_dash: bool = false
var wants_reload: bool = false

# References injected by GameManager
var game_manager: Node = null
var splatter_manager: SplatterManager = null
var audio_manager: AudioManager = null
var projectile_container: Node3D = null

# Articulated Blender hierarchy nodes
var _model_root: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _upper_body: Node3D
var _head: Node3D
var _marker_pivot: Node3D
var _muzzle_point: Node3D
var flag_anchor: Node3D

# Rest transforms cached after model loads
var _upper_rest_pos: Vector3
var _marker_rest_pos: Vector3
var _marker_rest_rot: Vector3

# Animation & VFX state
var _lower_yaw: float = 0.0
var _aim_yaw: float = 0.0
var _walk_phase: float = 0.0
var _recoil: float = 0.0
var _hit_flash_timer: float = 0.0
var _muzzle_flash_timer: float = 0.0

var _muzzle_light: OmniLight3D
var _muzzle_mesh: MeshInstance3D
var _foot_ring: MeshInstance3D
var _shield_dome: MeshInstance3D
var _hp_bar_root: Node3D
var _hp_bar_fill: MeshInstance3D
var _hp_bar_mat: StandardMaterial3D
var _dash_particles: CPUParticles3D
var _meshes: Array[MeshInstance3D] = []
var _flash_overlay_mat: ShaderMaterial


func initialize(p_team: int, p_is_player: bool, p_name: String, p_spawn: Vector3, p_gm: Node, p_splat: SplatterManager, p_audio: AudioManager, p_proj_container: Node3D) -> void:
	team = p_team
	is_player = p_is_player
	display_name = p_name
	spawn_pos = p_spawn
	game_manager = p_gm
	splatter_manager = p_splat
	audio_manager = p_audio
	projectile_container = p_proj_container

	paint_color = Color(0.08, 0.62, 1.0) if team == 0 else Color(1.0, 0.30, 0.12)
	accent_color = Color(0.02, 0.90, 1.0) if team == 0 else Color(1.0, 0.70, 0.14)

	# Physics layers: Blue = layer 3 (bit 4), Red = layer 4 (bit 8)
	collision_layer = 4 if team == 0 else 8
	collision_mask = 1 | 2 | 4 | 8

	# Capsule collider
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.48
	cap.height = 1.85
	col.shape = cap
	col.position.y = 0.925
	add_child(col)

	# Load Blender articulated model
	var model_path := "res://assets/models/player_blue.glb" if team == 0 else "res://assets/models/player_red.glb"
	var scene: PackedScene = load(model_path)
	_model_root = scene.instantiate()
	add_child(_model_root)

	# Find articulated rig pivots
	_leg_l = _find_node(_model_root, "LegL")
	_leg_r = _find_node(_model_root, "LegR")
	_upper_body = _find_node(_model_root, "UpperBody")
	_head = _find_node(_model_root, "Head")
	_marker_pivot = _find_node(_model_root, "MarkerPivot")
	_muzzle_point = _find_node(_model_root, "MuzzlePoint")
	flag_anchor = _find_node(_model_root, "FlagAnchor")

	if _upper_body:
		_upper_rest_pos = _upper_body.position
	if _marker_pivot:
		_marker_rest_pos = _marker_pivot.position
		_marker_rest_rot = _marker_pivot.rotation

	_collect_meshes(_model_root)
	# Exclude characters from receiving floor/wall Decal splatters so they stay clean
	for m in _meshes:
		m.layers = 4 # Render layer 3 (cameras see all layers, Decals only project on layers 1|2)

	_flash_overlay_mat = ShaderMaterial.new()
	_flash_overlay_mat.shader = load("res://shaders/character_rim.gdshader")
	_flash_overlay_mat.set_shader_parameter("aura_color", Color(1.0, 0.92, 0.55))
	_flash_overlay_mat.set_shader_parameter("intensity", 1.75)

	_setup_vfx_nodes()

	global_position = spawn_pos
	_lower_yaw = -PI * 0.5 if team == 0 else PI * 0.5
	_aim_yaw = _lower_yaw
	aim_point = spawn_pos + Vector3(10.0 if team == 0 else -10.0, 1.1, 0.0)


func _find_node(root: Node, target: String) -> Node3D:
	if root.name == target and root is Node3D:
		return root
	for child in root.get_children():
		var found := _find_node(child, target)
		if found:
			return found
	return null


func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		_meshes.append(node)
	for child in node.get_children():
		_collect_meshes(child)


func _setup_vfx_nodes() -> void:
	# 1. Crisp diegetic ground ring under feet
	_foot_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.56 if is_player else 0.46
	torus.outer_radius = 0.68 if is_player else 0.54
	torus.rings = 24
	torus.ring_segments = 6
	_foot_ring.mesh = torus
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if is_player:
		rmat.albedo_color = Color(0.15, 0.95, 1.0, 0.92)
		rmat.emission_enabled = true
		rmat.emission = Color(0.15, 0.95, 1.0)
		rmat.emission_energy_multiplier = 1.6
	else:
		rmat.albedo_color = Color(paint_color.r, paint_color.g, paint_color.b, 0.58)
	_foot_ring.material_override = rmat
	_foot_ring.position.y = 0.05
	_foot_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_foot_ring)

	# Soft grounding contact shadow under boots (keeps characters grounded in WebGL 2 where SSAO is off!)
	var contact_shadow := MeshInstance3D.new()
	var cs_plane := PlaneMesh.new()
	cs_plane.size = Vector2(1.45, 1.45)
	contact_shadow.mesh = cs_plane
	var cs_mat := StandardMaterial3D.new()
	cs_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cs_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cs_mat.albedo_texture = load("res://assets/textures/glow_soft.png")
	cs_mat.albedo_color = Color(0.03, 0.05, 0.04, 0.44)
	cs_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	contact_shadow.material_override = cs_mat
	contact_shadow.position.y = -0.025
	contact_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_foot_ring.add_child(contact_shadow)

	# 2. Muzzle flash sphere + dynamic OmniLight at barrel tip
	var muzzle_parent: Node3D = _muzzle_point if _muzzle_point else self
	_muzzle_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	_muzzle_mesh.mesh = sm
	var mmat := StandardMaterial3D.new()
	mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mmat.albedo_color = accent_color.lightened(0.4)
	mmat.emission_enabled = true
	mmat.emission = accent_color
	mmat.emission_energy_multiplier = 4.0
	_muzzle_mesh.material_override = mmat
	_muzzle_mesh.visible = false
	_muzzle_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle_parent.add_child(_muzzle_mesh)

	_muzzle_light = OmniLight3D.new()
	_muzzle_light.light_color = accent_color
	_muzzle_light.light_energy = 2.8
	_muzzle_light.omni_range = 4.5
	_muzzle_light.visible = false
	muzzle_parent.add_child(_muzzle_light)

	# 3. Spawn shield shimmer dome
	_shield_dome = MeshInstance3D.new()
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 1.08
	dome_mesh.height = 2.16
	_shield_dome.mesh = dome_mesh
	var smat := ShaderMaterial.new()
	smat.shader = load("res://shaders/character_rim.gdshader")
	smat.set_shader_parameter("aura_color", accent_color)
	smat.set_shader_parameter("intensity", 0.42)
	_shield_dome.material_override = smat
	_shield_dome.position.y = 1.0
	_shield_dome.visible = false
	_shield_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shield_dome)

	# 4. Minimal overhead floating HP bar (hidden at full HP)
	_hp_bar_root = Node3D.new()
	_hp_bar_root.position.y = 2.38
	_hp_bar_root.visible = false
	add_child(_hp_bar_root)

	var bg := MeshInstance3D.new()
	var bg_m := QuadMesh.new()
	bg_m.size = Vector2(1.18, 0.16)
	bg.mesh = bg_m
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.albedo_color = Color(0.06, 0.08, 0.12, 0.85)
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.no_depth_test = true
	bg.material_override = bg_mat
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hp_bar_root.add_child(bg)

	_hp_bar_fill = MeshInstance3D.new()
	var fm := QuadMesh.new()
	fm.size = Vector2(1.08, 0.10)
	_hp_bar_fill.mesh = fm
	_hp_bar_mat = StandardMaterial3D.new()
	_hp_bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hp_bar_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bar_mat.albedo_color = Color(0.18, 0.82, 1.0) if team == 0 else Color(1.0, 0.34, 0.18)
	_hp_bar_mat.no_depth_test = true
	_hp_bar_fill.material_override = _hp_bar_mat
	_hp_bar_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hp_bar_root.add_child(_hp_bar_fill)

	# 5. Dash turf-dust & energy puff trail
	_dash_particles = CPUParticles3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.14
	dm.height = 0.28
	_dash_particles.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.92, 0.90, 0.80, 0.7)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.roughness = 0.9
	_dash_particles.material_override = dmat
	_dash_particles.amount = 16
	_dash_particles.lifetime = 0.32
	_dash_particles.direction = Vector3(0, 0.8, 0)
	_dash_particles.spread = 45.0
	_dash_particles.initial_velocity_min = 1.0
	_dash_particles.initial_velocity_max = 2.8
	_dash_particles.gravity = Vector3(0, -3.5, 0)
	_dash_particles.position.y = 0.22
	_dash_particles.emitting = false
	add_child(_dash_particles)


func set_is_player(flag: bool) -> void:
	is_player = flag
	if _foot_ring:
		var torus: TorusMesh = _foot_ring.mesh
		torus.inner_radius = 0.56 if is_player else 0.46
		torus.outer_radius = 0.68 if is_player else 0.54
		var rmat: StandardMaterial3D = _foot_ring.material_override
		if is_player:
			rmat.albedo_color = Color(0.15, 0.95, 1.0, 0.92)
			rmat.emission_enabled = true
			rmat.emission = Color(0.15, 0.95, 1.0)
			rmat.emission_energy_multiplier = 1.6
		else:
			rmat.albedo_color = Color(paint_color.r, paint_color.g, paint_color.b, 0.58)
			rmat.emission_enabled = false


func _physics_process(delta: float) -> void:
	if not is_alive:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			respawn()
		return

	# Timers & out-of-combat armor regen
	_time_since_hit += delta
	if _time_since_hit >= REGEN_DELAY and hp < MAX_HP:
		hp = minf(MAX_HP, hp + REGEN_RATE * delta)
		_update_hp_bar()

	if shield_timer > 0.0:
		shield_timer -= delta
		if _shield_dome:
			_shield_dome.visible = shield_timer > 0.0
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	if _muzzle_flash_timer > 0.0:
		_muzzle_flash_timer -= delta
		if _muzzle_flash_timer <= 0.0:
			_muzzle_mesh.visible = false
			_muzzle_light.visible = false
	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0.0:
			for m in _meshes:
				m.material_overlay = null

	# Reload handling
	if wants_reload and not is_reloading and ammo < HOPPER_MAX:
		_start_reload()
	wants_reload = false

	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			is_reloading = false
			ammo = HOPPER_MAX

	# Dash initiation
	if wants_dash and dash_cooldown_timer <= 0.0 and dash_timer <= 0.0:
		var dir := move_input
		if dir.length_squared() < 0.01:
			dir = Vector3(-sin(_aim_yaw), 0.0, -cos(_aim_yaw))
		dash_dir = dir.normalized()
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN
		_dash_particles.emitting = true
		if audio_manager and is_player:
			audio_manager.play_sfx("dash", -5.0, 0.08)
	wants_dash = false

	# Horizontal Velocity
	var speed_mult := CARRY_SPEED_MULT if carrying_flag != null else 1.0
	if dash_timer > 0.0:
		dash_timer -= delta
		velocity.x = dash_dir.x * DASH_SPEED
		velocity.z = dash_dir.z * DASH_SPEED
		if dash_timer <= 0.0:
			_dash_particles.emitting = false
	else:
		var desired := move_input.normalized() * (MOVE_SPEED * speed_mult)
		var accel := 18.0 if desired.length_squared() > 0.01 else 15.0
		velocity.x = lerpf(velocity.x, desired.x, clampf(accel * delta, 0.0, 1.0))
		velocity.z = lerpf(velocity.z, desired.z, clampf(accel * delta, 0.0, 1.0))

	velocity.y = 0.0
	move_and_slide()
	# Keep grounded on turf plane
	global_position.y = 0.0

	# Clamp safely within arena boundaries
	global_position.x = clampf(global_position.x, -28.2, 28.2)
	global_position.z = clampf(global_position.z, -17.2, 17.2)

	# Firing Paintballs!
	if wants_fire and fire_cooldown <= 0.0 and not is_reloading:
		if ammo > 0:
			_fire_paintball()
		else:
			_start_reload()

	_update_procedural_animation(delta)


func _start_reload() -> void:
	is_reloading = true
	reload_timer = RELOAD_TIME
	if audio_manager and is_player:
		audio_manager.play_sfx("reload", -6.0, 0.05)


func _fire_paintball() -> void:
	ammo -= 1
	fire_cooldown = FIRE_INTERVAL if is_player else AI_FIRE_INTERVAL
	_recoil = 1.0
	_muzzle_flash_timer = 0.045
	_muzzle_mesh.visible = true
	_muzzle_light.visible = true

	var spawn_origin := _muzzle_point.global_position if _muzzle_point else (global_position + Vector3(0, 1.25, 0))
	var target := aim_point
	target.y = spawn_origin.y
	var dir := (target - spawn_origin)
	if dir.length_squared() < 0.04:
		dir = Vector3(-sin(_aim_yaw), 0.0, -cos(_aim_yaw))
	dir = dir.normalized()

	# Crisp player accuracy vs forgiving dodgeable AI spread
	var spread := 0.022 if is_player else 0.088
	dir = dir.rotated(Vector3.UP, randf_range(-spread, spread))
	dir.y += randf_range(-0.008, 0.016)
	dir = dir.normalized()

	if projectile_container:
		var proj := PaintballProjectile.new()
		projectile_container.add_child(proj)
		var spd := PAINTBALL_SPEED if is_player else AI_PAINTBALL_SPEED
		var dmg := PLAYER_DAMAGE if is_player else AI_DAMAGE
		proj.setup(team, self, spawn_origin, dir, spd, paint_color, splatter_manager, audio_manager, dmg)

	if audio_manager:
		var vol := -7.5 if is_player else -17.5
		audio_manager.play_sfx("shoot", vol, 0.10)

	if is_player and game_manager and game_manager.has_method("add_camera_shake"):
		game_manager.add_camera_shake(0.055)

	if ammo <= 0:
		_start_reload()


func _update_procedural_animation(delta: float) -> void:
	var horiz_vel := Vector3(velocity.x, 0.0, velocity.z)
	var spd := horiz_vel.length()

	# Aim yaw from character to aim_point
	var to_aim := aim_point - global_position
	to_aim.y = 0.0
	if to_aim.length_squared() > 0.04:
		var target_aim_yaw := atan2(-to_aim.x, -to_aim.z)
		_aim_yaw = lerp_angle(_aim_yaw, target_aim_yaw, clampf(18.0 * delta, 0.0, 1.0))

	# Lower body faces movement velocity when moving, or aligns smoothly with aim when idle
	if spd > 0.6:
		var move_yaw := atan2(-horiz_vel.x, -horiz_vel.z)
		# Keep lower body within ±65° of aim so legs don't twist backward awkwardly when backpedaling!
		var diff := wrapf(move_yaw - _aim_yaw, -PI, PI)
		if abs(diff) > PI * 0.6:
			move_yaw = wrapf(move_yaw + PI, -PI, PI)
		_lower_yaw = lerp_angle(_lower_yaw, move_yaw, clampf(12.0 * delta, 0.0, 1.0))
	else:
		_lower_yaw = lerp_angle(_lower_yaw, _aim_yaw, clampf(9.0 * delta, 0.0, 1.0))

	_model_root.rotation.y = _lower_yaw

	# Independent upper body twist toward aim direction!
	if _upper_body:
		var twist := clampf(wrapf(_aim_yaw - _lower_yaw, -PI, PI), -1.15, 1.15)
		_upper_body.rotation.y = twist

		# Athletic sprint forward lean + dramatic dash crouch-lean
		var lean_pitch := -0.14 * clampf(spd / MOVE_SPEED, 0.0, 1.0)
		if dash_timer > 0.0:
			lean_pitch = -0.38
		_upper_body.rotation.x = lerpf(_upper_body.rotation.x, lean_pitch, clampf(14.0 * delta, 0.0, 1.0))

		# Snappy run stride & torso bob
		if spd > 0.45:
			_walk_phase += delta * (spd * 1.45)
		else:
			_walk_phase = lerpf(_walk_phase, 0.0, clampf(8.0 * delta, 0.0, 1.0))

		var stride := sin(_walk_phase) * clampf(spd / MOVE_SPEED, 0.0, 1.0) * 0.72
		if _leg_l:
			_leg_l.rotation.x = stride
		if _leg_r:
			_leg_r.rotation.x = -stride

		var bob: float = absf(sin(_walk_phase)) * 0.075 * clampf(spd / MOVE_SPEED, 0.0, 1.0)
		_upper_body.position.y = _upper_rest_pos.y + bob

	# Elastic paintball marker recoil kickback!
	_recoil = lerpf(_recoil, 0.0, clampf(18.0 * delta, 0.0, 1.0))
	if _marker_pivot:
		_marker_pivot.position = _marker_rest_pos + Vector3(0.0, _recoil * 0.025, _recoil * 0.09)
		_marker_pivot.rotation = _marker_rest_rot + Vector3(_recoil * 0.14, 0.0, 0.0)


func apply_paint_hit(amount: float, attacker: Node3D, hit_dir: Vector3, hit_color: Color) -> void:
	if not is_alive or shield_timer > 0.0:
		return

	hp -= amount
	_time_since_hit = 0.0
	_hit_flash_timer = 0.09
	for m in _meshes:
		m.material_overlay = _flash_overlay_mat

	# Knockback impulse
	velocity += Vector3(hit_dir.x, 0.0, hit_dir.z) * 3.8

	var eliminated := hp <= 0.0
	if attacker is CharacterController:
		hit_landed.emit(attacker, self, eliminated)

	if is_player:
		player_damaged.emit(self, amount)

	_update_hp_bar()

	if eliminated:
		_tag_out(hit_color)


func _update_hp_bar() -> void:
	if not _hp_bar_root or not _hp_bar_fill:
		return
	var ratio := clampf(hp / MAX_HP, 0.0, 1.0)
	_hp_bar_root.visible = is_alive and ratio < 0.995
	_hp_bar_fill.scale.x = maxf(0.01, ratio)
	_hp_bar_fill.position.x = -(1.0 - ratio) * 0.54


func _tag_out(hit_color: Color) -> void:
	is_alive = false
	hp = 0.0
	respawn_timer = PLAYER_RESPAWN_TIME if is_player else AI_RESPAWN_TIME
	wants_fire = false
	_dash_particles.emitting = false
	_muzzle_mesh.visible = false
	_muzzle_light.visible = false

	# Big celebratory paint explosion when tagged out!
	if splatter_manager:
		splatter_manager.spawn_paint_burst(global_position + Vector3(0, 1.0, 0), Vector3.UP, hit_color, 26, 1.65)
		splatter_manager.spawn_splatter(Vector3(global_position.x, 0.05, global_position.z), Vector3.UP, hit_color, 1.65)

	if audio_manager:
		var vol := -4.0 if is_player else -11.0
		audio_manager.play_sfx("eliminated", vol, 0.08)

	if is_player and game_manager and game_manager.has_method("add_camera_shake"):
		game_manager.add_camera_shake(0.35)

	# Drop carried flag!
	if carrying_flag != null:
		var f := carrying_flag
		carrying_flag = null
		f.drop_at(global_position)
		if game_manager and game_manager.has_method("on_flag_dropped"):
			game_manager.on_flag_dropped(f, self)

	# Hide visual & disable collisions during respawn countdown
	_model_root.visible = false
	_foot_ring.visible = false
	_hp_bar_root.visible = false
	_shield_dome.visible = false
	collision_layer = 0


func respawn() -> void:
	is_alive = true
	hp = MAX_HP
	_time_since_hit = 99.0
	ammo = HOPPER_MAX
	is_reloading = false
	reload_timer = 0.0
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	shield_timer = 1.65
	global_position = spawn_pos + Vector3(randf_range(-1.2, 1.2), 0.0, randf_range(-1.8, 1.8))
	velocity = Vector3.ZERO
	_model_root.visible = true
	_foot_ring.visible = true
	_shield_dome.visible = true
	_hp_bar_root.visible = false
	collision_layer = 4 if team == 0 else 8
	for m in _meshes:
		m.material_overlay = null
