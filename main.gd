extends Node2D

# ゲーム状態定義
enum GameState {
	START,
	PLAYING,
	GAME_OVER
}

@onready var player = $Player
@onready var score_label = $ScoreLabel
@onready var high_score_label = $HighScoreLabel
@onready var game_over_label = $GameOverLabel

var state = GameState.START
var score: float = 0.0
var high_score: int = 0
var game_speed = 200.0
# スポーン間隔の保証用（秒）。最低間隔は速度に追従するので高速化しても詰まない
const MIN_SPAWN_INTERVAL = 1.0
const SPAWN_INTERVAL_RANDOM = 1.5
var spawn_cooldown = 1.2

func _ready():
	_ensure_jump_action()
	# ハイスコアを読み込み
	var file = FileAccess.open("user://high_score.txt", FileAccess.READ)
	if file != null:
		high_score = file.get_as_text().to_int()

	# UIの初期化
	update_ui()

func _ensure_jump_action():
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

func update_ui():
	score_label.text = "Score: %d" % int(score)
	high_score_label.text = "High Score: %d" % high_score

func start_game():
	state = GameState.PLAYING
	score = 0.0
	game_speed = 200.0
	spawn_cooldown = 1.2 # 開始直後の猶予
	# 残っている障害物を掃除
	for child in get_children():
		if child is Area2D:
			child.queue_free()
	player.reset()
	update_ui()
	game_over_label.hide()

func game_over():
	if state != GameState.PLAYING:
		return
	state = GameState.GAME_OVER

	# ハイスコア更新チェック
	if int(score) > high_score:
		high_score = int(score)
		var file = FileAccess.open("user://high_score.txt", FileAccess.WRITE)
		if file != null:
			file.store_string(str(high_score))

	update_ui()
	game_over_label.show()

func _process(delta):
	if state == GameState.PLAYING:
		score += delta

		# スコアに応じて速度を上げる
		game_speed = 200.0 + score * 5.0

		# プレイヤーの更新
		player.update(delta, game_speed)

		# 障害物スポーン（最低間隔を保証するので詰み配置が出ない）
		spawn_cooldown -= delta
		if spawn_cooldown <= 0.0:
			spawn_obstacle()
			spawn_cooldown = MIN_SPAWN_INTERVAL + randf() * SPAWN_INTERVAL_RANDOM

		_check_collision()

func _check_collision():
	var player_rect := Rect2(player.position, player.size)
	for child in get_children():
		if child is Area2D and child.name.begins_with("Obstacle"):
			var obstacle_rect := Rect2(child.position - Vector2(20, 20), Vector2(40, 40))
			if player_rect.intersects(obstacle_rect):
				game_over()
				break

func spawn_obstacle():
	var obstacle = preload("res://obstacle.tscn").instantiate()
	obstacle.name = "Obstacle"
	obstacle.position = Vector2(1200, 580) # 地面ライン上の障害物
	obstacle.speed = game_speed
	add_child(obstacle)

func _input(event):
	if state == GameState.START and _is_jump_pressed(event):
		start_game()
	elif state == GameState.GAME_OVER and _is_jump_pressed(event):
		start_game()
