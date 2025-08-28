extends Node
class_name BotBrain

# ===== Optional context để bot "biết chuyện" hơn (có cũng được, không có vẫn chạy) =====
var ctx: Dictionary = {
	"pot": 0,                    # tổng pot hiện tại (chưa gồm 'need')
	"players_in_pot": 2,
	"position": "mid",           # "early" | "mid" | "late"
	"last_aggressor": -1,
	"table_tightness": 0.0,      # 0..1, 1 = rất chặt
	"hero_image": 0.5,           # 0..1, 1 = rất tight
	"villain_aggr": 0.5          # 0..1, 1 = rất aggro
}

var hole_current: Array[int] = []       # 2 lá của bot (nếu set)
var board_current: Array[int] = []      # 0..5 lá board (nếu set)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

# ===== Public API: set bối cảnh khi có =====
func set_hand_and_board(hole: Array, board: Array[int]) -> void:
	hole_current = []
	for h in hole:
		hole_current.append(int(h))
	board_current = board.duplicate()

func set_context(new_ctx: Dictionary) -> void:
	for k in new_ctx.keys():
		ctx[k] = new_ctx[k]

# ===== API cũ (tương thích ngược) =====
func decide_action(need: int, bet_unit: int, raises: int, max_raises: int, hp_seat: int, street: String) -> String:
	var hole: Array[int] = hole_current
	var board: Array[int] = board_current
	var local_ctx: Dictionary = ctx.duplicate()
	var decision: Dictionary = _bot_decide_core(hole, board, street, need, bet_unit, raises, max_raises, hp_seat, local_ctx)
	return String(decision.get("type", "check"))

