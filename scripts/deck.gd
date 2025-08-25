# res://scripts/deck.gd
class_name Deck
extends RefCounted

var _cards: Array[int] = []

func _init() -> void:
	reset()

func reset() -> void:
	_cards.clear()
	for i in range(52):
		_cards.append(i)
	shuffle()

func shuffle() -> void:
	_cards.shuffle()

func is_empty() -> bool:
	return _cards.is_empty()

func remaining() -> int:
	return _cards.size()

func draw_one() -> int:
	if _cards.is_empty():
		push_warning("Deck is empty; returning -1")
		return -1
	return _cards.pop_back()

func draw_many(n: int) -> Array[int]:
	var res: Array[int] = []
	for i in n:
		if _cards.is_empty():
			push_warning("Deck empty while drawing many")
			break
		res.append(_cards.pop_back())
	return res
