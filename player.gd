extends Node2D

signal jumped(pos: Vector2)
signal landed(pos: Vector2)

@export var gravity: float = 500.0
@export var jump_force: float = -300.0
@export var max_fall_speed: float = 1000.0

var velocity_y: float = 0.0
var is_jumping: bool = false
var on_ground: bool = true
var squash_tween: Tween

@onready var sprite: Sprite2D = $Sprite

const FLOOR_Y := 550.0
const JUMP_CUT_MULTIPLIER := 0.5
const JUMP_STRETCH := Vector2(0.8, 1.25)
const LAND_SQUASH := Vector2(1.3, 0.7)
const SQUASH_RECOVER_TIME := 0.2

# 足元を支点にスプライトを伸縮させ、元の大きさへ戻す
func _squash(target: Vector2) -> void:
	if squash_tween != null:
		squash_tween.kill()
	sprite.scale = target
	squash_tween = create_tween()
	var scale_tweener := squash_tween.tween_property(sprite, "scale", Vector2.ONE, SQUASH_RECOVER_TIME)
	scale_tweener.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func reset() -> void:
	position = Vector2(100, FLOOR_Y)
	velocity_y = 0.0
	is_jumping = false
	on_ground = true
	if squash_tween != null:
		squash_tween.kill()
	sprite.scale = Vector2.ONE

func update(delta: float) -> void:
	if Input.is_action_just_pressed("jump") and on_ground:
		velocity_y = jump_force
		is_jumping = true
		on_ground = false
		_squash(JUMP_STRETCH)
		jumped.emit(position + Vector2(25, 50))

	if Input.is_action_just_released("jump"):
		if is_jumping:
			velocity_y *= JUMP_CUT_MULTIPLIER # 短くジャンプ

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
		velocity_y = 0.0
		if was_airborne:
			_squash(LAND_SQUASH)
			landed.emit(position + Vector2(25, 50))
