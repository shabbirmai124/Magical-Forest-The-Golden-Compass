extends Area2D
## Bottom pit boundary catching out-of-bounds falls cleanly.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.kill_player()
