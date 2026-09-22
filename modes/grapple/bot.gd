extends RefCounted

# 振り子グラップルモード用の参照プレイヤー。
# 「ボットが書けない = 人間にも理不尽である」という仮定のもと、
# このボットが規定秒数を生存できることをプレイアビリティの代理指標にしている。
#
# 方針: 落ちてきたらフック、振り子が最下点を過ぎたら離す。
# 最下点で離すと速く遠くへ飛び、遅めに離すと高く上がる。
# 振幅が小さくて位相が来ないときは時間で見切り、落下→再フックに戻す。

const HOOK_FALL_Y := 300.0
const HOOK_FALL_VY := 60.0
const HOOK_LOW_Y := 420.0
const RELEASE_THETA := 0.38
const SWING_TIMEOUT := 1.4

func decide(main: Node, harness: RefCounted) -> void:
	var mode: Node = main.get_active_mode()
	if mode.is_swinging():
		var past_bottom: bool = mode.swing_theta > RELEASE_THETA and mode.swing_omega > 0.0
		if past_bottom or mode.swing_elapsed > SWING_TIMEOUT:
			harness.release()
		# 保持中は何もしない（離さないことがホールドになる）。
	else:
		var falling_in: bool = mode.fly_velocity.y > HOOK_FALL_VY and mode.player_pos.y > HOOK_FALL_Y
		if falling_in or mode.player_pos.y > HOOK_LOW_Y:
			harness.press()
		else:
			harness.release()
