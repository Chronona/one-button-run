extends Node2D

# フラッピーモードのゲート（上下の柱と間の隙間）。
# 動きはホストが注入する時間で進める。自前の更新関数は持たない。

const VIEW_HEIGHT := 648.0

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
	var gap_top: float = gap_center - gap_half
	var gap_bottom: float = gap_center + gap_half
	var top := Rect2(position.x, -40.0, gate_width, gap_top + 40.0)
	var bottom := Rect2(position.x, gap_bottom, gate_width, VIEW_HEIGHT - gap_bottom + 40.0)
	return body.intersects(top) or body.intersects(bottom)

func _build_visuals() -> void:
	var gap_top: float = gap_center - gap_half
	var gap_bottom: float = gap_center + gap_half
	_add_pillar(Rect2(0.0, -40.0, gate_width, gap_top + 40.0), Color(0.10, 0.55, 0.45, 1.0))
	_add_pillar(Rect2(0.0, gap_bottom, gate_width, VIEW_HEIGHT - gap_bottom + 40.0), Color(0.10, 0.55, 0.45, 1.0))
	# 隙間の縁を明るくして、安全な通り道を示す。
	_add_pillar(Rect2(0.0, gap_top - 10.0, gate_width, 10.0), Color(0.45, 0.95, 0.80, 1.0))
	_add_pillar(Rect2(0.0, gap_bottom, gate_width, 10.0), Color(0.45, 0.95, 0.80, 1.0))

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