# ===== Core Decision =====
func _bot_decide_core(
	hole: Array[int],
	board: Array[int],
	street: String,
	need: int,
	bet_size: int,
	raises: int,
	max_raises: int,
	hp_p: int,
	ctx_in: Dictionary
) -> Dictionary:
	# ---------- Basic ----------
	var street_map: Dictionary = {"preflop": 0, "flop": 1, "turn": 2, "river": 3}
	var street_idx: int = int(street_map.get(street, 0))
	var players_in_pot: int = int(ctx_in.get("players_in_pot", 2))
	var position: String = String(ctx_in.get("position", "mid"))
	var last_aggressor: int = int(ctx_in.get("last_aggressor", -1))
	var table_tightness: float = float(ctx_in.get("table_tightness", 0.0))
	var hero_img: float = float(ctx_in.get("hero_image", 0.5))
	var villain_aggr: float = float(ctx_in.get("villain_aggr", 0.5))
	var pot: int = int(ctx_in.get("pot", 0))

	var can_raise: bool = (raises < max_raises) and (hp_p > need + bet_size)
	var can_allin: bool = (hp_p > 0)
	var free_bet: bool = (need == 0)

	# ---------- Strength rough 0..100 ----------
	var strength: int = _estimate_strength(hole, board, street_idx)
	strength = clamp(strength + rng.randi_range(-3, 3), 0, 100)  # jitter nhẹ

	# ---------- Draws & texture ----------
	var draw_info: Dictionary = _analyze_draws_and_texture(hole, board, street_idx)
	var draw_bonus: int = 0
	if bool(draw_info.get("has_oesd", false)):
		draw_bonus += 7
	elif bool(draw_info.get("has_gutshot", false)):
		draw_bonus += 3
	if bool(draw_info.get("has_flush_draw", false)):
		draw_bonus += 8
	elif bool(draw_info.get("has_backdoor_flush", false)):
		draw_bonus += 2

	var texture_penalty: int = 0
	if bool(draw_info.get("paired_board", false)):
		texture_penalty += 4
	var texture: String = String(draw_info.get("texture", "rainbow"))
	if texture == "monotone":
		texture_penalty += 5
	elif texture == "twotone":
		texture_penalty += 2

	# ---------- Position / multiway / tightness ----------
	var pos_bonus: int = (7 if position == "late" else (3 if position == "mid" else 0))
	var multiway_penalty: int = max(0, players_in_pot - 2) * 4
	var tight_penalty: int = int(6.0 * table_tightness)

	var eff_strength: int = clamp(strength + draw_bonus + pos_bonus - texture_penalty - multiway_penalty - tight_penalty, 0, 100)
	var equity: float = float(eff_strength) / 100.0

	# ---------- Pot odds + SPR ----------
	if pot <= 0:
		pot = raises * bet_size * players_in_pot  # ước lượng thô nếu thiếu
	var call_be: float = (float(need) / float(pot + need)) if (pot + need) > 0 else 0.0
	var spr: float = (float(hp_p) / float(pot)) if pot > 0 else 99.0
	var spr_is_low: bool = spr <= 2.0

	# ---------- Bluff policy ----------
	var is_aggressor: bool = (last_aggressor == 0)  # nếu bạn track seat, thay 0 bằng seat của bot
	var can_light_bluff: bool = free_bet or ((not is_aggressor) and raises == 0 and players_in_pot == 2)

	var base_bluff: float = 0.14 if position == "late" else 0.08
	base_bluff -= 0.02 * float(players_in_pot - 2)
	base_bluff -= 0.02 * float(street_idx)
	base_bluff *= clamp(1.1 - 0.4 * table_tightness, 0.6, 1.2)
	base_bluff *= clamp(1.2 - 0.4 * hero_img, 0.6, 1.3)
	base_bluff = clamp(base_bluff, 0.02, 0.16)
	if bool(draw_info.get("has_oesd", false)) or bool(draw_info.get("has_flush_draw", false)):
		base_bluff = min(0.22, base_bluff + 0.05)

	var do_bluff: bool = can_light_bluff and (rng.randf() < base_bluff) and (eff_strength < 70)

	# ---------- Raise thresholds ----------
	var raise_threshold_by_street: Array[int] = [72, 67, 62, 60]
	var raise_threshold: int = raise_threshold_by_street[street_idx]
	if villain_aggr >= 0.75:
		raise_threshold += 4

	# ---------- Decisions ----------
	if free_bet:
		if eff_strength >= 92 and (hp_p <= bet_size * 2 or spr_is_low) and can_allin:
			return {"type":"allin"}
		if ((eff_strength >= raise_threshold) and can_raise) or (do_bluff and can_raise):
			return {"type":"raise"}
		return {"type":"check"}

	# need > 0
	var safety_margin: float = 0.04 + 0.01 * float(street_idx)
	if equity + 0.000001 < (call_be - safety_margin):
		if hp_p <= (need + bet_size) and (equity > 0.27 or bool(draw_info.get("has_oesd", false)) or bool(draw_info.get("has_flush_draw", false))) and can_allin:
			return {"type":"allin"}
		return {"type":"fold"}

	var raise_edge: float = 0.05 + 0.01 * float(2 - street_idx)
	if (equity - call_be) >= raise_edge and eff_strength >= (raise_threshold - 5) and can_raise:
		if bool(draw_info.get("has_flush_draw", false)) or bool(draw_info.get("has_oesd", false)) or spr_is_low or table_tightness >= 0.6:
			return {"type":"raise"}

	if (eff_strength >= 90 and (hp_p <= need + bet_size or spr_is_low) and can_allin) or (hp_p <= need and can_allin):
		return {"type":"allin"}

	if hp_p >= need:
		return {"type":"call"}
	return {"type":"allin"}

