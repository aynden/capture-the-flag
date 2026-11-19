extends Control
class_name MinimapControl

var arena_builder: ArenaBuilder = null
var game_manager: Node = null


func _ready() -> void:
	custom_minimum_size = Vector2(236, 152)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _world_to_map(world_xz: Vector2) -> Vector2:
	var pad := 10.0
	var w := size.x - pad * 2.0
	var h := size.y - pad * 2.0
	var u := (world_xz.x + ArenaBuilder.FIELD_HALF_X) / (ArenaBuilder.FIELD_HALF_X * 2.0)
	var v := (world_xz.y + ArenaBuilder.FIELD_HALF_Z) / (ArenaBuilder.FIELD_HALF_Z * 2.0)
	return Vector2(pad + clampf(u, 0.0, 1.0) * w, pad + clampf(v, 0.0, 1.0) * h)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	# Sleek rounded dark glass background
	draw_rect(rect, Color(0.06, 0.09, 0.14, 0.84), true)
	draw_rect(rect, Color(0.28, 0.38, 0.50, 0.65), false, 2.0)

	var pad := 10.0
	var field_rect := Rect2(Vector2(pad, pad), size - Vector2(pad * 2.0, pad * 2.0))
	draw_rect(field_rect, Color(0.14, 0.28, 0.14, 0.92), true)

	# Alternating subtle turf stripes
	var stripe_w := field_rect.size.x / 10.0
	for i in range(0, 10, 2):
		draw_rect(Rect2(field_rect.position.x + i * stripe_w, field_rect.position.y, stripe_w, field_rect.size.y), Color(0.18, 0.34, 0.17, 0.55), true)

	# Team endzone subtle washes
	draw_rect(Rect2(field_rect.position, Vector2(field_rect.size.x * 0.18, field_rect.size.y)), Color(0.10, 0.45, 0.95, 0.18), true)
	draw_rect(Rect2(Vector2(field_rect.end.x - field_rect.size.x * 0.18, field_rect.position.y), Vector2(field_rect.size.x * 0.18, field_rect.size.y)), Color(0.95, 0.24, 0.12, 0.18), true)

	# Midfield chalk line & center circle
	var mid_x := field_rect.position.x + field_rect.size.x * 0.5
	draw_line(Vector2(mid_x, field_rect.position.y), Vector2(mid_x, field_rect.end.y), Color(1, 1, 1, 0.38), 1.5)
	draw_arc(Vector2(mid_x, field_rect.position.y + field_rect.size.y * 0.5), 14.0, 0.0, TAU, 24, Color(1, 1, 1, 0.35), 1.5)
	draw_rect(field_rect, Color(1, 1, 1, 0.42), false, 1.5)

	# Base rings
	var blue_b := _world_to_map(Vector2(ArenaBuilder.BLUE_BASE_POS.x, ArenaBuilder.BLUE_BASE_POS.z))
	var red_b := _world_to_map(Vector2(ArenaBuilder.RED_BASE_POS.x, ArenaBuilder.RED_BASE_POS.z))
	draw_circle(blue_b, 9.0, Color(0.12, 0.56, 1.0, 0.28))
	draw_arc(blue_b, 9.0, 0.0, TAU, 20, Color(0.18, 0.80, 1.0, 0.85), 1.5)
	draw_circle(red_b, 9.0, Color(1.0, 0.28, 0.14, 0.28))
	draw_arc(red_b, 9.0, 0.0, TAU, 20, Color(1.0, 0.50, 0.22, 0.85), 1.5)

	# Obstacles / Bunkers
	if is_instance_valid(arena_builder):
		var sx := field_rect.size.x / (ArenaBuilder.FIELD_HALF_X * 2.0)
		var sy := field_rect.size.y / (ArenaBuilder.FIELD_HALF_Z * 2.0)
		for ob in arena_builder.minimap_obstacles:
			var mp := _world_to_map(ob.pos)
			var sz := Vector2(maxf(4.0, ob.size.x * sx), maxf(4.0, ob.size.y * sy))
			var col: Color = ob.color
			draw_rect(Rect2(mp - sz * 0.5, sz), Color(col.r, col.g, col.b, 0.85), true)

	if not is_instance_valid(game_manager):
		return

	# Characters
	for team_i in range(2):
		var chars: Array = game_manager.get_team_characters(team_i)
		for ch in chars:
			if not is_instance_valid(ch) or not ch.is_alive:
				continue
			var mp := _world_to_map(Vector2(ch.global_position.x, ch.global_position.z))
			var col := Color(0.16, 0.72, 1.0) if team_i == 0 else Color(1.0, 0.34, 0.16)
			if ch.is_player:
				# Bright player indicator + facing direction pip
				var aim_v := Vector2(ch.aim_point.x - ch.global_position.x, ch.aim_point.z - ch.global_position.z)
				if aim_v.length_squared() > 0.01:
					aim_v = aim_v.normalized()
					draw_line(mp, mp + aim_v * 11.0, Color(0.4, 0.98, 1.0, 0.9), 2.0)
				draw_circle(mp, 5.4, Color(1, 1, 1, 0.95))
				draw_circle(mp, 3.8, Color(0.05, 0.90, 1.0))
			else:
				draw_circle(mp, 3.8, Color(0.05, 0.07, 0.10, 0.9))
				draw_circle(mp, 2.9, col)

	# Flags (pulsing diamond icons on top!)
	var pulse := 1.0 + 0.22 * sin(Time.get_ticks_msec() * 0.01)
	for team_i in range(2):
		var flag: FlagController = game_manager.get_flag(team_i)
		if not is_instance_valid(flag):
			continue
		var fp := _world_to_map(Vector2(flag.global_position.x, flag.global_position.z))
		var r := 6.0 * (pulse if flag.state != FlagController.State.AT_BASE else 1.0)
		var fcol := Color(0.15, 0.85, 1.0) if team_i == 0 else Color(1.0, 0.55, 0.15)
		var pts := PackedVector2Array([
			fp + Vector2(0, -r),
			fp + Vector2(r, 0),
			fp + Vector2(0, r),
			fp + Vector2(-r, 0),
		])
		draw_colored_polygon(pts, fcol)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(1, 1, 1, 0.95), 1.5)
