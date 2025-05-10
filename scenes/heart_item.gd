extends Area2D

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):	
	if body.name == "Dino":
		var game = get_tree().current_scene
		
		if game.hearts < game.MAX_HEARTS:
			game.get_node("HeartPickUp").play()
			game.hearts += 1
			game.update_hearts()
			queue_free()
