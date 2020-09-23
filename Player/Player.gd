extends KinematicBody2D

var floating_text = preload("res://FloatingText.tscn")

onready var sprite = $Sprite
onready var tween = $Tween
onready var animationPlayer = $AnimationPlayer
onready var animationTree = $AnimationTree
onready var animationState = animationTree.get("parameters/playback")
onready var hurtbox = $Hurtbox
onready var ladderHitbox = $LadderHitbox
onready var hitbox_pivot = $HitboxPivot
onready var platformDrop = $PlatformDropCheck
onready var collisionShape = $CollisionShape2D
onready var stats = $PlayerStats
onready var timer = $Timer
onready var hp_bar = $Camera2D/UI/HealthBar

export(int) var max_damage = 3
export(int) var min_damage = 1
export var max_speed = 160
export var acceleration = 1600
export var air_acceleration = 220
export var friction = 550
export var gravity = 17
export var jump_height = 360
export var climb_speed = 60
export var climb_jump_height = 100
export(int) var airdash_speed = 240
export(float) var airdash_time = 0.4
export(Color) var dmgTextColor = Color(0.4, 0.0, 0.7, 1.0)

enum {
	MOVE,
	ATTACK,
	AIRDASH,
	CROUCH,
	HURT,
	CLIMB
}

var state = MOVE
var velocity = Vector2.ZERO
var terminal_velocity = 250
var has_double_jump = true
var has_airdash = true
var is_climbing = false 
var rng = RandomNumberGenerator.new()
var airdash_direction = Vector2.ZERO

func _ready():
	hp_bar.update_max_health(stats.max_health)
	hp_bar.update_health(stats.health)
	rng.randomize()
	stats.connect("no_health", self, "queue_free")
	animationTree.active = true

func _physics_process(delta):
	match state:
		MOVE: 
			move_state(delta)
		AIRDASH:
			airdash_state(delta)
		ATTACK:
			attack_state(delta)
		CROUCH:
			crouch_state(delta)
		CLIMB:
			climb_state(delta)

func move_state(delta):
	var input_vector = get_input_vector()
	
	if is_on_floor():
		has_airdash = true
		has_double_jump = true
	
	if input_vector.y > 0 and is_on_floor() and !check_for_ladder():
		if Input.is_action_just_pressed("ui_down") and input_vector.x and can_dropthrough():
			platform_drop()
			move()
		else:
			state = CROUCH
	else:
		if input_vector.x:
			if is_on_floor():
				animationState.travel("Run")
				handle_sprite_flip(input_vector)
		else:
			if is_on_floor():
				animationState.travel("Idle")
			else:
				animationState.travel("Fall")
	
		if Input.is_action_just_pressed("attack"):
			state = ATTACK
			
		if Input.is_action_just_pressed("dash") and has_airdash and !is_on_floor():
			if input_vector != Vector2.ZERO:
				airdash_direction = input_vector
				has_airdash = false
				state = AIRDASH
	
		if Input.is_action_just_pressed("jump"):
			if is_on_floor():
				has_double_jump = true
				call_deferred("jump")
			else:
				if has_double_jump:
					has_double_jump = false
					call_deferred("jump")
	
		if Input.is_action_just_released("jump"):
			jump_cut()
	
		if input_vector.x:
			var accel = acceleration
			if !is_on_floor():
				accel = air_acceleration
			velocity = velocity.move_toward(Vector2(input_vector.x * max_speed, velocity.y), accel * delta)
		else:
			velocity = velocity.move_toward(Vector2(0, velocity.y), friction * delta)
			
		if state == MOVE:
			if input_vector.y and is_on_floor():
				check_for_ladder()
			elif input_vector.y < 0 and !is_on_floor():
				check_for_ladder()
	
		move()
		if velocity.y > 0:
			animationState.travel("Fall")

#We only care about this being it's own state so we avoid applying gravity
func airdash_state(delta):
	animationState.travel("Fall")
	if timer.is_stopped():
		animationPlayer.play("Airdash")
		has_double_jump = false
		timer.set_wait_time(airdash_time)
		timer.start()
		velocity = Vector2(airdash_direction.x * airdash_speed, airdash_direction.y * airdash_speed)
	velocity = velocity.move_toward(Vector2(0, 0), friction * delta)
	velocity = move_and_slide(velocity, Vector2(0, -1))
	if is_on_floor():
		animationPlayer.seek(animationPlayer.get_current_animation_length(), true)
		timer.stop()
		has_double_jump = true
		state = MOVE

func crouch_state(delta):
	animationState.travel("Crouch")
	if is_on_floor():
		if Input.is_action_just_released("ui_down"):
			state = MOVE
		else:
			if Input.is_action_just_pressed("jump"):
				var input_vector = get_input_vector()
				if !input_vector.x and can_dropthrough():
					platform_drop()
					state = MOVE
				else:
					airdash_direction = input_vector
					has_airdash = false
					state = AIRDASH
			elif Input.is_action_just_pressed("attack"):
				state = ATTACK
	else:
		state = MOVE
	velocity = velocity.move_toward(Vector2(0, velocity.y), 0.7 * friction * delta)
	move()

