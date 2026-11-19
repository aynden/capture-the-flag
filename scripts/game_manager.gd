extends Node3D
class_name GameManager

enum MatchState { TITLE_DEMO, PLAYING, PAUSED, MATCH_OVER }

const WIN_SCORE := 3
const MATCH_DURATION := 240.0
const FLAG_PICKUP_RADIUS := 2.35
const BASE_CAPTURE_RADIUS := 3.1

var match_state: int = MatchState.TITLE_DEMO
var scores := [0, 0] # [Blue, Red]
var time_left: float = MATCH_DURATION
var overtime: bool = false

# Player match stats
var player_captures: int = 0
var player_tags: int = 0
var player_returns: int = 0

var team_orders := [0, 0] # 0=auto, 1=attack, 2=defend
var _order_reset_timer: float = 0.0

var arena_builder: ArenaBuilder
var splatter_manager: SplatterManager
var audio_manager: AudioManager
var camera_rig: CameraRig
var player_input: PlayerInput
var hud: HUDController
var projectile_container: Node3D

var flags: Array[FlagController] = []
var teams: Array = [[], []] # teams[0] = Blue chars, teams[1] = Red chars
var ai_brains: Array[AIBrain] = []
var player_char: CharacterController = null
var player_ai_brain: AIBrain = null


func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS

	audio_manager = AudioManager.new()
	add_child(audio_manager)

	var existing_arena := get_node_or_null("Arena")
	if existing_arena is ArenaBuilder:
		arena_builder = existing_arena
		arena_builder.init_from_existing_scene()
	else:
		arena_builder = ArenaBuilder.new()
		arena_builder.name = "Arena"
		add_child(arena_builder)
		arena_builder.build_arena()

	splatter_manager = SplatterManager.new()
	add_child(splatter_manager)

	projectile_container = Node3D.new()
	projectile_container.name = "Projectiles"
	add_child(projectile_container)

	camera_rig = CameraRig.new()
	add_child(camera_rig)

	player_input = PlayerInput.new()
	player_input.camera = camera_rig.camera
	add_child(player_input)
	camera_rig.player_input = player_input

	_spawn_flags()
	_spawn_teams()

	hud = HUDController.new()
	add_child(hud)
	hud.build_ui(self, arena_builder)
	hud.start_match_pressed.connect(start_match)
	hud.resume_pressed.connect(func(): set_paused(false))
	hud.restart_pressed.connect(start_match)

	# Start in lively 4v4 AI skirmish Title Demo under cinematic orbiting camera!
	enter_title_demo()


func _spawn_flags() -> void:
	var blue_flag := FlagController.new()
	add_child(blue_flag)
	blue_flag.initialize(0, ArenaBuilder.BLUE_BASE_POS + Vector3(0.0, 0.56, 0.0))

	var red_flag := FlagController.new()
	add_child(red_flag)
	red_flag.initialize(1, ArenaBuilder.RED_BASE_POS + Vector3(0.0, 0.56, 0.0))

	flags = [blue_flag, red_flag]


func _spawn_teams() -> void:
	var blue_names := ["YOU", "NOVA", "BOLT", "AEGIS"]
	var red_names := ["BLAZE", "VIPER", "SCORCH", "TITAN"]
	var roles := [AIBrain.Role.ATTACKER, AIBrain.Role.ATTACKER, AIBrain.Role.INTERCEPTOR, AIBrain.Role.DEFENDER]

	var blue_spawns := [
		Vector3(-25.5, 0.0, 0.0),
		Vector3(-24.8, 0.0, -5.5),
		Vector3(-24.8, 0.0, 5.5),
		Vector3(-21.2, 0.0, -3.2),
	]
	var red_spawns := [
		Vector3(25.5, 0.0, 0.0),
		Vector3(24.8, 0.0, -5.5),
		Vector3(24.8, 0.0, 5.5),
		Vector3(21.2, 0.0, 3.2),
	]

	for team_i in range(2):
		var names := blue_names if team_i == 0 else red_names
		var spawns := blue_spawns if team_i == 0 else red_spawns
		for idx in range(4):
			var ch := CharacterController.new()
			add_child(ch)
			var is_p := (team_i == 0 and idx == 0)
			ch.initialize(team_i, is_p, names[idx], spawns[idx], self, splatter_manager, audio_manager, projectile_container)
			ch.hit_landed.connect(_on_hit_landed)
			ch.player_damaged.connect(_on_player_damaged)
			teams[team_i].append(ch)

			var brain := AIBrain.new()
			ch.add_child(brain)
			brain.setup(ch, self, roles[idx])
			ai_brains.append(brain)

			if is_p:
				player_char = ch
				player_ai_brain = brain
				player_input.character = ch
				camera_rig.target_node = ch


func enter_title_demo() -> void:
	match_state = MatchState.TITLE_DEMO
	get_tree().paused = false
	player_input.set_enabled(false)
	if player_char:
		player_char.set_is_player(false)
	if player_ai_brain:
		player_ai_brain.enabled = true
	camera_rig.set_mode(CameraRig.Mode.ORBIT_DEMO)
	hud.show_title()


