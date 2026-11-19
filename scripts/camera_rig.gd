extends Node3D
class_name CameraRig

enum Mode { ORBIT_DEMO, FOLLOW_PLAYER, OVERVIEW }

var mode: int = Mode.ORBIT_DEMO
var target_node: Node3D = null
var player_input: PlayerInput = null

var camera: Camera3D
var _orbit_angle: float = 0.35
var _trauma: float = 0.0
var _smooth_focus: Vector3 = Vector3.ZERO

const FOLLOW_OFFSET := Vector3(0.0, 19.5, 15.2)
const FOLLOW_FOV := 44.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = FOLLOW_FOV
	camera.near = 0.5
	camera.far = 220.0
	camera.current = true
	add_child(camera)


func add_shake(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


func set_mode(new_mode: int) -> void:
	mode = new_mode
	if mode == Mode.FOLLOW_PLAYER and is_instance_valid(target_node):
		_smooth_focus = target_node.global_position


func _process(delta: float) -> void:
	_trauma = maxf(0.0, _trauma - delta * 2.2)
	var shake := _trauma * _trauma
	var shake_off := Vector3(
		randf_range(-1.0, 1.0) * 0.65 * shake,
		randf_range(-1.0, 1.0) * 0.45 * shake,
		randf_range(-1.0, 1.0) * 0.65 * shake
	)

	if mode == Mode.ORBIT_DEMO:
		_orbit_angle += delta * 0.14
		var cam_pos := Vector3(sin(_orbit_angle) * 32.0, 21.5 + sin(_orbit_angle * 1.7) * 2.5, cos(_orbit_angle) * 26.0)
		camera.global_position = cam_pos + shake_off
		camera.look_at(Vector3(0.0, 1.2, 0.0), Vector3.UP)
	elif mode == Mode.OVERVIEW:
		camera.global_position = Vector3(0.0, 34.0, 27.0) + shake_off
		camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	elif mode == Mode.FOLLOW_PLAYER:
		var goal_focus := _smooth_focus
		if is_instance_valid(target_node):
			goal_focus = target_node.global_position
			if is_instance_valid(player_input):
				goal_focus += player_input.get_aim_offset_for_camera()
		# Keep camera framed gracefully near the field
		goal_focus.x = clampf(goal_focus.x, -21.5, 21.5)
		goal_focus.z = clampf(goal_focus.z, -11.5, 11.5)
		_smooth_focus = _smooth_focus.lerp(goal_focus, clampf(7.5 * delta, 0.0, 1.0))

		# Slight dynamic zoom-out when carrying flag for better escape vision!
		var extra_zoom := 1.08 if (is_instance_valid(target_node) and target_node.get("carrying_flag") != null) else 1.0
		var desired_pos := _smooth_focus + FOLLOW_OFFSET * extra_zoom
		camera.global_position = camera.global_position.lerp(desired_pos, clampf(8.5 * delta, 0.0, 1.0)) + shake_off
		camera.look_at(_smooth_focus + Vector3(0.0, 0.8, 0.0), Vector3.UP)
