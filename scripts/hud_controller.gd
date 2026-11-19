extends CanvasLayer
class_name HUDController

signal start_match_pressed
signal resume_pressed
signal restart_pressed

var game_manager: Node = null
var arena_builder: ArenaBuilder = null

# Gameplay HUD containers
var _hud_root: Control
var _blue_score_lbl: Label
var _red_score_lbl: Label
var _timer_lbl: Label
var _blue_flag_pill: Label
var _red_flag_pill: Label
var _banner_panel: PanelContainer
var _banner_lbl: Label
var _banner_timer: float = 0.0
var _feed_vbox: VBoxContainer
var _hp_bar: ProgressBar
var _hp_val_lbl: Label
var _dash_bar: ProgressBar
var _ammo_lbl: Label
var _ammo_pips: Array[ColorRect] = []
var _order_lbl: Label
var _respawn_panel: PanelContainer
var _respawn_lbl: Label
var _carrier_badge: PanelContainer
var _minimap: MinimapControl

var _damage_vignette: ColorRect
var _hit_marker_lbl: Label
var _hit_marker_timer: float = 0.0

# Overlays
var _title_overlay: Control
var _pause_overlay: Control
var _end_overlay: Control
var _end_title_lbl: Label
var _end_sub_lbl: Label
var _end_stats_lbl: Label


func build_ui(p_gm: Node, p_arena: ArenaBuilder) -> void:
	game_manager = p_gm
	arena_builder = p_arena

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Damage edge vignette flash
	_damage_vignette = ColorRect.new()
	_damage_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_vignette.color = Color(1.0, 0.16, 0.08, 0.0)
	_damage_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_damage_vignette)

	_build_gameplay_hud(root)
	_build_title_overlay(root)
	_build_pause_overlay(root)
	_build_end_overlay(root)

	show_title()


func _make_panel_style(bg: Color, border: Color, radius: int = 12, border_w: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = border_w
	s.border_width_right = border_w
	s.border_width_top = border_w
	s.border_width_bottom = border_w
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	return s


func _style_button(btn: Button, bg: Color, hover: Color, border: Color) -> void:
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0))
	btn.add_theme_stylebox_override("normal", _make_panel_style(bg, border, 12, 2))
	btn.add_theme_stylebox_override("hover", _make_panel_style(hover, border.lightened(0.25), 12, 2))
	btn.add_theme_stylebox_override("pressed", _make_panel_style(bg.darkened(0.18), border, 12, 2))
	btn.custom_minimum_size = Vector2(240, 54)


