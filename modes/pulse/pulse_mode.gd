extends "res://core/game_mode.gd"

# パルスモード。タップ = 拍に合わせた鼓動の一撃。
#
# 遊び方: 中心に向かって縮むリングが、目標の輪に重なった瞬間にタップする。
# 早すぎても遅すぎてもミスで終わり、黙って見ていても輪が閉じて終わる。
# テンポは速く、許容幅は狭くなり続ける。生き残るには毎拍の判断が要る。
#
# 時間も入力もホストから注入されるので、このスクリプトは自前の更新関数も
# 入力受け付けも持たない（tests/contract/test_input_isolation.gd が静的に検査）。

const CENTER := Vector2(576, 324)
const R_OUTER := 360.0
const TARGET_PHASE := 0.55
const R_TARGET := R_OUTER * (1.0 - TARGET_PHASE)

const BASE_PERIOD := 2.0
const MIN_PERIOD := 0.9
const PERIOD_SHRINK := 0.0061
const BASE_HALF := 0.09
const MIN_HALF := 0.045
const HALF_NARROW := 0.00025
const SUCCESS_SCORE := 5.0
const RING_POINTS := 48

const FEEDBACK_MAP := {
	"act": {"particles": "PulseParticles", "se": "PulseSE"},
	"fail": {"particles": "CrashParticles", "se": "GameOverSE"},
	"record": {"particles": "", "se": "HighScoreSE"},
}
const FEEDBACK_OFFSET := Vector2(0, -40)

# 成功時の鼓動（見た目のみ）。当たり判定は phase で行うので、
# 伸縮しても難易度には影響しない。
const HEART_PULSE := Vector2(1.5, 1.5)
const HEART_RECOVER_SEC := 0.2

var phase: float = 0.0
var beats: int = 0

var _elapsed: float = 0.0
var _failed: bool = false
# 同じ拍での空振り回数。開始タップは判定の前に来るため、初回の空振りは
# 警告に留める。連打でごまかすと2回目で失敗するので、連打は通用しない。
var _faults: int = 0
var _heart_tween: Tween

@onready var pulse_ring: Line2D = $PulseRing
@onready var window_in: Line2D = $WindowIn
@onready var window_out: Line2D = $WindowOut
@onready var target_ring: Line2D = $TargetRing
@onready var heart: Polygon2D = $Heart

func _ready() -> void:
	_build_circle(pulse_ring, R_OUTER)
	_build_circle(target_ring, R_TARGET)
	_build_circle(window_in, R_TARGET)
	_build_circle(window_out, R_TARGET)
	_sync_visuals()

func get_feedback_map() -> Dictionary:
	return FEEDBACK_MAP

func get_difficulty() -> float:
	return 1.0 / current_period()

func is_failed() -> bool:
	return _failed

func get_feedback_position(_event_name: String) -> Vector2:
	return CENTER + FEEDBACK_OFFSET

func get_player() -> Node:
	return self

# 今の周期。経過だけで決まり、縮む一方なので難易度は単調に上がる。
func current_period() -> float:
	return maxf(MIN_PERIOD, BASE_PERIOD - _elapsed * PERIOD_SHRINK)

# 許容半幅（位相単位）。狭まる一方で、最小値で止まる。
func current_half() -> float:
	return maxf(MIN_HALF, BASE_HALF - _elapsed * HALF_NARROW)

func window_start() -> float:
	return TARGET_PHASE - current_half()

func window_end() -> float:
	return TARGET_PHASE + current_half()

func mode_start() -> void:
	_elapsed = 0.0
	_failed = false
	phase = 0.0
	beats = 0
	_faults = 0
	_reset_heart_pulse()
	_sync_visuals()

func mode_tick(delta: float, act_pressed: bool, _act_released: bool) -> void:
	_elapsed += delta
	var period := current_period()

	# タップの判定は、時間を進める前に今の phase で行う。
	# ボットが読む値と判定に使う値が同じなので、境界での食い違いが出ない。
	if act_pressed and not _failed:
		host.emit_feedback("act")
		if window_start() <= phase and phase <= window_end():
			beats += 1
			host.add_score(SUCCESS_SCORE)
			phase = 0.0
			_faults = 0
			_pulse_heart()
		else:
			_faults += 1
			if _faults >= 2:
				_failed = true

	if not _failed:
		phase += delta / period
		if phase >= 1.0:
			phase = 1.0
			_failed = true

	_sync_visuals()

# 半径 r の円を Line2D の頂点列として作る。シーン側は空のまま置き、
# 実寸はここで与える（ファイルに座標を列挙しないための一本化）。
func _build_circle(line: Line2D, radius: float) -> void:
	if line == null:
		return
	var points := PackedVector2Array()
	for i in RING_POINTS + 1:
		var angle := TAU * float(i) / float(RING_POINTS)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	line.points = points

func _ring_radius() -> float:
	return R_OUTER * (1.0 - phase)

func _sync_visuals() -> void:
	if pulse_ring != null:
		var base := Vector2.ONE * maxf(_ring_radius() / R_OUTER, 0.001)
		pulse_ring.scale = base
	if window_in != null:
		window_in.scale = Vector2.ONE * (R_TARGET - current_half() * R_OUTER) / R_TARGET
	if window_out != null:
		window_out.scale = Vector2.ONE * (R_TARGET + current_half() * R_OUTER) / R_TARGET

# 見た目だけの鼓動。判定（phase）には触らない。
func _pulse_heart() -> void:
	if heart == null:
		return
	if _heart_tween != null:
		_heart_tween.kill()
	heart.scale = HEART_PULSE
	_heart_tween = create_tween()
	var recover := _heart_tween.tween_property(heart, "scale", Vector2.ONE, HEART_RECOVER_SEC)
	recover.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _reset_heart_pulse() -> void:
	if _heart_tween != null:
		_heart_tween.kill()
	if heart != null:
		heart.scale = Vector2.ONE
