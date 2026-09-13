extends Area2D

@export var speed = 200.0

func _process(delta):
	# 障害物を左に移動（速度はスポーン時に上書きされる）
	position.x -= speed * delta

	# 画面外に出たら削除
	if position.x < -50:
		queue_free()
