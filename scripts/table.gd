extends Node2D

@export var players: int = 4
@export var start_hp: int = 100
@export var bet_small: int = 4
@export var bet_big: int = 8
@export var max_raises: int = 3
@export var predeal_board_facedown: bool = true

@export var dealer_path: NodePath
@export var player_ctrl_path: NodePath
@export var bot_brain_path: NodePath

var dealer: Dealer
var player_ctrl: PlayerController
var bot: BotBrain

var hole_ids: Array = []      # [seat] -> Array[int]
var hole_nodes: Array = []    # [seat] -> Array[Card]

var hp: Array[int] = []
var pot: int = 0
var cheat_count: int = 0
var wins_count: int = 0
var hand_no: int = 1

func _ready() -> void:
	dealer = get_node_or_null(dealer_path) as Dealer
	player_ctrl = get_node_or_null(player_ctrl_path) as PlayerController
	bot = get_node_or_null(bot_brain_path) as BotBrain

	if dealer == null or not dealer.has_method("reset_all"):
		push_error("Dealer node không tồn tại hoặc chưa gắn script Dealer.gd")
		return

	hp.resize(players)
	for i in range(players):
		hp[i] = start_hp

	await _deal_new_hand()
	await _play_hand_flow()

func _cleanup_hole_nodes() -> void:
	for s in range(hole_nodes.size()):
		var arr := hole_nodes[s] as Array
		for n in arr:
			if is_instance_valid(n):
				n.queue_free()
	hole_nodes.clear()
	hole_ids.clear()

func _cleanup_before_new_hand() -> void:
	_cleanup_hole_nodes()
	if dealer != null and dealer.has_method("clear_board"):
		dealer.clear_board()

func _deal_new_hand() -> void:
	_cleanup_before_new_hand()
	if dealer != null and dealer.has_method("reset_all"):
		dealer.reset_all()
	pot = 0

	hole_ids.resize(players)
	hole_nodes.resize(players)
	for s in range(players):
		hole_ids[s] = []
		hole_nodes[s] = []

	for r in range(2):
		for seat in range(players):
			var face_up: bool = (seat == 0)
			var card_id: int = dealer.deck.draw_one()
			var idx: int = (hole_ids[seat] as Array).size()
			var node: Card = await dealer.fly_card_to_hand(card_id, seat, idx, idx, face_up)
			(hole_ids[seat] as Array).append(card_id)
			(hole_nodes[seat] as Array).append(node)

	if predeal_board_facedown:
		await dealer.predeal_board_facedown()

func _cards_to_string(cards: Array) -> String:
	var suit_labels := ["♠","♥","♦","♣"]
	var parts: Array[String] = []
	for c in cards:
		var id := int(c)
		var s := CardUtils.suit_of(id)
		var rank_str := CardUtils.rank_filename(id) 
		match rank_str:
			"JACK":  rank_str = "J"
			"QUEEN": rank_str = "Q"
			"KING":  rank_str = "K"
			"ACE":   rank_str = "A"
		if rank_str.begins_with("0"): 
			rank_str = str(int(rank_str))
		parts.append("%s%s" % [rank_str, suit_labels[s]])
	return ", ".join(parts)

func _print_hp() -> void:
	var out: Array[String] = []
	for i in range(players):
		out.append("P%d:%d" % [i, hp[i]])
	print("HP:" + ", ".join(out))

func _can_cheat(street: String) -> bool:
	var allow := (street == "flop" and dealer.board_revealed == 3)
	if player_ctrl != null and player_ctrl.has_method("can_cheat"):
		return player_ctrl.can_cheat(street, dealer.board_revealed)
	return allow

func _do_cheat(seat: int) -> void:
	if seat != 0: return
	if not _can_cheat("flop"): return
	cheat_count += 1
	var id: int = dealer.deck.draw_one()
	var idx: int = (hole_ids[0] as Array).size()
	var node: Card = await dealer.fly_card_to_hand(id, 0, idx, idx, true)
	(hole_ids[0] as Array).append(id)
	(hole_nodes[0] as Array).append(node)
	var risk: float = float(wins_count * 10 + cheat_count * 5)
	if randf() < risk / 100.0:
		hp[0] = max(0, hp[0] - 20)

