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

const OBSTACLE_SCENE: PackedScene = preload("res://obstacle.tscn")

var state: GameState = GameState.START
var score: float = 0.0
var high_score: int = 0
var game_speed: float = 200.0
# スポーン間隔の保証用（秒）。最低間隔は速度に追従するので高速化しても詰まらない
const MIN_SPAWN_INTERVAL: float = 1.0
const SPAWN_INTERVAL_RANDOM: float = 1.5
var spawn_cooldown: float = 1.2

func _ready() -> void:
	_ensure_jump_action()
	# ハイスコアを読み込み
	var save_file := FileAccess.open("user://high_score.txt", FileAccess.READ)
	if save_file != null:
		high_score = save_file.get_as_text().to_int()
		save_file.close()

	# UIの初期化
	update_ui()
	
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
	var mouse_button := InputEventMouseButton.new()
	mouse_button.button_index = MOUSE_BUTTON_LEFT
	if not InputMap.action_has_event("jump", mouse_button):
		InputMap.action_add_event("jump", mouse_button)
	var touch_event := InputEventScreenTouch.new()
	if not InputMap.action_has_event("jump", touch_event):
		InputMap.action_add_event("jump", touch_event)

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

func _restart_particles(node_name: String, pos: Vector2) -> void:
	var particles := get_node_or_null(node_name) as CPUParticles2D
	if particles != null:
		particles.position = pos
		particles.restart()

func _play_sound(node_name: String) -> void:
	var sound := get_node_or_null(node_name) as AudioStreamPlayer
	if sound != null:
		sound.play()

func _clear_obstacles() -> void:
	for child in get_children():
		if child is Area2D:
			child.queue_free()

func start_game() -> void:
	state = GameState.PLAYING
	score = 0.0
	game_speed = 200.0
	spawn_cooldown = 1.2 # 開始直後の猶予
	# 残っている障害物を掃除
	_clear_obstacles()
	player.reset()
	update_ui()
	game_over_label.hide()

func _on_player_jumped(pos: Vector2) -> void:
	_restart_particles("JumpParticles", pos)
	_play_sound("JumpSE")

func _on_player_landed(pos: Vector2) -> void:
	_restart_particles("LandParticles", pos)
	_play_sound("LandSE")

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
			save_file.close()

	update_ui()
	if is_record:
		game_over_label.text = "Game Over - New Record: %d! Spaceで再開" % high_score
	else:
		game_over_label.text = "Game Over - Score: %d  Spaceで再開" % int(score)
	game_over_label.show()

	# ゲームオーバー時の音とパーティクル
	_restart_particles("CrashParticles", player.position + Vector2(25, 25))
	_play_sound("GameOverSE")

	# 高スコア更新時の音
	if is_record:
		_play_sound("HighScoreSE")

func _process(delta: float) -> void:
	if state == GameState.PLAYING:
		score += delta

		# スコアに応じて速度を上げる
		game_speed = 200.0 + score * 5.0

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
	var obstacle := OBSTACLE_SCENE.instantiate() as Area2D
	obstacle.position = Vector2(1200, 580) # 地面ライン上の障害物
	obstacle.set("speed", game_speed)
	add_child(obstacle)

func _input(event: InputEvent) -> void:
	if state == GameState.START and _is_jump_pressed(event):
		start_game()
	elif state == GameState.GAME_OVER and _is_jump_pressed(event):
		start_game()
