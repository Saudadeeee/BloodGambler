# res://scripts/table_texas.gd
extends Node

const N_PLAYERS := 4
const PLAYER_ID := 0           # ghế của người chơi
const START_HP := 100
const ANTE := 2

# fixed-limit (đơn giản cho game jam)
const BET_SMALL := 4           # preflop, flop
const BET_BIG   := 8           # turn, river
const MAX_RAISES := 3

@onready var deck := Deck.new()
@onready var ui: BettingUI = $BettingUI as BettingUI


var hp: Array[int] = []
var pot: int = 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	if ui == null:
		var UIClass := preload("res://scripts/betting_ui.gd")
		ui = UIClass.new()
		ui.name = "BettingUI"
		add_child(ui)
	
	print("--- TEXAS HOLD'EM (PLAYER UI DEMO) ---")
	rng.randomize()
	hp.resize(N_PLAYERS)
	for i in range(N_PLAYERS):
		hp[i] = START_HP

	# Chơi 3 ván mẫu
	for h in range(3):
		if _alive_count() <= 1:
			break
		print("\n=== HAND %d ===" % (h + 1))
		await _play_one_hand()   # dùng await vì có chờ thao tác người chơi
		_print_hp()

	var alive := _alive_seats()
	if alive.size() == 1:
		print("\n==> CHAMPION: Player %d (HP=%d)" % [alive[0], hp[alive[0]]])

func _play_one_hand() -> void:
	deck.reset()
	pot = 0

	var alive: Array[int] = _alive_seats()
	if alive.size() < 2:
		return

	# ante
	for i in alive:
		var pay: int = min(ANTE, hp[i])
		hp[i] -= pay
		pot += pay

	# hole
	var hole_cards: Array = []
	hole_cards.resize(N_PLAYERS)
	for i in range(N_PLAYERS):
		hole_cards[i] = []
	for i in alive:
		hole_cards[i] = deck.draw_many(2)

	var active: Array[int] = alive.duplicate()
	var board: Array[int] = []

	_print_holes(active, hole_cards)

	# preflop
	if await _betting_round(active, hole_cards, board, "preflop", BET_SMALL):
		_award_when_all_fold(active)
		return

	# flop
	board += deck.draw_many(3)
	_print_board("Flop", board)
	if await _betting_round(active, hole_cards, board, "flop", BET_SMALL):
		_award_when_all_fold(active)
		return

	# turn
	board += deck.draw_many(1)
	_print_board("Turn", board)
	if await _betting_round(active, hole_cards, board, "turn", BET_BIG):
		_award_when_all_fold(active)
		return

	# river
	board += deck.draw_many(1)
	_print_board("River", board)
	if await _betting_round(active, hole_cards, board, "river", BET_BIG):
		_award_when_all_fold(active)
		return

	_showdown_and_payout(active, hole_cards, board)

