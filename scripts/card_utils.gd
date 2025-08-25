# res://scripts/card_utils.gd
class_name CardUtils


static func rank_of(card: int) -> int:
	return (card % 13) + 2

static func suit_of(card: int) -> int:
	return int(card / 13)  # 0=Spade,1=Heart,2=Diamond,3=Club

static func rank_to_string(rank: int) -> String:
	match rank:
		11: return "J"
		12: return "Q"
		13: return "K"
		14: return "A"
		_:  return str(rank)

static func suit_to_string(suit: int) -> String:
	match suit:
		0: return "♠"
		1: return "♥"
		2: return "♦"
		3: return "♣"
		_: return "?"

static func card_to_string(card: int) -> String:
	return "%s%s" % [rank_to_string(rank_of(card)), suit_to_string(suit_of(card))]
