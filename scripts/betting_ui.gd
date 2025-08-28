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
	_cache_nodes()
	_connect_signals()
	visible = false


func _cache_nodes() -> void:
	var hb := get_node_or_null("%HBoxContainer") as HBoxContainer
	if hb == null:
		push_error("[BettingUI] Missing node: %HBoxContainer")
		visible = false
		return

	FoldButton      = hb.get_node_or_null("FoldButton") as Button
	CheckCallButton = hb.get_node_or_null("CheckCallButton") as Button
	RaiseButton     = hb.get_node_or_null("RaiseButton") as Button
	AllInButton     = hb.get_node_or_null("AllInButton") as Button
	CheatButton     = hb.get_node_or_null("CheatButton") as Button

	var missing := []
	if FoldButton == null:           missing.append("FoldButton")
	if CheckCallButton == null:      missing.append("CheckCallButton")
	if RaiseButton == null:          missing.append("RaiseButton")
	if AllInButton == null:          missing.append("AllInButton")
	if missing.size() > 0:
		push_error("[BettingUI] Missing required nodes: %s" % ", ".join(missing))
		visible = false

func _connect_signals() -> void:
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

func set_cheat_enabled(enabled: bool) -> void:
	if CheatButton:
		CheatButton.disabled = not enabled
		CheatButton.visible = enabled
		CheatButton.modulate = Color(1, 1, 1, (1.0 if enabled else 0.5))

func prompt(street: String, need: int, bet_size: int, can_raise: bool, can_allin: bool, can_cheat: bool=false) -> void:
	visible = true
	_choice = ""
	_need = need

	if InfoLabel:
		InfoLabel.text = "Street: %s | To call: %d | Bet: %d" % [street.capitalize(), need, bet_size]

	if FoldButton:
		FoldButton.disabled = false
	if CheckCallButton:
		CheckCallButton.disabled = false
		CheckCallButton.text = ("Check" if need == 0 else "Call (%d)" % need)
	if RaiseButton:
		RaiseButton.disabled = not can_raise
	if AllInButton:
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
