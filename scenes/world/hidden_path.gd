extends Area2D
## Covers a secret alcove with a collision-free TileMapLayer.
## Interrupts any active tween so rapid edge crossings never flicker.

@onready var cover_layer: TileMapLayer = $TileMapLayer

var _fade_tween: Tween


func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node2D) -> void:
	if body.is_in_group("player"):
		_fade_to(0.15)


func _on_exit(body: Node2D) -> void:
	if body.is_in_group("player"):
		_fade_to(1.0)


func _fade_to(target_alpha: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(cover_layer, "modulate:a", target_alpha, 0.35)
