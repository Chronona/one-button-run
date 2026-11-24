extends Node2D

const PALETTE = preload("res://modes/polarity/palette.gd")

const WIDTH := 56.0
const HEIGHT := 760.0
const TOP := -80.0
const EDGE_WIDTH := 4.0

var phase: int = 0
var speed: float = 200.0

var _body_poly: Polygon2D
var _edge_left: Line2D
var _edge_right: Line2D
var _stripes: Array[Line2D] = []

func setup(p_phase: int, p_speed: float) -> void:
	phase = p_phase
	speed = p_speed
	_build_visuals()

func _ready() -> void:
	add_to_group("barriers")
	set_process(false)
	if get_child_count() == 0:
		_build_visuals()

func advance(delta: float) -> void:
	position.x -= speed * delta

func is_offscreen() -> bool:
	return position.x + WIDTH < -80.0

func get_body_rect() -> Rect2:
	return Rect2(position.x, TOP, WIDTH, HEIGHT)

func collides_with(body: Rect2) -> bool:
	return body.intersects(get_body_rect())

func set_player_phase(p_player_phase: int) -> void:
	var danger := phase == p_player_phase
	var base: Color = PALETTE.COLORS[phase]
	if _body_poly != null:
		_body_poly.color = Color(base.r, base.g, base.b, 0.90 if danger else 0.20)
	for stripe in _stripes:
		stripe.default_color = Color(1.0, 1.0, 1.0, 0.55 if danger else 0.10)
	if _edge_left != null:
		_edge_left.default_color = Color(base.r, base.g, base.b, 1.0 if danger else 0.30)
	if _edge_right != null:
		_edge_right.default_color = Color(base.r, base.g, base.b, 1.0 if danger else 0.30)

func _build_visuals() -> void:
	_body_poly = Polygon2D.new()
	_body_poly.polygon = PackedVector2Array([
		Vector2(0.0, TOP),
		Vector2(WIDTH, TOP),
		Vector2(WIDTH, TOP + HEIGHT),
		Vector2(0.0, TOP + HEIGHT),
	])
	_body_poly.color = PALETTE.COLORS[phase]
	add_child(_body_poly)

	_edge_left = _make_edge(0.0)
	_edge_right = _make_edge(WIDTH)
	add_child(_edge_left)
	add_child(_edge_right)

	for i in 5:
		var stripe := Line2D.new()
		stripe.width = 2.0
		var y := 100.0 + float(i) * 110.0
		stripe.points = PackedVector2Array([
			Vector2(7.0, y),
			Vector2(WIDTH - 7.0, y),
		])
		stripe.default_color = Color(1.0, 1.0, 1.0, 0.3)
		add_child(stripe)
		_stripes.append(stripe)

	set_player_phase(phase)

func _make_edge(x: float) -> Line2D:
	var edge := Line2D.new()
	edge.width = EDGE_WIDTH
	edge.points = PackedVector2Array([
		Vector2(x, TOP),
		Vector2(x, TOP + HEIGHT),
	])
	edge.default_color = PALETTE.COLORS[phase]
	return edge
