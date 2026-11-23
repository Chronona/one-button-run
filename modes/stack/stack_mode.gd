extends "res://core/game_mode.gd"

const CENTER_X := 576.0
const BASE_TOP := 580.0
const BLOCK_HEIGHT := 18.0
const BASE_HALF_WIDTH := 130.0
const MOVE_MIN := 216.0
const MOVE_MAX := 936.0
const HOVER_Y := 150.0
const SCROLL_LINE := 240.0

const BASE_SPEED := 180.0
const SPEED_PER_SECOND := 1.5
const MAX_SPEED := 480.0

const DROP_TIMEOUT := 1.5
const SPAWN_OFFSET_MIN := 140.0
const SPAWN_OFFSET_MAX := 240.0
const TRIM_FREE_TOL := 14.0
const MIN_BLOCK_WIDTH := 16.0
const PERFECT_SCORE := 10.0
const STACK_SCORE := 3.0
const PERFECT_FLASH_SEC := 0.7

const BLOCK_COLORS := [
	Color(0.32, 0.72, 0.96, 1.0),
	Color(0.46, 0.86, 0.72, 1.0),
	Color(0.72, 0.62, 0.98, 1.0),
	Color(0.96, 0.62, 0.54, 1.0),
]
const PERFECT_COLOR := Color(1.0, 0.88, 0.38, 1.0)
const GUIDE_COLOR := Color(0.45, 0.8, 1, 0.28)
const GUIDE_PERFECT_COLOR := Color(1.0, 0.88, 0.38, 0.6)

const FEEDBACK_MAP := {
	"act": {"particles": "PlaceParticles", "se": "PlaceSE"},
	"fail": {"particles": "CrashParticles", "se": "GameOverSE"},
	"record": {"particles": "", "se": "HighScoreSE"},
}

var move_speed: float = BASE_SPEED
var moving_x: float = CENTER_X
var moving_dir: float = 1.0
var block_width: float = BASE_HALF_WIDTH * 2.0
var top_center: float = CENTER_X
var top_width: float = BASE_HALF_WIDTH * 2.0
var height: int = 0

var _elapsed: float = 0.0
var _failed: bool = false
var _drop_timer: float = 0.0
var _top_surface_local_y: float = BASE_TOP
var _spawn_index: int = 0
var _perfect_flash_timer: float = 0.0
var _perfect_streak: int = 0

@onready var tower: Node2D = $Tower
@onready var base_block: Polygon2D = $Tower/BaseBlock
@onready var moving_block: Polygon2D = $MovingBlock
@onready var guide: Line2D = $Guide
@onready var height_label: Label = $HeightLabel
@onready var perfect_label: Label = $PerfectLabel

func get_feedback_map() -> Dictionary:
	return FEEDBACK_MAP

func get_difficulty() -> float:
	return move_speed

func is_failed() -> bool:
	return _failed

func scores_by_time() -> bool:
	return false

func get_feedback_position(event_name: String) -> Vector2:
	if event_name == "act":
		return Vector2(top_center, tower.position.y + _top_surface_local_y + BLOCK_HEIGHT * 0.5)
	return Vector2(top_center, tower.position.y + _top_surface_local_y - 24.0)

func get_player() -> Node:
	return self

func mode_start() -> void:
	_elapsed = 0.0
	_failed = false
	_drop_timer = 0.0
	move_speed = BASE_SPEED
	moving_x = CENTER_X
	moving_dir = 1.0
	block_width = BASE_HALF_WIDTH * 2.0
	top_center = CENTER_X
	top_width = BASE_HALF_WIDTH * 2.0
	height = 0
	_top_surface_local_y = BASE_TOP
	_spawn_index = 0
	_perfect_flash_timer = 0.0
	_perfect_streak = 0
	tower.position = Vector2.ZERO
	_clear_blocks()
	_spawn_block()
	_update_label()
	_update_perfect_label()
	_sync_visuals()

func mode_tick(delta: float, act_pressed: bool, _act_released: bool) -> void:
	_update_perfect_flash(delta)
	if _failed:
		return

	_elapsed += delta
	move_speed = minf(BASE_SPEED + _elapsed * SPEED_PER_SECOND, MAX_SPEED)

	if act_pressed:
		_drop_block()

	if _failed:
		_sync_visuals()
		return

	_drop_timer += delta
	_advance_moving(delta)

	if _drop_timer >= DROP_TIMEOUT:
		_drop_block()

	_sync_visuals()

func _advance_moving(delta: float) -> void:
	moving_x += moving_dir * move_speed * delta
	if moving_x > MOVE_MAX:
		moving_x = MOVE_MAX - (moving_x - MOVE_MAX)
		moving_dir = -1.0
	elif moving_x < MOVE_MIN:
		moving_x = MOVE_MIN + (MOVE_MIN - moving_x)
		moving_dir = 1.0

