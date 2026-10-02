extends "res://core/game_mode.gd"

# チャージ投擲モード。タップの「押下で構え」「解放で射出」だけが操作。
#
# 遊び方: 押している間に角度メーターが往復し、同時にパワーが溜まる。
# 離した瞬間の角度とパワーで弾が飛ぶ。標的に当てると残弾が戻る。
# 構えずにいると警告の後に見送りで残弾が減り、残弾が尽きると終わり。
# スコアは標的を1つ壊すごとに加点される（時間では増えない）。
# 標的を全破壊すると次のステージへ進み、角度メーターが速くなる。
# ステージを少ない投擲数で破壊するほど、次ステージの弾は発射後に分裂する
# （1発で3分裂、2発で2分裂、3発以上は分裂なし。ADR 0008）。
#
# 時間も入力もホストから注入されるので、自前の更新受け付けは持たない。
# 静的検査については spec の input_isolated_scripts を参照。

const TARGET_SCRIPT: GDScript = preload("res://modes/charge/target.gd")

const CANNON_POS := Vector2(120.0, 500.0)
const MUZZLE_OFFSET := Vector2(34.0, -12.0)
const GROUND_Y := 560.0
const FLY_X_MAX := 1250.0
const FLY_Y_TOP := -60.0
const MAX_FLIGHT_TIME := 6.0

# 角度メーターの振れ幅。下から上へ往復する。
const THETA_MIN := 0.26
const THETA_MAX := 1.31
# メーターの角速度が難易度の実体。素の値だけを返す。
const OMEGA_BASE := 2.2
const OMEGA_PER_SECOND := 0.008
const OMEGA_MAX := 4.5

const POWER_TIME := 1.2
const SPEED_MIN := 350.0
const SPEED_MAX := 950.0
const SHOT_GRAVITY := 500.0
const MAX_HOLD := 2.5

# 構えの制限時間。警告を出してから見送りで残弾を1つ失う。
# 警告なしで減弾すると放置死に見えるため、AIM_WARN_TIME で先に知らせる。
const AIM_WARN_TIME := 1.0
const AIM_TIMEOUT := 1.8
const START_AMMO := 5
const MAX_AMMO := 5

# 分裂弾。本体の弾道は変えず、横に散る弾を足す。本体はそのままなので
# 「分裂なし」で当たる射線は分裂ありでも必ず当たる（ボットの模擬も有効）。
const SPLIT_TIME := 0.4
const SPLIT_SPREAD := 0.14

const TARGET_RADIUS := 44.0
const SHELL_RADIUS := 8.0
const TARGET_X_MIN := 620.0
const TARGET_X_MAX := 1040.0
const TARGET_Y_MIN := 180.0
const TARGET_Y_MAX := 480.0
const TARGET_MIN_SEPARATION := 130.0
const TARGET_PLACE_TRIES := 40

# スコアは標的の破壊でだけ入る。経過時間では加算しない（ADR 0010）。
const TARGET_SCORE := 100.0

const FEEDBACK_MAP := {
	"act": {"particles": "ShootParticles", "se": "ShootSE"},
	"fail": {"particles": "CrashParticles", "se": "GameOverSE"},
	"record": {"particles": "", "se": "HighScoreSE"},
	"split": {"particles": "HitParticles", "se": "HitSE"},
}

const FEEDBACK_OFFSET := Vector2(17, -6)

var omega: float = OMEGA_BASE
var ammo: int = START_AMMO
var stage: int = 1
var charging: bool = false
var charge_time: float = 0.0
var flying: bool = false
var shell_pos := Vector2.ZERO
var shell_vel := Vector2.ZERO
var flight_time: float = 0.0
var aim_timer: float = 0.0
# 現ステージでの投擲数と、今のステージで使える分裂数（1 = 分裂なし）。
var stage_shots: int = 0
var split_count: int = 1
# 発射時点の分裂数。飛行中にステージが進んでも、この弾の分裂数は変わらない。
var _shot_split: int = 1

var _extra_shells: Array[Dictionary] = []
var _elapsed: float = 0.0
var _failed: bool = false

@onready var barrel: Polygon2D = $CannonBarrel
@onready var shell: Polygon2D = $Shell
@onready var power_back: ColorRect = $PowerBarBack
@onready var power_fill: ColorRect = $PowerBarFill
@onready var ammo_label: Label = $AmmoLabel
@onready var stage_label: Label = $StageLabel

func get_feedback_map() -> Dictionary:
	return FEEDBACK_MAP

func get_difficulty() -> float:
	return omega

func scores_by_time() -> bool:
	return false

func is_failed() -> bool:
	return _failed

