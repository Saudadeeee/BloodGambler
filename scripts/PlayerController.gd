extends Node
class_name PlayerController

@export var ui_path: NodePath
var ui: BettingUI

func _ready() -> void:
	# Tìm UI theo ui_path, nếu chưa đặt thì thử tìm node con tên "BettingUI"
	ui = get_node_or_null(ui_path) as BettingUI
	if ui == null:
		ui = get_node_or_null("../BettingUI") as BettingUI
	if ui == null:
		ui = get_node_or_null("BettingUI") as BettingUI

	if ui == null:
		push_error("PlayerController: CHƯA gán ui_path đến BettingUI (nên game sẽ không chờ bạn bấm).")

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
	if ui == null:
		# ĐỪNG fallback tự động — báo lỗi rõ ràng để bạn biết đang thiếu UI
		push_error("PlayerController.ask_action: ui == null ⇒ chưa trỏ tới BettingUI. Dừng ván để bạn sửa.")
		await get_tree().create_timer(9999.0).timeout  # treo ở đây để bạn thấy lỗi
		return "check"  # chỉ là dòng “đề phòng”, thực tế sẽ không tới đây

	ui.prompt(street, need, bet_unit, can_raise, can_allin, can_cheat_flag)
	await ui.action_chosen
	return ui.get_choice()