func _betting_round(active: Array[int], hole: Array, board: Array[int], street: String, bet_size: int) -> bool:
	if active.size() <= 1:
		return true

	var contrib := {}   
	for p in active:
		contrib[p] = 0

	var to_call: int = 0
	var raises: int = 0
	var players_to_act: int = active.size()
	var idx: int = 0

	print("[%s] pot=%d, bet=%d" % [street.capitalize(), pot, bet_size])

	while true:
		if active.size() <= 1:
			return true

		var p: int = active[idx]
		var need: int = to_call - int(contrib[p])
		if need < 0:
			need = 0

		var act: Dictionary = {}

		if p == PLAYER_ID:
			# lượt người chơi: hiện UI và đợi
			var can_raise: bool = (raises < MAX_RAISES) and (hp[p] > need + bet_size)
			var can_allin: bool = hp[p] > 0
			ui.prompt(street, need, bet_size, can_raise, can_allin)
			await ui.action_chosen
			var choice := ui.get_choice()
			act = {"type": choice}
		else:
			# bot
			act = _bot_decide(p, hole[p], board, street, need, bet_size, raises)

	
		if hp[p] <= 0 and act.get("type", "") != "fold":
			if need > 0:
				act["type"] = "allin"
			else:
				act["type"] = "check"

		match String(act["type"]):
			"fold":
				print("  P%d folds" % p)
				active.erase(p)
				players_to_act = max(players_to_act - 1, 0)
				if active.size() <= 1:
					return true
			"check":
				if need != 0:
					# invalid check -> coi như call nếu có tiền, hết tiền thì all-in
					if hp[p] >= need:
						act["type"] = "call"
					else:
						act["type"] = "allin"
					continue # xử lý lại nhánh ngay vòng sau
				print("  P%d checks" % p)
				players_to_act -= 1
			"call":
				var pay_c: int = min(need, hp[p])
				hp[p] -= pay_c
				contrib[p] = int(contrib[p]) + pay_c
				pot += pay_c
				print("  P%d calls (%d)" % [p, pay_c])
				players_to_act -= 1
			"raise":
				if raises >= MAX_RAISES:
					# gọi thay vì raise
					var pay_cap: int = min(need, hp[p])
					hp[p] -= pay_cap
					contrib[p] = int(contrib[p]) + pay_cap
					pot += pay_cap
					print("  P%d calls (cap reached) (%d)" % [p, pay_cap])
					players_to_act -= 1
				else:
					# trả phần thiếu + thêm bet_size
					var pay_need: int = min(need, hp[p])
					hp[p] -= pay_need
					contrib[p] = int(contrib[p]) + pay_need
					pot += pay_need

					var add: int = min(bet_size, hp[p])
					hp[p] -= add
					contrib[p] = int(contrib[p]) + add
					pot += add

					to_call = int(contrib[p])
					raises += 1
					players_to_act = active.size() - 1
					print("  P%d raises to %d (need=%d + add=%d)" % [p, to_call, pay_need, add])
			"allin":
				var pay_all: int = hp[p]
				if pay_all > 0:
					hp[p] = 0
					contrib[p] = int(contrib[p]) + pay_all
					pot += pay_all
				if int(contrib[p]) > to_call:
					to_call = int(contrib[p])
					raises += 1
					players_to_act = active.size() - 1
					print("  P%d ALL-IN to %d" % [p, to_call])
				else:
					print("  P%d ALL-IN (call)" % p)
					players_to_act -= 1
			_:
				# fallback
				if need == 0:
					print("  P%d checks" % p)
					players_to_act -= 1
				else:
					var pay_d: int = min(need, hp[p])
					hp[p] -= pay_d
					contrib[p] = int(contrib[p]) + pay_d
					pot += pay_d
					print("  P%d calls (%d)" % [p, pay_d])
					players_to_act -= 1

		if players_to_act <= 0:
			break

		idx = (idx + 1) % active.size()

	return false

func _bot_decide(p: int, hole: Array, board: Array[int], street: String, need: int, bet_size: int, raises: int) -> Dictionary:
	var strength: int = _rough_strength(hole, board) # 0..100
	var can_raise: bool = (raises < MAX_RAISES) and (hp[p] > need + bet_size)
	var jitter: int = rng.randi_range(-5, 5)
	strength = clamp(strength + jitter, 0, 100)

	if need == 0:
		if strength >= 75 and can_raise:
			return {"type": "raise"}
		elif strength >= 90 and hp[p] <= bet_size * 2:
			return {"type": "allin"}
		else:
			return {"type": "check"}
	else:
		if strength < 25 and need >= bet_size:
			return {"type": "fold"}
		if strength >= 85 and hp[p] <= need + bet_size:
			return {"type": "allin"}
		if strength >= 60 and can_raise:
			return {"type": "raise"}
		if hp[p] >= need:
			return {"type": "call"}
		return {"type": "allin"}