func move():
	velocity.y = min(velocity.y - (-gravity), terminal_velocity)
	velocity = move_and_slide(velocity, Vector2(0, -1))

func attack_state(_delta):
	if is_on_floor():
		if velocity.x != 0:
			velocity.x = velocity.x / 2
	move()
	animationState.travel("Attack")

func climb_state(_delta):
	var input_vector = get_input_vector()
	
	if input_vector.y:
		animationState.travel("Climb")
	else:
		animationState.travel("ClimbIdle")
	
	velocity.x = 0
	velocity.y = climb_speed * input_vector.y
	if Input.is_action_just_pressed("jump"):
		if input_vector.x != 0:
			velocity.x = climb_speed * input_vector.x
			velocity.y -= climb_jump_height
			is_climbing = false
			has_double_jump = false
			handle_sprite_flip(input_vector)
			animationState.travel("Jump")
	velocity = move_and_slide(velocity)
	if velocity != Vector2.ZERO and is_climbing:
		check_for_ladder()
	if !is_climbing:
		state = MOVE
		$CollisionShape2D.disabled = false

func handle_sprite_flip(input):
	sprite.flip_h = min(0, input.x)
	hitbox_pivot.rotation_degrees = min(0, 180 * input.x)

func can_dropthrough():
	for body in platformDrop.get_overlapping_bodies():
		return false
	return true

func get_input_vector():
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	return input_vector.normalized()

func jump():
	velocity.y = -jump_height
	animationState.travel("Jump")
	
func platform_drop():
	if state == MOVE:
		animationState.travel("Fall")
		velocity.y = 10
	else:
		velocity.y = -90
		has_double_jump = false	
		animationState.travel("Jump")
	collisionShape.disabled = true
	tween.interpolate_callback(collisionShape, 0.2, "set_disabled", false)
	tween.start()

func jump_cut():
	if velocity.y < -180:
		velocity.y = -180

func check_for_ladder():
	var closest_area = null
	var input = get_input_vector()
	for area in ladderHitbox.get_overlapping_areas():
		var can_grab = area.get_parent().can_be_grabbed
		if is_on_floor():
			if input.y > 0:	 # don't check for ladders below us when we press "up" while on the ground
				if not closest_area:
					closest_area = area 
				elif area.global_position.distance_to(ladderHitbox.global_position) < closest_area.global_position.distance_to(ladderHitbox.global_position) and can_grab:
					closest_area = area
		else: # check for ladders in both directions
			if not closest_area:
				closest_area = area 
			elif area.global_position.distance_to(ladderHitbox.global_position) < closest_area.global_position.distance_to(ladderHitbox.global_position) and can_grab:
				closest_area = area
	if closest_area and closest_area.get_parent().can_be_grabbed: # found a ladder
			velocity = Vector2.ZERO
			self.global_position.x = closest_area.global_position.x
			is_climbing = true
			state = CLIMB
			$CollisionShape2D.disabled = true
			return true # useful for making sure we don't crouch instead over in move_state
	else: # no ladder, usually called when we've climbed passed the end of a ladder
		is_climbing = false
		state = MOVE
		if input.x:
			handle_sprite_flip(input)

func take_damage(dmg):
	stats.health -= dmg
	hp_bar.update_health(stats.health)
	hurtbox.start_invincibility(1.5)
	animationPlayer.play("Damage")
	spawn_floating_text(dmg)

func spawn_floating_text(text):
	var dmg_text = floating_text.instance()
	dmg_text.position += Vector2(rng.randf_range(-7, 7), (-25 + rng.randf_range(0, -5)))
	dmg_text.velocity = Vector2(rng.randf_range(-5, 5), 0)
	dmg_text.modulate = dmgTextColor
	dmg_text.text = text
	add_child(dmg_text)

func attack_animation_finished():
	if Input.is_action_pressed("ui_down") and is_on_floor():
		state = CROUCH
	else:
		state = MOVE

func _on_LadderHitbox_area_exited(area):
	area.get_parent().can_be_grabbed = false
	yield(get_tree().create_timer(0.2), "timeout")
	area.get_parent().can_be_grabbed = true

func _on_Hurtbox_area_entered(area):
	if !hurtbox.tookDamageThisFrame:
		var dir = Vector2(self.global_position.x - area.get_parent().global_position.x, 0).normalized()
		take_damage(area.get_damage())
		velocity = Vector2(area.knockback.x * dir.x, -area.knockback.y)


func _on_Timer_timeout():
	match state:
		AIRDASH:
			state = MOVE
