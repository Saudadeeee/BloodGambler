# res://scripts/Main.gd
extends Node2D

@onready var table: Node2D = $Table

func _ready() -> void:
	# chạy ngay khi mở game (Table.gd đã tự deal + run_hand_with_board)
	pass

# Ví dụ phím R để chơi lại
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"): # Enter
		_restart_hand()

func _restart_hand() -> void:

	for c in table.get_children():
		
		pass
	# gọi lại quy trình (Table.gd của bạn đang tự _ready -> deal -> run_hand)
	table.call_deferred("_ready")  # đơn giản nhất cho demo
