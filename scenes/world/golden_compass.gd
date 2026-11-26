extends Area2D
## The Lost Golden Compass — spawned at the center arena pedestal after defeating
## the Forest Guardian. Awards 500 points, plays fanfare, and triggers victory.

@onready var sprite: Sprite2D = $Sprite2D
@onready var col: CollisionShape2D = $CollisionShape2D
@onready var light: PointLight2D = $PointLight2D
@onready var sfx: AudioStreamPlayer = $VictorySFX

var _collected: bool = false
var _bob_tween: Tween


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(sprite, "position:y", -14.0, 0.7).set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(sprite, "position:y", 14.0, 0.7).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()

	col.set_deferred("disabled", true)
	sprite.visible = false
	if light:
		light.visible = false

	GameManager.add_score(500)
	GameManager.trigger_victory()

	if sfx and sfx.stream:
		sfx.play()
		await sfx.finished

	queue_free()
