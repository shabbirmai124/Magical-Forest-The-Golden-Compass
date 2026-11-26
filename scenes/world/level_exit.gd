extends Area2D
## Glowing portal at the end of Levels 1 & 2.
## Guards against double-triggers and mid-fade restarts before advancing.

var _triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _triggered or GameManager.is_game_ended or not body.is_in_group("player"):
		return
	_triggered = true
	var start_level_idx := GameManager.current_level_index
	if "input_locked" in body:
		body.input_locked = true

	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("fade_to_black"):
		await hud.fade_to_black(0.35)

	if not is_inside_tree() or GameManager.is_game_ended:
		return
	if GameManager.current_level_index != start_level_idx:
		return

	GameManager.next_level()
