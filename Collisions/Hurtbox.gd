extends Area2D

onready var timer = $Timer
onready var collisionShape = $CollisionShape2D

export var invincible = false setget set_invincible
var tookDamageThisFrame = false

signal invincibility_started
signal invincibility_ended

func start_invincibility(duration):
	self.invincible = true
	timer.start(duration)

func set_invincible(value):
	invincible = value
	if invincible:
		emit_signal("invincibility_started")
	else:
		emit_signal("invincibility_ended")

func _on_Timer_timeout():
	self.invincible = false

func _on_Hurtbox_invincibility_ended():
	tookDamageThisFrame = false
	collisionShape.set_deferred("disabled", false)

func _on_Hurtbox_invincibility_started():
	tookDamageThisFrame = true
	collisionShape.set_deferred("disabled", true)
