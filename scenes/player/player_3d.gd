extends CharacterBody3D
## 3D Woodland Explorer with sculpted equipment, cloth cape shader physics,
## dynamic camera zoom (Mouse Wheel), 2-hit melee combo with fading crescent ribbon,
## tactical Evade Dash with light surge, breathing/banking/pendulum lantern animations,
## stride-synced moss footsteps, coyote time, jump buffering, and i-frames.

const PlayerVisuals3D = preload("res://scenes/player/player_visuals_3d.gd")

@export_group("Movement")
@export var walk_speed: float = 7.8
@export var sprint_speed: float = 11.6
@export var dash_speed: float = 20.5
@export var dash_duration: float = 0.25
@export var dash_cooldown_time: float = 0.50
@export var ground_accel: float = 52.0
@export var ground_friction: float = 58.0
@export var air_accel: float = 28.0
@export var air_friction: float = 12.0
@export var mouse_sensitivity: float = 0.0028
@export var key_turn_speed: float = 2.4

@export_group("Jumping & Gravity")
@export var allow_jump: bool = false
@export var jump_velocity: float = 13.5
@export var gravity_value: float = 26.0
@export var fall_gravity_mult: float = 1.32
@export var max_fall_speed: float = 34.0
@export var coyote_time: float = 0.14
@export var jump_buffer_time: float = 0.14

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
@onready var jump_sfx: AudioStreamPlayer = $Audio/Jump
@onready var land_sfx: AudioStreamPlayer = $Audio/Land
@onready var swing_sfx: AudioStreamPlayer = $Audio/AttackSwing
@onready var hurt_sfx: AudioStreamPlayer = $Audio/Hurt
@onready var footstep_sfx: AudioStreamPlayer = $Audio/Footstep
@onready var dash_sfx: AudioStreamPlayer = $Audio/Dash

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_attacking: bool = false
var is_invincible: bool = false
var is_dashing: bool = false
var input_locked: bool = false
var _was_on_floor: bool = true
var _hit_this_swing: Array[Node3D] = []
var _swing_active: bool = false
var _swing_damage: int = 1
var _attack_buffer_timer: float = 0.0
var _combo_reset_timer: float = 0.0
var _anim_t: float = 0.0
var _base_lantern_energy: float = 2.9
var _cloak_mat: ShaderMaterial = null
var _slash_mat: StandardMaterial3D = null
var _cam_base_pos: Vector3 = Vector3(0.36, 0.22, 0.0)
var _shake_tween: Tween = null
var _target_zoom: float = 6.6
var _combo_step: int = 0
var _dash_timer: float = 0.0
var _dash_cooldown: float = 0.0
var _dash_dir: Vector3 = Vector3.FORWARD
var _step_dist_accum: float = 0.0
var _prev_yaw: float = 0.0
var _auto_run: bool = false
var _l_knee: Node3D = null
var _r_knee: Node3D = null
var _l_elbow: Node3D = null
var _r_elbow: Node3D = null
var _lantern_swing: Node3D = null


