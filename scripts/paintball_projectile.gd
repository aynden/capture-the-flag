extends Node3D
class_name PaintballProjectile

var team: int = 0 # 0 = Blue, 1 = Red
var shooter: Node3D = null
var velocity: Vector3 = Vector3.ZERO
var damage: float = 22.0
var paint_color: Color = Color(0.08, 0.68, 1.0)
var life: float = 1.65

var splatter_manager: SplatterManager
var audio_manager: AudioManager


func _ready() -> void:
	var ball_mesh := SphereMesh.new()
	ball_mesh.radius = 0.125
	ball_mesh.height = 0.25
	ball_mesh.radial_segments = 12
	ball_mesh.rings = 8

	var trail_mesh := CylinderMesh.new()
	trail_mesh.top_radius = 0.085
	trail_mesh.bottom_radius = 0.008
	trail_mesh.height = 1.15
	trail_mesh.radial_segments = 8

	var ball := MeshInstance3D.new()
	ball.mesh = ball_mesh
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = paint_color.lightened(0.25)
	bmat.roughness = 0.08
	bmat.emission_enabled = true
	bmat.emission = paint_color
	bmat.emission_energy_multiplier = 2.4
	ball.material_override = bmat
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ball)

	var trail := MeshInstance3D.new()
	trail.mesh = trail_mesh
	var tmat := StandardMaterial3D.new()
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tmat.albedo_color = Color(paint_color.r, paint_color.g, paint_color.b, 0.58)
	tmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	trail.material_override = tmat
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Align cylinder along +Z (behind -Z forward)
	trail.rotation_degrees.x = 90.0
	trail.position.z = 0.55
	add_child(trail)


func setup(p_team: int, p_shooter: Node3D, start_pos: Vector3, dir: Vector3, speed: float, p_color: Color, p_splat: SplatterManager, p_audio: AudioManager) -> void:
	team = p_team
	shooter = p_shooter
	paint_color = p_color
	splatter_manager = p_splat
	audio_manager = p_audio
	global_position = start_pos
	var d := dir.normalized()
	velocity = d * speed
	if d.length_squared() > 0.001:
		look_at(start_pos + d, Vector3.UP)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return

	velocity.y -= 3.2 * delta
	var next_pos := global_position + velocity * delta

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position, next_pos)
	# Collide with World(1), Bunkers(2), and Enemy Team (Blue=4, Red=8)
	var enemy_layer := 8 if team == 0 else 4
	query.collision_mask = 1 | 2 | enemy_layer
	if is_instance_valid(shooter) and shooter is CollisionObject3D:
		query.exclude = [shooter.get_rid()]

	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var hit_pos: Vector3 = hit.position
		var hit_norm: Vector3 = hit.normal
		var collider = hit.collider

		if collider and collider.has_method("apply_paint_hit"):
			collider.apply_paint_hit(damage, shooter, velocity.normalized(), paint_color)
			if splatter_manager:
				splatter_manager.spawn_paint_burst(hit_pos, hit_norm, paint_color, 15, 1.15)
				# Also splash a splatter onto the ground under the hit player!
				splatter_manager.spawn_splatter(Vector3(hit_pos.x, 0.04, hit_pos.z), Vector3.UP, paint_color, 0.9)
		else:
			if splatter_manager:
				splatter_manager.spawn_splatter(hit_pos, hit_norm, paint_color, 1.0)
				splatter_manager.spawn_paint_burst(hit_pos, hit_norm, paint_color, 10, 0.9)
			if audio_manager and (not is_instance_valid(shooter) or shooter.get("is_player")):
				audio_manager.play_sfx("splat", -14.0, 0.14)

		queue_free()
		return

	global_position = next_pos
	if velocity.length_squared() > 0.1:
		look_at(global_position + velocity, Vector3.UP)
