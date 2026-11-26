extends Area3D
## 3D Secret Alcove Botanical Foliage Veil — dissolves gently on entry with chime & HUD alert.

const PropsVisuals3D = preload("res://scenes/world/props_visuals_3d.gd")
const SFX_SECRET: AudioStream = preload("res://assets/audio/sfx/secret_chime.wav")

@onready var cover_group: Node3D = $CoverGroup

var _fade_tween: Tween
var _foliage_mat: ShaderMaterial
var _discovered: bool = false
var _alpha_val: float = 1.0
var _sfx_player: AudioStreamPlayer


func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	_foliage_mat = PropsVisuals3D.build_hidden_foliage_curtain(cover_group)
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.stream = SFX_SECRET
	_sfx_player.bus = &"SFX"
	add_child(_sfx_player)


func _on_enter(body: Node3D) -> void:
	if body.is_in_group("player"):
		if not _discovered:
			_discovered = true
			if _sfx_player and _sfx_player.stream:
				_sfx_player.play()
			GameManager.add_score(25)
			GameManager.notification_posted.emit("Secret Woodland Alcove Discovered! (+25)", Color(0.42, 0.96, 0.86))
		_fade_to(0.14)


func _on_exit(body: Node3D) -> void:
	if body.is_in_group("player"):
		_fade_to(1.0)


func _fade_to(target_alpha: float) -> void:
	if not _foliage_mat:
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_method(func(v: float) -> void:
		_alpha_val = v
		_foliage_mat.set_shader_parameter("tint", Color(1.0, 1.0, 1.0, v))
	, _alpha_val, target_alpha, 0.38)
