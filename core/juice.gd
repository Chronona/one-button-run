extends Node

# 失敗時の画面演出（ヒットストップ・画面シェイク・フラッシュ）。
#
# ホストの feedback_emitted("fail") だけを契機にするので、どのモードでも同じように効く。
# モードもホストの状態機械も、この演出の存在を知らない。
# 時間は実時間で測る。ヒットストップ中は Engine.time_scale が下がるため、
# タイマーとトゥイーンは time_scale を無視させている。
# ゲームの進行は host.tick(delta) に注入された delta で動くので、演出は進行に影響しない。

const HITSTOP_TIME_SCALE := 0.05
const HITSTOP_DURATION_SEC := 0.12
const SHAKE_STRENGTH := 14.0
const SHAKE_DURATION_SEC := 0.35
const FLASH_ALPHA := 0.6
const FLASH_DURATION_SEC := 0.25

@onready var camera: Camera2D = $"../Camera"
@onready var flash_rect: ColorRect = $"../FlashLayer/FlashRect"

var _hitstop_id: int = 0
var _shake_tween: Tween
var _flash_tween: Tween

func _ready() -> void:
	var host := get_parent()
	host.feedback_emitted.connect(_on_feedback_emitted)
	host.game_started.connect(reset)

# テストがシーンを破棄したときに time_scale を残さない。
func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _on_feedback_emitted(event_name: String) -> void:
	if event_name == "fail":
		_start_hitstop()
		_start_shake()
		_start_flash()

# 再開時に演出を全部止めて初期状態へ戻す。ヒットストップ中に再開されても
# time_scale が残らない。
func reset() -> void:
	_end_hitstop(_hitstop_id)
	_hitstop_id += 1
	if _shake_tween != null:
		_shake_tween.kill()
	if _flash_tween != null:
		_flash_tween.kill()
	camera.offset = Vector2.ZERO
	flash_rect.color.a = 0.0

func _start_hitstop() -> void:
	_hitstop_id += 1
	Engine.time_scale = HITSTOP_TIME_SCALE
	# 第4引数 true で time_scale を無視する（遅くなった時間で待たない）。
	get_tree().create_timer(HITSTOP_DURATION_SEC, true, false, true).timeout.connect(
		_end_hitstop.bind(_hitstop_id))

# 古いタイマーが、後から始まったヒットストップを止めないよう id で照合する。
func _end_hitstop(id: int) -> void:
	if id == _hitstop_id:
		Engine.time_scale = 1.0

func _start_shake() -> void:
	if _shake_tween != null:
		_shake_tween.kill()
	_shake_tween = create_tween().set_ignore_time_scale(true)
	# 強さを 1 -> 0 に減衰させながら、毎フレーム向きをランダムに振る。
	_shake_tween.tween_method(_apply_shake, 1.0, 0.0, SHAKE_DURATION_SEC)
	_shake_tween.tween_callback(func() -> void: camera.offset = Vector2.ZERO)

func _apply_shake(decay: float) -> void:
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_STRENGTH * decay

func _start_flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	flash_rect.color.a = FLASH_ALPHA
	_flash_tween = create_tween().set_ignore_time_scale(true)
	_flash_tween.tween_property(flash_rect, "color:a", 0.0, FLASH_DURATION_SEC)
