# res://scripts/table_texas.gd
extends Node

const N_PLAYERS := 4
const START_HP := 100
const ANTE := 2
const ROUNDS := 10

@onready var deck := Deck.new()
var hp: Array[int] = []

func _ready() -> void:
	print("--- TEXAS HOLD'EM (ANTE DEMO) ---")
	hp.resize(N_PLAYERS)
	for i in range(N_PLAYERS):
		hp[i] = START_HP

	for r in range(ROUNDS):
		if _alive_count() <= 1:
			break
		print("\n=== HAND %d ===" % (r + 1))
		_play_one_hand()
		_print_hp()

	var alive := _alive_seats()
	if alive.size() == 1:
		print("\n==> CHAMPION: Player %d (HP=%d)" % [alive[0], hp[alive[0]]])
	else:
		print("\n==> Game end (nhiều người còn sống), HP:", hp)

func _play_one_hand() -> void:
	deck.reset()

	var alive := _alive_seats()
	if alive.size() < 2:
		return

	# Thu ante
	var pot: int = 0
	for i in alive:
		var pay: int = min(ANTE, hp[i])
		hp[i] -= pay
		pot += pay

	# Chia bài
	var hole_cards: Array = []
	hole_cards.resize(N_PLAYERS)
	for i in range(N_PLAYERS):
		hole_cards[i] = []
	for i in alive:
		hole_cards[i] = deck.draw_many(2)

	var board: Array = deck.draw_many(5)

	# In bài (chỉ in cho người còn sống)
	for i in alive:
		print("Player %d: %s" % [i, _cards_to_string(hole_cards[i])])
	print("Board: %s" % _cards_to_string(board))
	print("Pot (ante): %d HP" % pot)

	# Showdown
	var best_eval: Array = []
	var winners: Array[int] = []
	var has_best := false
	for i in alive:
		var eval_i: Array = HandEvaluator.evaluate_seven(hole_cards[i] + board)
		if not has_best:
			best_eval = eval_i
			winners = [i]
			has_best = true
		else:
			var cmp: int = HandEvaluator._compare_eval(eval_i, best_eval)
			if cmp > 0:
				best_eval = eval_i
				winners = [i]
			elif cmp == 0:
				winners.append(i)

	# Chia pot
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

	# In kết quả
	var names: Array[String] = []
	for w in winners:
		names.append("Player %d" % w)
	print("==> Winner(s): %s  (%s %s)" % [
		", ".join(names),
		HandEvaluator.hand_name(int(best_eval[0])),
		str(best_eval[1])
	])

	# Clamp HP không âm
	for i in range(N_PLAYERS):
		if hp[i] <= 0:
			hp[i] = 0

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

func _cards_to_string(cards: Array) -> String:
	var parts: Array[String] = []
	for c in cards:
		parts.append(CardUtils.card_to_string(int(c)))
	return ", ".join(parts)
