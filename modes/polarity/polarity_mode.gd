extends "res://core/game_mode.gd"

const BARRIER_SCRIPT: GDScript = preload("res://modes/polarity/polarity_barrier.gd")

const PLAYER_X := 220.0
const PLAYER_Y := 324.0
const PLAYER_HALF := 20.0
const PLAYER_SIZE := Vector2(40.0, 40.0)
const FEEDBACK_OFFSET := Vector2(20.0, 20.0)

const BASE_SPEED := 200.0
const SPEED_PER_SECOND := 1.5
const MAX_SPEED := 480.0
const SPAWN_X := 1240.0
const GAP_PIXELS := 440.0
const MIN_SPAWN_INTERVAL := 0.86
const SPAWN_INTERVAL_RANDOM := 0.18
const INITIAL_SPAWN_COOLDOWN := 0.8

const PHASE_COLORS := [
	Color(0.20, 0.92, 1.0, 1.0),
	Color(1.0, 0.38, 0.82, 1.0),
]
const PHASE_NAMES := ["CYAN", "MAGENTA"]
const FLIP_PULSE := Vector2(1.35, 1.35)
const FLIP_RECOVER_SEC := 0.16

const FEEDBACK_MAP := {
	"act": {"particles": "FlipParticles", "se": "FlipSE"},
	"fail": {"particles": "CrashParticles", "se": "GameOverSE"},
	"record": {"particles": "", "se": "HighScoreSE"},
}

var scroll_speed: float = BASE_SPEED
var player_phase: int = 0
var spawn_cooldown: float = INITIAL_SPAWN_COOLDOWN

var _next_phase: int = 0
var _elapsed: float = 0.0
var _failed: bool = false
var _flip_tween: Tween

@onready var player: Polygon2D = $Player
@onready var flip_particles: CPUParticles2D = $FlipParticles
@onready var flip_se: AudioStreamPlayer = $FlipSE
@onready var phase_label: Label = $PhaseLabel

func get_feedback_map() -> Dictionary:
	return FEEDBACK_MAP

func get_difficulty() -> float:
	return scroll_speed

func is_failed() -> bool:
	return _failed

func get_feedback_position(event_name: String) -> Vector2:
	if event_name == "act":
		return Vector2(PLAYER_X, PLAYER_Y) + FEEDBACK_OFFSET
	return Vector2(PLAYER_X, PLAYER_Y)

func get_player() -> Node:
	return self

func get_body_rect() -> Rect2:
	return Rect2(
		Vector2(PLAYER_X - PLAYER_HALF, PLAYER_Y - PLAYER_HALF),
		PLAYER_SIZE)

func mode_start() -> void:
	_elapsed = 0.0
	_failed = false
	scroll_speed = BASE_SPEED
	spawn_cooldown = INITIAL_SPAWN_COOLDOWN
	player_phase = 0
	_next_phase = 0
	_clear_all_barriers()
	_reset_flip_pulse()
	_sync_player()
	_update_label()

func mode_tick(delta: float, act_pressed: bool, _act_released: bool) -> void:
	_elapsed += delta
	scroll_speed = minf(BASE_SPEED + _elapsed * SPEED_PER_SECOND, MAX_SPEED)

	if act_pressed and not _failed:
		player_phase = 1 - player_phase
		_pulse_flip()
		_update_phase_feedback()
		host.emit_feedback("act")
		_update_label()

	_sync_player()
	_advance_barriers(delta)

	spawn_cooldown -= delta
	if spawn_cooldown <= 0.0:
		spawn_barrier()
		spawn_cooldown = maxf(MIN_SPAWN_INTERVAL, GAP_PIXELS / scroll_speed)
		spawn_cooldown += host.get_rng().randf() * SPAWN_INTERVAL_RANDOM

	_check_collision()

func spawn_barrier() -> void:
	var barrier: Node2D = BARRIER_SCRIPT.new()
	barrier.setup(_next_phase, scroll_speed)
	barrier.position = Vector2(SPAWN_X, 0.0)
	add_child(barrier)
	barrier.set_player_phase(player_phase)
	_next_phase = host.get_rng().randi() % 2

func _advance_barriers(delta: float) -> void:
	for barrier in _live_barriers():
		barrier.advance(delta)
		barrier.set_player_phase(player_phase)
		if barrier.is_offscreen():
			_despawn(barrier)

func _live_barriers() -> Array[Node]:
	return get_tree().get_nodes_in_group("barriers")

func _clear_all_barriers() -> void:
	for barrier in _live_barriers():
		_despawn(barrier)

func _despawn(barrier: Node) -> void:
	barrier.remove_from_group("barriers")
	barrier.queue_free()

func _check_collision() -> void:
	var body := get_body_rect()
	for barrier in _live_barriers():
		if barrier.phase == player_phase and barrier.collides_with(body):
			_failed = true
			return

func _sync_player() -> void:
	if player != null:
		player.color = PHASE_COLORS[player_phase]

func _update_phase_feedback() -> void:
	if flip_particles != null:
		flip_particles.color = PHASE_COLORS[player_phase]
	if flip_se != null:
		flip_se.pitch_scale = 1.2 if player_phase == 0 else 1.5

func _pulse_flip() -> void:
	if player == null:
		return
	if _flip_tween != null:
		_flip_tween.kill()
	player.scale = FLIP_PULSE
	_flip_tween = create_tween()
	var recover := _flip_tween.tween_property(player, "scale", Vector2.ONE, FLIP_RECOVER_SEC)
	recover.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _reset_flip_pulse() -> void:
	if _flip_tween != null:
		_flip_tween.kill()
	if player != null:
		player.scale = Vector2.ONE
	_update_phase_feedback()

func _update_label() -> void:
	if phase_label != null:
		phase_label.text = "PHASE: %s" % PHASE_NAMES[player_phase]
		phase_label.modulate = PHASE_COLORS[player_phase]
