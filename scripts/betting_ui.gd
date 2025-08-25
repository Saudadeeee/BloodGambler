extends Control
class_name BettingUI

signal action_chosen

var InfoLabel: Label
var FoldButton: Button
var CheckCallButton: Button
var RaiseButton: Button
var AllInButton: Button

var _choice: String = ""
var _need: int = 0

func _ready() -> void:
	_wire_children_or_build()
	visible = false

func _wire_children_or_build() -> void:
	# Label
	InfoLabel = get_node_or_null("InfoLabel") as Label
	if InfoLabel == null:
		InfoLabel = Label.new()
		InfoLabel.name = "InfoLabel"
		InfoLabel.text = "Ready"
		add_child(InfoLabel)

	# HBox + Buttons
	var hb := get_node_or_null("HBoxContainer") as HBoxContainer
	if hb == null:
		hb = HBoxContainer.new()
		hb.name = "HBoxContainer"
		add_child(hb)

	FoldButton = hb.get_node_or_null("FoldButton") as Button
	if FoldButton == null:
		FoldButton = Button.new()
		FoldButton.name = "FoldButton"
		FoldButton.text = "Fold"
		hb.add_child(FoldButton)

	CheckCallButton = hb.get_node_or_null("CheckCallButton") as Button
	if CheckCallButton == null:
		CheckCallButton = Button.new()
		CheckCallButton.name = "CheckCallButton"
		CheckCallButton.text = "Check/Call"
		hb.add_child(CheckCallButton)

	RaiseButton = hb.get_node_or_null("RaiseButton") as Button
	if RaiseButton == null:
		RaiseButton = Button.new()
		RaiseButton.name = "RaiseButton"
		RaiseButton.text = "Raise"
		hb.add_child(RaiseButton)

	AllInButton = hb.get_node_or_null("AllInButton") as Button
	if AllInButton == null:
		AllInButton = Button.new()
		AllInButton.name = "AllInButton"
		AllInButton.text = "All-in"
		hb.add_child(AllInButton)

	# Connect signals (an toàn nếu connect nhiều lần)
	if not FoldButton.pressed.is_connected(_on_FoldButton_pressed):
		FoldButton.pressed.connect(_on_FoldButton_pressed)
	if not CheckCallButton.pressed.is_connected(_on_CheckCallButton_pressed):
		CheckCallButton.pressed.connect(_on_CheckCallButton_pressed)
	if not RaiseButton.pressed.is_connected(_on_RaiseButton_pressed):
		RaiseButton.pressed.connect(_on_RaiseButton_pressed)
	if not AllInButton.pressed.is_connected(_on_AllInButton_pressed):
		AllInButton.pressed.connect(_on_AllInButton_pressed)

func prompt(street: String, need: int, bet_size: int, can_raise: bool, can_allin: bool) -> void:
	visible = true
	_choice = ""
	_need = need
	InfoLabel.text = "Street: %s | To call: %d | Bet: %d" % [street.capitalize(), need, bet_size]
	FoldButton.disabled = false
	CheckCallButton.disabled = false
	CheckCallButton.text = ("Check" if need == 0 else "Call (%d)" % need)
	RaiseButton.disabled = not can_raise
	AllInButton.disabled = not can_allin

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
