extends CharacterBody3D
## 3D Woodland Explorer Controller — Pure Godot 4 (GDScript / WebGL2 gl_compatibility)
## Smooth 3rd-person orbit camera with SpringArm3D collision avoidance,
## WASD/Arrow movement, Space Jump + Double Jump (coyote + buffer), Shift Dash (i-frames + FOV kick),
## 3-Hit Melee Combo (LMB / J) + Golden Compass Arc Ranged Wave (RMB / K),
## Golden Compass Pulse [G] (shockwave + 16 firefly trail orbs + beacons + Astral Bridge & Boss Shield shatter),
## Interact [E], Healing Herb [H], Y < -20m failsafe respawn, and live QuestManager compass tracking.

const PlayerVisuals3D = preload("res://scenes/player/player_visuals_3d.gd")
const GOLDEN_ARC_SCRIPT = preload("res://scenes/player/golden_arc_3d.gd")

@export_group("Movement")
@export var walk_speed: float = 8.4
@export var sprint_speed: float = 12.2
@export var dash_speed: float = 21.5
@export var dash_duration: float = 0.24
@export var dash_cooldown_time: float = 1.1
@export var ground_accel: float = 52.0
@export var ground_friction: float = 56.0
@export var air_accel: float = 30.0
@export var air_friction: float = 10.0
@export var mouse_sensitivity: float = 0.0028
@export var key_turn_speed: float = 2.4

@export_group("Jumping & Gravity")
@export var allow_jump: bool = true
@export var jump_velocity: float = 12.6
@export var double_jump_velocity: float = 11.4
@export var gravity_value: float = 27.0
@export var fall_gravity_mult: float = 1.32
@export var max_fall_speed: float = 34.0
@export var coyote_time: float = 0.14
@export var jump_buffer_time: float = 0.12

@onready var visual_rig: Node3D = $VisualRig
@onready var body_pivot: Node3D = $VisualRig/BodyPivot
@onready var head_group: Node3D = $VisualRig/BodyPivot/HeadGroup
@onready var cloak_pivot: Node3D = $VisualRig/BodyPivot/CloakPivot
@onready var left_leg: Node3D = $VisualRig/BodyPivot/LeftLegPivot
@onready var right_leg: Node3D = $VisualRig/BodyPivot/RightLegPivot
@onready var left_arm: Node3D = $VisualRig/BodyPivot/LeftArmPivot
@onready var right_arm: Node3D = $VisualRig/BodyPivot/RightArmPivot
@onready var lantern_light: OmniLight3D = $VisualRig/BodyPivot/LeftArmPivot/LanternLight
@onready var attack_area: Area3D = $VisualRig/AttackArea
@onready var slash_arc: MeshInstance3D = $VisualRig/SlashArcMesh
@onready var hit_sparks: GPUParticles3D = $VisualRig/HitSparks
@onready var cam_yaw: Node3D = $CameraYaw
@onready var cam_pitch: Node3D = $CameraYaw/CameraPitch
@onready var spring_arm: SpringArm3D = $CameraYaw/CameraPitch/SpringArm3D
@onready var cam: Camera3D = $CameraYaw/CameraPitch/SpringArm3D/Camera3D
@onready var footstep_dust: GPUParticles3D = $FootstepDust

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var _air_jumps_left: int = 1
var is_attacking: bool = false
var is_invincible: bool = false
var is_dashing: bool = false
var input_locked: bool = false
var _was_on_floor: bool = true
var _hit_this_swing: Array[Node3D] = []
var _swing_active: bool = false
var _swing_damage: int = 18
var _attack_buffer_timer: float = 0.0
var _combo_reset_timer: float = 0.0
var _ranged_cooldown: float = 0.0
var _anim_t: float = 0.0
var _base_lantern_energy: float = 2.4
var _cloak_mat: ShaderMaterial = null
var _slash_mat: StandardMaterial3D = null
var _cam_base_pos: Vector3 = Vector3(0.36, 0.22, 0.0)
var _shake_tween: Tween = null
var _target_zoom: float = 7.0
var _target_fov: float = 64.0
var _combo_step: int = 0
var _dash_timer: float = 0.0
var _dash_cooldown: float = 0.0
var _dash_dir: Vector3 = Vector3.FORWARD
var _step_dist_accum: float = 0.0
var _prev_yaw: float = 0.0
var _l_knee: Node3D = null
var _r_knee: Node3D = null
var _l_elbow: Node3D = null
var _r_elbow: Node3D = null
var _lantern_swing: Node3D = null
var _compass_needle: Node3D = null
var _compass_pulse_cd: float = 0.0
var _compass_pulse_max_cd: float = 5.5
var _compass_ui_accum: float = 0.0
var _interact_scan_accum: float = 0.0
var _nearest_interactable: Node3D = null
var _last_prompt_visible: bool = false
var _last_prompt_text: String = ""
var _hitstop_active: bool = false
var _compass_mote_mat: StandardMaterial3D = null
var _compass_mote_mesh: SphereMesh = null