func _bet_round(active: Array, street: String, bet_unit: int) -> bool:
	if active.size() <= 1:
		return true

	var contrib: Dictionary = {}
	for s in active:
		contrib[int(s)] = 0
	var to_call: int = 0
	var raises: int = 0
	var players_to_act: int = active.size()
	var idx: int = 0

	while true:
		if active.size() <= 1:
			return true

		var seat: int = int(active[idx])
		var need: int = max(0, to_call - int(contrib[seat]))
		var can_raise: bool = (raises < max_raises) and (hp[seat] > need + bet_unit)
		var act: String = ""
		if seat == 0:
			var cheat_enabled: bool = _can_cheat(street)
			if player_ctrl != null and player_ctrl.has_method("ask_action"):
				act = await player_ctrl.ask_action(street, need, bet_unit, can_raise, hp[seat] > 0, cheat_enabled)
			else:
				var ui := get_node_or_null("BettingUI") as BettingUI
				if ui:
					ui.prompt(street, need, bet_unit, can_raise, hp[seat] > 0, cheat_enabled)
					await ui.action_chosen
					act = ui.get_choice()
				else:
					act = "check" if need == 0 else "call"
		else:
			act = bot.decide_action(need, bet_unit, raises, max_raises, hp[seat], street)

		var advance_idx: bool = true

		match act:
			"cheat":
				if _can_cheat(street):
					_do_cheat(seat)
				else:
					advance_idx = false

			"fold":
				active.erase(seat)
				players_to_act = max(players_to_act - 1, 0)
				advance_idx = false
				if active.size() <= 1:
					_award_when_all_fold(active)
					return true
				if idx >= active.size():
					idx = 0

			"check":
				if need != 0:
					act = "call"
					advance_idx = false
					continue
				players_to_act -= 1

			"call":
				var pay: int = min(need, hp[seat])
				hp[seat] -= pay
				contrib[seat] = int(contrib[seat]) + pay
				pot += pay
				players_to_act -= 1

			"raise":
				if raises >= max_raises or not can_raise:
					var pay_cap: int = min(need, hp[seat])
					hp[seat] -= pay_cap
					contrib[seat] = int(contrib[seat]) + pay_cap
					pot += pay_cap
					players_to_act -= 1
				else:
					var pay_need: int = min(need, hp[seat])
					hp[seat] -= pay_need
					contrib[seat] = int(contrib[seat]) + pay_need
					pot += pay_need

					var add: int = min(bet_unit, hp[seat])
					hp[seat] -= add
					contrib[seat] = int(contrib[seat]) + add
					pot += add

					to_call = int(contrib[seat])
					raises += 1
					players_to_act = active.size() - 1

			"allin":
				var pay_all: int = hp[seat]
				if pay_all > 0:
					hp[seat] = 0
					contrib[seat] = int(contrib[seat]) + pay_all
					pot += pay_all
				if int(contrib[seat]) > to_call:
					to_call = int(contrib[seat])
					raises += 1
					players_to_act = active.size() - 1
				else:
					players_to_act -= 1

			_:
				if need == 0:
					players_to_act -= 1
				else:
					var pay_d: int = min(need, hp[seat])
					hp[seat] -= pay_d
					contrib[seat] = int(contrib[seat]) + pay_d
					pot += pay_d
					players_to_act -= 1

		if players_to_act <= 0:
			break
		if advance_idx:
			idx = (idx + 1) % active.size()

	return false

# ---------------- Showdown ----------------
func _best_eval5_any(cards: Array) -> Array:
	var n: int = cards.size()
	var best: Array = []
	var has_best: bool = false
	for a in range(n - 4):
		for b in range(a + 1, n - 3):
			for c in range(b + 1, n - 2):
				for d in range(c + 1, n - 1):
					for e in range(d + 1, n):
						var sel: Array[int] = [
							int(cards[a]), int(cards[b]),
							int(cards[c]), int(cards[d]), int(cards[e])
						]
						var ev: Array = HandEvaluator.evaluate_five(sel)
						if not has_best or HandEvaluator._compare_eval(ev, best) > 0:
							best = ev
							has_best = true
	return best

func _showdown_and_payout(active: Array) -> void:
	var best_eval: Array = []
	var winners: Array = []
	var has_best: bool = false

	for p in active:
		var seat: int = int(p)
		var cards: Array = (hole_ids[seat] as Array).duplicate()
		cards.append_array(dealer.board_ids)
		var ev: Array = _best_eval5_any(cards)
		if not has_best or HandEvaluator._compare_eval(ev, best_eval) > 0:
			best_eval = ev
			winners = [seat]
			has_best = true
		elif HandEvaluator._compare_eval(ev, best_eval) == 0:
			winners.append(seat)

	if winners.size() == 1:
		hp[int(winners[0])] += pot
	else:
		var share: int = pot / winners.size()
		var rem: int = pot % winners.size()
		for i in range(winners.size()):
			var add_each: int = share + (1 if i < rem else 0)
			hp[int(winners[i])] += add_each

	# Debug log tay bài + kết quả
	for p in active:
		var seat2: int = int(p)
		print("Player %d: %s" % [seat2, _cards_to_string(hole_ids[seat2] as Array)])
	print("Board: %s" % _cards_to_string(dealer.board_ids))
	var names: Array[String] = []
	for w in winners:
		names.append("P%d" % int(w))
	print("==> Winner(s): %s  (%s %s) | Pot=%d" %
		[", ".join(names), HandEvaluator.hand_name(int(best_eval[0])), str(best_eval[1]), pot])

	pot = 0
	_print_hp()

func _award_when_all_fold(active: Array) -> void:
	if active.size() == 1:
		var s: int = int(active[0])
		hp[s] += pot
		print("==> Everyone folded. P%d wins pot=%d" % [s, pot])
		pot = 0
	_print_hp()

# ---------------- Flow ----------------
func _active_seats() -> Array:
	var a: Array = []
	for s in range(players):
		if hp[s] > 0:
			a.append(s)
	return a

func _play_hand_flow() -> void:
	while _active_seats().size() > 1:
		print("\n=== HAND %d ===" % hand_no)
		hand_no += 1
		var active: Array = _active_seats()

		var ended: bool = await _bet_round(active, "preflop", bet_small)
		if ended:
			await _deal_new_hand()
			continue

		if predeal_board_facedown:
			await dealer.reveal_flop()
		ended = await _bet_round(active, "flop", bet_small)
		if ended:
			await _deal_new_hand()
			continue

		if predeal_board_facedown:
			await dealer.reveal_turn()
		ended = await _bet_round(active, "turn", bet_big)
		if ended:
			await _deal_new_hand()
			continue

		if predeal_board_facedown:
			await dealer.reveal_river()
		ended = await _bet_round(active, "river", bet_big)
		if ended:
			await _deal_new_hand()
			continue

		_showdown_and_payout(active)
		await _deal_new_hand()
