extends Node2D

signal jumped(pos: Vector2)
signal landed(pos: Vector2)

@export var gravity: float = 500.0
@export var jump_force: float = -300.0
@export var max_fall_speed: float = 1000.0

var velocity_y: float = 0.0
var is_jumping: bool = false
var on_ground: bool = true

const FLOOR_Y := 550.0
const START_X := 100.0
const JUMP_CUT_MULTIPLIER := 0.5

func reset() -> void:
	position = Vector2(START_X, FLOOR_Y)
	velocity_y = 0.0
	is_jumping = false
	on_ground = true

func update(delta: float) -> void:
	_try_jump()
	_cut_jump_on_release()
	_apply_gravity(delta)

	position.y += velocity_y * delta

	# 床との衝突判定
	if position.y >= FLOOR_Y:
		var was_airborne: bool = not on_ground
		position.y = FLOOR_Y
		on_ground = true
		is_jumping = false
		velocity_y = 0.0
		if was_airborne:
			landed.emit(position + Vector2(25, 50))

func _try_jump() -> void:
	if Input.is_action_just_pressed("jump") and on_ground:
		velocity_y = jump_force
		is_jumping = true
		on_ground = false
		jumped.emit(position + Vector2(25, 50))

func _cut_jump_on_release() -> void:
	if Input.is_action_just_released("jump"):
		if is_jumping and velocity_y < 0.0:
			velocity_y *= JUMP_CUT_MULTIPLIER # 上昇中のみ短くジャンプ

func _apply_gravity(delta: float) -> void:
	velocity_y += gravity * delta
	if velocity_y > max_fall_speed:
		velocity_y = max_fall_speed
