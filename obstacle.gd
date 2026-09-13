extends Area2D

@export var speed: float = 200.0

const DESPAWN_X := -50.0

func _process(delta: float) -> void:
	position.x -= speed * delta

	# 左端まで移動したら解放
	if position.x < DESPAWN_X:
		queue_free()
