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
const BODY_SIZE := Vector2(50, 50)

func reset() -> void:
	position = Vector2(START_X, FLOOR_Y)
	velocity_y = 0.0
	is_jumping = false
	on_ground = true

func get_body_rect() -> Rect2:
	return Rect2(position, BODY_SIZE)

# 1回のジャンプで接地できない時間。障害物の最低間隔はこれを上回らなければ、
# 着地前に次の障害物が到達する＝回避不能な配置になる。
func get_airtime() -> float:
	return 2.0 * absf(jump_force) / gravity

# 入力と時間は必ず引数で注入する。Input シングルトンを直接参照しないので、
# 固定タイムステップのヘッドレス再生が完全に決定論的になる。
func update(delta: float, act_pressed: bool, act_released: bool) -> void:
	if act_pressed:
		_try_jump()
	if act_released:
		_cut_jump()
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
	if not on_ground:
		return
	velocity_y = jump_force
	is_jumping = true
	on_ground = false
	jumped.emit(position + Vector2(25, 50))

func _cut_jump() -> void:
	if is_jumping and velocity_y < 0.0:
		velocity_y *= JUMP_CUT_MULTIPLIER # 上昇中のみ短くジャンプ

func _apply_gravity(delta: float) -> void:
	velocity_y += gravity * delta
	if velocity_y > max_fall_speed:
		velocity_y = max_fall_speed
