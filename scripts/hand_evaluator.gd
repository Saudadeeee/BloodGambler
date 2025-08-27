# res://scripts/hand_evaluator.gd
class_name HandEvaluator
extends RefCounted

const CARD_COUNT := 5

static func evaluate_five(cards: Array[int]) -> Array:
	assert(cards.size() == CARD_COUNT)
	var ranks: Array[int] = []
	var suits: Array[int] = []
	for c in cards:
		ranks.append(CardUtils.rank_of(c))
		suits.append(CardUtils.suit_of(c))
	ranks.sort() 
	var ranks_desc: Array[int] = ranks.duplicate()
	ranks_desc.reverse()

	var is_flush: bool = _is_flush(suits)
	var is_straight: bool = _is_straight(ranks)

	var counts: Dictionary = _rank_counts(ranks)
	var count_pairs: Array = _count_pairs(counts) 
	if is_straight and is_flush:
		var high: int = _straight_high(ranks)
		return [8, [high]]
		
	if int(count_pairs[0][0]) == 4:
		var four_rank: int = int(count_pairs[0][1])
		var kicker: Array[int] = _kickers(ranks_desc, [four_rank])
		return [7, [four_rank] + kicker]

	if int(count_pairs[0][0]) == 3 and count_pairs.size() >= 2 and int(count_pairs[1][0]) == 2:
		var trip_val: int = int(count_pairs[0][1])
		var pair_val: int = int(count_pairs[1][1])
		return [6, [trip_val, pair_val]]

	if is_flush:
		return [5, ranks_desc]

	if is_straight:
		return [4, [_straight_high(ranks)]]

	if int(count_pairs[0][0]) == 3:
		var trip_rank: int = int(count_pairs[0][1])
		var ks3: Array[int] = _kickers(ranks_desc, [trip_rank])
		return [3, [trip_rank] + ks3]

	if count_pairs.size() >= 2 and int(count_pairs[0][0]) == 2 and int(count_pairs[1][0]) == 2:
		var r0: int = int(count_pairs[0][1])
		var r1: int = int(count_pairs[1][1])
		var p1: int = maxi(r0, r1)
		var p2: int = mini(r0, r1)
		var ks2: Array[int] = _kickers(ranks_desc, [p1, p2])
		return [2, [p1, p2] + ks2]

	if int(count_pairs[0][0]) == 2:
		var pr: int = int(count_pairs[0][1])
		var ks1: Array[int] = _kickers(ranks_desc, [pr])
		return [1, [pr] + ks1]

	# High card
	return [0, ranks_desc]

static func compare_five(a_cards: Array[int], b_cards: Array[int]) -> int:
	var A: Array = evaluate_five(a_cards)
	var B: Array = evaluate_five(b_cards)
	return _compare_eval(A, B)


static func evaluate_seven(cards: Array[int]) -> Array:
	assert(cards.size() == 7)
	var best_eval: Array = []
	var has_best: bool = false
	for i in range(cards.size()):
		for j in range(i + 1, cards.size()):
			var sub_hand: Array[int] = []
			for k in range(cards.size()):
				if k != i and k != j:
					sub_hand.append(cards[k])
			var ev: Array = evaluate_five(sub_hand)
			if not has_best or _compare_eval(ev, best_eval) > 0:
				best_eval = ev
				has_best = true
	return best_eval

static func compare_seven(a_cards: Array[int], b_cards: Array[int]) -> int:
	var A: Array = evaluate_seven(a_cards)
	var B: Array = evaluate_seven(b_cards)
	return _compare_eval(A, B)

# (Tuỳ chọn) Lấy CHÍNH XÁC 5 lá mạnh nhất từ 7 lá để highlight UI
static func best_five_from_seven(cards: Array[int]) -> Array[int]:
	assert(cards.size() == 7)
	var best_eval: Array = []
	var best_keep: Array[int] = []
	var has_best: bool = false
	for a in range(7):
		for b in range(a + 1, 7):
			var keep: Array[int] = []
			for k in range(7):
				if k != a and k != b:
					keep.append(cards[k])
			var ev: Array = evaluate_five(keep)
			if not has_best or _compare_eval(ev, best_eval) > 0:
				best_eval = ev
				best_keep = keep
				has_best = true
	return best_keep


static func _compare_eval(A: Array, B: Array) -> int:
	if int(A[0]) != int(B[0]):
		return sign(int(A[0]) - int(B[0]))
	var at: Array = A[1]
	var bt: Array = B[1]
	var n: int = min(at.size(), bt.size())
	for i in range(n):
		if int(at[i]) != int(bt[i]):
			return sign(int(at[i]) - int(bt[i]))
	return 0

static func _is_flush(suits: Array[int]) -> bool:
	return suits.count(suits[0]) == CARD_COUNT

static func _is_straight(ranks_sorted: Array[int]) -> bool:
	for i in range(1, CARD_COUNT):
		if ranks_sorted[i] == ranks_sorted[i - 1]:
			return false
	if ranks_sorted == [2, 3, 4, 5, 14]:
		return true
	return ranks_sorted[4] - ranks_sorted[0] == 4

static func _straight_high(ranks_sorted: Array[int]) -> int:
	return 5 if ranks_sorted == [2, 3, 4, 5, 14] else ranks_sorted[4]

static func _rank_counts(ranks_sorted: Array[int]) -> Dictionary:
	var d := {}
	for r in ranks_sorted:
		d[r] = int(d.get(r, 0)) + 1
	return d

static func _count_pairs(counts: Dictionary) -> Array:
	var arr: Array = [] 
	for r in counts.keys():
		arr.append([int(counts[r]), int(r)])
	arr.sort_custom(func(a, b):
		if int(a[0]) != int(b[0]):
			return int(a[0]) > int(b[0])
		return int(a[1]) > int(b[1])
	)
	return arr

static func _kickers(ranks_desc: Array[int], exclude_ranks: Array[int]) -> Array[int]:
	var ks: Array[int] = []
	for r in ranks_desc:
		if not exclude_ranks.has(r):
			ks.append(r)
	return ks

static func hand_name(code: int) -> String:
	match code:
		8: return "Straight Flush"
		7: return "Four of a Kind"
		6: return "Full House"
		5: return "Flush"
		4: return "Straight"
		3: return "Three of a Kind"
		2: return "Two Pair"
		1: return "One Pair"
		_: return "High Card"
