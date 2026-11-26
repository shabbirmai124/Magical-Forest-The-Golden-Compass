extends Area2D
## Collectible crystal that bobs gently, awards 10 points + crystal counter on pickup,
## dims its light, plays a particle burst + pitch-varied chime, then frees cleanly.

@export var value: int = 10

@onready var sprite: Sprite2D = $Sprite2D
@onready var light: PointLight2D = $PointLight2D
@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var sfx: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var col: CollisionShape2D = $CollisionShape2D

var collected: bool = false
var _bob_tween: Tween


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(sprite, "position:y", -12.0, 0.8).set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(sprite, "position:y", 12.0, 0.8).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if collected or not body.is_in_group("player"):
		return
	collected = true
	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()

	GameManager.add_crystal(value)
	col.set_deferred("disabled", true)
	sprite.visible = false
	if light:
		create_tween().tween_property(light, "energy", 0.0, 0.2)
	if particles:
		particles.emitting = true

	if sfx and sfx.stream:
		sfx.pitch_scale = randf_range(0.95, 1.08)
		sfx.play()
		await sfx.finished
	elif particles:
		await get_tree().create_timer(particles.lifetime).timeout

	queue_free()