func _ready() -> void:
	add_to_group("player")
	if attack_area:
		attack_area.monitoring = false
		attack_area.body_entered.connect(_on_attack_hit)
		attack_area.area_entered.connect(_on_attack_area_hit)
	_cloak_mat = PlayerVisuals3D.enhance_explorer(self)
	_l_knee = left_leg.get_node_or_null("KneePivot") as Node3D
	_r_knee = right_leg.get_node_or_null("KneePivot") as Node3D
	_l_elbow = left_arm.get_node_or_null("ElbowPivot") as Node3D
	_r_elbow = right_arm.get_node_or_null("ElbowPivot") as Node3D
	if _l_elbow:
		_lantern_swing = _l_elbow.get_node_or_null("LanternSwingPivot") as Node3D
	_compass_needle = body_pivot.get_node_or_null("CompassBrooch/CompassBroochNeedle") as Node3D
	_setup_compass_vfx_assets()

	if slash_arc and slash_arc.material_override is StandardMaterial3D:
		_slash_mat = (slash_arc.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		slash_arc.material_override = _slash_mat
	if lantern_light:
		_base_lantern_energy = lantern_light.light_energy
	if spring_arm:
		spring_arm.collision_mask = 1
		spring_arm.spring_length = 7.0
		_target_zoom = spring_arm.spring_length
	if cam:
		_cam_base_pos = cam.position
		_target_fov = cam.fov
	_prev_yaw = visual_rig.rotation.y
	GameManager.dash_cooldown_changed.emit(1.0)
	GameManager.compass_pulse_cooldown_changed.emit(1.0)
	GameManager.set_gameplay_mouse()


func _setup_compass_vfx_assets() -> void:
	_compass_mote_mat = StandardMaterial3D.new()
	_compass_mote_mat.albedo_color = Color(1.0, 0.92, 0.45, 1.0)
	_compass_mote_mat.emission_enabled = true
	_compass_mote_mat.emission = Color(1.0, 0.84, 0.25, 1.0)
	_compass_mote_mat.emission_energy_multiplier = 3.6
	_compass_mote_mat.roughness = 0.2
	_compass_mote_mesh = SphereMesh.new()
	_compass_mote_mesh.radius = 0.14
	_compass_mote_mesh.height = 0.28


func _is_control_blocked() -> bool:
	return input_locked or GameManager.is_game_ended or GameManager.is_transitioning or GameManager.is_dialogue_open or GameManager.is_journal_open or get_tree().paused


func _unhandled_input(event: InputEvent) -> void:
	if _is_control_blocked():
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var sens: float = GameManager.mouse_sensitivity if GameManager.mouse_sensitivity > 0.0 else mouse_sensitivity
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		cam_yaw.rotate_y(-mm.relative.x * sens)
		var next_pitch: float = clampf(cam_pitch.rotation.x - mm.relative.y * sens, deg_to_rad(-52.0), deg_to_rad(28.0))
		cam_pitch.rotation.x = next_pitch
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_zoom = clampf(_target_zoom - 0.7, 4.2, 11.5)
				return
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_zoom = clampf(_target_zoom + 0.7, 4.2, 11.5)
				return
			elif Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
				if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
					GameManager.set_gameplay_mouse()
					return

	if event.is_action_pressed("jump") and allow_jump:
		jump_buffer_timer = jump_buffer_time
	elif event.is_action_pressed("attack"):
		_request_melee_attack()
	elif event.is_action_pressed("ranged_attack"):
		_trigger_golden_arc()
	elif event.is_action_pressed("dash") or event.is_action_pressed("dodge"):
		_try_dash()
	elif event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("compass_pulse"):
		_trigger_compass_pulse()
	elif event.is_action_pressed("heal"):
		_try_use_healing_herb()


func _physics_process(delta: float) -> void:
	# Always update compass needle & HUD target even if idle/dialogue
	_update_compass_tracking(delta)

	# Failsafe fall recovery (Y < -20m)
	if global_position.y < -20.0 and not GameManager.is_game_ended and not GameManager.is_transitioning:
		_trigger_fall_failsafe()
		return

	# Passive Compass Energy regeneration (+8/sec)
	if not GameManager.is_game_ended and not get_tree().paused:
		GameManager.modify_compass_energy(8.0 * delta)

	# Cooldowns
	if _dash_cooldown > 0.0:
		_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
		GameManager.dash_cooldown_changed.emit(clampf(1.0 - (_dash_cooldown / dash_cooldown_time), 0.0, 1.0))
	if _compass_pulse_cd > 0.0:
		_compass_pulse_cd = maxf(_compass_pulse_cd - delta, 0.0)
		GameManager.compass_pulse_cooldown_changed.emit(clampf(1.0 - (_compass_pulse_cd / _compass_pulse_max_cd), 0.0, 1.0))
	if _ranged_cooldown > 0.0:
		_ranged_cooldown = maxf(_ranged_cooldown - delta, 0.0)
	if _attack_buffer_timer > 0.0:
		_attack_buffer_timer = maxf(_attack_buffer_timer - delta, 0.0)
	if _combo_reset_timer > 0.0:
		_combo_reset_timer = maxf(_combo_reset_timer - delta, 0.0)
		if _combo_reset_timer <= 0.0:
			_combo_step = 0

	# Camera smooth zoom & dash FOV kick
	if spring_arm:
		spring_arm.spring_length = lerpf(spring_arm.spring_length, _target_zoom, clampf(delta * 10.0, 0.0, 1.0))
	if cam:
		var want_fov: float = 72.0 if is_dashing else _target_fov
		cam.fov = lerpf(cam.fov, want_fov, clampf(delta * 12.0, 0.0, 1.0))

	if _is_control_blocked():
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_friction * delta)
		if not is_on_floor():
			velocity.y = maxf(velocity.y - gravity_value * delta, -max_fall_speed)
		move_and_slide()
		_update_interact_scanner(delta, true)
		_animate_character(delta)
		return

	# Scan nearby interactables for floating [E] prompt
	_update_interact_scanner(delta, false)

	# Floor / Coyote / Double Jump tracking
	var on_floor_now: bool = is_on_floor()
	if on_floor_now:
		if not _was_on_floor and velocity.y < -4.0:
			if AudioManager:
				AudioManager.play_sfx("jump", 0.8, -5.0)
			if footstep_dust:
				footstep_dust.restart()
				footstep_dust.emitting = true
		coyote_timer = coyote_time
		_air_jumps_left = 1
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)
	_was_on_floor = on_floor_now

	# Jump buffer consumption (Ground/Coyote Jump or Double Jump)
	if jump_buffer_timer > 0.0:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
		if allow_jump:
			if coyote_timer > 0.0:
				velocity.y = jump_velocity
				coyote_timer = 0.0
				jump_buffer_timer = 0.0
				if AudioManager:
					AudioManager.play_sfx("jump", 1.02)
				if footstep_dust:
					footstep_dust.restart()
					footstep_dust.emitting = true
			elif _air_jumps_left > 0 and not on_floor_now:
				_air_jumps_left -= 1
				velocity.y = double_jump_velocity
				jump_buffer_timer = 0.0
				if AudioManager:
					AudioManager.play_sfx("jump", 1.24)
				_spawn_ring_burst(global_position + Vector3(0.0, 0.25, 0.0), Color(1.0, 0.88, 0.42), 1.4, 0.28)

	# Gravity
	if not is_on_floor():
		var g_mult: float = fall_gravity_mult if velocity.y < 0.0 else 1.0
		velocity.y = maxf(velocity.y - gravity_value * g_mult * delta, -max_fall_speed)

	# Directional Movement relative to CameraYaw
	var move_input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var cam_fwd: Vector3 = -cam_yaw.global_transform.basis.z
	cam_fwd.y = 0.0
	cam_fwd = cam_fwd.normalized() if cam_fwd.length_squared() > 0.001 else Vector3.FORWARD
	var cam_right: Vector3 = cam_yaw.global_transform.basis.x
	cam_right.y = 0.0
	cam_right = cam_right.normalized() if cam_right.length_squared() > 0.001 else Vector3.RIGHT

	var move_dir: Vector3 = (cam_right * move_input.x - cam_fwd * move_input.y)
	if move_dir.length_squared() > 1.0:
		move_dir = move_dir.normalized()

	if is_dashing:
		_dash_timer -= delta
		velocity.x = _dash_dir.x * dash_speed
		velocity.z = _dash_dir.z * dash_speed
		if _dash_timer <= 0.0:
			is_dashing = false
	else:
		var target_speed: float = sprint_speed if Input.is_action_pressed("sprint") else walk_speed
		if is_attacking:
			target_speed *= 0.48
		var accel: float = ground_accel if on_floor_now else air_accel
		var fric: float = ground_friction if on_floor_now else air_friction
		if move_dir.length_squared() > 0.01:
			velocity.x = move_toward(velocity.x, move_dir.x * target_speed, accel * delta)
			velocity.z = move_toward(velocity.z, move_dir.z * target_speed, accel * delta)
			var target_yaw: float = atan2(-move_dir.x, -move_dir.z)
			visual_rig.rotation.y = lerp_angle(visual_rig.rotation.y, target_yaw, clampf(delta * 14.0, 0.0, 1.0))
		else:
			velocity.x = move_toward(velocity.x, 0.0, fric * delta)
			velocity.z = move_toward(velocity.z, 0.0, fric * delta)

	move_and_slide()

	# Footstep cadence
	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horiz_speed > 1.8 and not is_dashing:
		_step_dist_accum += horiz_speed * delta
		if _step_dist_accum >= 2.35:
			_step_dist_accum = 0.0
			if AudioManager:
				AudioManager.play_sfx("footstep", randf_range(0.92, 1.12), -9.0)

	# Buffered combo follow-up
	if not is_attacking and _attack_buffer_timer > 0.0:
		_attack_buffer_timer = 0.0
		_perform_melee_attack()

	_animate_character(delta)