func start_match() -> void:
	match_state = MatchState.PLAYING
	get_tree().paused = false
	scores = [0, 0]
	time_left = MATCH_DURATION
	overtime = false
	player_captures = 0
	player_tags = 0
	player_returns = 0
	team_orders = [0, 0]

	# Clear active paintballs
	for child in projectile_container.get_children():
		child.queue_free()

	# Reset flags & characters cleanly
	for f in flags:
		f.reset_to_base()
	for team_i in range(2):
		for ch in teams[team_i]:
			ch.carrying_flag = null
			ch.respawn()

	if player_char:
		player_char.set_is_player(true)
	if player_ai_brain:
		player_ai_brain.enabled = false
	player_input.set_enabled(true)

	camera_rig.set_mode(CameraRig.Mode.FOLLOW_PLAYER)
	hud.show_gameplay()
	hud.show_banner("MATCH START — CAPTURE THE EMBER FLAG!", Color(0.18, 0.85, 1.0), 2.8)
	audio_manager.play_sfx("flag_pickup", -6.0, 0.02)


func set_paused(paused: bool) -> void:
	if match_state != MatchState.PLAYING and match_state != MatchState.PAUSED:
		return
	match_state = MatchState.PAUSED if paused else MatchState.PLAYING
	get_tree().paused = paused
	hud.show_pause(paused)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if match_state == MatchState.PLAYING:
			set_paused(true)
		elif match_state == MatchState.PAUSED:
			set_paused(false)
	elif match_state == MatchState.PLAYING:
		if event.is_action_pressed("ping_attack"):
			team_orders[0] = 1
			_order_reset_timer = 14.0
			hud.push_feed("SQUAD ORDER: ALL ATTACK EMBER BASE!", Color(0.24, 0.90, 1.0))
			audio_manager.play_sfx("flag_return", -9.0, 0.05)
		elif event.is_action_pressed("ping_defend"):
			team_orders[0] = 2
			_order_reset_timer = 14.0
			hud.push_feed("SQUAD ORDER: DEFEND COBALT BASE!", Color(1.0, 0.82, 0.25))
			audio_manager.play_sfx("flag_return", -9.0, 0.05)


func _process(delta: float) -> void:
	if match_state == MatchState.PAUSED:
		return

	if _order_reset_timer > 0.0:
		_order_reset_timer -= delta
		if _order_reset_timer <= 0.0:
			team_orders[0] = 0

	if match_state == MatchState.PLAYING or match_state == MatchState.TITLE_DEMO:
		_check_flag_interactions()
		_update_base_ring_urgency()

	if match_state == MatchState.PLAYING:
		if not overtime:
			time_left -= delta
			if time_left <= 0.0:
				time_left = 0.0
				if scores[0] == scores[1]:
					overtime = true
					hud.show_banner("OVERTIME! NEXT CAPTURE WINS!", Color(1.0, 0.45, 0.16), 3.4)
					audio_manager.play_sfx("flag_pickup", -4.0, 0.0)
				else:
					_finish_match(0 if scores[0] > scores[1] else 1)

		hud.update_hud(delta, scores[0], scores[1], time_left, overtime, flags[0], flags[1], player_char, team_orders[0])


func _check_flag_interactions() -> void:
	for team_i in range(2):
		var own_flag: FlagController = flags[team_i]
		var enemy_flag: FlagController = flags[1 - team_i]
		var own_base: Vector3 = get_base_pos(team_i)

		for ch in teams[team_i]:
			if not is_instance_valid(ch) or not ch.is_alive:
				continue

			# 1. Touching ENEMY flag (at base or dropped) -> GRAB IT!
			if enemy_flag.state != FlagController.State.CARRIED and ch.carrying_flag == null:
				var d_ef := _flat_dist(ch.global_position, enemy_flag.global_position)
				if d_ef <= FLAG_PICKUP_RADIUS:
					enemy_flag.pickup_by(ch)
					ch.carrying_flag = enemy_flag
					if match_state == MatchState.PLAYING:
						var col := Color(0.22, 0.85, 1.0) if team_i == 0 else Color(1.0, 0.42, 0.20)
						var who: String = "YOU" if ch.is_player else str(ch.display_name)
						var f_name := "EMBER FLAG" if team_i == 0 else "COBALT FLAG"
						hud.push_feed("%s grabbed the %s!" % [who, f_name], col)
						if ch.is_player or team_i == 1:
							hud.show_banner("%s GRABBED THE %s!" % [who, f_name], col, 2.2)
						audio_manager.play_sfx("flag_pickup", -5.0 if ch.is_player else -10.0, 0.03)

			# 2. Touching DROPPED OWN flag -> INSTANT RETURN TO BASE!
			if own_flag.state == FlagController.State.DROPPED:
				var d_of := _flat_dist(ch.global_position, own_flag.global_position)
				if d_of <= FLAG_PICKUP_RADIUS:
					own_flag.reset_to_base()
					if ch.is_player:
						player_returns += 1
					if match_state == MatchState.PLAYING:
						var col := Color(0.24, 0.88, 1.0) if team_i == 0 else Color(1.0, 0.50, 0.22)
						var who: String = "YOU" if ch.is_player else str(ch.display_name)
						var f_name := "COBALT FLAG" if team_i == 0 else "EMBER FLAG"
						hud.push_feed("%s returned the %s!" % [who, f_name], col)
						hud.show_banner("%s RETURNED!" % f_name, col, 1.8)
						audio_manager.play_sfx("flag_return", -6.0, 0.04)

			# 3. Carrying ENEMY flag onto OWN BASE while OWN FLAG is AT_BASE -> CAPTURE SCORE!!
			if ch.carrying_flag == enemy_flag and own_flag.state == FlagController.State.AT_BASE:
				var d_base := _flat_dist(ch.global_position, own_base)
				if d_base <= BASE_CAPTURE_RADIUS:
					_score_capture(team_i, ch, enemy_flag)


