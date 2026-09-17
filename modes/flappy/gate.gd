extends Node2D

# フラッピーモードのゲート（上下の柱と間の隙間）。
# 動きはホストが注入する時間で進める。自前の更新関数は持たない。

const VIEW_HEIGHT := 648.0
const PILLAR_COLOR := Color(0.10, 0.55, 0.45, 1.0)
const EDGE_COLOR := Color(0.45, 0.95, 0.80, 1.0)
const EDGE_THICKNESS := 10.0

var gap_center: float = 300.0
var gap_half: float = 150.0
var gate_width: float = 90.0
var speed: float = 180.0

func setup(p_gap_center: float, p_gap_half: float, p_width: float, p_speed: float) -> void:
	gap_center = p_gap_center
	gap_half = p_gap_half
	gate_width = p_width
	speed = p_speed
	_build_visuals()

func _ready() -> void:
	add_to_group("gates")
	# 時間はホストが注入する。自前の更新関数は持たない。
	set_process(false)
	if get_child_count() == 0:
		_build_visuals()

func advance(delta: float) -> void:
	position.x -= speed * delta

func is_offscreen() -> bool:
	return position.x + gate_width < -20.0

func front_x() -> float:
	return position.x + gate_width

func collides_with(body: Rect2) -> bool:
	return body.intersects(_top_rect(position.x)) or body.intersects(_bottom_rect(position.x))

func _gap_top() -> float:
	return gap_center - gap_half

func _gap_bottom() -> float:
	return gap_center + gap_half

func _top_rect(offset_x: float) -> Rect2:
	return Rect2(offset_x, -40.0, gate_width, _gap_top() + 40.0)

func _bottom_rect(offset_x: float) -> Rect2:
	return Rect2(offset_x, _gap_bottom(), gate_width, VIEW_HEIGHT - _gap_bottom() + 40.0)

func _build_visuals() -> void:
	_add_pillar(_top_rect(0.0), PILLAR_COLOR)
	_add_pillar(_bottom_rect(0.0), PILLAR_COLOR)
	# 隙間の縁を明るくして、安全な通り道を示す。
	_add_pillar(Rect2(0.0, _gap_top() - EDGE_THICKNESS, gate_width, EDGE_THICKNESS), EDGE_COLOR)
	_add_pillar(Rect2(0.0, _gap_bottom(), gate_width, EDGE_THICKNESS), EDGE_COLOR)

func _add_pillar(rect: Rect2, color: Color) -> void:
	var pillar := Polygon2D.new()
	pillar.polygon = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size,
		rect.position + Vector2(0.0, rect.size.y),
	])
	pillar.color = color
	add_child(pillar)
