extends Node2D

# ドッジャーモードのトゲ（左右レーンを塞ぐ障害物）。
# 動きはホストが注入する時間で進める。自前の更新関数は持たない。

const SPIKE_HALF := 28.0
const BODY_HALF := 24.0
const SPIKE_COLOR := Color(1.0, 0.30, 0.15, 1.0)
const CORE_COLOR := Color(1.0, 0.85, 0.30, 1.0)

var lane: int = 0
var speed: float = 220.0

func setup(p_lane: int, pos: Vector2, p_speed: float) -> void:
	lane = p_lane
	position = pos
	speed = p_speed
	_build_visuals()

func _ready() -> void:
	add_to_group("spikes")
	# 時間はホストが注入する。自前の更新関数は持たない。
	set_process(false)
	if get_child_count() == 0:
		_build_visuals()

func advance(delta: float) -> void:
	position.x -= speed * delta

func is_offscreen() -> bool:
	return position.x < -60.0

func get_body_rect() -> Rect2:
	return Rect2(position - Vector2(BODY_HALF, BODY_HALF), Vector2(BODY_HALF, BODY_HALF) * 2.0)

func _build_visuals() -> void:
	var outer := Polygon2D.new()
	outer.polygon = PackedVector2Array([
		Vector2(SPIKE_HALF, 0.0),
		Vector2(0.0, -SPIKE_HALF),
		Vector2(-SPIKE_HALF, 0.0),
		Vector2(0.0, SPIKE_HALF),
	])
	outer.color = SPIKE_COLOR
	add_child(outer)
	var core := Polygon2D.new()
	var half := SPIKE_HALF * 0.45
	core.polygon = PackedVector2Array([
		Vector2(half, 0.0),
		Vector2(0.0, -half),
		Vector2(-half, 0.0),
		Vector2(0.0, half),
	])
	core.color = CORE_COLOR
	add_child(core)
