extends "res://core/game_mode.gd"

# 振り子グラップルモード。タップの「押下でフック」「解放で射出」だけが操作。
#
# 遊び方: 押すと頭上のフック点にロープが掛かり、振り子になる。
# 押し続けるとロープが少しずつ伸びる。離すとその瞬間の接線方向へ飛ぶ。
# 最下点で離せば速く遠くへ、遅めに離せば高く上がる。地面に触れたら終わり。
#
# 時間も入力もホストから注入されるので、このスクリプトは自前の更新も
# 入力受け付けも持たない（tests/contract/test_input_isolation.gd が静的に検査）。
# 振り子は非線形なので、受け取った delta を 1/60 秒の固定刻みに割って積分する。
# こうすると可変フレームの実プレイと固定刻みのテスト再生で挙動が一致する。

const ANCHOR_SCRIPT: GDScript = preload("res://modes/grapple/anchor.gd")

const START_POS := Vector2(200.0, 200.0)
const HOME_X := 200.0
const GROUND_Y := 560.0
const CEIL_Y := 30.0
const X_MIN := 80.0
const X_MAX := 520.0

const GRAVITY_FLY := 480.0
const MAX_FALL_SPEED := 640.0

# 実物理より誇張した振り子の重力。周期が 0.8〜1.5 秒に収まる値。
const GRAVITY_SWING := 6000.0
const ROPE_MIN := 60.0
const ROPE_MAX := 330.0
const ROPE_EXTEND_RATE := 26.0
const FIXED_STEP := 1.0 / 60.0

# 解放時の加速。接線速度に足すので、どの位相で離しても前に上へ飛ぶ。
# 位相の判断は残る（最下点=速く遠く、遅め=高く）が、即死の罠にはならない。
const RELEASE_PUSH_X := 170.0
const RELEASE_PUSH_Y := -180.0

const BASE_SPEED := 200.0
const SPEED_PER_SECOND := 1.5
const MAX_SPEED := 420.0

const ANCHOR_Y := 110.0
const ANCHOR_SPACING := 340.0
const SPAWN_X := 1240.0
const HOOK_BACK := -140.0
const HOOK_AHEAD := 430.0
const INITIAL_SPAWN_COOLDOWN := 1.0
const INITIAL_ANCHOR_X := [350.0, 690.0, 1030.0]

const FEEDBACK_MAP := {
	"act": {"particles": "HookParticles", "se": "HookSE"},
	"fail": {"particles": "CrashParticles", "se": "GameOverSE"},
	"record": {"particles": "", "se": "HighScoreSE"},
}

const FEEDBACK_OFFSET := Vector2(18, 18)

var scroll_speed: float = BASE_SPEED
var player_pos := START_POS
var fly_velocity := Vector2.ZERO
var swinging: bool = false
var pivot := Vector2.ZERO
var rope_length: float = 0.0
var swing_theta: float = 0.0
var swing_omega: float = 0.0
var swing_elapsed: float = 0.0
var spawn_cooldown: float = INITIAL_SPAWN_COOLDOWN

var _elapsed: float = 0.0
var _failed: bool = false
var _accum: float = 0.0

@onready var player: Polygon2D = $Player
@onready var rope: Line2D = $Rope
@onready var hook_spark: Polygon2D = $HookSpark

func get_feedback_map() -> Dictionary:
	return FEEDBACK_MAP

func get_difficulty() -> float:
	return scroll_speed

func is_failed() -> bool:
	return _failed

func is_swinging() -> bool:
	return swinging

func get_feedback_position(_event_name: String) -> Vector2:
	return player_pos + FEEDBACK_OFFSET

func get_player() -> Node:
	return self

func get_body_rect() -> Rect2:
	return Rect2(player_pos - Vector2(18, 18), Vector2(36, 36))

func mode_start() -> void:
	_elapsed = 0.0
	_failed = false
	_accum = 0.0
	scroll_speed = BASE_SPEED
	spawn_cooldown = INITIAL_SPAWN_COOLDOWN
	player_pos = START_POS
	fly_velocity = Vector2.ZERO
	swinging = false
	rope_length = 0.0
	swing_theta = 0.0
	swing_omega = 0.0
	swing_elapsed = 0.0
	_clear_all_anchors()
	for anchor_x in INITIAL_ANCHOR_X:
		spawn_anchor_at(anchor_x)
	_sync_visuals()

func mode_tick(delta: float, act_pressed: bool, act_released: bool) -> void:
	_elapsed += delta
	scroll_speed = minf(BASE_SPEED + _elapsed * SPEED_PER_SECOND, MAX_SPEED)

	if act_pressed and not swinging and not _failed:
		_try_hook()

	if act_released and swinging:
		_release()

	if swinging:
		_integrate_swing(delta)
	else:
		_integrate_fly(delta)

	_advance_anchors(delta)

	spawn_cooldown -= delta
	if spawn_cooldown <= 0.0:
		spawn_anchor_at(SPAWN_X)
		spawn_cooldown = ANCHOR_SPACING / scroll_speed

	if player_pos.y >= GROUND_Y:
		_failed = true
	_sync_visuals()

func spawn_anchor_at(anchor_x: float) -> void:
	var anchor_node: Node2D = ANCHOR_SCRIPT.new()
	anchor_node.position = Vector2(anchor_x, ANCHOR_Y)
	add_child(anchor_node)

