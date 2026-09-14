extends Node2D

# ゲーム状態定義
enum GameState {
	START,
	PLAYING,
	GAME_OVER
}

@onready var player = $Player
@onready var score_label: Label = $ScoreLabel
@onready var high_score_label: Label = $HighScoreLabel
@onready var game_over_label: Label = $GameOverLabel

var state: GameState = GameState.START
var score: float = 0.0
var high_score: int = 0
var game_speed: float = 200.0
# スポーン間隔の保証用（秒）。最低間隔は速度に追従するので高速化しても詰まらない
const MIN_SPAWN_INTERVAL := 1.0
const SPAWN_INTERVAL_RANDOM := 1.5
const BASE_SPEED := 200.0
const SPEED_PER_SECOND := 5.0
const MAX_SPEED := 600.0
const INITIAL_SPAWN_COOLDOWN := 1.2
const OBSTACLE_SCENE: PackedScene = preload("res://obstacle.tscn")
const OBSTACLE_SPAWN_POS := Vector2(1200, 580)
var spawn_cooldown: float = INITIAL_SPAWN_COOLDOWN

func _ready() -> void:
	_ensure_jump_action()
	# ハイスコアを読み込み
	var save_file := FileAccess.open("user://high_score.txt", FileAccess.READ)
	if save_file != null:
		high_score = save_file.get_as_text().to_int()

	# UIの初期化（スタート時の操作ヒントを表示）
	update_ui()
	game_over_label.text = "Spaceでスタート"
	game_over_label.show()

	player.jumped.connect(_on_player_jumped)
	player.landed.connect(_on_player_landed)

func _ensure_jump_action() -> void:
	if not InputMap.has_action("jump"):
		InputMap.add_action("jump")
	var key_space := InputEventKey.new()
	key_space.physical_keycode = KEY_SPACE
	if not InputMap.action_has_event("jump", key_space):
		InputMap.action_add_event("jump", key_space)
	var key_up := InputEventKey.new()
	key_up.physical_keycode = KEY_UP
	if not InputMap.action_has_event("jump", key_up):
		InputMap.action_add_event("jump", key_up)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	if not InputMap.action_has_event("jump", mb):
		InputMap.action_add_event("jump", mb)
	var touch := InputEventScreenTouch.new()
	if not InputMap.action_has_event("jump", touch):
		InputMap.action_add_event("jump", touch)

func _is_jump_pressed(event: InputEvent) -> bool:
	if event.is_action_pressed("jump"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		return event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_UP
	if event is InputEventMouseButton and event.pressed:
		return event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch and event.pressed:
		return true
	return false

func update_ui() -> void:
	score_label.text = "Score: %d" % int(score)
	high_score_label.text = "High Score: %d" % high_score

func _play_se(se_name: String) -> void:
	var se = get_node_or_null(se_name)
	if se != null and se.has_method("play"):
		se.play()

func _play_feedback(particles_name: String, se_name: String, pos: Vector2) -> void:
	var particles = get_node_or_null(particles_name)
	if particles != null and particles.has_method("restart"):
		particles.position = pos
		particles.restart()
	_play_se(se_name)

func start_game() -> void:
	state = GameState.PLAYING
	score = 0.0
	game_speed = BASE_SPEED
	spawn_cooldown = INITIAL_SPAWN_COOLDOWN # 開始直後の猶予
	# 残っている障害物を掃除
	for child in get_children():
		if child is Area2D:
			child.queue_free()
	player.reset()
	update_ui()
	game_over_label.hide()

func _on_player_jumped(pos: Vector2) -> void:
	_play_feedback("JumpParticles", "JumpSE", pos)

func _on_player_landed(pos: Vector2) -> void:
	_play_feedback("LandParticles", "LandSE", pos)

func game_over() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.GAME_OVER

	# ハイスコア更新チェック
	var is_record := int(score) > high_score
	if is_record:
		high_score = int(score)
		var save_file := FileAccess.open("user://high_score.txt", FileAccess.WRITE)
		if save_file != null:
			save_file.store_string(str(high_score))

	update_ui()
	if is_record:
		game_over_label.text = "Game Over - 新記録! Score: %d\nSpaceで再開" % int(score)
	else:
		game_over_label.text = "Game Over - Score: %d / High: %d\nSpaceで再開" % [int(score), high_score]
	game_over_label.show()

	# ゲームオーバー時の音とパーティクル
	_play_feedback("CrashParticles", "GameOverSE", player.position + Vector2(25, 25))

	# 高スコア更新時の音
	if is_record:
		_play_se("HighScoreSE")

func _process(delta: float) -> void:
	if state == GameState.PLAYING:
		score += delta

		# スコアに応じて速度を上げる（上限付きで遊びやすく保つ）
		game_speed = minf(BASE_SPEED + score * SPEED_PER_SECOND, MAX_SPEED)

		# プレイヤーの更新
		player.update(delta)

		# 障害物スポーン（最低間隔を保証するので詰み配置が出ない）
		spawn_cooldown -= delta
		if spawn_cooldown <= 0.0:
			spawn_obstacle()
			spawn_cooldown = MIN_SPAWN_INTERVAL + randf() * SPAWN_INTERVAL_RANDOM

		_check_collision()
		if state == GameState.PLAYING:
			update_ui()

func _check_collision() -> void:
	var player_rect := Rect2(player.position, Vector2(50, 50))
	for child in get_children():
		if child is Area2D:
			var obstacle_rect := Rect2(child.position - Vector2(20, 20), Vector2(40, 40))
			if player_rect.intersects(obstacle_rect):
				game_over()
				break

func spawn_obstacle() -> void:
	var obstacle = OBSTACLE_SCENE.instantiate()
	obstacle.position = OBSTACLE_SPAWN_POS # 地面ライン上の障害物
	obstacle.speed = game_speed
	add_child(obstacle)

func _input(event: InputEvent) -> void:
	if state != GameState.PLAYING and _is_jump_pressed(event):
		start_game()
