extends CharacterBody2D
## Young explorer with smooth ground/air acceleration & friction,
## coyote time, jump buffer, variable jump height, asymmetric fall gravity,
## melee swing window, knockback, camera shake, and invincibility frames.

@export_group("Movement")
@export var max_speed: float = 580.0
@export var ground_acceleration: float = 4400.0
@export var ground_friction: float = 4800.0
@export var air_acceleration: float = 3000.0
@export var air_friction: float = 3000.0

@export_group("Jumping & Gravity")
@export var jump_velocity: float = -1240.0
@export var gravity_scale: float = 1.0
@export var fall_gravity_mult: float = 1.25
@export var max_fall_speed: float = 1680.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

@onready var visuals: Node2D = $Visuals
@onready var sprite: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var attack_pivot: Node2D = $AttackPivot
@onready var attack_area: Area2D = $AttackPivot/AttackArea
@onready var slash_arc: CanvasItem = $AttackPivot/SlashArc
@onready var cam: Camera2D = $Camera2D
@onready var footstep_dust: GPUParticles2D = $FootstepDust
@onready var jump_sfx: AudioStreamPlayer = $Audio/Jump
@onready var land_sfx: AudioStreamPlayer = $Audio/Land
@onready var swing_sfx: AudioStreamPlayer = $Audio/AttackSwing
@onready var hurt_sfx: AudioStreamPlayer = $Audio/Hurt

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_attacking: bool = false
var is_invincible: bool = false
var input_locked: bool = false
var _was_on_floor: bool = true
var _hit_this_swing: Array[Node2D] = []


func _ready() -> void:
	add_to_group("player")
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_hit)


func _physics_process(delta: float) -> void:
	if GameManager.is_game_ended:
		return

	var on_floor_now := is_on_floor()
	if on_floor_now and not _was_on_floor:
		_on_landed()
	_was_on_floor = on_floor_now

	_apply_gravity(delta, on_floor_now)

	if not input_locked:
		_handle_jump(delta)
		_handle_horizontal(delta, on_floor_now)
		if Input.is_action_just_pressed("attack") and not is_attacking:
			_perform_attack()
	else:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)

	move_and_slide()
	_update_animation()


func set_camera_limits(left: int, top: int, right: int, bottom: int, cam_zoom: float = 1.0) -> void:
	if cam:
		cam.limit_left = left
		cam.limit_top = top
		cam.limit_right = right
		cam.limit_bottom = bottom
		cam.zoom = Vector2(cam_zoom, cam_zoom)


func _apply_gravity(delta: float, on_floor_now: bool) -> void:
	if on_floor_now:
		coyote_timer = coyote_time
		return
	var mult := fall_gravity_mult if velocity.y > 0.0 else gravity_scale
	velocity.y = minf(velocity.y + gravity * mult * delta, max_fall_speed)
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
		_squash_stretch(Vector2(0.84, 1.18))

	# Variable jump height on early button release
	if Input.is_action_just_released("jump") and velocity.y < -320.0:
		velocity.y *= 0.5


func _handle_horizontal(delta: float, on_floor_now: bool) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	var accel := ground_acceleration if on_floor_now else air_acceleration
	var fric := ground_friction if on_floor_now else air_friction

	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * max_speed, accel * delta)
		sprite.flip_h = dir < 0.0
		attack_pivot.scale.x = -1.0 if dir < 0.0 else 1.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)


func _on_landed() -> void:
	_play_sfx(land_sfx, 0.92, 1.08)
	_squash_stretch(Vector2(1.18, 0.84))
	if footstep_dust:
		footstep_dust.restart()
		footstep_dust.emitting = true


func _squash_stretch(target_scale: Vector2) -> void:
	if not visuals:
		return
	visuals.scale = target_scale
	var tw := create_tween()
	tw.tween_property(visuals, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _perform_attack() -> void:
	is_attacking = true
	_hit_this_swing.clear()
	_play_sfx(swing_sfx, 0.94, 1.08)
	attack_area.monitoring = true
	if slash_arc:
		slash_arc.visible = true
		slash_arc.modulate.a = 0.95
		var stw := create_tween()
		stw.tween_property(slash_arc, "modulate:a", 0.2, 0.16)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
		sprite.play("attack")
	await get_tree().create_timer(0.16).timeout
	attack_area.monitoring = false
	if slash_arc:
		slash_arc.visible = false
	await get_tree().create_timer(0.12).timeout
	is_attacking = false


func _on_attack_hit(body: Node2D) -> void:
	if body in _hit_this_swing:
		return
	if body.has_method("take_damage"):
		_hit_this_swing.append(body)
		body.take_damage(1, global_position)


func take_damage(amount: int, source_pos: Vector2) -> void:
	if is_invincible or GameManager.is_game_ended:
		return
	is_invincible = true
	_play_sfx(hurt_sfx, 0.95, 1.05)
	GameManager.damage_player(amount)

	var knock_dir := signf(global_position.x - source_pos.x)
	if knock_dir == 0.0:
		knock_dir = -1.0
	velocity = Vector2(knock_dir * 640.0, -680.0)

	# 0.08 s camera shake
	if cam:
		var orig := cam.offset
		var shake_tw := create_tween()
		shake_tw.tween_property(cam, "offset", orig + Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 8.0)), 0.04)
		shake_tw.tween_property(cam, "offset", orig, 0.04)

	# 0.8 s invulnerability blink (4 pulses)
	var blink_tw := create_tween()
	for i in 4:
		blink_tw.tween_property(sprite, "modulate:a", 0.25, 0.1)
		blink_tw.tween_property(sprite, "modulate:a", 1.0, 0.1)
	await blink_tw.finished
	is_invincible = false


func _play_sfx(player_node: AudioStreamPlayer, min_pitch: float, max_pitch: float) -> void:
	if player_node and player_node.stream:
		player_node.pitch_scale = randf_range(min_pitch, max_pitch)
		player_node.play()


func _update_animation() -> void:
	if is_attacking or not sprite.sprite_frames:
		return
	if not is_on_floor():
		sprite.play("jump" if velocity.y < 0.0 else "fall")
	elif absf(velocity.x) > 40.0:
		sprite.play("run")
	else:
		sprite.play("idle")
