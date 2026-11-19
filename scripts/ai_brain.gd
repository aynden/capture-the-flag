extends Node
class_name AIBrain

enum Role { ATTACKER, INTERCEPTOR, DEFENDER }

var character: CharacterController = null
var game_manager: Node = null
var role: int = Role.ATTACKER
var enabled: bool = true

var _lane_z: float = 0.0
var _strafe_sign: float = 1.0
var _strafe_timer: float = 0.0
var _decision_timer: float = 0.0
var _stuck_timer: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _unstick_dir: Vector3 = Vector3.ZERO
var _unstick_timer: float = 0.0
var _current_target_pos: Vector3 = Vector3.ZERO


func setup(p_char: CharacterController, p_gm: Node, p_role: int) -> void:
	character = p_char
	game_manager = p_gm
	role = p_role
	_lane_z = [-11.5, 0.0, 11.5][randi() % 3]
	_strafe_sign = -1.0 if randf() < 0.5 else 1.0
	_strafe_timer = randf_range(0.6, 1.8)
	_decision_timer = randf_range(0.05, 0.3)
	_last_pos = character.global_position


func _physics_process(delta: float) -> void:
	if not enabled or not is_instance_valid(character) or not character.is_alive or not is_instance_valid(game_manager):
		return

	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(0.65, 1.75)
		_strafe_sign = -_strafe_sign

	_decision_timer -= delta
	if _decision_timer <= 0.0:
		_decision_timer = 0.22
		_choose_objective()

	# Anti-stuck detector
	if _unstick_timer > 0.0:
		_unstick_timer -= delta
	else:
		if character.global_position.distance_to(_last_pos) < 0.22:
			_stuck_timer += delta
			if _stuck_timer > 0.45:
				_stuck_timer = 0.0
				_unstick_timer = 0.55
				_lane_z = [-12.0, -5.0, 5.0, 12.0][randi() % 4]
				_unstick_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		else:
			_stuck_timer = maxf(0.0, _stuck_timer - delta * 2.0)
			_last_pos = character.global_position

	# Find best visible combat target
	var combat_target := _find_combat_target()
	var desired_dir := _compute_steering_dir(_current_target_pos)

	if _unstick_timer > 0.0:
		desired_dir = _unstick_dir

	# Tactical strafing during active gunfight (unless sprinting home with flag!)
	if combat_target != null and character.carrying_flag == null:
		var to_enemy := combat_target.global_position - character.global_position
		to_enemy.y = 0.0
		var dist := to_enemy.length()
		var right := Vector3(-to_enemy.z, 0.0, to_enemy.x).normalized() * _strafe_sign
		if dist < 8.5:
			desired_dir = (desired_dir * 0.45 + right * 0.85 - to_enemy.normalized() * 0.35).normalized()
		elif dist < 17.0:
			desired_dir = (desired_dir * 0.70 + right * 0.55).normalized()

	character.move_input = desired_dir

	# Aiming & Shooting with slight velocity lead!
	if combat_target != null:
		var dist := character.global_position.distance_to(combat_target.global_position)
		var flight_t := dist / CharacterController.PAINTBALL_SPEED
		var lead_pos := combat_target.global_position + combat_target.velocity * (flight_t * 0.65)
		character.aim_point = Vector3(lead_pos.x, 1.15, lead_pos.z)
		character.wants_fire = dist < 21.5 and _has_clear_shot(combat_target)
		# Dash evasively if hurt or carrying flag under fire!
		if character.dash_cooldown_timer <= 0.0 and ((character.hp < 50.0 and randf() < 0.04) or (character.carrying_flag != null and dist < 12.0 and randf() < 0.06)):
			character.wants_dash = true
	else:
		# Aim down movement path
		var look_ahead := character.global_position + desired_dir * 8.0
		character.aim_point = Vector3(look_ahead.x, 1.15, look_ahead.z)
		character.wants_fire = false
		# Dash to cross midfield quickly when running flag or attacking
		if character.dash_cooldown_timer <= 0.0 and abs(character.global_position.x) < 10.0 and randf() < 0.025:
			character.wants_dash = true


