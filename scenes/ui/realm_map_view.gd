extends Control
## Live Arcane Realm Map & Corner Minimap Renderer (Pure Godot 4 Custom _draw).
## Renders real stage trails, side glades/courtyards/colosseum/astral islands,
## live Player position & camera vision cone, Quest Objective beacon + compass guide line,
## Wayshrines, Rune Pillars, Shards, Chests, Lore Runestones, NPCs, Enemies, Bosses, & Portal.

const UI_FONT: Font = preload("res://resources/fonts/ui_font.tres")
const TITLE_FONT: Font = preload("res://resources/fonts/title_font.tres")

@export var is_full_map: bool = false

var _t: float = 0.0
var _redraw_accum: float = 0.0
var _world_half_extent: float = 104.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_redraw_accum += delta
	if _redraw_accum >= (0.045 if not is_full_map else 0.08):
		_redraw_accum = 0.0
		queue_redraw()


func _world_to_canvas(wx: float, wz: float, center: Vector2, map_radius: float, cam_origin: Vector2, world_span: float) -> Vector2:
	var dx: float = (wx - cam_origin.x) / world_span
	var dz: float = (wz - cam_origin.y) / world_span
	return center + Vector2(dx * map_radius, dz * map_radius)


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - (10.0 if is_full_map else 4.0)
	if r < 24.0:
		return

	var lvl: Node = get_tree().get_first_node_in_group("level_controller")
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	var layout_id: String = "level_1"
	if lvl and lvl.get("layout_id") != null:
		layout_id = String(lvl.get("layout_id"))

	var p_pos: Vector3 = player.global_position if (player and is_instance_valid(player)) else Vector3(0.0, 0.0, 74.0)
	var cam_heading: float = 0.0
	if player and is_instance_valid(player):
		var cy: Node3D = player.get_node_or_null("CameraYaw") as Node3D
		if cy:
			cam_heading = -cy.rotation.y

	# Corner minimap follows player (64m view radius); Full Map shows entire 220m realm centered at (0,0)
	var map_origin: Vector2 = Vector2.ZERO if is_full_map else Vector2(p_pos.x, p_pos.z)
	var world_span: float = _world_half_extent if is_full_map else 62.0

	# --- 1. BASE TERRAIN BACKDROP ---
	var bg_col: Color = Color(0.055, 0.115, 0.105, 0.95)
	var hill_col: Color = Color(0.08, 0.17, 0.145, 0.72)
	var road_col: Color = Color(0.46, 0.48, 0.42, 0.85)
	var glade_col: Color = Color(0.18, 0.34, 0.28, 0.78)
	match layout_id:
		"level_2":
			bg_col = Color(0.065, 0.085, 0.155, 0.95)
			hill_col = Color(0.10, 0.13, 0.23, 0.72)
			road_col = Color(0.44, 0.48, 0.62, 0.86)
			glade_col = Color(0.22, 0.28, 0.44, 0.82)
		"level_3":
			bg_col = Color(0.075, 0.10, 0.12, 0.95)
			hill_col = Color(0.13, 0.18, 0.20, 0.75)
			road_col = Color(0.42, 0.48, 0.46, 0.86)
			glade_col = Color(0.18, 0.28, 0.28, 0.82)
		"level_4":
			bg_col = Color(0.05, 0.08, 0.19, 0.96)
			hill_col = Color(0.11, 0.18, 0.36, 0.75)
			road_col = Color(0.55, 0.82, 1.0, 0.72)
			glade_col = Color(0.26, 0.40, 0.68, 0.82)

	if is_full_map:
		var rect := Rect2(c - Vector2(r, r), Vector2(r * 2.0, r * 2.0))
		draw_rect(rect, bg_col, true)
		# Subtle coordinate grid
		for g_idx in range(-3, 4):
			var off: float = (float(g_idx) / 4.0) * r
			draw_line(Vector2(c.x + off, c.y - r), Vector2(c.x + off, c.y + r), Color(0.5, 0.7, 0.7, 0.08), 1.0)
			draw_line(Vector2(c.x - r, c.y + off), Vector2(c.x + r, c.y + off), Color(0.5, 0.7, 0.7, 0.08), 1.0)
	else:
		draw_circle(c, r, bg_col)
		draw_circle(c, r * 0.66, hill_col)
		draw_arc(c, r * 0.66, 0.0, TAU, 36, Color(0.45, 0.76, 0.68, 0.14), 1.0, true)
		draw_arc(c, r * 0.33, 0.0, TAU, 28, Color(0.45, 0.76, 0.68, 0.12), 1.0, true)

	# --- 2. REAL STAGE TRAILS, GLADES, COURTYARDS, ARENA & ISLANDS ---
	_draw_stage_topology(layout_id, lvl, c, r, map_origin, world_span, road_col, glade_col)

	# --- 3. ACTIVE QUEST OBJECTIVE + COMPASS SIGHTLINE ---
	var tgt_pos: Vector3 = p_pos + Vector3(0.0, 0.0, -40.0)
	var tgt_label: String = "Objective"
	if QuestManager:
		var info: Dictionary = QuestManager.get_active_compass_target(p_pos)
		tgt_pos = info.get("position", tgt_pos)
		tgt_label = String(info.get("label", "Objective"))

	var p_pt: Vector2 = _world_to_canvas(p_pos.x, p_pos.z, c, r, map_origin, world_span)
	var tgt_pt: Vector2 = _world_to_canvas(tgt_pos.x, tgt_pos.z, c, r, map_origin, world_span)
	var clamped_tgt: Vector2 = _clamp_to_map(tgt_pt, c, r - 7.0)

	# Subtle golden guide line from player toward active objective
	draw_line(p_pt, clamped_tgt, Color(1.0, 0.88, 0.36, 0.38), 1.6, true)

	# --- 4. LIVE WORLD MARKERS ---
	# Sunlit Shards (warm gold dots)
	for n_var in get_tree().get_nodes_in_group("shard"):
		var n: Node3D = n_var as Node3D
		if not n or not is_instance_valid(n) or not n.visible:
			continue
		var pt: Vector2 = _world_to_canvas(n.global_position.x, n.global_position.z, c, r, map_origin, world_span)
		if _inside_map(pt, c, r - 4.0):
			draw_circle(pt, 3.2 if is_full_map else 2.6, Color(1.0, 0.90, 0.34, 0.96))

	# Treasure Chests (amber squares)
	for n_var in get_tree().get_nodes_in_group("chest"):
		var n: Node3D = n_var as Node3D
		if not n or not is_instance_valid(n):
			continue
		if n.get("is_opened") == true:
			continue
		var pt: Vector2 = _world_to_canvas(n.global_position.x, n.global_position.z, c, r, map_origin, world_span)
		if _inside_map(pt, c, r - 5.0):
			var sz: float = 4.2 if is_full_map else 3.4
			draw_rect(Rect2(pt - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(1.0, 0.74, 0.22, 0.98), true)
			draw_rect(Rect2(pt - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(0.12, 0.08, 0.03, 0.9), false, 1.0)

	# Lore Runestones (sky-blue triangles)
	for n_var in get_tree().get_nodes_in_group("lore_runestone"):
		var n: Node3D = n_var as Node3D
		if not n or not is_instance_valid(n):
			continue
		if n.get("is_read") == true:
			continue
		var pt: Vector2 = _world_to_canvas(n.global_position.x, n.global_position.z, c, r, map_origin, world_span)
		if _inside_map(pt, c, r - 5.0):
			_draw_triangle(pt, 4.4 if is_full_map else 3.5, Color(0.45, 0.86, 1.0, 0.98))

	# Rune Pillars (azure/gold diamonds)
	for n_var in get_tree().get_nodes_in_group("rune_pillar"):
		var n: Node3D = n_var as Node3D
		if not n or not is_instance_valid(n):
			continue
		var activated: bool = n.get("is_activated") == true
		var pt: Vector2 = _world_to_canvas(n.global_position.x, n.global_position.z, c, r, map_origin, world_span)
		if _inside_map(pt, c, r - 6.0):
			var col: Color = Color(0.45, 0.96, 0.70, 0.95) if activated else Color(0.42, 0.78, 1.0, 0.98)
			_draw_diamond(pt, 5.8 if is_full_map else 4.6, col)
			if is_full_map:
				var p_idx: int = int(n.get("pillar_index")) if n.get("pillar_index") != null else 1
				draw_string(UI_FONT, pt + Vector2(8.0, 4.0), "Pillar #%d" % p_idx, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)

	# Wayshrines (cyan beacons)
	for n_var in get_tree().get_nodes_in_group("wayshrine"):
		var n: Node3D = n_var as Node3D
		if not n or not is_instance_valid(n):
			continue
		var lit: bool = n.get("is_ignited") == true
		var pt: Vector2 = _world_to_canvas(n.global_position.x, n.global_position.z, c, r, map_origin, world_span)
		if _inside_map(pt, c, r - 6.0):
			var col: Color = Color(0.32, 0.98, 0.86, 1.0) if lit else Color(0.68, 0.92, 0.96, 0.92)
			_draw_diamond(pt, 5.5 if is_full_map else 4.4, col)
			if not lit:
				draw_circle(pt, 2.0, bg_col)
			if is_full_map:
				draw_string(UI_FONT, pt + Vector2(8.0, 4.0), "Wayshrine", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)

	# Story NPCs (emerald circles)
	for n_var in get_tree().get_nodes_in_group("npc"):
		var n: Node3D = n_var as Node3D
		if not n or not is_instance_valid(n):
			continue
		var pt: Vector2 = _world_to_canvas(n.global_position.x, n.global_position.z, c, r, map_origin, world_span)
		if _inside_map(pt, c, r - 6.0):
			draw_circle(pt, 5.0 if is_full_map else 4.0, Color(0.34, 0.96, 0.56, 1.0))
			draw_arc(pt, 5.2 if is_full_map else 4.2, 0.0, TAU, 16, Color(0.05, 0.14, 0.09, 1.0), 1.2, true)
			if is_full_map and n.get("npc_name") != null:
				draw_string(UI_FONT, pt + Vector2(8.0, 4.0), String(n.get("npc_name")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 0.98, 0.74))

	# Enemies & Bosses (crimson markers)
	for n_var in get_tree().get_nodes_in_group("enemy"):
		var n: Node3D = n_var as Node3D
		if not n or not is_instance_valid(n) or n.get("is_defeated") == true:
			continue
		var pt: Vector2 = _world_to_canvas(n.global_position.x, n.global_position.z, c, r, map_origin, world_span)
		if _inside_map(pt, c, r - 5.0):
			var is_boss: bool = n.is_in_group("boss") or n.is_in_group("astral_boss")
			if is_boss:
				_draw_diamond(pt, 7.2 if is_full_map else 5.8, Color(1.0, 0.24, 0.26, 1.0))
				draw_arc(pt, 9.0 + sin(_t * 5.0) * 1.6, 0.0, TAU, 20, Color(1.0, 0.36, 0.32, 0.7), 1.4, true)
				if is_full_map:
					draw_string(UI_FONT, pt + Vector2(10.0, 4.0), "BOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.55, 0.52))
			else:
				draw_circle(pt, 3.6 if is_full_map else 3.0, Color(0.96, 0.32, 0.32, 0.96))

	# Stage Portal (radiant violet/gold gateway icon)
	for n_var in get_tree().get_nodes_in_group("level_exit"):
		var n: Node3D = n_var as Node3D
		if not n or not is_instance_valid(n):
			continue
		var pt: Vector2 = _world_to_canvas(n.global_position.x, n.global_position.z, c, r, map_origin, world_span)
		var active_p: bool = n.get("_is_active") == true
		var p_col: Color = Color(0.38, 1.0, 0.84, 1.0) if active_p else Color(0.68, 0.48, 0.96, 0.92)
		var draw_pt: Vector2 = _clamp_to_map(pt, c, r - 8.0) if active_p else pt
		if _inside_map(draw_pt, c, r - 4.0):
			_draw_diamond(draw_pt, 7.0 if is_full_map else 5.6, p_col)
			draw_arc(draw_pt, 8.8 + sin(_t * 4.2) * 1.4, 0.0, TAU, 20, p_col, 1.5, true)
			if is_full_map:
				var pname: String = String(n.get("portal_name")) if n.get("portal_name") != null else "Stage Portal"
				draw_string(UI_FONT, draw_pt + Vector2(10.0, 4.0), pname + (" (OPEN)" if active_p else " (SEALED)"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, p_col)

	# --- 5. ACTIVE OBJECTIVE PULSING GOLD STAR BEACON ---
	var pulse_r: float = (8.0 if is_full_map else 6.5) + sin(_t * 5.2) * 2.4
	draw_arc(clamped_tgt, pulse_r, 0.0, TAU, 24, Color(1.0, 0.88, 0.32, 0.92), 1.8, true)
	draw_circle(clamped_tgt, 3.6 if is_full_map else 3.0, Color(1.0, 0.94, 0.52, 1.0))
	if is_full_map:
		draw_string(UI_FONT, clamped_tgt + Vector2(10.0, -8.0), "★ " + tgt_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.92, 0.50))

	# --- 6. PLAYER CAMERA VIEW CONE + DIRECTIONAL ARROW ---
	var p_clamped: Vector2 = _clamp_to_map(p_pt, c, r - 6.0)
	var fwd: Vector2 = Vector2(sin(cam_heading), -cos(cam_heading))
	var right_v: Vector2 = Vector2(cos(cam_heading), sin(cam_heading))

	# Translucent camera FOV cone
	var cone_len: float = 28.0 if is_full_map else 22.0
	var cone_w: float = 16.0 if is_full_map else 12.5
	draw_colored_polygon(
		PackedVector2Array([p_clamped, p_clamped + fwd * cone_len + right_v * cone_w, p_clamped + fwd * cone_len - right_v * cone_w]),
		Color(1.0, 0.92, 0.54, 0.16)
	)

	# Crisp Player Arrow
	var a_sz: float = 7.5 if is_full_map else 6.5
	var p_tip: Vector2 = p_clamped + fwd * a_sz
	var p_r: Vector2 = p_clamped - fwd * (a_sz * 0.65) + right_v * (a_sz * 0.62)
	var p_l: Vector2 = p_clamped - fwd * (a_sz * 0.65) - right_v * (a_sz * 0.62)
	var p_notch: Vector2 = p_clamped - fwd * (a_sz * 0.25)
	draw_colored_polygon(PackedVector2Array([p_tip, p_r, p_notch, p_l]), Color(1.0, 0.98, 0.92, 1.0))
	draw_polyline(PackedVector2Array([p_tip, p_r, p_notch, p_l, p_tip]), Color(0.1, 0.14, 0.18, 0.95), 1.4, true)

	# --- 7. ORNATE GOLDEN FRAME + NORTH COMPASS BADGE ---
	if is_full_map:
		var rect := Rect2(c - Vector2(r, r), Vector2(r * 2.0, r * 2.0))
		draw_rect(rect, Color(0.92, 0.76, 0.34, 0.96), false, 2.5)
		draw_string(TITLE_FONT, Vector2(c.x - 6.0, c.y - r + 18.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.55, 0.42))
		draw_string(TITLE_FONT, Vector2(c.x - 5.0, c.y + r - 8.0), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.82, 0.86, 0.84, 0.75))
		draw_string(TITLE_FONT, Vector2(c.x + r - 18.0, c.y + 5.0), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.82, 0.86, 0.84, 0.75))
		draw_string(TITLE_FONT, Vector2(c.x - r + 8.0, c.y + 5.0), "W", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.82, 0.86, 0.84, 0.75))
	else:
		draw_arc(c, r, 0.0, TAU, 56, Color(0.92, 0.76, 0.34, 0.96), 2.6, true)
		draw_arc(c, r - 3.0, 0.0, TAU, 48, Color(0.36, 0.74, 0.66, 0.45), 1.0, true)
		# Crisp "N" north badge at top of rim
		var n_pos: Vector2 = Vector2(c.x, c.y - r + 1.0)
		draw_circle(n_pos, 9.5, Color(0.05, 0.08, 0.12, 0.98))
		draw_arc(n_pos, 9.5, 0.0, TAU, 20, Color(0.94, 0.78, 0.36, 0.96), 1.6, true)
		draw_string(TITLE_FONT, n_pos + Vector2(-4.8, 4.2), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.54, 0.40))


