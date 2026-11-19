extends Node

const OUT_DIR := "/Users/andrej.zsigo/.gemini/antigravity/brain/3b0ee1fc-30a9-434b-83a5-a4267498fe99/scratch/pass1"

var _gm: GameManager
var _step: int = 0
var _timer: float = 0.0
var _sub_dir: String = OUT_DIR


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_sub_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_sub_dir)

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	_gm = main_scene.instantiate()
	add_child(_gm)


func _process(delta: float) -> void:
	_timer += delta

	# Step 0: Wait 2.2s for live Title Demo bots to start clashing -> capture Title Screen
	if _step == 0 and _timer >= 2.2:
		_save_shot("01_title_screen.png")
		# Transition into live gameplay mode!
		_gm.start_match()
		# Give player a forward dash & fire bursts so gameplay shot looks super dynamic
		if _gm.player_char:
			_gm.player_char.global_position = Vector3(-13.5, 0.0, 2.5)
			_gm.player_char.aim_point = Vector3(2.0, 1.15, -2.0)
			_gm.player_char.wants_fire = true
		# Spray a few decorative battle paint splatters across midfield so arena feels lived-in
		_seed_skirmish_splatters()
		_step = 1
		_timer = 0.0

	# Step 1: Capture Live Gameplay HUD shot after 1.6s of live action
	elif _step == 1 and _timer >= 1.6:
		_save_shot("02_gameplay_hud.png")
		if _gm.player_char:
			_gm.player_char.wants_fire = false
		# Move camera to dramatic low-angle midfield action shot
		_gm.hud._hud_root.visible = false
		_gm.camera_rig.mode = CameraRig.Mode.OVERVIEW
		_gm.camera_rig.set_process(false)
		_gm.camera_rig.camera.global_position = Vector3(-2.5, 11.5, 16.5)
		_gm.camera_rig.camera.look_at(Vector3(1.5, 1.2, -1.5), Vector3.UP)
		# Trigger live paintball volleys right across midfield!
		for ch in _gm.teams[0]:
			if ch.is_alive:
				ch.aim_point = Vector3(10.0, 1.15, randf_range(-6, 6))
				ch.wants_fire = true
		for ch in _gm.teams[1]:
			if ch.is_alive:
				ch.aim_point = Vector3(-10.0, 1.15, randf_range(-6, 6))
				ch.wants_fire = true
		_step = 2
		_timer = 0.0

	# Step 2: Capture Midfield Action Shot
	elif _step == 2 and _timer >= 1.0:
		_save_shot("03_midfield_action.png")
		# Stage Hero Close-up Shot near Cobalt Base Flag Pedestal!
		if _gm.player_char:
			_gm.player_char.respawn()
			_gm.player_char.shield_timer = 0.0
			_gm.player_char._shield_dome.visible = false
			_gm.player_char.global_position = Vector3(-20.4, 0.0, 2.2)
			_gm.player_char.move_input = Vector3(0.4, 0.0, -0.2)
			_gm.player_char.aim_point = Vector3(-14.0, 1.2, 0.2)
			_gm.player_char.wants_fire = true
		_gm.flags[0].reset_to_base()
		_gm.camera_rig.camera.global_position = Vector3(-16.2, 3.8, 7.6)
		_gm.camera_rig.camera.look_at(Vector3(-21.5, 1.45, 0.8), Vector3.UP)
		_step = 3
		_timer = 0.0

	# Step 3: Capture Hero Close-Up Shot
	elif _step == 3 and _timer >= 0.45:
		_save_shot("04_hero_closeup.png")
		# High Stadium Overview shot
		_gm.camera_rig.camera.global_position = Vector3(0.0, 32.0, 30.0)
		_gm.camera_rig.camera.look_at(Vector3(0.0, 0.5, -2.0), Vector3.UP)
		_step = 4
		_timer = 0.0

	# Step 4: Capture Stadium Overview and quit cleanly!
	elif _step == 4 and _timer >= 0.4:
		_save_shot("05_stadium_overview.png")
		print("ALL SCREENSHOTS CAPTURED IN: ", _sub_dir)
		get_tree().quit()


func _seed_skirmish_splatters() -> void:
	var c_blue := Color(0.08, 0.62, 1.0)
	var c_red := Color(1.0, 0.30, 0.12)
	var spots := [
		[Vector3(-3.2, 0.04, -2.4), c_blue],
		[Vector3(-1.4, 0.04, 3.1), c_red],
		[Vector3(2.8, 0.04, -1.6), c_blue],
		[Vector3(4.5, 0.04, 2.2), c_red],
		[Vector3(-8.5, 0.04, -3.5), c_red],
		[Vector3(-9.2, 0.04, 5.0), c_blue],
		[Vector3(9.4, 0.04, -4.8), c_blue],
		[Vector3(8.2, 0.04, 3.8), c_red],
		[Vector3(0.5, 0.04, -10.5), c_blue],
		[Vector3(-2.1, 0.04, 11.2), c_red],
		[Vector3(-15.0, 0.04, 1.5), c_red],
		[Vector3(15.2, 0.04, -2.0), c_blue],
	]
	for s in spots:
		_gm.splatter_manager.spawn_splatter(s[0], Vector3.UP, s[1], randf_range(0.9, 1.45))


func _save_shot(filename: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var full_path := _sub_dir.path_join(filename)
	img.save_png(full_path)
	print("Saved screenshot: ", full_path)
