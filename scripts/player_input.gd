extends Node3D
class_name PlayerInput

var character: CharacterController = null
var camera: Camera3D = null
var enabled: bool = false

var _reticle_mesh: MeshInstance3D
var _aim_line_mesh: MeshInstance3D
var _aim_point_world: Vector3 = Vector3.ZERO


func _ready() -> void:
	# Sleek 3D Diegetic Ground Aim Reticle
	_reticle_mesh = MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.45, 1.45)
	_reticle_mesh.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = load("res://assets/textures/reticle.png")
	mat.albedo_color = Color(0.12, 0.94, 1.0, 0.92)
	mat.emission_enabled = true
	mat.emission = Color(0.12, 0.94, 1.0)
	mat.emission_energy_multiplier = 1.6
	mat.no_depth_test = true
	_reticle_mesh.material_override = mat
	_reticle_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_reticle_mesh.visible = false
	add_child(_reticle_mesh)


func set_enabled(val: bool) -> void:
	enabled = val
	if _reticle_mesh:
		_reticle_mesh.visible = val
	if not val and is_instance_valid(character):
		character.move_input = Vector3.ZERO
		character.wants_fire = false


func _process(delta: float) -> void:
	if not enabled or not is_instance_valid(character) or not is_instance_valid(camera):
		if _reticle_mesh:
			_reticle_mesh.visible = false
		return

	if not character.is_alive:
		_reticle_mesh.visible = false
		character.move_input = Vector3.ZERO
		character.wants_fire = false
		return

	# Movement input (WASD / Arrow keys aligned to screen XZ plane)
	var ix := Input.get_axis("move_left", "move_right")
	var iz := Input.get_axis("move_up", "move_down")
	character.move_input = Vector3(ix, 0.0, iz)

	# Aim raycast onto plane Y = 1.15m
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	if abs(ray_dir.y) > 0.001:
		var t := (1.15 - ray_origin.y) / ray_dir.y
		if t > 0.0:
			_aim_point_world = ray_origin + ray_dir * t
			character.aim_point = _aim_point_world

	_reticle_mesh.visible = true
	_reticle_mesh.global_position = Vector3(_aim_point_world.x, 0.12, _aim_point_world.z)
	_reticle_mesh.rotation.y += delta * 1.4
	var pulse := 1.0 + (0.18 if Input.is_action_pressed("fire") else 0.0)
	_reticle_mesh.scale = _reticle_mesh.scale.lerp(Vector3.ONE * pulse, clampf(16.0 * delta, 0.0, 1.0))

	character.wants_fire = Input.is_action_pressed("fire")
	if Input.is_action_just_pressed("dash"):
		character.wants_dash = true
	if Input.is_action_just_pressed("reload"):
		character.wants_reload = true


func get_aim_offset_for_camera() -> Vector3:
	if not enabled or not is_instance_valid(character) or not character.is_alive:
		return Vector3.ZERO
	var diff := _aim_point_world - character.global_position
	diff.y = 0.0
	var max_look := 3.2
	if diff.length() > 14.0:
		diff = diff.normalized() * 14.0
	return (diff / 14.0) * max_look
