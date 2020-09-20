extends Node2D

var can_be_grabbed = true

func _ready():
	pass # Replace with function body.


func _on_Area2D_body_entered(body):
	if body.name == "Player" and can_be_grabbed:
		can_be_grabbed = false

func _on_Area2D_body_exited(body):
	if body.name == "Player":
		if body.is_climbing:
			if body.get_input_vector().y:
				body.check_for_ladder()
		can_be_grabbed = true
	