func _score_capture(scoring_team: int, scorer: CharacterController, captured_flag: FlagController) -> void:
	scorer.carrying_flag = null
	captured_flag.reset_to_base()

	var team_col := Color(0.10, 0.72, 1.0) if scoring_team == 0 else Color(1.0, 0.34, 0.14)
	splatter_manager.spawn_capture_celebration(get_base_pos(scoring_team), team_col)

	if match_state != MatchState.PLAYING:
		return

	scores[scoring_team] += 1
	if scorer.is_player:
		player_captures += 1

	var t_name := "TEAM COBALT" if scoring_team == 0 else "TEAM EMBER"
	var who := "YOU" if scorer.is_player else scorer.display_name
	hud.show_banner("%s SCORES!  (%s)" % [t_name, who], team_col, 3.0)
	hud.push_feed("%s CAPTURED the flag! [%d - %d]" % [who, scores[0], scores[1]], team_col)
	audio_manager.play_sfx("flag_capture", -3.0, 0.0)
	add_camera_shake(0.32)

	if scores[scoring_team] >= WIN_SCORE or overtime:
		_finish_match(scoring_team)


func _finish_match(winner_team: int) -> void:
	match_state = MatchState.MATCH_OVER
	player_input.set_enabled(false)
	if player_char:
		player_char.set_is_player(false)
	if player_ai_brain:
		player_ai_brain.enabled = true
	camera_rig.set_mode(CameraRig.Mode.ORBIT_DEMO)
	hud.show_match_over(winner_team, scores[0], scores[1], player_captures, player_tags, player_returns)


func on_flag_dropped(flag: FlagController, dropper: CharacterController) -> void:
	if match_state != MatchState.PLAYING:
		return
	var f_name := "COBALT FLAG" if flag.team == 0 else "EMBER FLAG"
	var col := Color(0.24, 0.85, 1.0) if flag.team == 0 else Color(1.0, 0.55, 0.20)
	hud.push_feed("%s dropped the %s!" % [dropper.display_name, f_name], col)


func on_flag_auto_returned(flag: FlagController) -> void:
	if match_state != MatchState.PLAYING:
		return
	var f_name := "COBALT FLAG" if flag.team == 0 else "EMBER FLAG"
	hud.push_feed("%s auto-returned to base." % f_name, Color(0.85, 0.90, 0.96))


func _on_hit_landed(attacker: CharacterController, victim: CharacterController, eliminated: bool) -> void:
	if match_state != MatchState.PLAYING:
		return
	if attacker.is_player:
		hud.flash_hit_marker(eliminated)
		audio_manager.play_sfx("hit", -5.5 if eliminated else -8.5, 0.08)
		if eliminated:
			player_tags += 1
	if eliminated:
		var col := Color(0.32, 0.84, 1.0) if attacker.team == 0 else Color(1.0, 0.45, 0.25)
		hud.push_feed("%s tagged out %s!" % [attacker.display_name, victim.display_name], col)


func _on_player_damaged(_victim: CharacterController, _amount: float) -> void:
	if match_state == MatchState.PLAYING:
		hud.flash_damage()
		add_camera_shake(0.14)


func _update_base_ring_urgency() -> void:
	if arena_builder.blue_ring_mat:
		var blue_scoring := flags[1].state == FlagController.State.CARRIED and flags[0].state == FlagController.State.AT_BASE
		arena_builder.blue_ring_mat.set_shader_parameter("urgency", 1.0 if blue_scoring else 0.0)
	if arena_builder.red_ring_mat:
		var red_scoring := flags[0].state == FlagController.State.CARRIED and flags[1].state == FlagController.State.AT_BASE
		arena_builder.red_ring_mat.set_shader_parameter("urgency", 1.0 if red_scoring else 0.0)


func add_camera_shake(amount: float) -> void:
	if is_instance_valid(camera_rig):
		camera_rig.add_shake(amount)


func get_flag(team_i: int) -> FlagController:
	return flags[team_i]


func get_base_pos(team_i: int) -> Vector3:
	return ArenaBuilder.BLUE_BASE_POS if team_i == 0 else ArenaBuilder.RED_BASE_POS


func get_team_characters(team_i: int) -> Array:
	return teams[team_i]


func get_team_order(team_i: int) -> int:
	return team_orders[team_i]


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
