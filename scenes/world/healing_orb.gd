extends Area2D
## Woodland restoration orb that restores +1 HP (or grants +25 bonus score if already full).

@export var heal_amount: int = 1
@export var full_hp_bonus: int = 25

@onready var sprite: Sprite2D = $Sprite2D
@onready var light: PointLight2D = $PointLight2D
@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var sfx: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var col: CollisionShape2D = $CollisionShape2D

var _collected: bool = false
var _bob_tween: Tween


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(sprite, "position:y", -10.0, 0.9).set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(sprite, "position:y", 10.0, 0.9).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()

	if GameManager.health < GameManager.max_health:
		GameManager.heal_player(heal_amount)
	else:
		GameManager.add_score(full_hp_bonus)

	col.set_deferred("disabled", true)
	sprite.visible = false
	if light:
		create_tween().tween_property(light, "energy", 0.0, 0.2)
	if particles:
		particles.emitting = true
	if sfx and sfx.stream:
		sfx.pitch_scale = 1.25
		sfx.play()
		await sfx.finished
	elif particles:
		await get_tree().create_timer(particles.lifetime).timeout

	queue_free()