# ===== Strength Estimation (0..100) đơn giản =====
func _estimate_strength(hole: Array[int], board: Array[int], street_idx: int) -> int:
	if hole.size() < 2:
		var baseline: Array[int] = [52, 55, 57, 58]  # nhẹ theo street
		return baseline[street_idx]

	var r1: int = CardUtils.rank_of(int(hole[0]))
	var r2: int = CardUtils.rank_of(int(hole[1]))
	var s1: int = CardUtils.suit_of(int(hole[0]))
	var s2: int = CardUtils.suit_of(int(hole[1]))

	var hi: int = max(r1, r2)  # 0..12 ~ 2..A
	var lo: int = min(r1, r2)
	var pair: bool = (r1 == r2)
	var suited: bool = (s1 == s2)
	var gap: int = abs(r1 - r2)

	var val: int = 50
	if pair:
		val += 12 + int(float(hi) * 0.8)
	else:
		val += int(float(hi - 4) * 1.2)
		if suited: val += 3
		if gap == 1: val += 4
		elif gap == 2: val += 2
		elif gap >= 4: val -= 2

	if board.size() > 0:
		var rank_count: Dictionary = {}
		for c in board:
			var rr: int = CardUtils.rank_of(int(c))
			rank_count[rr] = int(rank_count.get(rr, 0)) + 1
		rank_count[r1] = int(rank_count.get(r1, 0)) + 1
		rank_count[r2] = int(rank_count.get(r2, 0)) + 1

		var best_count: int = 1
		for k in rank_count.keys():
			best_count = max(best_count, int(rank_count[k]))

		if best_count >= 3: val += 20
		elif best_count == 2: val += 8

	val += street_idx * 2
	return clamp(val, 0, 100)

# ===== Draws & Texture =====
func _analyze_draws_and_texture(hole: Array[int], board: Array[int], street_idx: int) -> Dictionary:
	var all_cards: Array[int] = []
	all_cards.append_array(hole)
	all_cards.append_array(board)

	# Suit counts
	var suit_cnt: Array[int] = [0, 0, 0, 0]
	for idc in all_cards:
		var s: int = CardUtils.suit_of(int(idc))
		if s >= 0 and s < 4:
			suit_cnt[s] += 1
	var max_suit: int = 0
	for sc in suit_cnt:
		max_suit = max(max_suit, sc)

	var on_flop: bool = (street_idx == 1)
	var has_flush_draw: bool = (max_suit >= 4)
	var has_backdoor_flush: bool = on_flop and (max_suit == 3)

	# Straight-ish
	var rank_set: Dictionary = {}
	for idc in all_cards:
		rank_set[CardUtils.rank_of(int(idc))] = true

	var has_oesd: bool = false
	var has_gutshot: bool = false
	if board.size() >= 3:
		has_oesd = _has_window_of_k(rank_set, 4, 5)
		if not has_oesd:
			has_gutshot = _has_window_of_k(rank_set, 4, 6)

	# Texture: paired? monotone? two-tone? (dựa trên BOARD)
	var texture: String = _suit_pattern(board)
	var paired_board: bool = _is_paired_board(board)

	return {
		"has_flush_draw": has_flush_draw,
		"has_backdoor_flush": has_backdoor_flush,
		"has_oesd": has_oesd,
		"has_gutshot": has_gutshot,
		"texture": texture,
		"paired_board": paired_board
	}

# ---- Helpers (method riêng) ----
func _has_window_of_k(set_dict: Dictionary, need_len: int, window: int) -> bool:
	for start in range(13):
		var count: int = 0
		for d in range(window):
			var rr: int = (start + d) % 13
			if set_dict.has(rr):
				count += 1
		if count >= need_len:
			return true
	return false

func _suit_pattern(cards: Array[int]) -> String:
	var cnt: Array[int] = [0, 0, 0, 0]
	for idc in cards:
		var ss: int = CardUtils.suit_of(int(idc))
		if ss >= 0 and ss < 4:
			cnt[ss] += 1
	cnt.sort()
	if cnt[3] >= 3 and cnt[2] == 0:
		return "monotone"
	if cnt[3] == 2 and cnt[2] == 2:
		return "twotone"
	return "rainbow"

func _is_paired_board(cards: Array[int]) -> bool:
	var seen: Dictionary = {}
	for idc in cards:
		var r: int = CardUtils.rank_of(int(idc))
		if seen.has(r):
			return true
		seen[r] = true
	return false
