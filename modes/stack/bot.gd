extends RefCounted

const PRESS_TOL := 12.0

func decide(main: Node, harness: RefCounted) -> void:
	var mode: Node = main.get_active_mode()
	if mode.is_failed():
		harness.release()
		return
	if absf(mode.moving_x - mode.top_center) <= PRESS_TOL:
		harness.press()
	else:
		harness.release()