func _choose_objective() -> void:
	var my_team := character.team
	var own_flag: FlagController = game_manager.get_flag(my_team)
	var enemy_flag: FlagController = game_manager.get_flag(1 - my_team)
	var own_base: Vector3 = game_manager.get_base_pos(my_team)
	var enemy_base: Vector3 = game_manager.get_base_pos(1 - my_team)

	# 1. If I am carrying the enemy flag -> RUN HOME!
	if character.carrying_flag != null:
		if own_flag.state == FlagController.State.AT_BASE:
			_current_target_pos = _route_with_lane(own_base)
		else:
			# Own flag is away: hold near friendly defensive cover until teammates return it!
			_current_target_pos = own_base + Vector3(6.5 if my_team == 0 else -6.5, 0.0, _lane_z * 0.5)
		return

	# Check player's tactical command ping bias for Blue team
	var team_order: int = game_manager.get_team_order(my_team) # 0=auto, 1=attack, 2=defend

	# 2. Urgent: Friendly flag is DROPPED -> nearest bots rush to return it!
	if own_flag.state == FlagController.State.DROPPED:
		if role != Role.ATTACKER or character.global_position.distance_to(own_flag.global_position) < 16.0:
			_current_target_pos = own_flag.global_position
			return

	# 3. Urgent: Friendly flag is CARRIED by enemy -> INTERCEPTOR & DEFENDER hunt carrier!
	if own_flag.state == FlagController.State.CARRIED and is_instance_valid(own_flag.carrier):
		if role == Role.INTERCEPTOR or role == Role.DEFENDER or team_order == 2:
			_current_target_pos = own_flag.carrier.global_position
			return

	# 4. Enemy flag is DROPPED -> grab it!
	if enemy_flag.state == FlagController.State.DROPPED:
		if role != Role.DEFENDER or team_order == 1:
			_current_target_pos = enemy_flag.global_position
			return

	# 5. Friendly teammate is carrying enemy flag -> ESCORT them!
	if enemy_flag.state == FlagController.State.CARRIED and is_instance_valid(enemy_flag.carrier):
		if role == Role.INTERCEPTOR:
			_current_target_pos = enemy_flag.carrier.global_position + Vector3(3.0 if my_team == 0 else -3.0, 0, _strafe_sign * 3.0)
			return

	# 6. Standard Role Behavior (or Player Ping override)
	var effective_role := role
	if team_order == 1:
		effective_role = Role.ATTACKER
	elif team_order == 2 and role != Role.ATTACKER:
		effective_role = Role.DEFENDER

	if effective_role == Role.ATTACKER or effective_role == Role.INTERCEPTOR:
		_current_target_pos = _route_with_lane(enemy_base)
	else:
		# Defender patrols defensive semicircle in front of own base
		var patrol_x := own_base.x + (9.0 if my_team == 0 else -9.0)
		var patrol_z := sin(Time.get_ticks_msec() * 0.0008 + float(character.get_instance_id() % 10)) * 8.5
		_current_target_pos = Vector3(patrol_x, 0.0, patrol_z)


func _route_with_lane(goal: Vector3) -> Vector3:
	# If far from goal along X, steer through a flanking/midfield lane waypoint first
	var dx := absf(character.global_position.x - goal.x)
	if dx > 16.0:
		var mid_x := lerpf(character.global_position.x, goal.x, 0.45)
		return Vector3(mid_x, 0.0, _lane_z)
	return goal


func _find_combat_target() -> CharacterController:
	var best: CharacterController = null
	var best_score := 9999.0
	var enemies: Array = game_manager.get_team_characters(1 - character.team)
	for e in enemies:
		if not is_instance_valid(e) or not e.is_alive:
			continue
		var d := character.global_position.distance_to(e.global_position)
		if d > 23.0:
			continue
		var has_los := _has_clear_shot(e)
		var score := d
		if not has_los:
			score += 14.0
		if e.carrying_flag != null:
			score -= 9.0 # High priority on enemy flag carrier!
		if score < best_score:
			best_score = score
			best = e
	return best


func _has_clear_shot(target: CharacterController) -> bool:
	var space := character.get_world_3d().direct_space_state
	var from_p := character.global_position + Vector3(0, 1.15, 0)
	var to_p := target.global_position + Vector3(0, 1.15, 0)
	var q := PhysicsRayQueryParameters3D.create(from_p, to_p)
	q.collision_mask = 1 | 2 # World & Bunkers only
	var hit := space.intersect_ray(q)
	return hit.is_empty()


func _compute_steering_dir(goal: Vector3) -> Vector3:
	var to_goal := goal - character.global_position
	to_goal.y = 0.0
	if to_goal.length_squared() < 0.25:
		return Vector3.ZERO
	var base_dir := to_goal.normalized()

	# Multi-whisker obstacle avoidance around bunkers & walls!
	var space := character.get_world_3d().direct_space_state
	var origin := character.global_position + Vector3(0, 0.8, 0)
	var avoid := Vector3.ZERO

	var angles := [0.0, 0.42, -0.42, 0.95, -0.95]
	var lengths := [3.1, 2.5, 2.5, 1.7, 1.7]
	for i in range(angles.size()):
		var dir := base_dir.rotated(Vector3.UP, angles[i])
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * lengths[i])
		q.collision_mask = 1 | 2
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var d := origin.distance_to(hit.position)
			var weight := clampf((lengths[i] - d) / lengths[i], 0.0, 1.0)
			# Steer tangentially away from obstacle normal + slight side bias
			var push := Vector3(hit.normal.x, 0.0, hit.normal.z).normalized()
			var tangent := Vector3(-push.z, 0.0, push.x) * _strafe_sign
			avoid += (push * 1.15 + tangent * 0.75) * weight

	# Subtle teammate separation so bots don't clump together!
	for mate in game_manager.get_team_characters(character.team):
		if mate == character or not is_instance_valid(mate) or not mate.is_alive:
			continue
		var mate_node := mate as Node3D
		var diff: Vector3 = character.global_position - mate_node.global_position
		diff.y = 0.0
		var dist: float = diff.length()
		if dist > 0.01 and dist < 2.2:
			avoid += diff.normalized() * ((2.2 - dist) / 2.2) * 1.1

	var final_dir := base_dir + avoid * 1.35
	final_dir.y = 0.0
	return final_dir.normalized() if final_dir.length_squared() > 0.001 else base_dir
