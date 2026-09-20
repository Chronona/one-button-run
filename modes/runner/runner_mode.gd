extends "res://core/game_mode.gd"

# ランナーモード。タップ = ジャンプ。
#
# 時間も入力もホストから注入されるので、このスクリプトは _process も _input も
# 持たない（tests/contract/test_input_isolation.gd が静的に検査している）。

@onready var player = $Player

const SPAWN_REACTION_MARGIN := 0.25
const MIN_SPAWN_INTERVAL := 1.0
const SPAWN_INTERVAL_RANDOM := 1.5
const MIN_GAP_PIXELS := 350.0
const BASE_SPEED := 200.0
const SPEED_PER_SECOND := 5.0
const MAX_SPEED := 600.0
const INITIAL_SPAWN_COOLDOWN := 1.2
const OBSTACLE_SCENE: PackedScene = preload("res://modes/runner/obstacle.tscn")
const OBSTACLE_SPAWN_POS := Vector2(1200, 580)

const FEEDBACK_MAP := {
	"act": {"particles": "JumpParticles", "se": "JumpSE"},
	"land": {"particles": "LandParticles", "se": "LandSE"},
	"fail": {"particles": "CrashParticles", "se": "GameOverSE"},
	"record": {"particles": "", "se": "HighScoreSE"},
}

var game_speed: float = BASE_SPEED
var spawn_cooldown: float = INITIAL_SPAWN_COOLDOWN

var _elapsed: float = 0.0
var _failed: bool = false
var _min_spawn_interval: float = MIN_SPAWN_INTERVAL

func _ready() -> void:
	player.jumped.connect(_on_player_jumped)
	player.landed.connect(_on_player_landed)

	# 障害物の最低間隔はプレイヤーの滞空時間から導出する。定数のままだと、
	# 速度が上がったときに着地前へ次の障害物が到達する回避不能な配置が出る。
	_min_spawn_interval = maxf(MIN_SPAWN_INTERVAL, player.get_airtime() + SPAWN_REACTION_MARGIN)

func get_feedback_map() -> Dictionary:
	return FEEDBACK_MAP

func get_difficulty() -> float:
	return game_speed

func is_failed() -> bool:
	return _failed

# act / land は足元、fail / record は機体の中心寄りに出す。
const FAIL_FEEDBACK_OFFSET := Vector2(25, 25)

func get_feedback_position(event_name: String) -> Vector2:
	if event_name == "act" or event_name == "land":
		return player.position + player.FEEDBACK_OFFSET
	return player.position + FAIL_FEEDBACK_OFFSET

func get_player() -> Node2D:
	return player

func mode_start() -> void:
	_elapsed = 0.0
	_failed = false
	game_speed = BASE_SPEED
	spawn_cooldown = INITIAL_SPAWN_COOLDOWN # 開始直後の猶予
	# 残っている障害物を掃除（グループで確実に取得）
	for obstacle_node in _live_obstacles():
		_despawn(obstacle_node)
	player.reset()

func mode_tick(delta: float, act_pressed: bool, act_released: bool) -> void:
	_elapsed += delta

	# 経過に応じて速度を上げる（上限付きで遊びやすく保つ）
	game_speed = minf(BASE_SPEED + _elapsed * SPEED_PER_SECOND, MAX_SPEED)

	player.update(delta, act_pressed, act_released)
	_advance_obstacles(delta)

	# 障害物スポーン（最低間隔を保証するので詰み配置が出ない）
	spawn_cooldown -= delta
	if spawn_cooldown <= 0.0:
		spawn_obstacle()
		var base_interval := maxf(_min_spawn_interval, MIN_GAP_PIXELS / game_speed)
		spawn_cooldown = base_interval + host.get_rng().randf() * SPAWN_INTERVAL_RANDOM

	_check_collision()

func _on_player_jumped() -> void:
	host.emit_feedback("act")

func _on_player_landed() -> void:
	host.emit_feedback("land")

func _advance_obstacles(delta: float) -> void:
	for obstacle_node in _live_obstacles():
		obstacle_node.advance(delta)
		if obstacle_node.is_offscreen():
			_despawn(obstacle_node)

# 生存中の障害物一覧。取得箇所が3か所に散ると名前のtypoで
# 幽霊障害物が生まれるので、グループ名の記述はここに一本化する。
func _live_obstacles() -> Array[Node]:
	return get_tree().get_nodes_in_group("obstacles")

# グループから即座に外してから解放する。queue_free は次フレームまで残るため、
# 手動 tick のテストでは外し忘れると幽霊障害物と衝突してしまう。
func _despawn(obstacle_node: Node) -> void:
	obstacle_node.remove_from_group("obstacles")
	obstacle_node.queue_free()

func _check_collision() -> void:
	var player_rect: Rect2 = player.get_body_rect()
	for obstacle_node in _live_obstacles():
		if player_rect.intersects(obstacle_node.get_body_rect()):
			_failed = true
			return

func spawn_obstacle() -> void:
	var obstacle_node = OBSTACLE_SCENE.instantiate()
	obstacle_node.position = OBSTACLE_SPAWN_POS # 地面ライン上の障害物
	obstacle_node.set("speed", game_speed)
	add_child(obstacle_node)