func _ready() -> void:
	add_to_group("player")
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_hit)
	_cloak_mat = PlayerVisuals3D.enhance_explorer(self)
	_l_knee = left_leg.get_node_or_null("KneePivot") as Node3D
	_r_knee = right_leg.get_node_or_null("KneePivot") as Node3D
	_l_elbow = left_arm.get_node_or_null("ElbowPivot") as Node3D
	_r_elbow = right_arm.get_node_or_null("ElbowPivot") as Node3D
	if _l_elbow:
		_lantern_swing = _l_elbow.get_node_or_null("LanternSwingPivot") as Node3D
	if slash_arc and slash_arc.material_override is StandardMaterial3D:
		_slash_mat = (slash_arc.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		slash_arc.material_override = _slash_mat
	if lantern_light:
		_base_lantern_energy = lantern_light.light_energy
	if spring_arm:
		_target_zoom = spring_arm.spring_length
	if cam:
		_cam_base_pos = cam.position
	_prev_yaw = visual_rig.rotation.y
	GameManager.dash_cooldown_changed.emit(1.0)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_game_ended or get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_auto_run = not _auto_run
		var msg := "Continuous Auto-Run ON (Steer with Mouse / A-D, S to Stop)" if _auto_run else "Auto-Run OFF"
		GameManager.notification_posted.emit(msg, Color(0.55, 0.96, 0.88))
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = clampf(_target_zoom - 0.65, 3.6, 13.5)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = clampf(_target_zoom + 0.65, 3.6, 13.5)
			return
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var sens := GameManager.mouse_sensitivity if GameManager.mouse_sensitivity > 0.0 else mouse_sensitivity
		cam_yaw.rotate_y(-event.relative.x * sens)
		cam_pitch.rotation.x = clampf(cam_pitch.rotation.x - event.relative.y * sens, deg_to_rad(-55.0), deg_to_rad(18.0))


func _physics_process(delta: float) -> void:
	if GameManager.is_game_ended:
		return

	_anim_t += delta
	if lantern_light:
		var boost := 1.4 if is_dashing else 0.0
		lantern_light.light_energy = _base_lantern_energy + boost + sin(_anim_t * 6.5) * 0.16 + sin(_anim_t * 14.0) * 0.08
	if spring_arm:
		spring_arm.spring_length = lerpf(spring_arm.spring_length, _target_zoom, 9.5 * delta)

	if _dash_cooldown > 0.0:
		_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
		GameManager.dash_cooldown_changed.emit(1.0 - (_dash_cooldown / dash_cooldown_time))
	if _attack_buffer_timer > 0.0:
		_attack_buffer_timer = maxf(_attack_buffer_timer - delta, 0.0)
	if _combo_reset_timer > 0.0:
		_combo_reset_timer = maxf(_combo_reset_timer - delta, 0.0)
		if _combo_reset_timer <= 0.0 and not is_attacking:
			_combo_step = 0

	var cam_turn := Input.get_axis("cam_right", "cam_left")
	if cam_turn != 0.0:
		cam_yaw.rotate_y(cam_turn * key_turn_speed * delta)

	var on_floor_now := is_on_floor()
	if on_floor_now and not _was_on_floor:
		_on_landed()
	_was_on_floor = on_floor_now

	_apply_gravity(delta, on_floor_now)

	if is_dashing:
		_dash_timer -= delta
		velocity.x = _dash_dir.x * dash_speed
		velocity.z = _dash_dir.z * dash_speed
		if _dash_timer <= 0.0:
			is_dashing = false
	elif not input_locked:
		if allow_jump:
			_handle_jump(delta)
		_handle_horizontal(delta, on_floor_now)
		if Input.is_action_just_pressed("dodge") and _dash_cooldown <= 0.0:
			_perform_dash()
		if Input.is_action_just_pressed("attack"):
			_attack_buffer_timer = 0.18
		if _attack_buffer_timer > 0.0 and not is_attacking:
			_attack_buffer_timer = 0.0
			_perform_attack()
	else:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_friction * delta)

	if cam:
		var is_sprinting := Input.is_action_pressed("sprint") and Vector2(velocity.x, velocity.z).length() > walk_speed * 0.9
		var desired_fov := 72.0 if is_dashing else (68.5 if is_sprinting else 64.0)
		cam.fov = lerpf(cam.fov, desired_fov, 7.5 * delta)

	move_and_slide()
	if _swing_active:
		_scan_sword_hits()
	_update_procedural_anim(delta, on_floor_now)


func _apply_gravity(delta: float, on_floor_now: bool) -> void:
	if on_floor_now:
		coyote_timer = coyote_time
		return
	var mult := fall_gravity_mult if velocity.y < 0.0 else 1.0
	velocity.y = maxf(velocity.y - gravity_value * mult * delta, -max_fall_speed)
	coyote_timer -= delta