func _build_gameplay_hud(parent: Control) -> void:
	_hud_root = Control.new()
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_hud_root)

	# ==================== TOP-CENTER SCOREBOARD PILL ====================
	var top_vbox := VBoxContainer.new()
	top_vbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_vbox.offset_top = 14
	top_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_vbox.add_theme_constant_override("separation", 6)
	top_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(top_vbox)

	var score_center := CenterContainer.new()
	score_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_vbox.add_child(score_center)

	var score_panel := PanelContainer.new()
	score_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.09, 0.14, 0.86), Color(0.32, 0.42, 0.56, 0.55), 16, 2))
	score_center.add_child(score_panel)

	var shbox := HBoxContainer.new()
	shbox.add_theme_constant_override("separation", 18)
	score_panel.add_child(shbox)

	var blue_tag := Label.new()
	blue_tag.text = "COBALT"
	blue_tag.add_theme_font_size_override("font_size", 15)
	blue_tag.add_theme_color_override("font_color", Color(0.24, 0.78, 1.0))
	shbox.add_child(blue_tag)

	_blue_score_lbl = Label.new()
	_blue_score_lbl.text = "0"
	_blue_score_lbl.add_theme_font_size_override("font_size", 28)
	_blue_score_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	shbox.add_child(_blue_score_lbl)

	var sep1 := ColorRect.new()
	sep1.custom_minimum_size = Vector2(2, 28)
	sep1.color = Color(0.35, 0.45, 0.58, 0.5)
	shbox.add_child(sep1)

	_timer_lbl = Label.new()
	_timer_lbl.text = "04:00"
	_timer_lbl.add_theme_font_size_override("font_size", 22)
	_timer_lbl.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))
	_timer_lbl.custom_minimum_size = Vector2(76, 0)
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shbox.add_child(_timer_lbl)

	var sep2 := ColorRect.new()
	sep2.custom_minimum_size = Vector2(2, 28)
	sep2.color = Color(0.35, 0.45, 0.58, 0.5)
	shbox.add_child(sep2)

	_red_score_lbl = Label.new()
	_red_score_lbl.text = "0"
	_red_score_lbl.add_theme_font_size_override("font_size", 28)
	_red_score_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	shbox.add_child(_red_score_lbl)

	var red_tag := Label.new()
	red_tag.text = "EMBER"
	red_tag.add_theme_font_size_override("font_size", 15)
	red_tag.add_theme_color_override("font_color", Color(1.0, 0.42, 0.22))
	shbox.add_child(red_tag)

	# Flag status pills row directly below scoreboard
	var flag_center := CenterContainer.new()
	flag_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_vbox.add_child(flag_center)

	var fhbox := HBoxContainer.new()
	fhbox.add_theme_constant_override("separation", 14)
	flag_center.add_child(fhbox)

	var bp := PanelContainer.new()
	bp.add_theme_stylebox_override("panel", _make_panel_style(Color(0.05, 0.14, 0.26, 0.82), Color(0.14, 0.62, 1.0, 0.75), 10, 1))
	fhbox.add_child(bp)
	_blue_flag_pill = Label.new()
	_blue_flag_pill.text = "COBALT FLAG: SAFE"
	_blue_flag_pill.add_theme_font_size_override("font_size", 13)
	_blue_flag_pill.add_theme_color_override("font_color", Color(0.75, 0.93, 1.0))
	bp.add_child(_blue_flag_pill)

	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", _make_panel_style(Color(0.24, 0.08, 0.06, 0.82), Color(1.0, 0.36, 0.16, 0.75), 10, 1))
	fhbox.add_child(rp)
	_red_flag_pill = Label.new()
	_red_flag_pill.text = "EMBER FLAG: AT BASE"
	_red_flag_pill.add_theme_font_size_override("font_size", 13)
	_red_flag_pill.add_theme_color_override("font_color", Color(1.0, 0.84, 0.72))
	rp.add_child(_red_flag_pill)

	# Animated Event Banner
	var banner_center := CenterContainer.new()
	banner_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_vbox.add_child(banner_center)

	_banner_panel = PanelContainer.new()
	_banner_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.12, 0.20, 0.92), Color(1.0, 0.78, 0.20, 0.9), 14, 2))
	_banner_panel.visible = false
	banner_center.add_child(_banner_panel)

	_banner_lbl = Label.new()
	_banner_lbl.add_theme_font_size_override("font_size", 22)
	_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	_banner_panel.add_child(_banner_lbl)

	# ==================== TOP-RIGHT EVENT FEED ====================
	_feed_vbox = VBoxContainer.new()
	_feed_vbox.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_feed_vbox.offset_left = -310
	_feed_vbox.offset_right = -18
	_feed_vbox.offset_top = 18
	_feed_vbox.add_theme_constant_override("separation", 6)
	_feed_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_feed_vbox)

	# ==================== BOTTOM-LEFT PLAYER STATUS CARD ====================
	var status_panel := PanelContainer.new()
	status_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	status_panel.offset_left = 18
	status_panel.offset_bottom = -18
	status_panel.offset_top = -152
	status_panel.offset_right = 296
	status_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.09, 0.14, 0.86), Color(0.18, 0.65, 1.0, 0.65), 14, 2))
	_hud_root.add_child(status_panel)

	var svbox := VBoxContainer.new()
	svbox.add_theme_constant_override("separation", 7)
	status_panel.add_child(svbox)

	# Health Row
	var hp_row := HBoxContainer.new()
	svbox.add_child(hp_row)
	var hp_title := Label.new()
	hp_title.text = "ARMOR"
	hp_title.add_theme_font_size_override("font_size", 12)
	hp_title.add_theme_color_override("font_color", Color(0.68, 0.82, 0.96))
	hp_row.add_child(hp_title)
	var hp_spacer := Control.new()
	hp_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_child(hp_spacer)
	_hp_val_lbl = Label.new()
	_hp_val_lbl.text = "100 / 100"
	_hp_val_lbl.add_theme_font_size_override("font_size", 12)
	_hp_val_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	hp_row.add_child(_hp_val_lbl)

	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = 100.0
	_hp_bar.value = 100.0
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(0, 12)
	_hp_bar.add_theme_stylebox_override("background", _make_panel_style(Color(0.12, 0.16, 0.22, 0.9), Color(0.2, 0.25, 0.35, 0.4), 6, 1))
	_hp_bar.add_theme_stylebox_override("fill", _make_panel_style(Color(0.10, 0.82, 0.98), Color(0.5, 0.95, 1.0), 6, 0))
	svbox.add_child(_hp_bar)

	# Dash Charge Bar
	var dash_row := HBoxContainer.new()
	dash_row.add_theme_constant_override("separation", 8)
	svbox.add_child(dash_row)
	var dash_lbl := Label.new()
	dash_lbl.text = "DASH"
	dash_lbl.add_theme_font_size_override("font_size", 11)
	dash_lbl.add_theme_color_override("font_color", Color(0.68, 0.82, 0.96))
	dash_row.add_child(dash_lbl)
	_dash_bar = ProgressBar.new()
	_dash_bar.max_value = 100.0
	_dash_bar.value = 100.0
	_dash_bar.show_percentage = false
	_dash_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dash_bar.custom_minimum_size = Vector2(0, 8)
	_dash_bar.add_theme_stylebox_override("background", _make_panel_style(Color(0.12, 0.16, 0.22, 0.9), Color(0.2, 0.25, 0.35, 0.4), 4, 1))
	_dash_bar.add_theme_stylebox_override("fill", _make_panel_style(Color(1.0, 0.76, 0.18), Color(1.0, 0.9, 0.5), 4, 0))
	dash_row.add_child(_dash_bar)

	# Hopper Paintball Counter + Visual Pips
	var ammo_row := HBoxContainer.new()
	svbox.add_child(ammo_row)
	var ammo_title := Label.new()
	ammo_title.text = "HOPPER"
	ammo_title.add_theme_font_size_override("font_size", 12)
	ammo_title.add_theme_color_override("font_color", Color(0.68, 0.82, 0.96))
	ammo_row.add_child(ammo_title)
	var a_sp := Control.new()
	a_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ammo_row.add_child(a_sp)
	_ammo_lbl = Label.new()
	_ammo_lbl.text = "24 / 24"
	_ammo_lbl.add_theme_font_size_override("font_size", 14)
	_ammo_lbl.add_theme_color_override("font_color", Color(0.28, 0.90, 1.0))
	ammo_row.add_child(_ammo_lbl)

	var pips_hbox := HBoxContainer.new()
	pips_hbox.add_theme_constant_override("separation", 4)
	svbox.add_child(pips_hbox)
	for i in range(12):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(16, 7)
		pip.color = Color(0.10, 0.78, 1.0)
		pips_hbox.add_child(pip)
		_ammo_pips.append(pip)

	_order_lbl = Label.new()
	_order_lbl.text = "SQUAD: AUTO  [Q Attack • E Defend]"
	_order_lbl.add_theme_font_size_override("font_size", 11)
	_order_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.90, 0.85))
	svbox.add_child(_order_lbl)

	# ==================== BOTTOM-RIGHT LIVE MINIMAP ====================
	_minimap = MinimapControl.new()
	_minimap.arena_builder = arena_builder
	_minimap.game_manager = game_manager
	_minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_minimap.offset_left = -254
	_minimap.offset_right = -18
	_minimap.offset_top = -170
	_minimap.offset_bottom = -18
	_hud_root.add_child(_minimap)

	# ==================== RESPAWN COUNTDOWN PILL ====================
	var resp_center := CenterContainer.new()
	resp_center.set_anchors_preset(Control.PRESET_CENTER)
	resp_center.offset_left = -200
	resp_center.offset_right = 200
	resp_center.offset_top = 80
	resp_center.offset_bottom = 140
	resp_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(resp_center)

	_respawn_panel = PanelContainer.new()
	_respawn_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.24, 0.06, 0.06, 0.90), Color(1.0, 0.35, 0.18, 0.9), 12, 2))
	_respawn_panel.visible = false
	resp_center.add_child(_respawn_panel)
	_respawn_lbl = Label.new()
	_respawn_lbl.text = "TAGGED OUT — RESPAWNING IN 3.0s"
	_respawn_lbl.add_theme_font_size_override("font_size", 18)
	_respawn_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.90))
	_respawn_panel.add_child(_respawn_lbl)

	# Carrying Flag Objective Pill (bottom-center!)
	var carry_center := CenterContainer.new()
	carry_center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	carry_center.offset_top = -78
	carry_center.offset_bottom = -26
	carry_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(carry_center)

	_carrier_badge = PanelContainer.new()
	_carrier_badge.add_theme_stylebox_override("panel", _make_panel_style(Color(0.24, 0.08, 0.04, 0.90), Color(1.0, 0.72, 0.16, 0.95), 14, 2))
	_carrier_badge.visible = false
	carry_center.add_child(_carrier_badge)
	var c_lbl := Label.new()
	c_lbl.text = "⚑  CARRYING EMBER FLAG — RETURN TO COBALT BASE!"
	c_lbl.add_theme_font_size_override("font_size", 16)
	c_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.76))
	_carrier_badge.add_child(c_lbl)

	# Hit marker flash near top-center
	_hit_marker_lbl = Label.new()
	_hit_marker_lbl.text = "✕"
	_hit_marker_lbl.add_theme_font_size_override("font_size", 26)
	_hit_marker_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.24, 0.0))
	_hit_marker_lbl.set_anchors_preset(Control.PRESET_CENTER)
	_hit_marker_lbl.offset_left = -16
	_hit_marker_lbl.offset_top = -18
	_hud_root.add_child(_hit_marker_lbl)


