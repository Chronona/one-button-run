extends Node2D

signal jumped(pos: Vector2)
signal landed(pos: Vector2)

@export var gravity = 500.0
@export var jump_force = -300.0
@export var max_fall_speed = 1000.0

var velocity_y = 0.0
var is_jumping = false
var on_ground = true

const FLOOR_Y = 550.0

func reset():
	position = Vector2(100, FLOOR_Y)
	velocity_y = 0
	is_jumping = false
	on_ground = true

func update(delta, _speed):
	if Input.is_action_just_pressed("jump") and on_ground:
		velocity_y = jump_force
		is_jumping = true
		on_ground = false
		jumped.emit(position + Vector2(25, 50))

	if Input.is_action_just_released("jump"):
		if is_jumping:
			velocity_y *= 0.5 # 短くジャンプ

	# 重力適用
	velocity_y += gravity * delta

	# 最大落下速度制限
	if velocity_y > max_fall_speed:
		velocity_y = max_fall_speed

	position.y += velocity_y * delta

	# 床との衝突判定
	if position.y >= FLOOR_Y:
		var was_airborne: bool = not on_ground
		position.y = FLOOR_Y
		on_ground = true
		is_jumping = false
		velocity_y = 0
		if was_airborne:
			landed.emit(position + Vector2(25, 50))
