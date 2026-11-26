extends Area3D
## 3D Ancient Dimensional Portal — advances to the next stage when active.
## Supports starts_dormant mode (Stage 3 Astral Portal unlocked by the Golden Compass).

const MeshFactory3D = preload("res://scenes/common/mesh_factory_3d.gd")
const SHADER_PORTAL: Shader = preload("res://resources/shaders/portal_vortex_3d.gdshader")
const MAT_STONE: StandardMaterial3D = preload("res://resources/materials3d/ancient_stone.tres")
const MAT_RUNE: StandardMaterial3D = preload("res://resources/materials3d/rune_stone.tres")
const MAT_FILIGREE: StandardMaterial3D = preload("res://resources/materials3d/metal_filigree.tres")

@export var starts_dormant: bool = false

@onready var vortex_mesh: MeshInstance3D = $VortexDisc
@onready var outer_ring: MeshInstance3D = $OuterAstrolabe
@onready var portal_light: OmniLight3D = $PortalLight
@onready var trigger_col: CollisionShape3D = $CollisionShape3D
@onready var sfx: AudioStreamPlayer = $PortalSFX

var _is_active: bool = true
var _triggered: bool = false
var _t: float = 0.0
var _vortex_mat: ShaderMaterial = null


func _ready() -> void:
	add_to_group("stage_portals")
	body_entered.connect(_on_body_entered)
	_build_archway()

	_vortex_mat = ShaderMaterial.new()
	_vortex_mat.shader = SHADER_PORTAL
	_vortex_mat.set_shader_parameter("outer_color", Color(0.08, 0.65, 0.78))
	_vortex_mat.set_shader_parameter("inner_color", Color(0.72, 1.0, 0.96))
	if vortex_mesh:
		vortex_mesh.material_override = _vortex_mat
	if outer_ring:
		outer_ring.mesh = MeshFactory3D.build_astrolabe_ring_mesh(2.15, 2.48, 0.16, 36)
		outer_ring.material_override = MAT_FILIGREE

	if starts_dormant:
		add_to_group("awakened_portal")
		_set_portal_active(false)
	else:
		_set_portal_active(true)


func _build_archway() -> void:
	var arch_root := Node3D.new()
	arch_root.name = "PortalArchway"
	add_child(arch_root)

	var col_mesh := MeshFactory3D.build_fluted_column_mesh(0.55, 5.4)
	for side in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		pillar.mesh = col_mesh
		pillar.position = Vector3(side * 2.55, 2.7, 0.0)
		pillar.material_override = MAT_STONE
		arch_root.add_child(pillar)

		var plinth := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(1.55, 0.72, 1.55)
		plinth.mesh = pm
		plinth.position = Vector3(side * 2.55, 0.36, 0.0)
		plinth.material_override = MAT_RUNE
		arch_root.add_child(plinth)

	var lintel := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(6.8, 0.95, 1.65)
	lintel.mesh = lm
	lintel.position = Vector3(0.0, 5.65, 0.0)
	lintel.material_override = MAT_STONE
	arch_root.add_child(lintel)

	var keystone := MeshInstance3D.new()
	keystone.mesh = MeshFactory3D.build_rune_shard_mesh(0.42, 1.15, 19)
	keystone.position = Vector3(0.0, 6.45, 0.0)
	keystone.material_override = MAT_RUNE
	arch_root.add_child(keystone)

	var base_step := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 3.4
	bm.bottom_radius = 3.9
	bm.height = 0.42
	base_step.mesh = bm
	base_step.position = Vector3(0.0, 0.12, 0.0)
	base_step.material_override = MAT_STONE
	arch_root.add_child(base_step)


func _set_portal_active(active: bool) -> void:
	_is_active = active
	if vortex_mesh:
		vortex_mesh.visible = active
	if portal_light:
		portal_light.light_energy = 4.2 if active else 0.45
		portal_light.light_color = Color(0.32, 0.96, 0.92) if active else Color(0.45, 0.48, 0.65)


func awaken_portal() -> void:
	if _is_active:
		return
	_set_portal_active(true)
	if _vortex_mat:
		_vortex_mat.set_shader_parameter("outer_color", Color(0.26, 0.52, 0.98))
		_vortex_mat.set_shader_parameter("inner_color", Color(1.0, 0.92, 0.56))
	if vortex_mesh:
		vortex_mesh.scale = Vector3(0.05, 0.05, 0.05)
		create_tween().tween_property(vortex_mesh, "scale", Vector3.ONE, 0.85).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if portal_light:
		portal_light.light_color = Color(0.55, 0.88, 1.0)
		portal_light.light_energy = 0.5
		create_tween().tween_property(portal_light, "light_energy", 5.2, 0.85)
	if sfx and sfx.stream:
		sfx.pitch_scale = 0.92
		sfx.play()


func _process(delta: float) -> void:
	_t += delta
	if outer_ring:
		outer_ring.rotate_z(delta * (1.2 if _is_active else 0.18))
	if portal_light and _is_active:
		portal_light.light_energy = 4.2 + sin(_t * 3.4) * 0.55


func _on_body_entered(body: Node3D) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	if not _is_active:
		GameManager.notification_posted.emit("The Astral Portal lies dormant — vanquish the Guardian & claim the Golden Compass!", Color(0.96, 0.82, 0.42))
		return
	_triggered = true
	if trigger_col:
		trigger_col.set_deferred("disabled", true)
	if sfx and sfx.stream:
		sfx.pitch_scale = 1.05
		sfx.play()
	GameManager.add_score(150)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("fade_to_black"):
		await hud.fade_to_black(0.4)
	if is_inside_tree():
		GameManager.next_level()