func _build_title_overlay(parent: Control) -> void:
	_title_overlay = Control.new()
	_title_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(_title_overlay)

	# Editorial unobstructed framing: sleek Title Header in upper area + Action CTA in lower-third
	# so the live 3D Golden-Hour paintball battle shines right through the center of the viewport!
	var top_bar := CenterContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_top = 34
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_overlay.add_child(top_bar)

	var header_card := PanelContainer.new()
	header_card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.05, 0.08, 0.14, 0.80), Color(0.96, 0.74, 0.18, 0.88), 20, 2))
	top_bar.add_child(header_card)

	var hvbox := VBoxContainer.new()
	hvbox.add_theme_constant_override("separation", 6)
	hvbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_card.add_child(hvbox)

	var bar_hbox := HBoxContainer.new()
	bar_hbox.add_theme_constant_override("separation", 8)
	bar_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hvbox.add_child(bar_hbox)
	var b_bar := ColorRect.new()
	b_bar.custom_minimum_size = Vector2(140, 5)
	b_bar.color = Color(0.10, 0.70, 1.0)
	bar_hbox.add_child(b_bar)
	var g_bar := ColorRect.new()
	g_bar.custom_minimum_size = Vector2(44, 5)
	g_bar.color = Color(1.0, 0.78, 0.18)
	bar_hbox.add_child(g_bar)
	var r_bar := ColorRect.new()
	r_bar.custom_minimum_size = Vector2(140, 5)
	r_bar.color = Color(1.0, 0.30, 0.14)
	bar_hbox.add_child(r_bar)

	var title := Label.new()
	title.text = "CAPTURE THE FLAG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(0.99, 0.99, 0.97))
	hvbox.add_child(title)

	var sub := Label.new()
	sub.text = "GOLDEN HOUR PAINTBALL ARENA  •  4v4 TACTICAL CTF  •  FIRST TO 3 CAPTURES"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(1.0, 0.84, 0.40))
	hvbox.add_child(sub)

	# Bottom CTA Dock (leaves live 3D midfield action completely unobstructed!)
	var bot_center := CenterContainer.new()
	bot_center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_center.offset_top = -148
	bot_center.offset_bottom = -24
	_title_overlay.add_child(bot_center)

	var bvbox := VBoxContainer.new()
	bvbox.add_theme_constant_override("separation", 10)
	bvbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_center.add_child(bvbox)

	var btn_center := CenterContainer.new()
	bvbox.add_child(btn_center)
	var play_btn := Button.new()
	play_btn.text = "PLAY MATCH"
	play_btn.custom_minimum_size = Vector2(270, 56)
	_style_button(play_btn, Color(0.08, 0.50, 0.96), Color(0.14, 0.64, 1.0), Color(0.35, 0.90, 1.0))
	play_btn.pressed.connect(func(): start_match_pressed.emit())
	btn_center.add_child(play_btn)

	var ctrl_pill := PanelContainer.new()
	ctrl_pill.add_theme_stylebox_override("panel", _make_panel_style(Color(0.05, 0.08, 0.14, 0.78), Color(0.32, 0.42, 0.56, 0.45), 10, 1))
	bvbox.add_child(ctrl_pill)
	var ctrl := Label.new()
	ctrl.text = "WASD Move   •   Mouse Aim & Paintball Fire   •   Space / RMB Tactical Dash   •   R Reload Pod   •   Q / E Squad Orders"
	ctrl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctrl.add_theme_font_size_override("font_size", 12)
	ctrl.add_theme_color_override("font_color", Color(0.84, 0.90, 0.96))
	ctrl_pill.add_child(ctrl)


