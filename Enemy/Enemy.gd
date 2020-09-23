extends KinematicBody2D

var floating_text = load("res://FloatingText.tscn")

onready var sprite = $Sprite
onready var timer = $Timer
onready var chaseTimer = $ChaseTimer
onready var hitstunTimer = $HitstunTimer
onready var tween = $Tween
onready var collisionShape = $CollisionShape2D
onready var hitbox = $Hitbox
onready var hitboxShape = $Hitbox/CollisionShape2D
onready var hurtbox = $Hurtbox
onready var animationPlayer = $AnimationPlayer
onready var animationTree = $AnimationTree
onready var animationState = animationTree.get("parameters/playback")
onready var spawnBox = get_parent().get_parent() # Parent = Enemies node, Grandparent = EnemySpawner
onready var textList = $FloatingTextList
onready var hp_bar = $HealthBar
onready var health = max_health setget health_changed

export(int) var max_health = 3 
export(int) var max_damage = 2
export(int) var min_damage = 1
export var max_speed = 80
export var acceleration = 500
export var air_acceleration = 300
export var friction = 320
export var gravity = 17
export(float) var chase_time = 15.0
export(float) var chase_leeway = 15.0
export(Color) var dmgTextColor = Color(0.7, 0.7, 0.1, 1.0)

enum { 
	IDLE,
	PATROL,
	CHASE,
	HURT,
	DEAD
}

var terminal_velocity = 250
var state = IDLE
var velocity = Vector2.ZERO
var direction = 0
var rng = RandomNumberGenerator.new()
var chase_target = null

func _ready():
	hp_bar.update_max_health(max_health)
	hp_bar.update_health(health)
	hp_bar.set_visible(false)
	animationTree.active = true
	rng.randomize()
	tween.interpolate_callback(hitboxShape, 1.0, "set_disabled", false) #janky fix to hitbox on spawn bug
	tween.start()

func _physics_process(delta):
	match state:
		IDLE:
			idle_state(delta)
		PATROL:
			patrol_state(delta)
		CHASE:
			chase_state(delta)
		HURT:
			hurt_state(delta)
		DEAD:
			velocity = Vector2.ZERO
			
func health_changed(value):
	health = clamp(value, 0, max_health)
	hp_bar.update_health(health)
	hp_bar.set_visible(true)
	if health == 0:
		die()

func die():
	if state != DEAD:
		state = DEAD
		hitboxShape.set_deferred("disabled", true)
		hurtbox.set_deferred("disabled", true)
		animationState.travel("Die")
		tween.interpolate_property(sprite, "modulate:a", 1.0, 0.0, 1.0, Tween.EASE_IN)
		tween.interpolate_deferred_callback(self, 1.0, "queue_free")
		tween.start()
	velocity = Vector2.ZERO

func idle_state(delta):
	animationState.travel("Idle")
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	if timer.is_stopped():
		timer.set_wait_time(rng.randf_range(1.0, 3.0))
		timer.start()
	
func patrol_state(delta):
	animationState.travel("Run")
	if timer.is_stopped():
		timer.set_wait_time(rng.randf_range(0.5, 2.0))
		timer.start()
	if direction != 0:
		if global_position.x >= spawnBox.global_position.x + spawnBox.width:
			direction = -1
		elif global_position.x <= spawnBox.global_position.x - spawnBox.width:
			direction = 1
		move(delta)
	else:
		state = IDLE

func chase_state(delta):
	if chase_target:
		animationState.travel("Run")
		if chaseTimer.is_stopped():
			chaseTimer.set_wait_time(chase_time)
			chaseTimer.start()
		if global_position.x >= spawnBox.global_position.x + spawnBox.width:
				direction = -1
		elif global_position.x <= spawnBox.global_position.x - spawnBox.width:
				direction = 1
		else:
			if abs(chase_target.global_position.x - self.global_position.x) > (chase_leeway * rng.randf_range(0.1, 2.0)):
				var dir = Vector2(chase_target.global_position.x - self.global_position.x, 0).normalized()
				direction = dir.x
		move(delta)
	else:
		state = IDLE

func move(delta):
	sprite.flip_h = min(0, direction)
	velocity.y = min(velocity.y - (-gravity), terminal_velocity)
	if is_on_floor():
		velocity = velocity.move_toward(Vector2(direction * max_speed, velocity.y), acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2(direction * max_speed, velocity.y), air_acceleration * delta)
	velocity = move_and_slide(velocity, Vector2(0, -1))

func hurt_state(delta):
	animationState.travel("Hurt")
	if global_position.x >= spawnBox.global_position.x + spawnBox.width:
		direction = -1
		move(delta)
	elif global_position.x <= spawnBox.global_position.x - spawnBox.width:
		direction = 1
		move(delta)
	else:
		if is_on_floor():
			velocity = velocity.move_toward(Vector2(0, velocity.y), friction * delta)
		else:
			velocity.y = min(velocity.y - (0.25 * -gravity), terminal_velocity)
	velocity = move_and_slide(velocity, Vector2(0, -1))

func _on_Timer_timeout():
	match state:
		IDLE:
			state = PATROL
			direction = clamp(rng.randi_range(-2, 2), -1, 1) #results in a 1 in 5 chance to return to idle, otherwise give direction
		PATROL:
			direction = clamp(rng.randi_range(-2, 2), -1, 1) #results in a 1 in 5 chance to return to idle, otherwise give direction

func hurt_animation_finished():
	pass
	#state = CHASE

func _on_Hurtbox_area_entered(area):
	if state != DEAD: # Check state here to avoid damaging already dead enemies
		var area_parent = area.get_parent().get_parent()
		take_damage(area.get_damage())
		var dir = Vector2(self.global_position.x - area_parent.global_position.x, 0).normalized()
		direction = dir.x
		sprite.flip_h = max(0, direction)
		if state == DEAD: # State could have changed since initial condition due to take_damage
			hitbox.set_deferred("disabled", true)
			hurtbox.set_deferred("disabled", true)
		else:
			state = HURT
			chase_target = area_parent
			hitstunTimer.start(calculate_hitstun(area.hitstun))
		velocity.x = area.knockback.x * direction
		velocity.y = -area.knockback.y

func take_damage(dmg):
	self.health -= dmg
	spawn_floating_text(dmg)

func calculate_hitstun(hitstun):
	var output = hitstun * 0.25 * (max_health / health)
	return output

func spawn_floating_text(text):
	var dmg_text = floating_text.instance()
	dmg_text.position += Vector2(rng.randf_range(-7, 7), (-35 + rng.randf_range(0, -5) * textList.get_child_count()))
	dmg_text.velocity = Vector2(rng.randf_range(-5, 5), 0)
	dmg_text.modulate = dmgTextColor
	dmg_text.text = text
	textList.add_child(dmg_text)

func _on_ChaseTimer_timeout():
	match state:
		CHASE:
			chase_target = null
			hp_bar.set_visible(false)
			state = IDLE


func _on_HitstunTimer_timeout():
	match state:
		HURT:
			if chase_target:
				state = CHASE
			else: 
				state = IDLE
