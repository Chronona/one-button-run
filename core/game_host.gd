extends Node2D

# ゲームのホスト。ジャンルが変わっても不変な部分だけを持つ。
#
#   - START / PLAYING / GAME_OVER の状態機械と、1アクションだけで一周する再開フロー
#   - スコアとハイスコアの永続化
#   - 唯一の入力経路（press_act / release_act）
#   - 演出イベントの発火（実体のノードはモード側にある）
#   - registry.json で指定されたモードの読み込み
#
# 実際のゲームプレイは modes/ 配下のモードが持つ。週次の大型アップデートは
# モードを追加して registry.json の active を切り替えるだけで完結する。

enum GameState {
	START,
	PLAYING,
	GAME_OVER
}

signal feedback_emitted(event_name: String)

@onready var score_label: Label = $ScoreLabel
@onready var high_score_label: Label = $HighScoreLabel
@onready var game_over_label: Label = $GameOverLabel
@onready var mode_container: Node2D = $ModeContainer

const REGISTRY_PATH := "res://modes/registry.json"
const HIGH_SCORE_PATH := "user://high_score.txt"

# 唯一の操作アクション。1ボタン契約の中心なので、ここを増やすと契約テストが落ちる。
const ACT_ACTION := "jump"

var state: GameState = GameState.START
var score: float = 0.0
var high_score: int = 0

var _mode: Node = null
var _rng := RandomNumberGenerator.new()
var _act_pressed_latch: bool = false
var _act_released_latch: bool = false

func _ready() -> void:
	_rng.randomize()
	_ensure_act_action()
	_load_high_score()
	_load_active_mode()

	# UIの初期化（スタート時の操作ヒントを表示）
	update_ui()
	game_over_label.text = "Spaceでスタート"
	game_over_label.show()

func _load_active_mode() -> void:
	var entry := get_active_mode_entry()
	var scene_path: String = entry.get("scene", "")
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		push_error("有効なモードのシーンを解決できません: '%s'" % scene_path)
		return
	var scene: PackedScene = load(scene_path)
	_mode = scene.instantiate()
	mode_container.add_child(_mode)
	_mode.mode_setup(self)

# registry.json の active が指すモードの定義を返す。テストもここを通して spec を引く。
func get_active_mode_entry() -> Dictionary:
	if not FileAccess.file_exists(REGISTRY_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
	if not parsed is Dictionary:
		return {}
	var active: String = parsed.get("active", "")
	var modes: Dictionary = parsed.get("modes", {})
	return modes.get(active, {})

func get_active_mode() -> Node:
	return _mode

func get_rng() -> RandomNumberGenerator:
	return _rng

# テストとリプレイのための決定論シード。実プレイでは _ready の randomize が効く。
# seed の代入が state もリセットするので、state を別途 0 にしてはいけない
# （0 にすると seed が打ち消され、どのシードでも同じ乱数列になる）。
func set_rng_seed(rng_seed: int) -> void:
	_rng.seed = rng_seed

func is_playing() -> bool:
	return state == GameState.PLAYING

func is_game_over() -> bool:
	return state == GameState.GAME_OVER

# 難易度と演出定義はモードが持つ。ホストは素通しするだけ。
func get_difficulty() -> float:
	return _mode.get_difficulty() if _mode != null else 0.0

func get_feedback_map() -> Dictionary:
	return _mode.get_feedback_map() if _mode != null else {}

func _ensure_act_action() -> void:
	if not InputMap.has_action(ACT_ACTION):
		InputMap.add_action(ACT_ACTION)
	var space_key := InputEventKey.new()
	space_key.physical_keycode = KEY_SPACE
	_register_act_event(space_key)
	var up_key := InputEventKey.new()
	up_key.physical_keycode = KEY_UP
	_register_act_event(up_key)
	var mouse_button := InputEventMouseButton.new()
	mouse_button.button_index = MOUSE_BUTTON_LEFT
	_register_act_event(mouse_button)
	_register_act_event(InputEventScreenTouch.new())

func _register_act_event(event: InputEvent) -> void:
	if not InputMap.action_has_event(ACT_ACTION, event):
		InputMap.action_add_event(ACT_ACTION, event)

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

# 演出の発火。ノードの解決はモードのシーン内で行うので、ホストは
# どんな見た目・音になっているかを知らない。
func emit_feedback(event_name: String, pos: Vector2) -> void:
	var entry: Dictionary = get_feedback_map().get(event_name, {})
	if _mode != null:
		var particles_name: String = entry.get("particles", "")
		if particles_name != "":
			var particles = _mode.get_node_or_null(particles_name)
			if particles != null and particles.has_method("restart"):
				particles.position = pos
				particles.restart()
		var se_name: String = entry.get("se", "")
		if se_name != "":
			var sound_player = _mode.get_node_or_null(se_name)
			if sound_player != null and sound_player.has_method("play"):
				sound_player.play()
	feedback_emitted.emit(event_name)

func start_game() -> void:
	state = GameState.PLAYING
	score = 0.0
	if _mode != null:
		_mode.mode_start()
	update_ui()
	game_over_label.hide()

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

	var fail_pos: Vector2 = _mode.get_fail_position() if _mode != null else Vector2.ZERO
	emit_feedback("fail", fail_pos)

	if is_record:
		emit_feedback("record", fail_pos)

func _process(delta: float) -> void:
	tick(delta)

# ゲーム進行の全体。時間を引数で受けるので、テストは実時間を待たずに
# 固定タイムステップで何十秒ぶんでも一瞬で再生できる。
func tick(delta: float) -> void:
	var act_pressed := _act_pressed_latch
	var act_released := _act_released_latch
	_act_pressed_latch = false
	_act_released_latch = false

	if state != GameState.PLAYING or _mode == null:
		return

	score += delta
	_mode.mode_tick(delta, act_pressed, act_released)

	if _mode.is_failed():
		game_over()
	else:
		update_ui()
