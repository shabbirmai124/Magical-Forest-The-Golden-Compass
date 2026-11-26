extends Node3D
## Ancient Carved Lore Runestone (Stage 2 Side Quest: Cartographer's Lost Notes).
## Press [E] nearby to decipher hidden lore and progress the Side Quest.

@export var rune_title: String = "Ancient Lore Runestone"
@export var lore_lines: Array[String] = [
	"Inscription I: Three Rune Pillars anchor the ancient seal of Thornhollow.",
	"When all three blaze in harmony, the Sanctum of the Grove shall open once more."
]

var compass_label: String = "Lore Runestone"
var _is_read: bool = false
var _t: float = 0.0
var _glow_mat: StandardMaterial3D = null
var _beacon: MeshInstance3D = null


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("lore_runestone")
	_build_visuals()


func _build_visuals() -> void:
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.28, 0.34, 0.38, 1.0)
	stone_mat.roughness = 0.88

	_glow_mat = StandardMaterial3D.new()
	_glow_mat.albedo_color = Color(0.32, 0.88, 1.0, 1.0)
	_glow_mat.emission_enabled = true
	_glow_mat.emission = Color(0.22, 0.84, 1.0, 1.0)
	_glow_mat.emission_energy_multiplier = 2.4

	var tablet := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(1.1, 2.3, 0.38)
	tablet.mesh = tm
	tablet.position = Vector3(0.0, 1.15, 0.0)
	tablet.material_override = stone_mat
	add_child(tablet)

	var rune_strip := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(0.28, 1.55, 0.44)
	rune_strip.mesh = rm
	rune_strip.position = Vector3(0.0, 1.25, 0.0)
	rune_strip.material_override = _glow_mat
	add_child(rune_strip)

	var col_body := StaticBody3D.new()
	col_body.collision_layer = 1
	col_body.collision_mask = 0
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.2, 2.3, 0.5)
	col.shape = bs
	col.position = Vector3(0.0, 1.15, 0.0)
	col_body.add_child(col)
	add_child(col_body)

	_beacon = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.22
	bm.bottom_radius = 0.38
	bm.height = 14.0
	_beacon.mesh = bm
	_beacon.position = Vector3(0.0, 7.0, 0.0)
	var bmat := StandardMaterial3D.new()
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.albedo_color = Color(1.0, 0.88, 0.35, 0.32)
	bmat.emission_enabled = true
	bmat.emission = Color(1.0, 0.84, 0.25, 1.0)
	bmat.emission_energy_multiplier = 2.0
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beacon.material_override = bmat
	_beacon.visible = false
	add_child(_beacon)


func _process(delta: float) -> void:
	_t += delta
	if _glow_mat:
		_glow_mat.emission_energy_multiplier = (1.1 if _is_read else 2.4) + sin(_t * 3.0) * 0.45


func is_compass_eligible() -> bool:
	return not _is_read


func highlight_compass_beacon(duration: float = 10.0) -> void:
	if _is_read or not _beacon:
		return
	_beacon.visible = true
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if is_instance_valid(_beacon):
			_beacon.visible = false
	)


func get_interact_prompt() -> String:
	return "[E] Read %s" % rune_title


func interact(_player: Node3D) -> void:
	if AudioManager:
		AudioManager.play_sfx("rune_activate")
	GameManager.dialogue_requested.emit(rune_title, "Ancient Carving", lore_lines, Callable(self, "_on_finished"))


func _on_finished() -> void:
	if not _is_read:
		_is_read = true
		if _beacon:
			_beacon.visible = false
		if _glow_mat:
			_glow_mat.albedo_color = Color(1.0, 0.88, 0.38, 1.0)
			_glow_mat.emission = Color(1.0, 0.82, 0.26, 1.0)
		GameManager.add_score(75)
		if QuestManager:
			QuestManager.record_progress("read_runestones", 1)
