extends Area2D

@export var speed: float = 200.0

const DESPAWN_X := -50.0
const BODY_SIZE := Vector2(40, 40)

func _ready() -> void:
	add_to_group("obstacles")
	# 時間はホスト（main.gd）が注入する。自前の _process は持たない。
	set_process(false)

func advance(delta: float) -> void:
	position.x -= speed * delta

func is_offscreen() -> bool:
	return position.x < DESPAWN_X

func get_body_rect() -> Rect2:
	return Rect2(position - BODY_SIZE * 0.5, BODY_SIZE)