func _animate_character(delta: float) -> void:
	var hspeed: float = Vector2(velocity.x, velocity.z).length()
	var speed_norm: float = clampf(hspeed / sprint_speed, 0.0, 1.0)
	_anim_t += delta * lerpf(2.2, 11.5, speed_norm)

	if _cloak_mat:
		_cloak_mat.set_shader_parameter("move_speed_norm", clampf(speed_norm + (0.6 if is_dashing else 0.0), 0.0, 1.4))

	if body_pivot:
		var bob: float = absf(sin(_anim_t)) * 0.08 * speed_norm if is_on_floor() else 0.0
		body_pivot.position.y = lerpf(body_pivot.position.y, bob, clampf(delta * 16.0, 0.0, 1.0))
		var yaw_delta: float = angle_difference(_prev_yaw, visual_rig.rotation.y)
		_prev_yaw = visual_rig.rotation.y
		var bank: float = clampf(-yaw_delta * 2.2, -0.22, 0.22)
		body_pivot.rotation.z = lerpf(body_pivot.rotation.z, bank, clampf(delta * 10.0, 0.0, 1.0))
		body_pivot.rotation.x = lerpf(body_pivot.rotation.x, -0.14 * speed_norm - (0.22 if is_dashing else 0.0), clampf(delta * 10.0, 0.0, 1.0))

	if left_leg and right_leg:
		var stride: float = sin(_anim_t) * 0.72 * speed_norm if is_on_floor() else 0.35
		left_leg.rotation.x = lerpf(left_leg.rotation.x, stride, clampf(delta * 14.0, 0.0, 1.0))
		right_leg.rotation.x = lerpf(right_leg.rotation.x, -stride, clampf(delta * 14.0, 0.0, 1.0))
		if _l_knee:
			_l_knee.rotation.x = lerpf(_l_knee.rotation.x, maxf(-stride, 0.0) * 0.7, clampf(delta * 14.0, 0.0, 1.0))
		if _r_knee:
			_r_knee.rotation.x = lerpf(_r_knee.rotation.x, maxf(stride, 0.0) * 0.7, clampf(delta * 14.0, 0.0, 1.0))

	if left_arm:
		left_arm.rotation.x = lerpf(left_arm.rotation.x, 0.22 - sin(_anim_t) * 0.28 * speed_norm, clampf(delta * 12.0, 0.0, 1.0))
	if _lantern_swing:
		_lantern_swing.rotation.x = sin(_anim_t * 0.85) * 0.16 * (0.25 + speed_norm)
		_lantern_swing.rotation.z = cos(_anim_t * 0.65) * 0.1 * (0.25 + speed_norm)

	if right_arm and not is_attacking:
		right_arm.rotation.x = lerpf(right_arm.rotation.x, -0.15 + sin(_anim_t) * 0.35 * speed_norm, clampf(delta * 12.0, 0.0, 1.0))
		right_arm.rotation.y = lerpf(right_arm.rotation.y, 0.0, clampf(delta * 12.0, 0.0, 1.0))

	if cloak_pivot:
		var cloak_lift: float = 0.28 + speed_norm * 0.42 + (0.38 if is_dashing else 0.0) + (0.24 if not is_on_floor() else 0.0)
		cloak_pivot.rotation.x = lerpf(cloak_pivot.rotation.x, cloak_lift, clampf(delta * 8.0, 0.0, 1.0))