func _build_pause_overlay(parent: Control) -> void:
	_pause_overlay = Control.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.visible = false
	parent.add_child(_pause_overlay)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.04, 0.06, 0.10, 0.62)
	_pause_overlay.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.09, 0.15, 0.94), Color(0.24, 0.74, 1.0, 0.8), 18, 2))
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "MATCH PAUSED"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	vbox.add_child(lbl)

	var res_btn := Button.new()
	res_btn.text = "RESUME"
	_style_button(res_btn, Color(0.08, 0.52, 0.96), Color(0.15, 0.64, 1.0), Color(0.35, 0.88, 1.0))
	res_btn.pressed.connect(func(): resume_pressed.emit())
	vbox.add_child(res_btn)

	var rest_btn := Button.new()
	rest_btn.text = "RESTART MATCH"
	_style_button(rest_btn, Color(0.20, 0.25, 0.34), Color(0.28, 0.34, 0.44), Color(0.50, 0.58, 0.68))
	rest_btn.pressed.connect(func(): restart_pressed.emit())
	vbox.add_child(rest_btn)


func _build_end_overlay(parent: Control) -> void:
	_end_overlay = Control.new()
	_end_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_overlay.visible = false
	parent.add_child(_end_overlay)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.04, 0.06, 0.10, 0.55)
	_end_overlay.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_overlay.add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.09, 0.15, 0.92), Color(1.0, 0.78, 0.20, 0.9), 20, 2))
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	_end_title_lbl = Label.new()
	_end_title_lbl.text = "TEAM COBALT WINS!"
	_end_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title_lbl.add_theme_font_size_override("font_size", 38)
	vbox.add_child(_end_title_lbl)

	_end_sub_lbl = Label.new()
	_end_sub_lbl.text = "FINAL SCORE:  3  —  1"
	_end_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_sub_lbl.add_theme_font_size_override("font_size", 20)
	_end_sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	vbox.add_child(_end_sub_lbl)

	_end_stats_lbl = Label.new()
	_end_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_stats_lbl.add_theme_font_size_override("font_size", 15)
	_end_stats_lbl.add_theme_color_override("font_color", Color(0.84, 0.90, 0.96))
	vbox.add_child(_end_stats_lbl)

	var btn_c := CenterContainer.new()
	vbox.add_child(btn_c)
	var again_btn := Button.new()
	again_btn.text = "PLAY AGAIN"
	_style_button(again_btn, Color(0.08, 0.52, 0.96), Color(0.16, 0.64, 1.0), Color(0.35, 0.90, 1.0))
	again_btn.pressed.connect(func(): restart_pressed.emit())
	btn_c.add_child(again_btn)