func is_charging() -> bool:
	return charging

func is_flying() -> bool:
	return flying

func is_aiming() -> bool:
	return not charging and not flying and not _failed

func is_aim_warning() -> bool:
	return is_aiming() and aim_timer >= AIM_WARN_TIME

func get_feedback_position(event_name: String) -> Vector2:
	if event_name == "act":
		return muzzle_pos() + FEEDBACK_OFFSET
	if event_name == "split":
		return shell_pos
	return CANNON_POS + FEEDBACK_OFFSET

func get_player() -> Node:
	return self

func muzzle_pos() -> Vector2:
	return CANNON_POS + MUZZLE_OFFSET

func current_omega() -> float:
	return omega

func charge_angle(t: float) -> float:
	return THETA_MIN + (THETA_MAX - THETA_MIN) * absf(sin(omega * t))

func charge_power(t: float) -> float:
	return minf(t / POWER_TIME, 1.0)

func launch_velocity(t: float) -> Vector2:
	var ang := charge_angle(t)
	var speed := lerpf(SPEED_MIN, SPEED_MAX, charge_power(t))
	return Vector2(cos(ang), -sin(ang)) * speed

# 前ステージの投擲数から、次ステージの分裂数を決める。
func split_for_shots(shots: int) -> int:
	if shots <= 1:
		return 3
	if shots == 2:
		return 2
	return 1

func mode_start() -> void:
	_elapsed = 0.0
	_failed = false
	omega = OMEGA_BASE
	ammo = START_AMMO
	stage = 1
	charging = false
	charge_time = 0.0
	flying = false
	flight_time = 0.0
	aim_timer = 0.0
	stage_shots = 0
	split_count = 1
	_shot_split = 1
	_clear_extra_shells()
	_clear_all_targets()
	_spawn_stage()
	_show_shell(false)
	_update_labels()
	_sync_visuals()

func mode_tick(delta: float, act_pressed: bool, act_released: bool) -> void:
	if _failed:
		return
	_elapsed += delta
	omega = minf(OMEGA_BASE + _elapsed * OMEGA_PER_SECOND, OMEGA_MAX)

	if flying:
		_integrate_shell(delta)
	elif charging:
		if act_released:
			_fire()
		else:
			charge_time += delta
			if charge_time >= MAX_HOLD:
				_fire()
	else:
		if act_pressed and ammo > 0:
			charging = true
			charge_time = 0.0
			aim_timer = 0.0
		else:
			aim_timer += delta
			if aim_timer >= AIM_TIMEOUT:
				aim_timer = 0.0
				ammo = maxi(ammo - 1, 0)
				_update_labels()
				if ammo <= 0:
					_failed = true
	_sync_visuals()

func _fire() -> void:
	var vel := launch_velocity(charge_time)
	charging = false
	ammo = maxi(ammo - 1, 0)
	flying = true
	shell_pos = muzzle_pos()
	shell_vel = vel
	flight_time = 0.0
	aim_timer = 0.0
	stage_shots += 1
	_shot_split = split_count
	_clear_extra_shells()
	_show_shell(true)
	_update_labels()
	host.emit_feedback("act")

func _integrate_shell(delta: float) -> void:
	var before := flight_time
	flight_time += delta
	if before < SPLIT_TIME and flight_time >= SPLIT_TIME and _shot_split > 1:
		_split_shell()
	var main_alive := _step_shell(delta)
	var any_alive := main_alive
	for extra in _extra_shells:
		extra["vel"].y += SHOT_GRAVITY * delta
		extra["pos"] += extra["vel"] * delta
		extra["node"].position = extra["pos"]
		if extra["alive"]:
			_check_shell_hit(extra["pos"])
			if _shell_in_bounds(extra["pos"]):
				any_alive = true
			else:
				extra["alive"] = false
				extra["node"].visible = false
	if not any_alive or flight_time >= MAX_FLIGHT_TIME:
		_end_flight()

func _step_shell(delta: float) -> bool:
	shell_vel.y += SHOT_GRAVITY * delta
	shell_pos += shell_vel * delta
	_check_shell_hit(shell_pos)
	return _shell_in_bounds(shell_pos)

func _shell_in_bounds(pos: Vector2) -> bool:
	return pos.y < GROUND_Y and pos.x <= FLY_X_MAX and pos.y >= FLY_Y_TOP

func _check_shell_hit(pos: Vector2) -> void:
	for target_node in _live_targets():
		if pos.distance_to(target_node.position) <= TARGET_RADIUS + SHELL_RADIUS:
			_hit_target(target_node)
			break

