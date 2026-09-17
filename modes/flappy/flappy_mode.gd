extends "res://core/game_mode.gd"

# フラッピーモード。タップ = 羽ばたき（上昇）。
#
# 重力が常に下へ引くので、放っておけば床に落ちて終わる。
# ゲートの隙間を抜けるために、タップで高度を保つのが仕事。
# 時間も入力もホストから注入されるので、自前の更新関数は持たない。

const GATE_SCRIPT: GDScript = preload("res://modes/flappy/gate.gd")

const PLAYER_X := 200.0
const START_Y := 250.0
const FLOOR_Y := 560.0
const CEIL_Y := 40.0
const GRAVITY := 450.0
const FLAP_VELOCITY := -300.0
const MAX_FALL_SPEED := 700.0
const PLAYER_SIZE := Vector2(40, 36)
const FEEDBACK_OFFSET := Vector2(20, 18)

const BASE_SPEED := 180.0
const SPEED_PER_SECOND := 1.2
const MAX_SPEED := 360.0
const SPAWN_X := 1240.0
const GATE_WIDTH := 90.0
const GAP_HALF := 170.0
const GAP_TRAVEL_PIXELS := 520.0
const MIN_GAP_CENTER := 170.0
const MAX_GAP_CENTER := 460.0
const MAX_GAP_STEP := 120.0
const INITIAL_SPAWN_COOLDOWN := 1.6
const INITIAL_GAP_Y := 300.0

const FEEDBACK_MAP := {
	"act": {"particles": "FlapParticles", "se": "FlapSE"},
	"fail": {"particles": "CrashParticles", "se": "GameOverSE"},
	"record": {"particles": "", "se": "HighScoreSE"},
}

var scroll_speed: float = BASE_SPEED
var player_pos := Vector2(PLAYER_X, START_Y)
var velocity_y: float = 0.0
var spawn_cooldown: float = INITIAL_SPAWN_COOLDOWN

var _elapsed: float = 0.0
var _failed: bool = false
var _last_gap_y: float = INITIAL_GAP_Y

@onready var bird: Polygon2D = $Bird

func get_feedback_map() -> Dictionary:
	return FEEDBACK_MAP

func get_difficulty() -> float:
	return scroll_speed

func is_failed() -> bool:
	return _failed

func get_fail_position() -> Vector2:
	return player_pos + FEEDBACK_OFFSET

func get_player() -> Node:
	return self

func get_body_rect() -> Rect2:
	return Rect2(player_pos, PLAYER_SIZE)

func mode_start() -> void:
	_elapsed = 0.0
	_failed = false
	scroll_speed = BASE_SPEED
	spawn_cooldown = INITIAL_SPAWN_COOLDOWN
	_last_gap_y = INITIAL_GAP_Y
	player_pos = Vector2(PLAYER_X, START_Y)
	velocity_y = 0.0
	for gate_node in get_tree().get_nodes_in_group("gates"):
		_despawn(gate_node)
	_sync_bird()

func mode_tick(delta: float, act_pressed: bool, act_released: bool) -> void:
	_elapsed += delta
	scroll_speed = minf(BASE_SPEED + _elapsed * SPEED_PER_SECOND, MAX_SPEED)

	if act_pressed and not _failed:
		velocity_y = FLAP_VELOCITY
		host.emit_feedback("act", player_pos + FEEDBACK_OFFSET)

	velocity_y = minf(velocity_y + GRAVITY * delta, MAX_FALL_SPEED)
	player_pos.y += velocity_y * delta

	if player_pos.y < CEIL_Y:
		player_pos.y = CEIL_Y
		velocity_y = maxf(velocity_y, 0.0)

	_advance_gates(delta)

	spawn_cooldown -= delta
	if spawn_cooldown <= 0.0:
		spawn_gate()
		spawn_cooldown = GAP_TRAVEL_PIXELS / scroll_speed

	if player_pos.y >= FLOOR_Y:
		_failed = true
		return
	_check_gate_collision()
	_sync_bird()

func spawn_gate() -> void:
	var gap_y: float = clampf(
		_last_gap_y + host.get_rng().randf_range(-MAX_GAP_STEP, MAX_GAP_STEP),
		MIN_GAP_CENTER, MAX_GAP_CENTER)
	_last_gap_y = gap_y
	var gate_node: Node2D = GATE_SCRIPT.new()
	gate_node.setup(gap_y, GAP_HALF, GATE_WIDTH, scroll_speed)
	gate_node.position = Vector2(SPAWN_X, 0.0)
	add_child(gate_node)

func _advance_gates(delta: float) -> void:
	for gate_node in get_tree().get_nodes_in_group("gates"):
		gate_node.advance(delta)
		if gate_node.is_offscreen():
			_despawn(gate_node)

# queue_free は次フレームまで残るため、グループから先に外す。
# 手動 tick のテストでは外し忘れると幽霊ゲートと衝突してしまう。
func _despawn(gate_node: Node) -> void:
	gate_node.remove_from_group("gates")
	gate_node.queue_free()

func _check_gate_collision() -> void:
	var body := get_body_rect()
	for gate_node in get_tree().get_nodes_in_group("gates"):
		if gate_node.collides_with(body):
			_failed = true
			return

func _sync_bird() -> void:
	if bird != null:
		bird.position = player_pos + PLAYER_SIZE * 0.5
		bird.rotation = clampf(velocity_y / MAX_FALL_SPEED, -0.45, 0.6)
