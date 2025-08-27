extends Control
class_name HUD

@export var label_path: NodePath
var label: Label

func _ready() -> void:
	if label_path != NodePath():
		label = get_node(label_path) as Label

func show_status(street: String, pot: int, risk_pct: float, hp: Array) -> void:
	if label == null: return
	var hp_str := []
	for i in range(hp.size()):
		hp_str.append("P%d:%d" % [i, int(hp[i])])
	label.text = "Street: %s | Pot=%d | Risk=%.1f%% | %s" % [street.capitalize(), pot, risk_pct, ", ".join(hp_str)]