# ==============================================================================
# COMBAT — 3-HIT MELEE COMBO & GOLDEN COMPASS ARC RANGED WAVE
# ==============================================================================
func _request_melee_attack() -> void:
	if is_attacking:
		_attack_buffer_timer = 0.24
		return
	_perform_melee_attack()


func _perform_melee_attack() -> void:
	is_attacking = true
	_swing_active = true
	_hit_this_swing.clear()
	_combo_step = (_combo_step % 3) + 1
	_combo_reset_timer = 0.95

	var base_dmg: int = maxi(GameManager.attack_damage, 12)
	var mult: float = 1.0
	var sfx_name: String = "sword_1"
	var arc_color: Color = Color(0.55, 0.95, 1.0, 0.86)
	if _combo_step == 2:
		mult = 1.18
		sfx_name = "sword_2"
		arc_color = Color(0.75, 0.96, 1.0, 0.9)
	elif _combo_step == 3:
		mult = 1.65
		sfx_name = "sword_3"
		arc_color = Color(1.0, 0.86, 0.34, 0.95)

	_swing_damage = int(round(float(base_dmg) * mult))

	# Snap facing toward camera forward if standing still
	var fwd: Vector3 = -visual_rig.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.001 else Vector3.FORWARD
	velocity.x += fwd.x * (6.5 if _combo_step == 3 else 3.8)
	velocity.z += fwd.z * (6.5 if _combo_step == 3 else 3.8)

	if AudioManager:
		AudioManager.play_sfx(sfx_name)

	if attack_area:
		attack_area.monitoring = true
		# Also immediately check overlapping bodies in case enemy is already inside hitbox
		for b in attack_area.get_overlapping_bodies():
			_on_attack_hit(b)

	if slash_arc:
		slash_arc.visible = true
		slash_arc.scale = Vector3(1.15, 0.22, 1.15) * (1.28 if _combo_step == 3 else 1.0)
		slash_arc.rotation = Vector3(0.0, deg_to_rad(-42.0 if _combo_step == 1 else (42.0 if _combo_step == 2 else 0.0)), deg_to_rad(14.0 if _combo_step == 2 else -14.0))
		if _slash_mat:
			_slash_mat.albedo_color = arc_color
			_slash_mat.emission = Color(arc_color.r, arc_color.g, arc_color.b, 1.0)
			_slash_mat.emission_energy_multiplier = 3.2 if _combo_step == 3 else 2.4

	if right_arm:
		var tw: Tween = create_tween()
		var swing_y: float = -1.35 if _combo_step == 2 else 1.35
		tw.tween_property(right_arm, "rotation", Vector3(deg_to_rad(72.0), swing_y, 0.0), 0.09)
		tw.tween_property(right_arm, "rotation", Vector3(deg_to_rad(-18.0), -swing_y * 0.4, 0.0), 0.14)

	var active_time: float = 0.20 if _combo_step == 3 else 0.16
	var recov_time: float = 0.16 if _combo_step == 3 else 0.11
	await get_tree().create_timer(active_time).timeout
	_swing_active = false
	if attack_area:
		attack_area.monitoring = false
	if slash_arc:
		slash_arc.visible = false
	await get_tree().create_timer(recov_time).timeout
	is_attacking = false


