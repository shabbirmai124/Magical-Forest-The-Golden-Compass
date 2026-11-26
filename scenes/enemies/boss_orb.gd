extends Area2D
## Energy orb projectile fired by the Forest Guardian.
## Uses LifetimeTimer (4s) to guarantee zero leaked nodes, deletes on wall or player hit.

@onready var lifetime_timer: Timer = $LifetimeTimer

var direction: Vector2 = Vector2.LEFT
var speed: float = 620.0
var _consumed: bool = false


func _ready() -> void:
	body_entered.connect(_on_hit)
	lifetime_timer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if not _consumed:
		global_position += direction * speed * delta
		rotation += delta * 4.5


func _on_hit(body: Node2D) -> void:
	if _consumed:
		return
	_consumed = true
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1, global_position)
	queue_free()
