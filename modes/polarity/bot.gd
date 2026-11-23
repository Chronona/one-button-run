extends RefCounted

const PLAYER_FRONT_X := 240.0
const LEAD_SECONDS := 0.18
const EXTRA_LEAD := 18.0

func decide(main: Node, harness: RefCounted) -> void:
	var mode: Node = main.get_active_mode()
	if mode.is_failed():
		harness.release()
		return

	var nearest: Node2D = null
	var nearest_left: float = 1.0e9
	for barrier in main.get_tree().get_nodes_in_group("barriers"):
		var left: float = barrier.position.x
		var right: float = left + barrier.WIDTH
		if right >= PLAYER_FRONT_X - 12.0 and left < nearest_left:
			nearest = barrier
			nearest_left = left

	if nearest == null or nearest.phase != mode.player_phase:
		harness.release()
		return

	var lead: float = main.get_difficulty() * LEAD_SECONDS + EXTRA_LEAD
	if nearest_left - PLAYER_FRONT_X <= lead:
		harness.press()
	else:
		harness.release()