func _on_attack_area_hit(area: Area3D) -> void:
	if area and area.get_parent() is Node3D:
		_on_attack_hit(area.get_parent() as Node3D)


func _on_attack_hit(body: Node3D) -> void:
	if not _swing_active or body == null or body == self:
		return
	if body in _hit_this_swing:
		return
	if body.has_method("take_damage"):
		_hit_this_swing.append(body)
		var dir: Vector3 = (body.global_position - global_position)
		dir.y = 0.0
		dir = dir.normalized() if dir.length_squared() > 0.001 else -visual_rig.global_transform.basis.z
		body.take_damage(_swing_damage, dir * (11.0 if _combo_step == 3 else 7.5))
		GameManager.modify_compass_energy(12.0)
		if AudioManager:
			AudioManager.play_sfx("hit_impact", 1.1 if _combo_step == 3 else 1.0)
		if hit_sparks:
			hit_sparks.restart()
			hit_sparks.emitting = true
		_camera_shake(0.18 if _combo_step == 3 else 0.09, 0.14)
		_trigger_hitstop(0.04)


func _trigger_golden_arc() -> void:
	if _ranged_cooldown > 0.0 or is_attacking:
		return
	if not GameManager.consume_compass_energy(25.0):
		GameManager.post_toast("LOW COMPASS ENERGY", "Strike foes or wait briefly to recharge (25 Energy needed)", Color(0.95, 0.65, 0.35))
		return

	_ranged_cooldown = 0.45
	var fwd: Vector3 = -cam_yaw.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.001 else -visual_rig.global_transform.basis.z
	visual_rig.rotation.y = atan2(-fwd.x, -fwd.z)

	var proj: Area3D = Area3D.new()
	proj.set_script(GOLDEN_ARC_SCRIPT)
	proj.set("direction", fwd)
	proj.set("damage", int(round(float(GameManager.attack_damage) * 1.45)))
	proj.global_position = global_position + Vector3(0.0, 1.25, 0.0) + fwd * 1.15
	get_tree().current_scene.add_child(proj)

	if AudioManager:
		AudioManager.play_sfx("golden_arc")
	_camera_shake(0.1, 0.1)


