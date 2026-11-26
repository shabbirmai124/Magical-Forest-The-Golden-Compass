extends Area3D
## 3D Lost Golden Compass artifact — hovers & rotates majestically over the altar pedestal.
## Can either unlock an Astral Portal for continuing adventures or trigger Victory Celebration.

const PropsVisuals3D = preload("res://scenes/world/props_visuals_3d.gd")

@export var unlocks_next_portal: bool = false

@onready var visual: Node3D = $VisualPivot
@onready var col: CollisionShape3D = $CollisionShape3D
@onready var light: OmniLight3D = $OmniLight3D
@onready var sfx: AudioStreamPlayer = $VictorySFX

var _collected: bool = false
var _t: float = 0.0
var _parts: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_parts = PropsVisuals3D.enhance_golden_compass(self)


func _process(delta: float) -> void:
	if _collected:
		return
	_t += delta
	visual.rotate_y(delta * 1.4)
	visual.position.y = sin(_t * 2.2) * 0.2
	if _parts.has("outer_gimbal"):
		(_parts["outer_gimbal"] as Node3D).rotate_x(delta * 1.1)
	if _parts.has("inner_gimbal"):
		(_parts["inner_gimbal"] as Node3D).rotate_z(delta * -1.5)
	if _parts.has("rose"):
		(_parts["rose"] as Node3D).rotate_z(delta * 2.1)


func _on_body_entered(body: Node3D) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	col.set_deferred("disabled", true)
	if sfx and sfx.stream:
		sfx.play()

	var ctw := create_tween().set_parallel(true)
	ctw.tween_property(visual, "scale", Vector3.ONE * 1.9, 0.25).set_trans(Tween.TRANS_BACK)
	ctw.tween_property(visual, "position:y", visual.position.y + 1.5, 0.35)
	if light:
		ctw.tween_property(light, "light_energy", 8.5, 0.25)
	await ctw.finished
	if not is_inside_tree():
		return

	visual.visible = false
	if light:
		light.visible = false

	GameManager.add_score(500)

	if unlocks_next_portal:
		var portal := get_tree().get_first_node_in_group("awakened_portal")
		if portal and portal.has_method("awaken_portal"):
			portal.awaken_portal()
			GameManager.notification_posted.emit("Golden Compass Claimed! Enter the Northern Astral Portal!", Color(1.0, 0.88, 0.38))
			if sfx and sfx.playing:
				await sfx.finished
			queue_free()
			return

	GameManager.trigger_victory()
	if sfx and sfx.playing:
		await sfx.finished
	queue_free()
