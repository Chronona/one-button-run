extends "res://core/game_mode.gd"

# ドッジャーモード。タップ = 上下レーンの瞬時切替。
#
# 遊び方: 自機は画面左に固定され、トゲが右から 2 本のレーンに沿って迫る。
# タップするたびにもう一方のレーンへ瞬時に移る。トゲに触れたら終わり。
# トゲは 2 レーンに必ず交互に現れるので、同時に両レーンが塞がれる
# 回避不能な配置は出ない。無操作なら最初のトゲが自機のレーンに来る。
#
# 時間も入力もホストから注入されるので、このスクリプトは自前の更新も
# 入力受け付けも持たない（tests/contract/test_input_isolation.gd が静的に検査）。

const SPIKE_SCRIPT: GDScript = preload("res://modes/dodger/spike.gd")

const PLAYER_X := 200.0
const LANE_TOP_Y := 230.0
const LANE_BOTTOM_Y := 450.0
const PLAYER_HALF := 20.0
const PLAYER_SIZE := Vector2(40, 40)
const FEEDBACK_OFFSET := Vector2(20, 20)
# レーンごとの自機色（見た目のみ）。当たり判定には使わない。
const LANE_TOP_COLOR := Color(0.25, 0.95, 1.0)
const LANE_BOTTOM_COLOR := Color(1.0, 0.45, 0.95)

const BASE_SPEED := 220.0
const SPEED_PER_SECOND := 1.5
const MAX_SPEED := 480.0
const SPAWN_X := 1240.0
const GAP_TRAVEL_PIXELS := 460.0
const SPAWN_INTERVAL_RANDOM := 0.6
const INITIAL_SPAWN_COOLDOWN := 1.0

const FEEDBACK_MAP := {
	"act": {"particles": "SwitchParticles", "se": "SwitchSE"},
	"fail": {"particles": "CrashParticles", "se": "GameOverSE"},
	"record": {"particles": "", "se": "HighScoreSE"},
}

var scroll_speed: float = BASE_SPEED
var player_lane: int = 0
var player_pos := Vector2(PLAYER_X, LANE_TOP_Y)
var spawn_cooldown: float = INITIAL_SPAWN_COOLDOWN

var _elapsed: float = 0.0
var _failed: bool = false
var _next_lane: int = 0

@onready var player: Polygon2D = $Player

func get_feedback_map() -> Dictionary:
	return FEEDBACK_MAP

func get_difficulty() -> float:
	return scroll_speed

func is_failed() -> bool:
	return _failed

func get_feedback_position(_event_name: String) -> Vector2:
	return player_pos + FEEDBACK_OFFSET

func get_player() -> Node:
	return self

func get_body_rect() -> Rect2:
	return Rect2(player_pos - Vector2(PLAYER_HALF, PLAYER_HALF), PLAYER_SIZE)

func lane_y(lane: int) -> float:
	if lane == 0:
		return LANE_TOP_Y
	return LANE_BOTTOM_Y

func mode_start() -> void:
	_elapsed = 0.0
	_failed = false
	scroll_speed = BASE_SPEED
	spawn_cooldown = INITIAL_SPAWN_COOLDOWN
	player_lane = 0
	player_pos = Vector2(PLAYER_X, LANE_TOP_Y)
	# 最初のトゲは自機のレーンに出す。無操作なら必ず当たるので、
	# 放置で遊べてしまうゲームにはならない。
	_next_lane = player_lane
	_clear_all_spikes()
	_sync_player()

func mode_tick(delta: float, act_pressed: bool, _act_released: bool) -> void:
	_elapsed += delta
	scroll_speed = minf(BASE_SPEED + _elapsed * SPEED_PER_SECOND, MAX_SPEED)

	if act_pressed and not _failed:
		player_lane = 1 - player_lane
		player_pos.y = lane_y(player_lane)
		host.emit_feedback("act")

	_sync_player()
	_advance_spikes(delta)

	spawn_cooldown -= delta
	if spawn_cooldown <= 0.0:
		spawn_spike()
		spawn_cooldown = GAP_TRAVEL_PIXELS / scroll_speed + host.get_rng().randf() * SPAWN_INTERVAL_RANDOM

	_check_collision()

func spawn_spike() -> void:
	var spike_node: Node2D = SPIKE_SCRIPT.new()
	spike_node.setup(_next_lane, Vector2(SPAWN_X, lane_y(_next_lane)), scroll_speed)
	add_child(spike_node)
	# レーンは必ず交互にする。同時に両レーンが塞がれないので、
	# 反応さえすれば回避不能な配置は出ない。
	_next_lane = 1 - _next_lane

func _advance_spikes(delta: float) -> void:
	for spike_node in _live_spikes():
		spike_node.advance(delta)
		if spike_node.is_offscreen():
			_despawn(spike_node)

# 生存中のトゲ一覧。取得箇所が散ると名前のtypoで
# 幽霊トゲが生まれるので、グループ名の記述はここに一本化する。
func _live_spikes() -> Array[Node]:
	return get_tree().get_nodes_in_group("spikes")

# ラウンド開始時の掃除用。進行中の破棄と同一手順にまとめて、
# 掃除漏れによる幽霊トゲとの衝突を防ぐ。
func _clear_all_spikes() -> void:
	for spike_node in _live_spikes():
		_despawn(spike_node)

# queue_free は次フレームまで残るため、グループから先に外す。
# 手動 tick のテストでは外し忘れると幽霊トゲと衝突してしまう。
func _despawn(spike_node: Node) -> void:
	spike_node.remove_from_group("spikes")
	spike_node.queue_free()

func _check_collision() -> void:
	var body := get_body_rect()
	for spike_node in _live_spikes():
		if body.intersects(spike_node.get_body_rect()):
			_failed = true
			return

func _sync_player() -> void:
	if player == null:
		return
	player.position = player_pos
	if player_lane == 0:
		player.color = LANE_TOP_COLOR
	else:
		player.color = LANE_BOTTOM_COLOR