func _rough_strength(hole: Array, board: Array[int]) -> int:
	var total: int = 2 + board.size()
	if total == 2:
		var r1: int = CardUtils.rank_of(int(hole[0]))
		var r2: int = CardUtils.rank_of(int(hole[1]))
		var s1: int = CardUtils.suit_of(int(hole[0]))
		var s2: int = CardUtils.suit_of(int(hole[1]))
		var score: int = 0
		if r1 == r2:
			score = 60 + maxi(r1, r2) * 2
		else:
			score = maxi(r1, r2) * 2
			if s1 == s2:
				score += 8
			if abs(r1 - r2) <= 1:
				score += 6
			elif abs(r1 - r2) == 2:
				score += 3
		return clamp(score, 0, 100)
	elif total == 5:
		var ev5: Array = HandEvaluator.evaluate_five(hole + board)
		return 15 * int(ev5[0]) + 5
	elif total == 6:
		var best: Array = _best_eval_from(hole + board)
		return 15 * int(best[0]) + 10
	else:
		var ev7: Array = HandEvaluator.evaluate_seven(hole + board)
		return 15 * int(ev7[0]) + 15

func _best_eval_from(cards: Array[int]) -> Array:
	if cards.size() == 5:
		return HandEvaluator.evaluate_five(cards)
	if cards.size() == 6:
		var best: Array = []
		var has_best := false
		for i in range(6):
			var sub: Array[int] = []
			for k in range(6):
				if k != i:
					sub.append(cards[k])
			var ev: Array = HandEvaluator.evaluate_five(sub)
			if not has_best or HandEvaluator._compare_eval(ev, best) > 0:
				best = ev
				has_best = true
		return best
	return HandEvaluator.evaluate_seven(cards)

func _showdown_and_payout(active: Array[int], hole: Array, board: Array[int]) -> void:
	var best_eval: Array = []
	var winners: Array[int] = []
	var has_best := false

	for p in active:
		var ev: Array = HandEvaluator.evaluate_seven(hole[p] + board)
		if not has_best or HandEvaluator._compare_eval(ev, best_eval) > 0:
			best_eval = ev
			winners = [p]
			has_best = true
		elif HandEvaluator._compare_eval(ev, best_eval) == 0:
			winners.append(p)

	if winners.size() == 1:
		hp[winners[0]] += pot
	else:
		var share: int = pot / winners.size()
		var rem: int = pot % winners.size()
		for idx in range(winners.size()):
			var add: int = share
			if idx < rem:
				add += 1
			hp[winners[idx]] += add

	for p in active:
		print("Player %d: %s" % [p, _cards_to_string(hole[p])])
	print("Board: %s" % _cards_to_string(board))
	var names: Array[String] = []
	for w in winners:
		names.append("P%d" % w)
	print("==> Winner(s): %s  (%s %s) | Pot=%d" % [
		", ".join(names),
		HandEvaluator.hand_name(int(best_eval[0])),
		str(best_eval[1]),
		pot
	])

func _award_when_all_fold(active: Array[int]) -> void:
	if active.size() == 1:
		hp[active[0]] += pot
		print("==> Everyone folded. P%d wins pot=%d" % [active[0], pot])

func _alive_seats() -> Array[int]:
	var res: Array[int] = []
	for i in range(N_PLAYERS):
		if hp[i] > 0:
			res.append(i)
	return res

func _alive_count() -> int:
	return _alive_seats().size()

func _print_hp() -> void:
	var parts: Array[String] = []
	for i in range(N_PLAYERS):
		parts.append("P%d:%d" % [i, hp[i]])
	print("HP:", ", ".join(parts))

func _print_holes(active: Array[int], hole: Array) -> void:
	for p in active:
		print("Player %d: %s" % [p, _cards_to_string(hole[p])])

func _print_board(stage: String, board: Array[int]) -> void:
	print("%s: %s" % [stage, _cards_to_string(board)])

func _cards_to_string(cards: Array) -> String:
	var parts: Array[String] = []
	for c in cards:
		parts.append(CardUtils.card_to_string(int(c)))
	return ", ".join(parts)