func _draw_stage_topology(layout_id: String, lvl: Node, c: Vector2, r: float, origin: Vector2, span: float, road_col: Color, glade_col: Color) -> void:
	if layout_id == "level_1" or layout_id == "level_2":
		# 1. Spawn plaza & Portal plaza
		for pz in [74.0, -72.0]:
			var pt: Vector2 = _world_to_canvas(0.0, pz, c, r, origin, span)
			var pr: float = (12.0 / span) * r
			if _inside_map(pt, c, r + pr):
				draw_circle(_clamp_to_map(pt, c, r - 2.0) if not _inside_map(pt, c, r) else pt, minf(pr, r * 0.25), glade_col)

		# 2. Side Glades / Courtyards + branch trails
		var glades: Array = []
		if lvl and lvl.has_method("_side_glades_for_stage"):
			glades = lvl._side_glades_for_stage()
		for g_var in glades:
			var g: Dictionary = g_var
			var gx: float = float(g["x"])
			var gz: float = float(g["z"])
			var gr: float = float(g["r"])
			var rx: float = lvl._path_center_x(gz) if (lvl and lvl.has_method("_path_center_x")) else 0.0
			var p_main: Vector2 = _world_to_canvas(rx, gz, c, r, origin, span)
			var p_glade: Vector2 = _world_to_canvas(gx, gz, c, r, origin, span)
			if _inside_map(p_main, c, r) or _inside_map(p_glade, c, r):
				draw_line(_clamp_to_map(p_main, c, r - 3.0), _clamp_to_map(p_glade, c, r - 3.0), road_col, 4.5 if is_full_map else 4.0, true)
			if _inside_map(p_glade, c, r - 4.0):
				draw_circle(p_glade, clampf((gr / span) * r, 8.0, 26.0), glade_col)

		# 3. Winding Main Road ribbon
		var pts := PackedVector2Array()
		for i in range(37):
			var z: float = lerpf(78.0, -76.0, float(i) / 36.0)
			var rx: float = lvl._path_center_x(z) if (lvl and lvl.has_method("_path_center_x")) else 0.0
			var mp: Vector2 = _world_to_canvas(rx, z, c, r, origin, span)
			if _inside_map(mp, c, r - 3.0):
				pts.append(mp)
			else:
				if pts.size() >= 2:
					draw_polyline(pts, road_col, 5.5 if is_full_map else 5.0, true)
				pts.clear()
		if pts.size() >= 2:
			draw_polyline(pts, road_col, 5.5 if is_full_map else 5.0, true)

	elif layout_id == "level_3":
		# Approach Bridge + Circular Boss Colosseum
		var b_start: Vector2 = _world_to_canvas(0.0, 74.0, c, r, origin, span)
		var b_end: Vector2 = _world_to_canvas(0.0, 18.0, c, r, origin, span)
		draw_line(_clamp_to_map(b_start, c, r - 3.0), _clamp_to_map(b_end, c, r - 3.0), road_col, 8.0, true)
		var ac: Vector2 = _world_to_canvas(0.0, -18.0, c, r, origin, span)
		var ar: float = (42.0 / span) * r
		if _inside_map(ac, c, r + ar):
			draw_circle(ac, minf(ar, r * 0.82), glade_col)
			draw_arc(ac, minf(ar, r * 0.82), 0.0, TAU, 40, road_col, 2.2, true)

	elif layout_id == "level_4":
		# Floating Celestial Sanctuary Islands & Starlight Bridges
		var islands: Array = [
			[0.0, 68.0, 14.0], [0.0, 26.0, 12.0], [-28.0, 0.0, 11.0],
			[28.0, 0.0, 11.0], [0.0, -14.0, 13.0], [0.0, -56.0, 22.0]
		]
		var bridges: Array = [
			[Vector2(0.0, 68.0), Vector2(0.0, 26.0)],
			[Vector2(0.0, 26.0), Vector2(0.0, -14.0)],
			[Vector2(0.0, -14.0), Vector2(0.0, -56.0)],
			[Vector2(0.0, 14.0), Vector2(-28.0, 0.0)],
			[Vector2(0.0, 14.0), Vector2(28.0, 0.0)],
		]
		for br in bridges:
			var p0: Vector2 = _world_to_canvas(br[0].x, br[0].y, c, r, origin, span)
			var p1: Vector2 = _world_to_canvas(br[1].x, br[1].y, c, r, origin, span)
			if _inside_map(p0, c, r) or _inside_map(p1, c, r):
				draw_line(_clamp_to_map(p0, c, r - 3.0), _clamp_to_map(p1, c, r - 3.0), road_col, 3.5, true)
		for isl in islands:
			var ip: Vector2 = _world_to_canvas(float(isl[0]), float(isl[1]), c, r, origin, span)
			if _inside_map(ip, c, r - 3.0):
				var ir: float = clampf((float(isl[2]) / span) * r, 7.0, 38.0)
				draw_circle(ip, ir, glade_col)
				draw_arc(ip, ir, 0.0, TAU, 24, road_col, 1.4, true)


func _inside_map(pt: Vector2, center: Vector2, rad: float) -> bool:
	if is_full_map:
		return absf(pt.x - center.x) <= rad and absf(pt.y - center.y) <= rad
	return pt.distance_to(center) <= rad


func _clamp_to_map(pt: Vector2, center: Vector2, rad: float) -> Vector2:
	if is_full_map:
		return Vector2(clampf(pt.x, center.x - rad, center.x + rad), clampf(pt.y, center.y - rad, center.y + rad))
	var d: Vector2 = pt - center
	if d.length() > rad and d.length() > 0.001:
		return center + d.normalized() * rad
	return pt


func _draw_diamond(pt: Vector2, rad: float, col: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			pt + Vector2(0.0, -rad),
			pt + Vector2(rad * 0.85, 0.0),
			pt + Vector2(0.0, rad),
			pt + Vector2(-rad * 0.85, 0.0),
		]),
		col
	)


func _draw_triangle(pt: Vector2, rad: float, col: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			pt + Vector2(0.0, -rad),
			pt + Vector2(rad * 0.9, rad * 0.75),
			pt + Vector2(-rad * 0.9, rad * 0.75),
		]),
		col
	)