func _try_dash() -> void:
	if is_dashing or _dash_cooldown > 0.0:
		return
	var move_input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var cam_fwd: Vector3 = -cam_yaw.global_transform.basis.z
	cam_fwd.y = 0.0
	cam_fwd = cam_fwd.normalized() if cam_fwd.length_squared() > 0.001 else Vector3.FORWARD
	var cam_right: Vector3 = cam_yaw.global_transform.basis.x
	cam_right.y = 0.0
	cam_right = cam_right.normalized() if cam_right.length_squared() > 0.001 else Vector3.RIGHT

	var d: Vector3 = cam_right * move_input.x - cam_fwd * move_input.y
	if d.length_squared() > 0.01:
		_dash_dir = d.normalized()
	else:
		_dash_dir = -visual_rig.global_transform.basis.z
		_dash_dir.y = 0.0
		_dash_dir = _dash_dir.normalized() if _dash_dir.length_squared() > 0.001 else Vector3.FORWARD

	visual_rig.rotation.y = atan2(-_dash_dir.x, -_dash_dir.z)
	is_dashing = true
	_dash_timer = dash_duration
	_dash_cooldown = dash_cooldown_time
	GameManager.dash_cooldown_changed.emit(0.0)

	if AudioManager:
		AudioManager.play_sfx("dash")
	_spawn_ring_burst(global_position + Vector3(0.0, 0.5, 0.0), Color(0.55, 0.96, 1.0), 1.8, 0.25)
	_grant_dash_iframes(0.35)


func _grant_dash_iframes(duration: float) -> void:
	is_invincible = true
	await get_tree().create_timer(duration).timeout
	is_invincible = false


# ==============================================================================
# INTERACT [E] & HEALING HERB [H]
# ==============================================================================
func _update_interact_scanner(delta: float, force_hide: bool) -> void:
	if force_hide:
		if _last_prompt_visible:
			_last_prompt_visible = false
			_last_prompt_text = ""
			GameManager.interact_prompt_changed.emit(false, "")
		return

	_interact_scan_accum += delta
	if _interact_scan_accum < 0.08:
		return
	_interact_scan_accum = 0.0

	var best: Node3D = null
	var best_d: float = 3.7 * 3.7
	for n_var in get_tree().get_nodes_in_group("interactable"):
		var n: Node3D = n_var as Node3D
		if not n or not is_instance_valid(n) or not n.is_inside_tree():
			continue
		if n.has_method("can_interact") and not bool(n.can_interact()):
			continue
		var d_sq: float = global_position.distance_squared_to(n.global_position)
		if d_sq < best_d:
			best_d = d_sq
			best = n

	_nearest_interactable = best
	if best:
		var prompt: String = "[E] Interact"
		if best.has_method("get_interact_prompt"):
			prompt = String(best.get_interact_prompt())
		if not _last_prompt_visible or _last_prompt_text != prompt:
			_last_prompt_visible = true
			_last_prompt_text = prompt
			GameManager.interact_prompt_changed.emit(true, prompt)
	else:
		if _last_prompt_visible:
			_last_prompt_visible = false
			_last_prompt_text = ""
			GameManager.interact_prompt_changed.emit(false, "")


