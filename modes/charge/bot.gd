extends RefCounted

# チャージ投擲モード用の参照プレイヤー。
# 「ボットが書けない = 人間にも理不尽である」という仮定のもと、
# このボットが規定秒数を生存できることをプレイアビリティの代理指標にしている。
#
# 方針: 構えたら今離したときの弾道を前向きに模擬し、
# 標的に当たる瞬間だけ離す。当たらなければ溜め続ける。
# パワーが最大になった後は角度だけが往復するので、
# 届く範囲の標的には必ず解が現れる。何もしないと見送りで
# 残弾が減るため、構えられる場面ではすぐ構える。

const SIM_DT := 1.0 / 60.0
const SIM_MAX_TIME := 6.0
# 自動発射より手前で見切る時刻。ここまで解が出なければ諦めて離す。
const HOLD_LIMIT := 2.3

func decide(main: Node, harness: RefCounted) -> void:
	var mode: Node = main.get_active_mode()
	if mode.is_flying():
		return
	if mode.is_charging():
		if mode.charge_time >= HOLD_LIMIT or _shot_hits(main, mode, mode.charge_time):
			harness.release()
		return
	if mode.ammo > 0:
		harness.press()
	else:
		harness.release()

# 今離した弾が標的に届くかを、モードと同じ更新式で模擬する。
func _shot_hits(main: Node, mode: Node, charge_t: float) -> bool:
	var pos: Vector2 = mode.muzzle_pos()
	var vel: Vector2 = mode.launch_velocity(charge_t)
	var targets: Array[Node] = mode.get_tree().get_nodes_in_group("targets")
	var hit_radius: float = mode.TARGET_RADIUS + mode.SHELL_RADIUS
	var steps: int = int(SIM_MAX_TIME / SIM_DT)
	for _i in steps:
		vel.y += mode.SHOT_GRAVITY * SIM_DT
		pos += vel * SIM_DT
		for target_node in targets:
			if pos.distance_to(target_node.position) <= hit_radius:
				return true
		if pos.y >= mode.GROUND_Y or pos.x > mode.FLY_X_MAX or pos.y < mode.FLY_Y_TOP:
			return false
	return false
