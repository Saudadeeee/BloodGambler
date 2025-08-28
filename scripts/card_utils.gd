# res://scripts/CardUtils.gd
class_name CardUtils

# Mã hoá 1 lá bài = số nguyên 0..51
# suit = id / 13  (0=SPADES, 1=HEARTS, 2=DIAMONDS, 3=CLUBS)
# rank = id % 13  (0=02, 1=03, ..., 8=10, 9=JACK, 10=QUEEN, 11=KING, 12=ACE)

static func suit_of(id: int) -> int:
	return id / 13

static func rank_of(id: int) -> int:
	return id % 13

static func suit_name_upper(id_or_suit: int) -> String:
	var s := id_or_suit
	if s >= 0 and s <= 51:
		s = suit_of(s)
	match s:
		0: return "SPADES"
		1: return "HEARTS"
		2: return "DIAMONDS"
		3: return "CLUBS"
		_: return "SPADES"

static func rank_filename(id_or_rank: int) -> String:
	var r := id_or_rank
	if r >= 0 and r <= 51:
		r = rank_of(r)
	# 0..8 => 02..10, 9..12 => JACK..ACE
	if r <= 7:
		# 0->02, 1->03, ..., 7->09
		return str(2 + r).pad_zeros(2)
	elif r == 8:
		return "10"
	elif r == 9:
		return "JACK"
	elif r == 10:
		return "QUEEN"
	elif r == 11:
		return "KING"
	else:
		return "ACE"

static func texture_path_for(id: int, base_dir: String = "res://assets/card_deck") -> String:
	var suit = suit_name_upper(id)
	var rank = rank_filename(id)
	return "%s/%s_%s.png" % [base_dir, suit, rank]
