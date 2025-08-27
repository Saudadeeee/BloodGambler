# res://scripts/Card.gd
extends Node2D
class_name Card

@export var back_texture: Texture2D              
@export var assets_base_dir := "res://assets/card_deck"  
@onready var sprite: Sprite2D = $Sprite

var _card_id := -1
var _face_up := false

func set_card(id: int, face_up: bool) -> void:
	_card_id = id
	_face_up = face_up
	_update_texture()

func flip(to_face_up: bool, duration := 0.18) -> void:
	if _face_up == to_face_up:
		return
	var tw := create_tween()
	tw.tween_property(self, "scale:x", 0.0, duration * 0.5)
	await tw.finished
	_face_up = to_face_up
	_update_texture()
	var tw2 := create_tween()
	tw2.tween_property(self, "scale:x", 1.0, duration * 0.5)

func _update_texture() -> void:
	if not _face_up:
		sprite.texture = back_texture
		return
	var path := CardUtils.texture_path_for(_card_id, assets_base_dir)
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	else:
		push_error("Không tìm thấy ảnh lá bài: %s" % path)
