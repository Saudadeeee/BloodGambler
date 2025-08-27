extends Node
class_name BotBrain


func decide_action(need: int, bet_unit: int, raises: int, max_raises: int, hp_seat: int, street: String) -> String:
	if need == 0:
		return "raise" if (randi() % 5 == 0 and raises < max_raises and hp_seat > bet_unit) else "check"
	else:
		if need >= bet_unit * 2 and (randi() % 4 == 0):
			return "fold"
		if raises < max_raises and (randi() % 6 == 0) and hp_seat > (need + bet_unit):
			return "raise"
		return "call"
