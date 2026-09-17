extends Node2D

# ゲーム状態定義
enum GameState {
	START,
	PLAYING,
	GAME_OVER
}

signal feedback_emitted(event_name: String)

@onready var player = $Player
@onready var score_label: Label = $ScoreLabel
@onready var high_score_label: Label = $HighScoreLabel
@onready var game_over_label: Label = $GameOverLabel

var state: GameState = GameState.START
var score: float = 0.0
var high_score: int = 0
var game_speed: float = 200.0
# スポーン間隔の下限（秒）。プレイヤーの滞空時間＋反応猶予から導出するので、
# ジャンプ性能を調整しても回避不能な配置は生まれない。
const SPAWN_REACTION_MARGIN := 0.25
const MIN_SPAWN_INTERVAL := 1.0
const SPAWN_INTERVAL_RANDOM := 1.5
const MIN_GAP_PIXELS := 350.0
const BASE_SPEED := 200.0
const SPEED_PER_SECOND := 5.0
const MAX_SPEED := 600.0
const INITIAL_SPAWN_COOLDOWN := 1.2
const OBSTACLE_SCENE: PackedScene = preload("res://obstacle.tscn")
const OBSTACLE_SPAWN_POS := Vector2(1200, 580)
const HIGH_SCORE_PATH := "user://high_score.txt"

# 唯一の操作アクション。1ボタン契約の中心なので、ここを増やすと契約テストが落ちる。
const ACT_ACTION := "jump"

# フィードバック契約。イベント名 -> 視覚 / 聴覚チャンネル。
# ノード名ではなくイベント名でテストするので、演出を差し替えても契約は壊れない。
const FEEDBACK_MAP := {
	"act": {"particles": "JumpParticles", "se": "JumpSE"},
	"land": {"particles": "LandParticles", "se": "LandSE"},
	"fail": {"particles": "CrashParticles", "se": "GameOverSE"},
	"record": {"particles": "", "se": "HighScoreSE"},
}

var spawn_cooldown: float = INITIAL_SPAWN_COOLDOWN

var _min_spawn_interval: float = MIN_SPAWN_INTERVAL
var _rng := RandomNumberGenerator.new()
var _act_pressed_latch: bool = false
var _act_released_latch: bool = false

func _ready() -> void:
	_rng.randomize()
	_ensure_act_action()
	_load_high_score()

	# UIの初期化（スタート時の操作ヒントを表示）
	update_ui()
	game_over_label.text = "Spaceでスタート"
	game_over_label.show()

	player.jumped.connect(_on_player_jumped)
	player.landed.connect(_on_player_landed)

	_min_spawn_interval = maxf(MIN_SPAWN_INTERVAL, player.get_airtime() + SPAWN_REACTION_MARGIN)

# テストとリプレイのための決定論シード。実プレイでは _ready の randomize が効く。
# seed の代入が state もリセットするので、state を別途 0 にしてはいけない
# （0 にすると seed が打ち消され、どのシードでも同じ乱数列になる）。
func set_rng_seed(rng_seed: int) -> void:
	_rng.seed = rng_seed

func is_playing() -> bool:
	return state == GameState.PLAYING

func is_game_over() -> bool:
	return state == GameState.GAME_OVER

func _ensure_act_action() -> void:
	if not InputMap.has_action(ACT_ACTION):
		InputMap.add_action(ACT_ACTION)
	var space_key := InputEventKey.new()
	space_key.physical_keycode = KEY_SPACE
	if not InputMap.action_has_event(ACT_ACTION, space_key):
		InputMap.action_add_event(ACT_ACTION, space_key)
	var up_key := InputEventKey.new()
	up_key.physical_keycode = KEY_UP
	if not InputMap.action_has_event(ACT_ACTION, up_key):
		InputMap.action_add_event(ACT_ACTION, up_key)
	var mouse_button := InputEventMouseButton.new()
	mouse_button.button_index = MOUSE_BUTTON_LEFT
	if not InputMap.action_has_event(ACT_ACTION, mouse_button):
		InputMap.action_add_event(ACT_ACTION, mouse_button)
	var touch_event := InputEventScreenTouch.new()
	if not InputMap.action_has_event(ACT_ACTION, touch_event):
		InputMap.action_add_event(ACT_ACTION, touch_event)

func _load_high_score() -> void:
	var save_file := FileAccess.open(HIGH_SCORE_PATH, FileAccess.READ)
	if save_file != null:
		high_score = save_file.get_as_text().to_int()

func _save_high_score() -> void:
	var save_file := FileAccess.open(HIGH_SCORE_PATH, FileAccess.WRITE)
	if save_file != null:
		save_file.store_string(str(high_score))

func _is_act_pressed(event: InputEvent) -> bool:
	if event.is_action_pressed(ACT_ACTION):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		return event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_UP
	if event is InputEventMouseButton and event.pressed:
		return event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch and event.pressed:
		return true
	return false