func _drop_block() -> void:
	if _failed:
		return

	var moving_left := moving_x - block_width * 0.5
	var moving_right := moving_x + block_width * 0.5
	var top_left := top_center - top_width * 0.5
	var top_right := top_center + top_width * 0.5
	var overlap_left := maxf(moving_left, top_left)
	var overlap_right := minf(moving_right, top_right)
	var overlap := overlap_right - overlap_left

	if overlap <= 0.0 or overlap < MIN_BLOCK_WIDTH:
		_failed = true
		_perfect_streak = 0
		return

	var perfect := absf(moving_x - top_center) <= TRIM_FREE_TOL
	if perfect:
		_perfect_streak += 1
	else:
		_perfect_streak = 0
	var new_center := (overlap_left + overlap_right) * 0.5
	var new_width := overlap
	if perfect:
		new_center = top_center
		new_width = top_width

	var center_local_y := _top_surface_local_y - BLOCK_HEIGHT * 0.5
	var color: Color = PERFECT_COLOR if perfect else BLOCK_COLORS[height % BLOCK_COLORS.size()]
	_add_block(new_center, new_width, center_local_y, color)

	top_center = new_center
	top_width = new_width
	_top_surface_local_y -= BLOCK_HEIGHT
	if height > 0:
		host.add_score(PERFECT_SCORE if perfect else STACK_SCORE)
	height += 1
	host.emit_feedback("act")
	if perfect:
		_flash_perfect()
	_update_label()
	_scroll_tower()
	_spawn_block()

func _make_block_polygon(width: float) -> PackedVector2Array:
	var half_width := width * 0.5
	var half_height := BLOCK_HEIGHT * 0.5
	return PackedVector2Array([
		Vector2(-half_width, -half_height),
		Vector2(half_width, -half_height),
		Vector2(half_width, half_height),
		Vector2(-half_width, half_height),
	])

func _add_block(center_x: float, width: float, center_y: float, color: Color) -> void:
	var node := Polygon2D.new()
	node.polygon = _make_block_polygon(width)
	node.position = Vector2(center_x, center_y)
	node.color = color
	tower.add_child(node)

func _scroll_tower() -> void:
	var top_screen_y := tower.position.y + _top_surface_local_y
	if top_screen_y < SCROLL_LINE:
		tower.position.y += SCROLL_LINE - top_screen_y
	for child in tower.get_children():
		if child == base_block:
			continue
		if tower.position.y + child.position.y > 700.0:
			tower.remove_child(child)
			child.queue_free()

func _spawn_block() -> void:
	block_width = top_width
	_drop_timer = 0.0
	if _spawn_index == 0:
		moving_x = top_center
		moving_dir = 1.0
	else:
		var direction := 1.0 if _spawn_index % 2 == 1 else -1.0
		var offset: float = host.get_rng().randf_range(SPAWN_OFFSET_MIN, SPAWN_OFFSET_MAX)
		moving_x = clampf(top_center + direction * offset, MOVE_MIN, MOVE_MAX)
		moving_dir = -direction
	_spawn_index += 1
	_set_moving_shape()
	if moving_block != null:
		moving_block.color = BLOCK_COLORS[height % BLOCK_COLORS.size()]

func _set_moving_shape() -> void:
	if moving_block == null:
		return
	moving_block.polygon = _make_block_polygon(block_width)

func _sync_visuals() -> void:
	if moving_block != null:
		moving_block.position = Vector2(moving_x, HOVER_Y)
	if guide != null:
		var top_y := tower.position.y + _top_surface_local_y
		guide.points = PackedVector2Array([
			Vector2(moving_x, HOVER_Y + BLOCK_HEIGHT * 0.5),
			Vector2(moving_x, top_y),
		])
		# ぴったり重なる位置ではガイドを金色にして、PERFECT の狙いどころを伝える。
		var perfect_ready := absf(moving_x - top_center) <= TRIM_FREE_TOL
		guide.default_color = GUIDE_PERFECT_COLOR if perfect_ready else GUIDE_COLOR
		guide.visible = not _failed

func _update_label() -> void:
	if height_label != null:
		height_label.text = "Height: %d" % height

func _flash_perfect() -> void:
	_perfect_flash_timer = PERFECT_FLASH_SEC
	if perfect_label != null:
		perfect_label.text = "PERFECT!" if _perfect_streak < 2 else "PERFECT! x%d" % _perfect_streak
	_update_perfect_label()

func _update_perfect_flash(delta: float) -> void:
	if _perfect_flash_timer <= 0.0:
		return
	_perfect_flash_timer = maxf(0.0, _perfect_flash_timer - delta)
	_update_perfect_label()

func _update_perfect_label() -> void:
	if perfect_label != null:
		perfect_label.visible = _perfect_flash_timer > 0.0

func _clear_blocks() -> void:
	for child in tower.get_children():
		if child == base_block:
			continue
		tower.remove_child(child)
		child.queue_free()
