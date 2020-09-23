extends Control

onready var health_over = $HealthBarOver
onready var health_under = $HealthBarUnder
onready var tween = $Tween
onready var timer = $Timer


func update_health(health):
	health_over.value = health
	tween.interpolate_property(health_under, "value", health_under.value, health, 0.4, Tween.TRANS_CUBIC, Tween.EASE_OUT, 0.3)
	tween.start()

func update_max_health(max_health):
	health_over.max_value = max_health
	health_under.max_value = max_health


