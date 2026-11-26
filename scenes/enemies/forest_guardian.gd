extends CharacterBody2D
## Final Boss — The Forest Guardian.
## Phase 1 (12->7 HP): wide figure-8 hover, 0.5s telegraph then 1 aimed orb every 2.2s.
## Phase 2 (6->1 HP): roar + crimson-gold aura + 1.65x speed + 3-orb 15° fan every 1.45s.
## Defeat: disables hitbox/timer, hides boss bar, +200 score, spawns Golden Compass at safe pedestal.

@export var max_hp: int = 12
@export var orb_scene: PackedScene = preload("res://scenes/enemies/boss_orb.tscn")
@export var compass_scene: PackedScene = preload("res://scenes/world/golden_compass.tscn")
@export var compass_spawn_marker: NodePath
@export var fallback_compass_position: Vector2 = Vector2(1280, 1040)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $ContactHitBox
@onready var aura_light: PointLight2D = $AuraLight
@onready var attack_timer: Timer = $AttackTimer
@onready var cast_sfx: AudioStreamPlayer = $Audio/Cast
@onready var roar_sfx: AudioStreamPlayer = $Audio/Roar
@onready var hit_sfx: AudioStreamPlayer = $Audio/Hit

var hp: int
var phase_two: bool = false
var is_telegraphing: bool = false
var is_defeated: bool = false
var hover_origin: Vector2
var t: float = 0.0
var _overlapping_player: Node2D = null


func _ready() -> void:
	hp = max_hp
	hover_origin = global_position
	GameManager.boss_health_changed.emit(hp, max_hp, true)
	attack_timer.timeout.connect(_start_attack_telegraph)
	hitbox.body_entered.connect(func(b: Node2D) -> void:
		if not is_defeated and b.is_in_group("player"):
			_overlapping_player = b
			if b.has_method("take_damage"):
				b.take_damage(1, global_position)
	)
	hitbox.body_exited.connect(func(b: Node2D) -> void:
		if b == _overlapping_player:
			_overlapping_player = null
	)


func _physics_process(delta: float) -> void:
	if is_defeated:
		velocity = Vector2.ZERO
		return

	if _overlapping_player and is_instance_valid(_overlapping_player) and _overlapping_player.has_method("take_damage"):
		_overlapping_player.take_damage(1, global_position)

	if is_telegraphing:
		velocity = Vector2.ZERO
		return

	t += delta
	var speed_mult := 1.65 if phase_two else 1.0
	var target_pos := Vector2(
		hover_origin.x + sin(t * 1.1 * speed_mult) * 420.0,
		hover_origin.y + sin(t * 2.2 * speed_mult) * 104.0,
	)
	velocity = (target_pos - global_position) * 3.5
	move_and_slide()


func _start_attack_telegraph() -> void:
	if is_defeated or is_telegraphing or GameManager.is_game_ended:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player or not orb_scene:
		return

	is_telegraphing = true
	sprite.modulate = Color(1.6, 1.35, 0.5, 1.0)
	await get_tree().create_timer(0.5).timeout

	if is_defeated or GameManager.is_game_ended:
		return

	sprite.modulate = _base_tint()
	_fire_orb_volley(player)
	is_telegraphing = false


func _fire_orb_volley(player: Node2D) -> void:
	if not is_instance_valid(player):
		return
	if cast_sfx and cast_sfx.stream:
		cast_sfx.pitch_scale = randf_range(0.95, 1.05)
		cast_sfx.play()

	var base_dir := (player.global_position - global_position).normalized()
	var spread_deg: Array[float] = [-15.0, 0.0, 15.0] if phase_two else [0.0]
	for deg in spread_deg:
		var orb := orb_scene.instantiate()
		orb.global_position = global_position
		orb.direction = base_dir.rotated(deg_to_rad(deg))
		get_tree().current_scene.add_child(orb)


func take_damage(amount: int, _source_pos: Vector2) -> void:
	if is_defeated:
		return
	hp = maxi(hp - amount, 0)
	GameManager.boss_health_changed.emit(hp, max_hp, true)

	if hit_sfx and hit_sfx.stream:
		hit_sfx.pitch_scale = randf_range(0.9, 1.1)
		hit_sfx.play()

	sprite.modulate = Color(1.6, 0.4, 0.4, 1.0)
	await get_tree().create_timer(0.1).timeout
	if is_defeated:
		return
	sprite.modulate = _base_tint()

	if not phase_two and hp <= max_hp / 2 and hp > 0:
		_enter_phase_two()

	if hp <= 0:
		_defeat()


func _enter_phase_two() -> void:
	phase_two = true
	attack_timer.wait_time = 1.45
	sprite.modulate = _base_tint()
	if aura_light:
		aura_light.color = Color(1.0, 0.35, 0.25, 1.0)
		aura_light.energy = 1.35
	if roar_sfx and roar_sfx.stream:
		roar_sfx.play()


func _base_tint() -> Color:
	return Color(1.22, 0.85, 0.55, 1.0) if phase_two else Color.WHITE


func _defeat() -> void:
	if is_defeated:
		return
	is_defeated = true
	_overlapping_player = null
	attack_timer.stop()
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	GameManager.add_score(200)
	GameManager.register_enemy_defeated()
	GameManager.boss_health_changed.emit(0, max_hp, false)

	var spawn_pos := fallback_compass_position
	if not compass_spawn_marker.is_empty():
		var marker := get_node_or_null(compass_spawn_marker) as Node2D
		if marker:
			spawn_pos = marker.global_position

	if compass_scene:
		var compass := compass_scene.instantiate()
		compass.global_position = spawn_pos
		get_tree().current_scene.call_deferred("add_child", compass)

	queue_free()
