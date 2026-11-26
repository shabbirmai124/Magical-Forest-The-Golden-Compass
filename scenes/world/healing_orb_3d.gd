extends Area3D
## 3D Woodland Restoration Dew Orb — restores +1 HP (or +25 bonus if full HP).

const PropsVisuals3D = preload("res://scenes/world/props_visuals_3d.gd")

@export var heal_amount: int = 1
@export var full_hp_bonus: int = 25

@onready var visual: Node3D = $VisualPivot
@onready var light: OmniLight3D = $OmniLight3D
@onready var particles: GPUParticles3D = $GPUParticles3D
@onready var sfx: AudioStreamPlayer = $AudioStreamPlayer
@onready var col: CollisionShape3D = $CollisionShape3D

var _collected: bool = false
var _t: float = 0.0
var _rings: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_rings = PropsVisuals3D.enhance_healing_orb(self)
	if light:
		light.distance_fade_enabled = true
		light.distance_fade_begin = 38.0
		light.distance_fade_length = 14.0


func _process(delta: float) -> void:
	if _collected:
		return
	_t += delta
	visual.position.y = sin(_t * 2.2) * 0.16
	visual.rotate_y(delta * 0.9)
	if _rings.has("ring1"):
		(_rings["ring1"] as Node3D).rotate_x(delta * 1.4)
	if _rings.has("ring2"):
		(_rings["ring2"] as Node3D).rotate_z(delta * -1.7)


func _on_body_entered(body: Node3D) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	if GameManager.health < GameManager.max_health:
		GameManager.heal_player(heal_amount)
	else:
		GameManager.add_score(full_hp_bonus)

	col.set_deferred("disabled", true)
	var ptw := create_tween().set_parallel(true)
	ptw.tween_property(visual, "scale", Vector3.ONE * 1.6, 0.1).set_trans(Tween.TRANS_BACK)
	ptw.tween_property(visual, "scale", Vector3.ZERO, 0.15).set_delay(0.1)
	if light:
		create_tween().tween_property(light, "light_energy", 0.0, 0.25)
	if particles:
		particles.emitting = true
	if sfx and sfx.stream:
		sfx.pitch_scale = 1.25
		sfx.play()
		await sfx.finished
	elif particles:
		await get_tree().create_timer(particles.lifetime).timeout
	queue_free()
