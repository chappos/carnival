extends Area2D

export(int) var knockback = 100
export(int) var max_damage = 1 
export(int) var min_damage = 1

var rng = RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	
func get_damage():
	return rng.randi_range(min_damage, max_damage)
