extends Node
class_name PlayerController

@export var ui_path: NodePath
var ui: BettingUI

func _ready() -> void:

	ui = get_node_or_null(ui_path) as BettingUI
func can_cheat(street: String, board_revealed: int) -> bool:
	return street == "flop" and board_revealed == 3

func ask_action(
	street: String,
	need: int,
	bet_unit: int,
	can_raise: bool,
	can_allin: bool,
	can_cheat_flag: bool
) -> String:
	ui.prompt(street, need, bet_unit, can_raise, can_allin, can_cheat_flag)
	await ui.action_chosen
	return ui.get_choice()
