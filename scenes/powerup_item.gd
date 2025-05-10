extends Area2D

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if body.name == "Dino":
		var game = get_tree().current_scene
		game.get_node("PowerUpGrab").play()
		
		body.has_power = true
		body.power_timer = body.POWER_DURATION
		queue_free()
