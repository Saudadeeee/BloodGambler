extends Control
class_name BettingUI

signal action_chosen

var InfoLabel: Label
var FoldButton: Button
var CheckCallButton: Button
var RaiseButton: Button
var AllInButton: Button
var CheatButton: Button

var _choice: String = ""
var _need: int = 0

func _ready() -> void:
	_wire_children_or_build()
	visible = false

func _wire_children_or_build() -> void:
	# ===== TÌM NODE THEO TÊN Ở MỌI CẤP CON (KHÔNG TẠO TRÙNG) =====
	# Label
	InfoLabel = find_child("InfoLabel", true, false) as Label
	if InfoLabel == null:
		InfoLabel = Label.new()
		InfoLabel.name = "InfoLabel"
		InfoLabel.text = "Ready"
		add_child(InfoLabel)

	# HBox
	var hb := find_child("HBoxContainer", true, false) as HBoxContainer
	if hb == null:
		hb = HBoxContainer.new()
		hb.name = "HBoxContainer"
		add_child(hb)

	# Buttons (chỉ tạo nếu KHÔNG tìm thấy ở đâu trong cây con)
	FoldButton = find_child("FoldButton", true, false) as Button
	if FoldButton == null:
		FoldButton = Button.new()
		FoldButton.name = "FoldButton"
		FoldButton.text = "Fold"
		hb.add_child(FoldButton)

	CheckCallButton = find_child("CheckCallButton", true, false) as Button
	if CheckCallButton == null:
		CheckCallButton = Button.new()
		CheckCallButton.name = "CheckCallButton"
		CheckCallButton.text = "Check/Call"
		hb.add_child(CheckCallButton)

	RaiseButton = find_child("RaiseButton", true, false) as Button
	if RaiseButton == null:
		RaiseButton = Button.new()
		RaiseButton.name = "RaiseButton"
		RaiseButton.text = "Raise"
		hb.add_child(RaiseButton)

	AllInButton = find_child("AllInButton", true, false) as Button
	if AllInButton == null:
		AllInButton = Button.new()
		AllInButton.name = "AllInButton"
		AllInButton.text = "All-in"
		hb.add_child(AllInButton)

	CheatButton = find_child("CheatButton", true, false) as Button
	if CheatButton == null:
		CheatButton = Button.new()
		CheatButton.name = "CheatButton"
		CheatButton.text = "Cheat"
		hb.add_child(CheatButton)

	# ===== KẾT NỐI TÍN HIỆU (AN TOÀN KHI GỌI NHIỀU LẦN) =====
	if FoldButton and not FoldButton.pressed.is_connected(_on_FoldButton_pressed):
		FoldButton.pressed.connect(_on_FoldButton_pressed)
	if CheckCallButton and not CheckCallButton.pressed.is_connected(_on_CheckCallButton_pressed):
		CheckCallButton.pressed.connect(_on_CheckCallButton_pressed)
	if RaiseButton and not RaiseButton.pressed.is_connected(_on_RaiseButton_pressed):
		RaiseButton.pressed.connect(_on_RaiseButton_pressed)
	if AllInButton and not AllInButton.pressed.is_connected(_on_AllInButton_pressed):
		AllInButton.pressed.connect(_on_AllInButton_pressed)
	if CheatButton and not CheatButton.pressed.is_connected(_on_CheatButton_pressed):
		CheatButton.pressed.connect(_on_CheatButton_pressed)

# Bật/tắt nút Cheat từ Table/PlayerController
func set_cheat_enabled(enabled: bool) -> void:
	if CheatButton:
		CheatButton.disabled = not enabled
		# hiệu ứng mờ khi disable (tuỳ thích)
		CheatButton.modulate = Color(1, 1, 1, 1.0 if enabled else 0.5)
func prompt(street: String, need: int, bet_size: int, can_raise: bool, can_allin: bool, can_cheat: bool=false) -> void:
	visible = true
	_choice = ""
	_need = need
	InfoLabel.text = "Street: %s | To call: %d | Bet: %d" % [street.capitalize(), need, bet_size]
	FoldButton.disabled = false
	CheckCallButton.disabled = false
	CheckCallButton.text = ("Check" if need == 0 else "Call (%d)" % need)
	RaiseButton.disabled = not can_raise
	AllInButton.disabled = not can_allin
	if CheatButton:
		CheatButton.visible = can_cheat
		CheatButton.disabled = not can_cheat


func get_choice() -> String:
	return _choice

func _emit(choice: String) -> void:
	_choice = choice
	visible = false
	action_chosen.emit()

func _on_FoldButton_pressed() -> void:
	_emit("fold")

func _on_CheckCallButton_pressed() -> void:
	_emit("check" if _need == 0 else "call")

func _on_RaiseButton_pressed() -> void:
	_emit("raise")

func _on_AllInButton_pressed() -> void:
	_emit("allin")

func _on_CheatButton_pressed() -> void:
	_emit("cheat")