func _try_hook() -> void:
	var closest_anchor: Node2D = null
	var closest_dx: float = HOOK_AHEAD + 1.0
	for anchor_node in get_tree().get_nodes_in_group("anchors"):
		var dx: float = anchor_node.position.x - player_pos.x
		if _is_in_hook_range(dx) and dx < closest_dx:
			closest_anchor = anchor_node
			closest_dx = dx
	if closest_anchor == null:
		return
	# 支点は掛けた瞬間の位置で凍結する。以後は支点を中心とする振り子になる。
	pivot = closest_anchor.position
	var offset := player_pos - pivot
	var distance := offset.length()
	rope_length = clampf(distance, ROPE_MIN, ROPE_MAX)
	swing_theta = atan2(offset.x, offset.y)
	var tangent := Vector2(cos(swing_theta), -sin(swing_theta))
	swing_omega = clampf(fly_velocity.dot(tangent) / rope_length, -4.0, 4.0)
	swing_elapsed = 0.0
	_accum = 0.0
	swinging = true
	host.emit_feedback("act")

func _release() -> void:
	var tangent := Vector2(cos(swing_theta), -sin(swing_theta))
	var release_vel := tangent * (rope_length * swing_omega)
	fly_velocity = Vector2(
		clampf(release_vel.x + RELEASE_PUSH_X, -120.0, 560.0),
		clampf(release_vel.y + RELEASE_PUSH_Y, -660.0, 420.0))
	swinging = false

func _integrate_swing(delta: float) -> void:
	_accum += delta
	var guard := 0
	while _accum >= FIXED_STEP and guard < 8:
		swing_omega += -(GRAVITY_SWING / rope_length) * sin(swing_theta) * FIXED_STEP
		swing_theta += swing_omega * FIXED_STEP
		rope_length = minf(rope_length + ROPE_EXTEND_RATE * FIXED_STEP, ROPE_MAX)
		swing_elapsed += FIXED_STEP
		_accum -= FIXED_STEP
		guard += 1
	if guard >= 8:
		_accum = 0.0
	player_pos = pivot + rope_length * Vector2(sin(swing_theta), cos(swing_theta))
	if player_pos.y < CEIL_Y:
		player_pos.y = CEIL_Y

func _integrate_fly(delta: float) -> void:
	fly_velocity.y = minf(fly_velocity.y + GRAVITY_FLY * delta, MAX_FALL_SPEED)
	player_pos += fly_velocity * delta
	# 前進の名残は減衰させ、開始位置の付近へゆるく戻す。画面外に出ないため。
	fly_velocity.x = move_toward(fly_velocity.x, 0.0, 260.0 * delta)
	fly_velocity.x += clampf((HOME_X - player_pos.x) * 1.5, -90.0, 90.0) * delta
	if player_pos.x < X_MIN:
		player_pos.x = X_MIN
		fly_velocity.x = maxf(fly_velocity.x, 0.0)
	if player_pos.x > X_MAX:
		player_pos.x = X_MAX
		fly_velocity.x = minf(fly_velocity.x, 0.0)
	if player_pos.y < CEIL_Y:
		player_pos.y = CEIL_Y
		fly_velocity.y = maxf(fly_velocity.y, 0.0)

func _advance_anchors(delta: float) -> void:
	for anchor_node in get_tree().get_nodes_in_group("anchors"):
		anchor_node.advance(delta, scroll_speed)
		if anchor_node.is_offscreen():
			_despawn(anchor_node)

# queue_free は次フレームまで残るため、グループから先に外す。
# 手動 tick のテストでは外し忘れると幽霊アンカーにフックしてしまう。
func _despawn(anchor_node: Node) -> void:
	anchor_node.remove_from_group("anchors")
	anchor_node.queue_free()

# ラウンド開始時の掃除用。進行中の破棄と同一手順にまとめて、
# 掃除漏れによる幽霊アンカーへのフックを防ぐ。
func _clear_all_anchors() -> void:
	for anchor_node in get_tree().get_nodes_in_group("anchors"):
		_despawn(anchor_node)

# フック可能な相対位置か。掛けるときと狙い目の表示で同じ判定を使う。
func _is_in_hook_range(dx: float) -> bool:
	return dx >= HOOK_BACK and dx <= HOOK_AHEAD

func _sync_visuals() -> void:
	if player != null:
		player.position = player_pos
		if swinging:
			player.rotation = clampf(swing_omega * 0.35, -0.6, 0.6)
		else:
			player.rotation = clampf(fly_velocity.y / MAX_FALL_SPEED, -0.45, 0.6)
	if rope != null:
		rope.visible = swinging
		if swinging:
			rope.points = PackedVector2Array([player_pos, pivot])
	if hook_spark != null:
		hook_spark.visible = swinging
		if swinging:
			hook_spark.position = pivot
	_update_anchor_highlight()

func _update_anchor_highlight() -> void:
	for anchor_node in get_tree().get_nodes_in_group("anchors"):
		var dx: float = anchor_node.position.x - player_pos.x
		var in_range := (not swinging) and _is_in_hook_range(dx)
		if anchor_node.has_method("set_highlight"):
			anchor_node.set_highlight(in_range)
