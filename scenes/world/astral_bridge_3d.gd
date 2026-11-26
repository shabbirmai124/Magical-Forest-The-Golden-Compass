extends Node3D
## Stage 4 Hidden Astral Light Bridge — initially ethereal/non-solid until illuminated by Golden Compass Pulse [G].
## Once revealed by [G], solidifies into a glowing walkable starlight bridge and updates the Stage 4 Main Quest!

@export var bridge_length: float = 20.0
@export var bridge_width: float = 5.4
@export var bridge_index: int = 1

var compass_label: String = "Hidden Astral Bridge [G]"
var _revealed: bool = false
var _counted_quest: bool = false
var _t: float = 0.0
var _deck_mesh: MeshInstance3D = null
var _deck_mat: StandardMaterial3D = null
var _col_shape: CollisionShape3D = null
var _rail_nodes: Array[MeshInstance3D] = []


func _ready() -> void:
	compass_label = "Astral Light Bridge #%d [G]" % bridge_index
	add_to_group("astral_bridge")
	_build_visuals()
	_set_solid_state(false)


func _build_visuals() -> void:
	var body := StaticBody3D.new()
	body.name = "BridgeCollider"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	_col_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(bridge_width, 0.45, bridge_length)
	_col_shape.shape = box
	_col_shape.position = Vector3(0.0, -0.22, 0.0)
	body.add_child(_col_shape)

	_deck_mat = StandardMaterial3D.new()
	_deck_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_deck_mat.albedo_color = Color(1.0, 0.88, 0.42, 0.14)
	_deck_mat.emission_enabled = true
	_deck_mat.emission = Color(1.0, 0.84, 0.3, 1.0)
	_deck_mat.emission_energy_multiplier = 0.65
	_deck_mat.roughness = 0.18

	_deck_mesh = MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(bridge_width, 0.28, bridge_length)
	_deck_mesh.mesh = dm
	_deck_mesh.position = Vector3(0.0, -0.14, 0.0)
	_deck_mesh.material_override = _deck_mat
	add_child(_deck_mesh)

	for sgn in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.18, 0.18, bridge_length)
		rail.mesh = rm
		rail.position = Vector3(sgn * (bridge_width * 0.48), 0.55, 0.0)
		rail.material_override = _deck_mat
		add_child(rail)
		_rail_nodes.append(rail)


func _set_solid_state(solid: bool) -> void:
	_revealed = solid
	if _col_shape:
		_col_shape.disabled = not solid
	if _deck_mat:
		_deck_mat.albedo_color = Color(1.0, 0.9, 0.45, 0.88 if solid else 0.14)
		_deck_mat.emission_energy_multiplier = 2.6 if solid else 0.55


func _process(delta: float) -> void:
	_t += delta
	if _deck_mat:
		if _revealed:
			_deck_mat.emission_energy_multiplier = 2.4 + sin(_t * 3.5) * 0.4
		else:
			_deck_mat.albedo_color.a = 0.10 + 0.06 * sin(_t * 2.5)


func is_compass_eligible() -> bool:
	return not _counted_quest


func illuminate_by_compass() -> void:
	if not _revealed:
		_set_solid_state(true)
		if AudioManager:
			AudioManager.play_sfx("portal_unlock")
		GameManager.post_toast("ASTRAL BRIDGE ILLUMINATED", "Starlight Bridge #%d has solidified!" % bridge_index, Color(1.0, 0.92, 0.46))
	if not _counted_quest:
		_counted_quest = true
		if QuestManager:
			QuestManager.record_progress("illuminate_bridges", 1)