func _try_interact() -> void:
	if _nearest_interactable and is_instance_valid(_nearest_interactable) and _nearest_interactable.has_method("interact"):
		_nearest_interactable.interact(self)


func _try_use_healing_herb() -> void:
	if GameManager.use_healing_herb():
		if AudioManager:
			AudioManager.play_sfx("heal")
		_spawn_ring_burst(global_position + Vector3(0.0, 0.85, 0.0), Color(0.32, 0.98, 0.56), 2.4, 0.45)
		GameManager.post_toast("HEALING HERB USED", "+2 Vitality restored", Color(0.42, 0.96, 0.62))
	elif GameManager.healing_herbs <= 0:
		GameManager.post_toast("NO HEALING HERBS", "Open hidden chests to gather more herbs", Color(0.95, 0.65, 0.35))
	else:
		GameManager.post_toast("VITALITY FULL", "Your health is already at maximum", Color(0.65, 0.92, 0.85))


# ==============================================================================
# GOLDEN COMPASS PULSE [G] & LIVE OBJECTIVE TRACKING
# ==============================================================================
func _update_compass_tracking(delta: float) -> void:
	_compass_ui_accum += delta
	if _compass_ui_accum < 0.06:
		return
	_compass_ui_accum = 0.0

	var target_info: Dictionary = QuestManager.get_active_compass_target(global_position)
	var tgt_pos: Vector3 = target_info.get("position", global_position + Vector3(0.0, 0.0, -50.0))
	var label: String = String(target_info.get("label", "Northern Trail"))

	var to_tgt: Vector3 = tgt_pos - global_position
	var dist_m: float = Vector2(to_tgt.x, to_tgt.z).length()
	var world_angle: float = atan2(to_tgt.x, -to_tgt.z)
	var cam_heading: float = -cam_yaw.rotation.y
	var rel_angle: float = wrapf(world_angle - cam_heading, -PI, PI)

	if _compass_needle:
		var rig_rel: float = wrapf(world_angle + visual_rig.rotation.y, -PI, PI)
		_compass_needle.rotation.y = lerp_angle(_compass_needle.rotation.y, -rig_rel, 0.25)

	GameManager.compass_updated.emit(rel_angle, dist_m, label)


func _trigger_compass_pulse() -> void:
	if _compass_pulse_cd > 0.0:
		return
	_compass_pulse_cd = _compass_pulse_max_cd
	GameManager.compass_pulse_cooldown_changed.emit(0.0)

	if AudioManager:
		AudioManager.play_sfx("compass_pulse")
	_camera_shake(0.14, 0.22)

	# 1. Expanding golden shockwave ring from Explorer
	_spawn_ring_burst(global_position + Vector3(0.0, 0.28, 0.0), Color(1.0, 0.88, 0.36), 18.0, 0.85)

	# 2. Lantern flare surge
	if lantern_light:
		var tw: Tween = create_tween()
		tw.tween_property(lantern_light, "light_energy", _base_lantern_energy * 2.6, 0.14)
		tw.tween_property(lantern_light, "light_energy", _base_lantern_energy, 0.55)

	# 3. 16 Glowing golden firefly orbs flowing toward active quest target
	var target_info: Dictionary = QuestManager.get_active_compass_target(global_position)
	var tgt_pos: Vector3 = target_info.get("position", global_position + Vector3(0.0, 0.0, -40.0))
	_spawn_compass_trail_orbs(tgt_pos)

	# 4. Highlight chests, shards, traps, lore runestones within 45m for 10s
	for grp in ["chest", "shard", "trap", "lore_runestone", "rune_pillar"]:
		for n_var in get_tree().get_nodes_in_group(grp):
			var n: Node3D = n_var as Node3D
			if n and is_instance_valid(n) and global_position.distance_to(n.global_position) <= 45.0:
				if n.has_method("highlight_compass_beacon"):
					n.highlight_compass_beacon(10.0)

	# 5. Stage 4: Illuminate hidden Astral Light Bridges within 28m
	for b_var in get_tree().get_nodes_in_group("astral_bridge"):
		var bridge: Node3D = b_var as Node3D
		if bridge and is_instance_valid(bridge) and global_position.distance_to(bridge.global_position) <= 28.0:
			if bridge.has_method("illuminate_by_compass"):
				bridge.illuminate_by_compass()

	# 6. Stage 4 Final Boss: Shatter Aurelius's Astral Aegis Shield within 38m
	for boss_var in get_tree().get_nodes_in_group("astral_boss"):
		var boss: Node3D = boss_var as Node3D
		if boss and is_instance_valid(boss) and global_position.distance_to(boss.global_position) <= 38.0:
			if boss.has_method("shatter_shield_by_compass"):
				boss.shatter_shield_by_compass()


