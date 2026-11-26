extends Area3D
## 3D Collectible Mana Crystal — floats, spins, illuminates nearby moss,
## awards +10 score & crystal count on pickup.

const PropsVisuals3D = preload("res://scenes/world/props_visuals_3d.gd")

@export var value: int = 10

@onready var visual: Node3D = $VisualPivot
@onready var light: OmniLight3D = $OmniLight3D
@onready var particles: GPUParticles3D = $GPUParticles3D
@onready var sfx: AudioStreamPlayer = $AudioStreamPlayer
@onready var col: CollisionShape3D = $CollisionShape3D

var collected: bool = false
var _t: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_t = randf() * TAU
	PropsVisuals3D.enhance_crystal(self)
	if light:
		light.distance_fade_enabled = true
		light.distance_fade_begin = 38.0
		light.distance_fade_length = 14.0


func _process(delta: float) -> void:
	if collected:
		return
	_t += delta
	visual.rotate_y(delta * 1.6)
	visual.position.y = sin(_t * 2.4) * 0.18


func _on_body_entered(body: Node3D) -> void:
	if collected or not body.is_in_group("player"):
		return
	collected = true
	GameManager.add_crystal(value)
	col.set_deferred("disabled", true)
	var ptw := create_tween().set_parallel(true)
	ptw.tween_property(visual, "scale", Vector3.ONE * 1.55, 0.09).set_trans(Tween.TRANS_BACK)
	ptw.tween_property(visual, "scale", Vector3.ZERO, 0.14).set_delay(0.09)
	ptw.tween_property(visual, "position:y", visual.position.y + 0.6, 0.2)
	if light:
		create_tween().tween_property(light, "light_energy", 0.0, 0.24)
	if particles:
		particles.emitting = true
	if sfx and sfx.stream:
		sfx.pitch_scale = randf_range(0.95, 1.08)
		sfx.play()
		await sfx.finished
	elif particles:
		await get_tree().create_timer(particles.lifetime).timeout
	queue_free()