func _handle_jump(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		_play_sfx(jump_sfx, 0.96, 1.06)
		_squash_stretch(Vector3(0.84, 1.2, 0.84))
		if footstep_dust:
			footstep_dust.restart()
			footstep_dust.emitting = true

	if Input.is_action_just_released("jump") and velocity.y > 4.5:
		velocity.y *= 0.52


func _get_camera_move_dir() -> Vector3:
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _auto_run:
		if input_vec.y > 0.35:
			_auto_run = false
		elif input_vec.y >= -0.1:
			input_vec.y = -1.0
	var basis := cam_yaw.global_transform.basis
	var forward := -basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := basis.x
	right.y = 0.0
	right = right.normalized()
	var move_dir := (right * input_vec.x - forward * input_vec.y)
	if move_dir.length() > 1.0:
		move_dir = move_dir.normalized()
	return move_dir


func _handle_horizontal(delta: float, on_floor_now: bool) -> void:
	var move_dir := _get_camera_move_dir()
	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var accel := ground_accel if on_floor_now else air_accel
	var fric := ground_friction if on_floor_now else air_friction

	if move_dir.length() > 0.05:
		velocity.x = move_toward(velocity.x, move_dir.x * target_speed, accel * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * target_speed, accel * delta)
		var target_yaw := atan2(-move_dir.x, -move_dir.z)
		visual_rig.rotation.y = lerp_angle(visual_rig.rotation.y, target_yaw, 14.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)
		velocity.z = move_toward(velocity.z, 0.0, fric * delta)


func _perform_dash() -> void:
	var move_dir := _get_camera_move_dir()
	if move_dir.length() < 0.05:
		move_dir = -visual_rig.global_transform.basis.z
		move_dir.y = 0.0
		move_dir = move_dir.normalized()
	_dash_dir = move_dir
	visual_rig.rotation.y = atan2(-move_dir.x, -move_dir.z)
	is_dashing = true
	_dash_timer = dash_duration
	_dash_cooldown = dash_cooldown_time
	GameManager.dash_cooldown_changed.emit(0.0)
	_play_sfx(dash_sfx, 0.94, 1.08)
	_squash_stretch(Vector3(0.8, 0.88, 1.28))
	if footstep_dust:
		footstep_dust.restart()
		footstep_dust.emitting = true


func _on_landed() -> void:
	_play_sfx(land_sfx, 0.92, 1.08)
	_squash_stretch(Vector3(1.18, 0.82, 1.18))
	if footstep_dust:
		footstep_dust.restart()
		footstep_dust.emitting = true


func _squash_stretch(target_scale: Vector3) -> void:
	if not body_pivot:
		return
	body_pivot.scale = target_scale
	var tw := create_tween()
	tw.tween_property(body_pivot, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _aim_rig_for_attack() -> void:
	var cam_fwd := -cam_yaw.global_transform.basis.z
	cam_fwd.y = 0.0
	if cam_fwd.length() > 0.01:
		cam_fwd = cam_fwd.normalized()
	else:
		cam_fwd = -visual_rig.global_transform.basis.z

	var best_enemy: Node3D = null
	var best_score := -999.0
	for e_var in get_tree().get_nodes_in_group("enemies"):
		var enemy := e_var as Node3D
		if not enemy or not is_instance_valid(enemy):
			continue
		if ("state" in enemy and int(enemy.get("state")) == 2) or ("is_defeated" in enemy and bool(enemy.get("is_defeated"))):
			continue
		var flat := enemy.global_position - global_position
		flat.y = 0.0
		var dist := flat.length()
		if dist > 5.0 or dist < 0.05:
			continue
		var dir := flat / dist
		var dot_cam := cam_fwd.dot(dir)
		if dot_cam < 0.15 and dist > 2.4:
			continue
		var score := dot_cam * 2.2 - dist * 0.25
		if score > best_score:
			best_score = score
			best_enemy = enemy

	var aim_dir := cam_fwd
	if best_enemy:
		var to_e := best_enemy.global_position - global_position
		to_e.y = 0.0
		if to_e.length() > 0.05:
			aim_dir = to_e.normalized()
	else:
		var move_dir := _get_camera_move_dir()
		if move_dir.length() > 0.1:
			aim_dir = move_dir.normalized()

	visual_rig.rotation.y = atan2(-aim_dir.x, -aim_dir.z)


func _perform_attack() -> void:
	is_attacking = true
	_swing_active = true
	_hit_this_swing.clear()
	_aim_rig_for_attack()

	var step_idx := _combo_step
	_combo_step = (_combo_step + 1) % 3
	_combo_reset_timer = 0.9
	var is_finisher := (step_idx == 2)
	_swing_damage = 2 if is_finisher else 1

	_play_sfx(swing_sfx, 0.92 if step_idx == 0 else (1.05 if step_idx == 1 else 0.82), 1.04 if step_idx == 0 else (1.18 if step_idx == 1 else 0.92))
	attack_area.monitoring = true

	var lunge_dir := -visual_rig.global_transform.basis.z
	lunge_dir.y = 0.0
	if lunge_dir.length() > 0.01:
		lunge_dir = lunge_dir.normalized()
	var lunge_spd := 6.4 if is_finisher else 4.6
	velocity.x += lunge_dir.x * lunge_spd
	velocity.z += lunge_dir.z * lunge_spd

	var a_start := deg_to_rad(-68.0) if step_idx == 0 else (deg_to_rad(70.0) if step_idx == 1 else deg_to_rad(-82.0))
	var a_end := deg_to_rad(76.0) if step_idx == 0 else (deg_to_rad(-72.0) if step_idx == 1 else deg_to_rad(88.0))

	if body_pivot:
		var torso_tw := create_tween()
		body_pivot.rotation.y = -a_start * 0.25
		torso_tw.tween_property(body_pivot, "rotation:y", -a_end * 0.22, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		torso_tw.tween_property(body_pivot, "rotation:y", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if right_arm:
		right_arm.rotation = Vector3(deg_to_rad(62.0 if is_finisher else 54.0), a_start * 0.68, 0.0)
		var rtw := create_tween()
		rtw.tween_property(right_arm, "rotation:y", a_end * 0.72, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _r_elbow:
		_r_elbow.rotation.x = 0.55 if is_finisher else 0.42

	if slash_arc:
		slash_arc.visible = true
		slash_arc.rotation.y = a_start
		slash_arc.scale = Vector3(0.95, 0.22, 0.95) if is_finisher else Vector3(0.88, 0.18, 0.88)
		if _slash_mat:
			var col := Color(1.0, 0.92, 0.45, 0.96) if is_finisher else Color(0.55, 0.96, 1.0, 0.92)
			_slash_mat.albedo_color = col
			_slash_mat.emission = Color(1.0, 0.85, 0.35, 1.0) if is_finisher else Color(0.45, 0.94, 1.0, 1.0)
		var end_sc := Vector3(1.52, 0.3, 1.52) if is_finisher else Vector3(1.36, 0.26, 1.36)
		var stw := create_tween().set_parallel(true)
		stw.tween_property(slash_arc, "rotation:y", a_end, 0.17).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		stw.tween_property(slash_arc, "scale", end_sc, 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if _slash_mat:
			stw.tween_property(_slash_mat, "albedo_color:a", 0.0, 0.19)

	_scan_sword_hits()
	await get_tree().create_timer(0.20).timeout
	if not is_inside_tree():
		return
	_swing_active = false
	attack_area.monitoring = false
	if slash_arc:
		slash_arc.visible = false
	if right_arm:
		create_tween().tween_property(right_arm, "rotation", Vector3.ZERO, 0.1)
	await get_tree().create_timer(0.06 if not is_finisher else 0.11).timeout
	if not is_inside_tree():
		return
	is_attacking = false


func _scan_sword_hits() -> void:
	for body in attack_area.get_overlapping_bodies():
		if body is Node3D:
			_try_hit_target(body as Node3D)

	var fwd := -visual_rig.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var sword_pt := visual_rig.global_position + fwd * 1.55

	for e_var in get_tree().get_nodes_in_group("enemies"):
		var enemy := e_var as Node3D
		if not enemy or not is_instance_valid(enemy) or enemy in _hit_this_swing:
			continue
		var flat_from_player := enemy.global_position - global_position
		flat_from_player.y = 0.0
		var dist_p := flat_from_player.length()
		if dist_p > 0.2 and fwd.dot(flat_from_player / dist_p) < -0.25 and dist_p > 1.8:
			continue
		var hit_r := 2.95 if ("engage_radius" in enemy) else 2.25
		var max_dy := 3.6 if ("engage_radius" in enemy) else 2.5
		var flat_d := Vector2(enemy.global_position.x - sword_pt.x, enemy.global_position.z - sword_pt.z).length()
		if flat_d <= hit_r and absf(enemy.global_position.y - (global_position.y + 1.3)) <= max_dy:
			_try_hit_target(enemy)

	for o_var in get_tree().get_nodes_in_group("boss_orbs"):
		var orb := o_var as Node3D
		if not orb or not is_instance_valid(orb):
			continue
		if orb.global_position.distance_to(sword_pt + Vector3(0.0, 1.1, 0.0)) <= 2.35:
			if orb.has_method("deflect"):
				orb.deflect()
				if hit_sparks:
					hit_sparks.restart()
					hit_sparks.emitting = true


func _on_attack_hit(body: Node3D) -> void:
	_try_hit_target(body)


func _try_hit_target(body: Node3D) -> void:
	if body in _hit_this_swing:
		return
	if body.has_method("take_damage") and not body.is_in_group("player"):
		_hit_this_swing.append(body)
		if hit_sparks:
			hit_sparks.restart()
			hit_sparks.emitting = true
		_shake_camera(0.07, 0.09)
		body.take_damage(_swing_damage, global_position)


func _shake_camera(amp: float, duration: float) -> void:
	if not cam:
		return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.tween_property(cam, "position", _cam_base_pos + Vector3(randf_range(-amp, amp), randf_range(-amp * 0.75, amp * 0.75), amp * 0.9), duration * 0.4)
	_shake_tween.tween_property(cam, "position", _cam_base_pos, duration * 0.6)


func take_damage(amount: int, source_pos: Vector3) -> void:
	if is_invincible or is_dashing or GameManager.is_game_ended:
		return
	is_invincible = true
	_play_sfx(hurt_sfx, 0.95, 1.05)
	GameManager.damage_player(amount)

	var knock := global_position - source_pos
	knock.y = 0.0
	if knock.length() < 0.05:
		knock = -visual_rig.global_transform.basis.z
	knock = knock.normalized()
	velocity.x = knock.x * 8.5
	velocity.z = knock.z * 8.5
	velocity.y = 2.4

	_shake_camera(0.18, 0.12)

	for i in 4:
		if not is_inside_tree():
			return
		body_pivot.visible = false
		await get_tree().create_timer(0.09).timeout
		if not is_inside_tree():
			return
		body_pivot.visible = true
		await get_tree().create_timer(0.09).timeout
	is_invincible = false


func _play_sfx(player_node: AudioStreamPlayer, min_pitch: float, max_pitch: float) -> void:
	if player_node and player_node.stream:
		player_node.pitch_scale = randf_range(min_pitch, max_pitch)
		player_node.play()


func _update_procedural_anim(delta: float, on_floor_now: bool) -> void:
	var h_speed := Vector2(velocity.x, velocity.z).length()
	var speed_norm := clampf(h_speed / walk_speed, 0.0, 1.45)

	if _cloak_mat:
		_cloak_mat.set_shader_parameter("move_speed_norm", clampf(h_speed / sprint_speed, 0.0, 1.5))

	# Smooth angular bank tilt when turning cleanly at speed
	var yaw_delta := wrapf(visual_rig.rotation.y - _prev_yaw, -PI, PI) / maxf(delta, 0.001)
	_prev_yaw = visual_rig.rotation.y
	var target_bank := clampf(yaw_delta * 0.045 * clampf(speed_norm, 0.0, 1.0), -0.22, 0.22)
	body_pivot.rotation.z = lerpf(body_pivot.rotation.z, target_bank, 9.0 * delta)

	if on_floor_now and h_speed > 1.8 and not is_dashing:
		_step_dist_accum += h_speed * delta
		if _step_dist_accum >= 2.25:
			_step_dist_accum = 0.0
			_play_sfx(footstep_sfx, 0.88, 1.14)
	else:
		_step_dist_accum = 0.8

	if not on_floor_now:
		left_leg.rotation.x = lerpf(left_leg.rotation.x, deg_to_rad(32.0), 10.0 * delta)
		right_leg.rotation.x = lerpf(right_leg.rotation.x, deg_to_rad(-24.0), 10.0 * delta)
		if _l_knee:
			_l_knee.rotation.x = lerpf(_l_knee.rotation.x, deg_to_rad(-38.0), 10.0 * delta)
		if _r_knee:
			_r_knee.rotation.x = lerpf(_r_knee.rotation.x, deg_to_rad(-22.0), 10.0 * delta)
		left_arm.rotation.x = lerpf(left_arm.rotation.x, deg_to_rad(-38.0), 8.0 * delta)
		if not is_attacking:
			right_arm.rotation.x = lerpf(right_arm.rotation.x, deg_to_rad(25.0), 8.0 * delta)
		cloak_pivot.rotation.x = lerpf(cloak_pivot.rotation.x, deg_to_rad(-38.0), 8.0 * delta)
		body_pivot.rotation.x = lerpf(body_pivot.rotation.x, deg_to_rad(4.0 if velocity.y < 0 else -5.0), 7.0 * delta)
	elif h_speed > 0.4:
		var freq := 11.2 * maxf(speed_norm, 0.72)
		var phase := _anim_t * freq
		var stride := sin(phase) * 0.66 * clampf(speed_norm, 0.25, 1.35)
		left_leg.rotation.x = stride
		right_leg.rotation.x = -stride
		if _l_knee:
			_l_knee.rotation.x = -maxf(0.0, -cos(phase)) * 0.92 * clampf(speed_norm, 0.3, 1.25) - 0.12 * clampf(speed_norm, 0.0, 1.0)
		if _r_knee:
			_r_knee.rotation.x = -maxf(0.0, cos(phase)) * 0.92 * clampf(speed_norm, 0.3, 1.25) - 0.12 * clampf(speed_norm, 0.0, 1.0)
		left_arm.rotation.x = -stride * 0.46 + sin(_anim_t * 3.8) * 0.04
		if _l_elbow:
			_l_elbow.rotation.x = lerpf(_l_elbow.rotation.x, 0.42 + maxf(0.0, -stride) * 0.45, 10.0 * delta)
		if not is_attacking:
			right_arm.rotation.x = stride * 0.45
			if _r_elbow:
				_r_elbow.rotation.x = lerpf(_r_elbow.rotation.x, 0.28 + maxf(0.0, stride) * 0.52, 10.0 * delta)
			body_pivot.rotation.y = lerpf(body_pivot.rotation.y, -stride * 0.09, 10.0 * delta)
		body_pivot.position.y = absf(cos(phase)) * 0.072 * clampf(speed_norm, 0.0, 1.2)
		body_pivot.rotation.x = lerpf(body_pivot.rotation.x, deg_to_rad(-8.5 * clampf(speed_norm, 0.0, 1.3)), 8.0 * delta)
		if head_group:
			head_group.rotation.x = lerpf(head_group.rotation.x, deg_to_rad(5.5 * clampf(speed_norm, 0.0, 1.2)), 8.0 * delta)
			head_group.rotation.y = lerpf(head_group.rotation.y, 0.0, 8.0 * delta)
		cloak_pivot.rotation.x = lerpf(cloak_pivot.rotation.x, deg_to_rad(-16.0 - speed_norm * 22.0), 8.0 * delta)
	else:
		var breath := sin(_anim_t * 2.2)
		left_leg.rotation.x = lerpf(left_leg.rotation.x, 0.0, 10.0 * delta)
		right_leg.rotation.x = lerpf(right_leg.rotation.x, 0.0, 10.0 * delta)
		if _l_knee:
			_l_knee.rotation.x = lerpf(_l_knee.rotation.x, 0.0, 10.0 * delta)
		if _r_knee:
			_r_knee.rotation.x = lerpf(_r_knee.rotation.x, 0.0, 10.0 * delta)
		left_arm.rotation.x = breath * 0.06
		if _l_elbow:
			_l_elbow.rotation.x = lerpf(_l_elbow.rotation.x, 0.34 + breath * 0.05, 8.0 * delta)
		if not is_attacking:
			right_arm.rotation.x = -breath * 0.05
			if _r_elbow:
				_r_elbow.rotation.x = lerpf(_r_elbow.rotation.x, 0.22 - breath * 0.04, 8.0 * delta)
			body_pivot.rotation.y = lerpf(body_pivot.rotation.y, 0.0, 8.0 * delta)
		body_pivot.position.y = breath * 0.025
		body_pivot.rotation.x = lerpf(body_pivot.rotation.x, breath * 0.02, 6.0 * delta)
		if head_group:
			head_group.rotation.x = lerpf(head_group.rotation.x, breath * 0.035, 5.0 * delta)
			head_group.rotation.y = sin(_anim_t * 0.9) * 0.08
		cloak_pivot.rotation.x = lerpf(cloak_pivot.rotation.x, deg_to_rad(-12.0 + sin(_anim_t * 2.0) * 3.5), 6.0 * delta)

	if _lantern_swing:
		_lantern_swing.rotation.z = lerpf(_lantern_swing.rotation.z, -target_bank * 1.6 + sin(_anim_t * 3.1) * 0.06, 9.0 * delta)
		_lantern_swing.rotation.x = lerpf(_lantern_swing.rotation.x, clampf(h_speed * 0.025, 0.0, 0.32) - left_arm.rotation.x * 0.4, 9.0 * delta)
