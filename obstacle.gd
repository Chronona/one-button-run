extends Area2D

@export var speed: float = 200.0

func _process(delta: float) -> void:
	position.x -= speed * delta
	
	# 左端まで移動したら解放
	if position.x < -50:
		queue_free()