# 本体を残し、速度を ± 回転した弾を足す。3分裂は左右、2分裂は上側だけ。
func _split_shell() -> void:
	var angles: Array[float] = []
	if _shot_split >= 3:
		angles.assign([SPLIT_SPREAD, -SPLIT_SPREAD])
	else:
		angles.assign([SPLIT_SPREAD])
	for angle in angles:
		var node: Polygon2D = shell.duplicate()
		add_child(node)
		node.visible = true
		node.position = shell_pos
		_extra_shells.append({
			"pos": shell_pos,
			"vel": shell_vel.rotated(angle),
			"node": node,
			"alive": true,
		})
	host.emit_feedback("split")

func _clear_extra_shells() -> void:
	for extra in _extra_shells:
		extra["node"].queue_free()
	_extra_shells.clear()

func _hit_target(target_node: Node2D) -> void:
	var hit_pos: Vector2 = target_node.position
	_remove_target(target_node)
	ammo = mini(ammo + 1, MAX_AMMO)
	host.add_score(TARGET_SCORE)
	_play_hit(hit_pos)
	if _live_targets().is_empty():
		stage += 1
		ammo = mini(ammo + 1, MAX_AMMO)
		split_count = split_for_shots(stage_shots)
		stage_shots = 0
		_spawn_stage()
	_update_labels()

func _end_flight() -> void:
	flying = false
	aim_timer = 0.0
	_clear_extra_shells()
	_show_shell(false)
	if ammo <= 0:
		_failed = true

func _spawn_stage() -> void:
	var count: int = mini(stage, 3)
	var placed: Array[Vector2] = []
	for i in count:
		placed.append(_pick_target_pos(placed))
	for pos in placed:
		var target_node: Node2D = TARGET_SCRIPT.new()
		target_node.setup(TARGET_RADIUS)
		target_node.position = pos
		add_child(target_node)

func _pick_target_pos(placed: Array[Vector2]) -> Vector2:
	var fallback := Vector2(
		(TARGET_X_MIN + TARGET_X_MAX) * 0.5,
		(TARGET_Y_MIN + TARGET_Y_MAX) * 0.5)
	for i in TARGET_PLACE_TRIES:
		var candidate := Vector2(
			host.get_rng().randf_range(TARGET_X_MIN, TARGET_X_MAX),
			host.get_rng().randf_range(TARGET_Y_MIN, TARGET_Y_MAX))
		var clear := true
		for other in placed:
			if candidate.distance_to(other) < TARGET_MIN_SEPARATION:
				clear = false
				break
		if clear:
			return candidate
		fallback = candidate
	return fallback

func _live_targets() -> Array[Node]:
	return get_tree().get_nodes_in_group("targets")

func _clear_all_targets() -> void:
	for target_node in _live_targets():
		_remove_target(target_node)

# queue_free は次フレームまで残るため、グループから先に外す。
# 手動 tick のテストでは外し忘れると幽霊標的に命中してしまう。
func _remove_target(target_node: Node) -> void:
	target_node.remove_from_group("targets")
	target_node.queue_free()

func _play_hit(hit_pos: Vector2) -> void:
	var particles = get_node_or_null("HitParticles")
	if particles != null and particles.has_method("restart"):
		particles.position = hit_pos
		particles.restart()
	var sound_player = get_node_or_null("HitSE")
	if sound_player != null and sound_player.has_method("play"):
		sound_player.play()

func _show_shell(visible_now: bool) -> void:
	if shell != null:
		shell.visible = visible_now
		if visible_now:
			shell.position = shell_pos

func _update_labels() -> void:
	if ammo_label != null:
		ammo_label.text = "Ammo: %d" % ammo
	if stage_label != null:
		var split_text := "  x%d" % split_count if split_count > 1 else ""
		stage_label.text = "Stage: %d%s" % [stage, split_text]

func _sync_visuals() -> void:
	var aim_angle := charge_angle(charge_time) if charging else charge_angle(0.0)
	if barrel != null:
		barrel.rotation = -aim_angle
	if shell != null and flying:
		shell.position = shell_pos
	if power_back != null:
		power_back.visible = charging
	if power_fill != null:
		power_fill.visible = charging
		if charging:
			var power := charge_power(charge_time)
			power_fill.offset_right = power_fill.offset_left + 140.0 * power
	_update_warn_visual()

func _update_warn_visual() -> void:
	var warning := is_aim_warning()
	var label := get_node_or_null("WarnLabel") as Label
	if label != null:
		label.visible = warning
	if ammo_label != null:
		ammo_label.modulate = Color(1.0, 0.4, 0.35) if warning else Color.WHITE
