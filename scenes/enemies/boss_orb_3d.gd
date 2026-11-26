extends Area3D
## 3D Energy orb projectile fired by the Forest Guardian.

const MeshFactory3D = preload("res://scenes/common/mesh_factory_3d.gd")

@onready var lifetime_timer: Timer = $LifetimeTimer

var direction: Vector3 = Vector3.FORWARD
var speed: float = 11.5
var _consumed: bool = false


func _ready() -> void:
	add_to_group("boss_orbs")
	body_entered.connect(_on_hit)
	lifetime_timer.timeout.connect(queue_free)
	var mi := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mi:
		mi.mesh = MeshFactory3D.build_rune_shard_mesh(0.32, 0.72, 13)
	var halo := MeshInstance3D.new()
	halo.mesh = MeshFactory3D.build_astrolabe_ring_mesh(0.42, 0.49, 0.04, 16)
	halo.rotation.x = deg_to_rad(35.0)
	add_child(halo)


func _physics_process(delta: float) -> void:
	if not _consumed:
		global_position += direction * speed * delta
		rotate_y(delta * 4.5)
		rotate_x(delta * 3.2)


func deflect() -> void:
	if _consumed:
		return
	_consumed = true
	set_deferred("monitoring", false)
	GameManager.add_score(5)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 1.65, 0.08)
	tw.tween_property(self, "scale", Vector3.ZERO, 0.09)
	await tw.finished
	if is_inside_tree():
		queue_free()


func _on_hit(body: Node3D) -> void:
	if _consumed:
		return
	_consumed = true
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1, global_position)
	queue_free()
