extends Area2D

export(String, FILE, "*.tscn") var enemy_file
export(int) var max_enemies = 3
export(float) var respawn_time = 5.0

onready var enemy_scene = load(enemy_file)
onready var enemies = $Enemies
onready var timer = $Timer
onready var tween = $Tween
onready var collisionShape = $CollisionShape2D
onready var width = collisionShape.shape.extents.x #width counted from center, so actual width is 2x this number 

var rng = RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	timer.set_wait_time(respawn_time)
	timer.start()

func _on_Timer_timeout():
	var enemies_alive = enemies.get_child_count()
	while max_enemies > enemies_alive:
		var enemy = enemy_scene.instance()
		enemies.add_child(enemy)
		enemy.global_position.x = global_position.x + rng.randf_range(-width, width)
		enemy.modulate.a = 0.0
		tween.interpolate_property(enemy, "modulate:a", 0.0, 1.0, 1, Tween.TRANS_LINEAR)
		tween.start()
		enemies_alive = enemies.get_child_count()
	timer.start()
	