func _is_act_released(event: InputEvent) -> bool:
	if event.is_action_released(ACT_ACTION):
		return true
	if event is InputEventKey and not event.pressed:
		return event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_UP
	if event is InputEventMouseButton and not event.pressed:
		return event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch and not event.pressed:
		return true
	return false

# 唯一の入力経路。テストとボットもここを叩くので、実プレイと同じ道筋を通る。
func press_act() -> void:
	if state != GameState.PLAYING:
		start_game()
	_act_pressed_latch = true

func release_act() -> void:
	_act_released_latch = true

func _input(event: InputEvent) -> void:
	if _is_act_pressed(event):
		press_act()
	elif _is_act_released(event):
		release_act()

func update_ui() -> void:
	score_label.text = "Score: %d" % int(score)
	high_score_label.text = "High Score: %d" % high_score

# 演出の実体。イベント名で引けるので、モードごとに差し替えても呼び出し側は変わらない。
func emit_feedback(event_name: String, pos: Vector2) -> void:
	var entry: Dictionary = FEEDBACK_MAP.get(event_name, {})
	var particles_name: String = entry.get("particles", "")
	if particles_name != "":
		var particles = get_node_or_null(particles_name)
		if particles != null and particles.has_method("restart"):
			particles.position = pos
			particles.restart()
	var se_name: String = entry.get("se", "")
	if se_name != "":
		var sound_player = get_node_or_null(se_name)
		if sound_player != null and sound_player.has_method("play"):
			sound_player.play()
	feedback_emitted.emit(event_name)

func start_game() -> void:
	state = GameState.PLAYING
	score = 0.0
	game_speed = BASE_SPEED
	spawn_cooldown = INITIAL_SPAWN_COOLDOWN # 開始直後の猶予
	# 残っている障害物を掃除（グループで確実に取得）
	for obstacle_node in get_tree().get_nodes_in_group("obstacles"):
		_despawn(obstacle_node)
	player.reset()
	update_ui()
	game_over_label.hide()

func _on_player_jumped(pos: Vector2) -> void:
	emit_feedback("act", pos)

func _on_player_landed(pos: Vector2) -> void:
	emit_feedback("land", pos)

func game_over() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.GAME_OVER

	# ハイスコア更新チェック
	var is_record := int(score) > high_score
	if is_record:
		high_score = int(score)
		_save_high_score()

	update_ui()
	if is_record:
		game_over_label.text = "Game Over - 新記録! Score: %d\nSpaceで再開" % int(score)
	else:
		game_over_label.text = "Game Over - Score: %d / High: %d\nSpaceで再開" % [int(score), high_score]
	game_over_label.show()

	emit_feedback("fail", player.position + Vector2(25, 25))

	if is_record:
		emit_feedback("record", player.position + Vector2(25, 25))

func _process(delta: float) -> void:
	tick(delta)

# ゲーム進行の全体。時間を引数で受けるので、テストは実時間を待たずに
# 固定タイムステップで何十秒ぶんでも一瞬で再生できる。
func tick(delta: float) -> void:
	var act_pressed := _act_pressed_latch
	var act_released := _act_released_latch
	_act_pressed_latch = false
	_act_released_latch = false

	if state != GameState.PLAYING:
		return

	score += delta

	# スコアに応じて速度を上げる（上限付きで遊びやすく保つ）
	game_speed = minf(BASE_SPEED + score * SPEED_PER_SECOND, MAX_SPEED)

	player.update(delta, act_pressed, act_released)
	_advance_obstacles(delta)

	# 障害物スポーン（最低間隔を保証するので詰み配置が出ない）
	spawn_cooldown -= delta
	if spawn_cooldown <= 0.0:
		spawn_obstacle()
		var base_interval := maxf(_min_spawn_interval, MIN_GAP_PIXELS / game_speed)
		spawn_cooldown = base_interval + _rng.randf() * SPAWN_INTERVAL_RANDOM

	_check_collision()
	if state == GameState.PLAYING:
		update_ui()

func _advance_obstacles(delta: float) -> void:
	for obstacle_node in get_tree().get_nodes_in_group("obstacles"):
		obstacle_node.advance(delta)
		if obstacle_node.is_offscreen():
			_despawn(obstacle_node)

# グループから即座に外してから解放する。queue_free は次フレームまで残るため、
# 手動 tick のテストでは外し忘れると幽霊障害物と衝突してしまう。
func _despawn(obstacle_node: Node) -> void:
	obstacle_node.remove_from_group("obstacles")
	obstacle_node.queue_free()

func _check_collision() -> void:
	var player_rect: Rect2 = player.get_body_rect()
	for obstacle_node in get_tree().get_nodes_in_group("obstacles"):
		if player_rect.intersects(obstacle_node.get_body_rect()):
			game_over()
			break

func spawn_obstacle() -> void:
	var obstacle_node = OBSTACLE_SCENE.instantiate()
	obstacle_node.position = OBSTACLE_SPAWN_POS # 地面ライン上の障害物
	obstacle_node.set("speed", game_speed)
	add_child(obstacle_node)
