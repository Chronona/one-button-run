extends Node2D

# 振り子グラップル用のアンカー（天井のフック点）。
# 見た目はここが作り、動きはモードが注入する時間で進める。自前の更新は持たない。

const CABLE_COLOR := Color(0.55, 0.45, 0.85, 1.0)
const DIAMOND_COLOR := Color(1.0, 0.75, 0.30, 1.0)
const RING_COLOR := Color(1.0, 0.90, 0.60, 1.0)
const DIM_MODULATE := Color(0.55, 0.55, 0.60, 1.0)

var _highlighted: bool = false

func _ready() -> void:
	add_to_group("anchors")
	_build_visuals()

func advance(delta: float, speed: float) -> void:
	position.x -= speed * delta

func is_offscreen() -> bool:
	return position.x < -60.0

func set_highlight(enabled: bool) -> void:
	if enabled == _highlighted:
		return
	_highlighted = enabled
	modulate = Color.WHITE if enabled else DIM_MODULATE

func _build_visuals() -> void:
	if get_child_count() > 0:
		return
	# 天井までのケーブル（アンカーは y=0 の天井から吊られている想定）。
	var cable := Polygon2D.new()
	var top_y := -position.y
	cable.polygon = PackedVector2Array([
		Vector2(-3.0, top_y),
		Vector2(3.0, top_y),
		Vector2(3.0, -12.0),
		Vector2(-3.0, -12.0),
	])
	cable.color = CABLE_COLOR
	add_child(cable)
	# フック点の菱形。
	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([
		Vector2(0.0, -14.0),
		Vector2(10.0, 0.0),
		Vector2(0.0, 14.0),
		Vector2(-10.0, 0.0),
	])
	diamond.color = DIAMOND_COLOR
	add_child(diamond)
	# 狙える範囲を示す輪。
	var ring := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * float(i) / 24.0
		points.append(Vector2(cos(angle), sin(angle)) * 20.0)
	ring.polygon = points
	ring.color = RING_COLOR
	add_child(ring)
	modulate = DIM_MODULATE
