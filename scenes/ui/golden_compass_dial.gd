extends Control
## Ornate, Strictly Circular Golden Compass Dial (Custom _draw Vector Widget).
## Displays an engraved 8-point compass rose, rotating N/E/S/W cardinal letters synced to
## camera heading, a smooth glowing gold-and-crimson objective needle, and Pulse-ready aura.

const UI_FONT: Font = preload("res://resources/fonts/ui_font.tres")

var target_rel_angle: float = 0.0
var _display_angle: float = 0.0
var camera_heading: float = 0.0
var pulse_ready: float = 1.0
var _t: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(58.0, 58.0)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_compass_state(rel_angle: float, cam_head: float, cd_ratio: float) -> void:
	target_rel_angle = rel_angle
	camera_heading = cam_head
	pulse_ready = clampf(cd_ratio, 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	_display_angle = lerp_angle(_display_angle, target_rel_angle, clampf(delta * 14.0, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 2.0
	if r < 8.0:
		return

	# Pulse-ready subtle outer golden halo
	if pulse_ready >= 0.99:
		var glow_a: float = 0.22 + 0.14 * sin(_t * 3.6)
		draw_arc(c, r + 1.2, 0.0, TAU, 40, Color(1.0, 0.88, 0.36, glow_a), 2.5, true)

	# Dark twilight compass face
	draw_circle(c, r, Color(0.055, 0.095, 0.145, 0.98))
	draw_circle(c, r * 0.72, Color(0.075, 0.125, 0.185, 0.85))

	# Outer ornate metallic gold bezel + inner trim ring
	draw_arc(c, r, 0.0, TAU, 48, Color(0.94, 0.78, 0.36, 0.98), 2.4, true)
	draw_arc(c, r - 3.2, 0.0, TAU, 40, Color(0.42, 0.74, 0.66, 0.45), 1.0, true)

	# Rotating 8-point engraved ticks + N/E/S/W synced to camera heading
	var cardinals: Array = [
		{"ang": 0.0, "txt": "N", "col": Color(1.0, 0.52, 0.38, 0.98)},
		{"ang": PI * 0.5, "txt": "E", "col": Color(0.86, 0.88, 0.78, 0.72)},
		{"ang": PI, "txt": "S", "col": Color(0.86, 0.88, 0.78, 0.72)},
		{"ang": -PI * 0.5, "txt": "W", "col": Color(0.86, 0.88, 0.78, 0.72)},
	]
	for i in 8:
		var a: float = (float(i) * PI * 0.25) - camera_heading - PI * 0.5
		var dir: Vector2 = Vector2(cos(a), sin(a))
		var inner_len: float = r - (6.0 if (i % 2 == 0) else 4.2)
		var col: Color = Color(0.96, 0.82, 0.42, 0.75) if (i % 2 == 0) else Color(0.62, 0.76, 0.74, 0.42)
		draw_line(c + dir * inner_len, c + dir * (r - 1.5), col, 1.3, true)

	for cd_var in cardinals:
		var cd: Dictionary = cd_var
		var a: float = float(cd["ang"]) - camera_heading - PI * 0.5
		var pos: Vector2 = c + Vector2(cos(a), sin(a)) * (r - 10.5)
		var txt: String = String(cd["txt"])
		var fsize: int = 9 if txt == "N" else 8
		draw_string(UI_FONT, pos + Vector2(-3.2, 3.2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, cd["col"])

	# Rotating Golden Objective Needle (0 rad = straight up / ahead of camera)
	var up_dir: Vector2 = Vector2(sin(_display_angle), -cos(_display_angle))
	var right_dir: Vector2 = Vector2(cos(_display_angle), sin(_display_angle))

	var tip: Vector2 = c + up_dir * (r * 0.74)
	var tail: Vector2 = c - up_dir * (r * 0.48)
	var side_r: Vector2 = c + right_dir * (r * 0.24)
	var side_l: Vector2 = c - right_dir * (r * 0.24)

	# Drop shadow beneath needle
	var sh: Vector2 = Vector2(1.0, 1.6)
	draw_colored_polygon(PackedVector2Array([tip + sh, side_r + sh, tail + sh, side_l + sh]), Color(0.0, 0.0, 0.0, 0.45))

	# Front golden half (bright glowing pointer)
	draw_colored_polygon(PackedVector2Array([tip, side_r, c]), Color(1.0, 0.91, 0.44, 1.0))
	draw_colored_polygon(PackedVector2Array([tip, c, side_l]), Color(0.92, 0.72, 0.24, 1.0))

	# Rear counterweight tail (subtle teal-silver)
	draw_colored_polygon(PackedVector2Array([tail, side_l, c]), Color(0.32, 0.54, 0.58, 0.92))
	draw_colored_polygon(PackedVector2Array([tail, c, side_r]), Color(0.22, 0.38, 0.44, 0.92))

	# Center jewel pin
	draw_circle(c, 3.4, Color(0.18, 0.14, 0.08, 1.0))
	draw_circle(c, 2.2, Color(1.0, 0.94, 0.62, 1.0))
