extends CharacterBody2D
## Forest Wisp — Patrols in a figure-8 hover, chases when player enters DetectZone,
## takes 2 hits to defeat, disables hitboxes immediately on death, and awards +25 score.

enum State { PATROL, CHASE, DEAD }

@export var chase_speed: float = 310.0
@export var patrol_range: float = 256.0
@export var hp: int = 2

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $ContactHitBox
@onready var detect_zone: Area2D = $DetectZone
@onready var light: PointLight2D = $PointLight2D
@onready var particles: GPUParticles2D = $DefeatParticles
@onready var hit_sfx: AudioStreamPlayer2D = $HitSFX

var state: State = State.PATROL
var start_pos: Vector2
var time_passed: float = 0.0
var target: Node2D = null
var _overlapping_player: Node2D = null


func _ready() -> void:
	start_pos = global_position
	hitbox.body_entered.connect(_on_touch_player)
	hitbox.body_exited.connect(func(b: Node2D) -> void:
		if b == _overlapping_player:
			_overlapping_player = null
	)
	detect_zone.body_entered.connect(func(b: Node2D) -> void:
		if state != State.DEAD and b.is_in_group("player"):
			target = b
			state = State.CHASE
	)
	detect_zone.body_exited.connect(func(b: Node2D) -> void:
		if b == target:
			target = null
			if state != State.DEAD:
				state = State.PATROL
	)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	time_passed += delta

	if state == State.CHASE and target and is_instance_valid(target):
		var dir := (target.global_position - global_position).normalized()
		velocity = dir * chase_speed
	else:
		var desired := Vector2(
			start_pos.x + sin(time_passed * 1.4) * patrol_range,
			start_pos.y + sin(time_passed * 2.8) * 56.0
		)
		velocity = (desired - global_position) * 3.0

	sprite.flip_h = velocity.x < 0.0
	move_and_slide()

	if _overlapping_player and is_instance_valid(_overlapping_player) and _overlapping_player.has_method("take_damage"):
		_overlapping_player.take_damage(1, global_position)


func _on_touch_player(body: Node2D) -> void:
	if state == State.DEAD:
		return
	if body.is_in_group("player"):
		_overlapping_player = body
		if body.has_method("take_damage"):
			body.take_damage(1, global_position)


func take_damage(amount: int, source_pos: Vector2) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	velocity = (global_position - source_pos).normalized() * 560.0
	if hit_sfx and hit_sfx.stream:
		hit_sfx.pitch_scale = randf_range(1.1, 1.3)
		hit_sfx.play()

	if hp <= 0:
		_die()
		return

	sprite.modulate = Color(1.6, 0.4, 0.4, 1.0)
	await get_tree().create_timer(0.1).timeout
	if state != State.DEAD:
		sprite.modulate = Color(1.15, 1.28, 1.3, 1.0)


func _die() -> void:
	state = State.DEAD
	_overlapping_player = null
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	detect_zone.set_deferred("monitoring", false)
	sprite.visible = false
	if light:
		light.visible = false
	GameManager.add_score(25)
	GameManager.register_enemy_defeated()
	if particles:
		particles.emitting = true
		await get_tree().create_timer(particles.lifetime).timeout
	queue_free()
