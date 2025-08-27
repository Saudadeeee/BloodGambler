# res://scripts/Deck.gd
class_name Deck
extends Resource
var cards: Array[int] = []
var rng := RandomNumberGenerator.new()
func _init() -> void:
	rng.randomize()
	reset()
func reset() -> void:
	cards.clear()
	for i in range(52):
		cards.append(i)
	shuffle()
func shuffle() -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp
func draw_one() -> int:
	if cards.is_empty():
		push_warning("Deck empty, resetting.")
		reset()
	return cards.pop_back()

func draw_many(n: int) -> Array[int]:
	var out: Array[int] = []
	for _i in range(n):
		out.append(draw_one())
	return out