func show_title() -> void:
	_title_overlay.visible = true
	_hud_root.visible = false
	_pause_overlay.visible = false
	_end_overlay.visible = false


func show_gameplay() -> void:
	_title_overlay.visible = false
	_hud_root.visible = true
	_pause_overlay.visible = false
	_end_overlay.visible = false


func show_pause(paused: bool) -> void:
	_pause_overlay.visible = paused


func show_match_over(winner_team: int, blue_score: int, red_score: int, captures: int, tags: int, returns: int) -> void:
	_hud_root.visible = false
	_pause_overlay.visible = false
	_end_overlay.visible = true
	if winner_team == 0:
		_end_title_lbl.text = "TEAM COBALT VICTORY!"
		_end_title_lbl.add_theme_color_override("font_color", Color(0.22, 0.84, 1.0))
	else:
		_end_title_lbl.text = "TEAM EMBER VICTORY!"
		_end_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.40, 0.20))
	_end_sub_lbl.text = "FINAL SCORE:   COBALT %d  —  %d EMBER" % [blue_score, red_score]
	_end_stats_lbl.text = "YOUR MATCH STATS\nFlags Captured: %d   •   Opponents Tagged: %d   •   Flags Returned: %d" % [captures, tags, returns]


func show_banner(text: String, accent_col: Color = Color(1.0, 0.82, 0.22), duration: float = 2.6) -> void:
	_banner_lbl.text = text
	_banner_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.10, 0.18, 0.92), accent_col, 14, 2))
	_banner_panel.visible = true
	_banner_timer = duration