func _spawn_compass_trail_orbs(target_pos: Vector3) -> void:
	var start_pos: Vector3 = global_position + Vector3(0.0, 1.35, 0.0)
	var dir: Vector3 = target_pos - start_pos
	var dist: float = clampf(dir.length(), 6.0, 34.0)
	var flat_dir: Vector3 = dir.normalized() if dir.length_squared() > 0.01 else Vector3.FORWARD
	var side_vec: Vector3 = flat_dir.cross(Vector3.UP).normalized()
	if side_vec.length_squared() < 0.01:
		side_vec = Vector3.RIGHT

	for i in 16:
		var t: float = float(i + 1) / 16.0
		var orb: MeshInstance3D = MeshInstance3D.new()
		orb.mesh = _compass_mote_mesh
		orb.material_override = _compass_mote_mat
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_tree().current_scene.add_child(orb)
		orb.global_position = start_pos

		var end_p: Vector3 = start_pos + flat_dir * (dist * t)
		end_p.y = lerpf(start_pos.y, target_pos.y + 1.4, t) + sin(t * PI) * 2.2
		end_p += side_vec * sin(float(i) * 0.9) * 0.85

		var tw: Tween = orb.create_tween()
		tw.tween_interval(float(i) * 0.035)
		tw.tween_property(orb, "global_position", end_p, 0.72 + t * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(orb, "scale", Vector3(1.25, 1.25, 1.25), 0.35)
		tw.tween_property(orb, "scale", Vector3(0.01, 0.01, 0.01), 0.35)
		tw.tween_callback(orb.queue_free)


func _spawn_ring_burst(center: Vector3, col: Color, max_radius: float, duration: float) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 10
	ring.mesh = tm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(col.r, col.g, col.b, 0.85)
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 3.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = mat
	get_tree().current_scene.add_child(ring)
	ring.global_position = center
	ring.scale = Vector3(0.3, 0.15, 0.3)

	var tw: Tween = ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(max_radius, 0.15, max_radius), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(ring.queue_free)


# ==============================================================================
# DAMAGE, HITSTOP, SHAKE & FALL FAILSAFE
# ==============================================================================
func take_damage(amount: int, knockback: Vector3 = Vector3.ZERO) -> void:
	if is_invincible or GameManager.is_game_ended or GameManager.is_transitioning:
		return
	is_invincible = true
	GameManager.damage_player(amount)
	if AudioManager:
		AudioManager.play_sfx("player_hurt")
	_camera_shake(0.24, 0.22)

	if knockback.length_squared() > 0.01:
		velocity.x = knockback.x
		velocity.z = knockback.z
		velocity.y = maxf(velocity.y, 4.8)

	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("flash_damage_vignette"):
		hud.flash_damage_vignette()

	# Blink visual rig during 1.0s i-frames
	var blink_t: float = 0.0
	while blink_t < 1.0:
		if not is_inside_tree():
			return
		if body_pivot:
			body_pivot.visible = not body_pivot.visible
		await get_tree().create_timer(0.1).timeout
		blink_t += 0.1
	if body_pivot:
		body_pivot.visible = true
	is_invincible = false


func _trigger_fall_failsafe() -> void:
	GameManager.damage_player(1)
	if GameManager.is_game_ended:
		return
	global_position = GameManager.checkpoint_position + Vector3(0.0, 0.65, 0.0)
	velocity = Vector3.ZERO
	GameManager.post_toast("RETURNED TO SAFE GROUND", "Fell into the abyss (-1 Vitality)", Color(1.0, 0.58, 0.36))


func _trigger_hitstop(duration: float) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = 0.08
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


func _camera_shake(intensity: float, duration: float) -> void:
	if not cam:
		return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	var steps: int = 5
	for i in steps:
		var damp: float = 1.0 - (float(i) / float(steps))
		var offset: Vector3 = Vector3(randf_range(-intensity, intensity) * damp, randf_range(-intensity, intensity) * damp, 0.0)
		_shake_tween.tween_property(cam, "position", _cam_base_pos + offset, duration / float(steps))
	_shake_tween.tween_property(cam, "position", _cam_base_pos, 0.05)
