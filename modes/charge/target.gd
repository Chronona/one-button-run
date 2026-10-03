extends Node2D

# チャージ投擲用の標的。発射台の右側に静止する。
# 動きは持たず、当たり判定はモードが注入する時間の中で行う。
# 自前の更新受け付けは持たない。

const RING_COLOR := Color(0.35, 1.0, 0.65, 1.0)
const DISC_COLOR := Color(0.05, 0.45, 0.30, 1.0)
const CORE_COLOR := Color(1.0, 0.95, 0.55, 1.0)
# 的の円盤と外側リングで共有する多角形の分割数。
const SEGMENTS := 24

var target_radius: float = 44.0

func setup(p_radius: float) -> void:
	target_radius = p_radius
	_build_visuals()

func _ready() -> void:
	add_to_group("targets")
	if get_child_count() == 0:
		_build_visuals()

# 的の円盤と外側リングで同じ24角形の生成を共有する。見た目専用であり、
# 当たり判定（TARGET_RADIUS）はモード側が持つため難易度には影響しない。
func _circle_points(p_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in SEGMENTS:
		var angle := TAU * float(i) / float(SEGMENTS)
		points.append(Vector2(cos(angle), sin(angle)) * p_radius)
	return points

func _build_visuals() -> void:
	if get_child_count() > 0:
		return
	var disc := Polygon2D.new()
	disc.polygon = _circle_points(target_radius)
	disc.color = DISC_COLOR
	add_child(disc)
	var ring := Polygon2D.new()
	ring.polygon = _circle_points(target_radius + 6.0)
	ring.color = RING_COLOR
	add_child(ring)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(0.0, -12.0),
		Vector2(9.0, 0.0),
		Vector2(0.0, 12.0),
		Vector2(-9.0, 0.0),
	])
	core.color = CORE_COLOR
	add_child(core)