func push_feed(msg: String, accent_col: Color = Color(0.88, 0.92, 0.98)) -> void:
	if _feed_vbox.get_child_count() >= 4:
		_feed_vbox.get_child(0).queue_free()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _make_panel_style(Color(0.05, 0.08, 0.13, 0.78), Color(accent_col.r, accent_col.g, accent_col.b, 0.7), 8, 1))
	var l := Label.new()
	l.text = msg
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", accent_col)
	p.add_child(l)
	_feed_vbox.add_child(p)
	get_tree().create_timer(4.8).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free()
	)


func flash_damage() -> void:
	_damage_vignette.color.a = 0.34


func flash_hit_marker(eliminated: bool) -> void:
	_hit_marker_timer = 0.16
	_hit_marker_lbl.add_theme_color_override("font_color", Color(1.0, 0.30, 0.18, 1.0) if eliminated else Color(1.0, 0.92, 0.32, 0.95))


func update_hud(delta: float, blue_score: int, red_score: int, time_left: float, overtime: bool, blue_flag: FlagController, red_flag: FlagController, player: CharacterController, squad_order: int) -> void:
	if _damage_vignette.color.a > 0.0:
		_damage_vignette.color.a = maxf(0.0, _damage_vignette.color.a - delta * 1.4)

	if _hit_marker_timer > 0.0:
		_hit_marker_timer -= delta
		if _hit_marker_timer <= 0.0:
			_hit_marker_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0))

	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			_banner_panel.visible = false

	_blue_score_lbl.text = str(blue_score)
	_red_score_lbl.text = str(red_score)

	if overtime:
		_timer_lbl.text = "OT!"
		_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.42, 0.22))
	else:
		var mins := int(maxf(0.0, time_left)) / 60
		var secs := int(maxf(0.0, time_left)) % 60
		_timer_lbl.text = "%02d:%02d" % [mins, secs]
		_timer_lbl.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82))

	if is_instance_valid(blue_flag):
		_blue_flag_pill.text = "COBALT FLAG: " + _flag_state_str(blue_flag)
	if is_instance_valid(red_flag):
		_red_flag_pill.text = "EMBER FLAG: " + _flag_state_str(red_flag)

	if is_instance_valid(player):
		_hp_bar.value = player.hp
		_hp_val_lbl.text = "%d / %d" % [int(ceil(player.hp)), int(CharacterController.MAX_HP)]
		var dash_pct := 100.0 * (1.0 - clampf(player.dash_cooldown_timer / CharacterController.DASH_COOLDOWN, 0.0, 1.0))
		_dash_bar.value = dash_pct

		if player.is_reloading:
			_ammo_lbl.text = "RELOADING..."
			_ammo_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.24))
		else:
			_ammo_lbl.text = "%d / %d" % [player.ammo, CharacterController.HOPPER_MAX]
			_ammo_lbl.add_theme_color_override("font_color", Color(0.28, 0.90, 1.0))

		var filled_pips := int(ceil(float(player.ammo) / 2.0))
		for i in range(_ammo_pips.size()):
			_ammo_pips[i].color = Color(0.10, 0.78, 1.0) if i < filled_pips else Color(0.18, 0.24, 0.32, 0.65)

		_respawn_panel.visible = not player.is_alive
		if not player.is_alive:
			_respawn_lbl.text = "TAGGED OUT — RESPAWNING IN %.1fs" % maxf(0.0, player.respawn_timer)
		if _carrier_badge:
			_carrier_badge.visible = player.is_alive and player.carrying_flag != null

	var order_names := ["AUTO", "ATTACK!", "DEFEND!"]
	_order_lbl.text = "SQUAD: %s  [Q Attack • E Defend]" % order_names[clampi(squad_order, 0, 2)]


func _flag_state_str(f: FlagController) -> String:
	match f.state:
		FlagController.State.AT_BASE:
			return "AT BASE"
		FlagController.State.CARRIED:
			return "TAKEN!"
		FlagController.State.DROPPED:
			return "DROPPED (%.0fs)" % maxf(0.0, f.drop_timer)
	return "AT BASE"
