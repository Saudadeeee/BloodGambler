extends Node2D
class_name Dealer

# ---------- Config ----------
@export var card_scene: PackedScene
@export var board_spacing_px: float = 72.0
@export var hand_spacing_px: float = 48.0

# Kéo thả các node vị trí vào đây
@export var deck_spot_path: NodePath
@export var board_spot_path: NodePath
@export var p_spot_paths: Array[NodePath] = []   

# ---------- Scene refs ----------
var deck_spot: Node2D
var board_spot: Node2D
var p_spots: Array = []          

# ---------- State ----------
var deck: Deck = Deck.new()

var board_ids: Array[int] = []  
var board_cards: Array[Card] = []    
var board_revealed: int = 0    

func _ready() -> void:
	deck_spot = get_node(deck_spot_path) as Node2D
	board_spot = get_node(board_spot_path) as Node2D
	p_spots.clear()
	for p in p_spot_paths:
		var n := get_node_or_null(p) as Node2D
		if n != null:
			p_spots.append(n)


func clear_board() -> void:
	for c in board_cards:
		if is_instance_valid(c):
			c.queue_free()
	board_cards.clear()
	board_ids.clear()
	board_revealed = 0

func reset_all() -> void:
	deck.reset()
	clear_board()

func _board_pos(i: int) -> Vector2:
	# i 0..4
	var total_w := board_spacing_px * 4.0
	var base_x := -total_w * 0.5
	return board_spot.global_position + Vector2(base_x + float(i) * board_spacing_px, 0.0)

func _hand_pos_for(seat: int, index_in_hand: int, total_in_hand: int) -> Vector2:

	if seat < 0 or seat >= p_spots.size():
		return Vector2.ZERO
	var total_w := hand_spacing_px * float(max(total_in_hand - 1, 0))
	var base_x := -0.5 * total_w
	var x := base_x + float(index_in_hand) * hand_spacing_px
	return (p_spots[seat] as Node2D).global_position + Vector2(x, 0.0)

func _spawn_board_card(card_id: int, i: int) -> Card:
	var card := card_scene.instantiate() as Card
	add_child(card)         
	card.position = deck_spot.global_position
	card.set_card(card_id, false) 
	board_cards.append(card)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "position", _board_pos(i), 0.22)
	return card

func fly_card_to_hand(card_id: int, seat: int, index_in_hand: int, visual_total: int, face_up: bool) -> Card:
	if card_scene == null or deck_spot == null or p_spots.size() == 0:
		push_error("Dealer.fly_card_to_hand: thiếu scene/spot. Kiểm tra Inspector (card_scene, deck_spot_path, p_spot_paths).")
		return null

	var card := card_scene.instantiate() as Card
	add_child(card)
	card.position = deck_spot.global_position
	card.scale = Vector2(1, 1)
	card.set_card(card_id, false)  # úp

	var target := _hand_pos_for(seat, index_in_hand, max(visual_total, index_in_hand + 1))
	var tw := create_tween()
	tw.tween_property(card, "position", target, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished

	if face_up:
		await card.flip(true, 0.16)

	await get_tree().create_timer(0.06).timeout
	return card

func predeal_board_facedown() -> void:

	clear_board()

	deck.draw_one()
	var flop := deck.draw_many(3)

	deck.draw_one()
	var turn := deck.draw_one()
	# burn3 + river
	deck.draw_one()
	var river := deck.draw_one()

	board_ids.append_array([flop[0], flop[1], flop[2], turn, river])

	for i in range(5):
		_spawn_board_card(board_ids[i], i)
		await get_tree().process_frame
		await get_tree().create_timer(0.04).timeout

	board_revealed = 0

func reveal_flop() -> void:
	for i in range(3):
		await board_cards[i].flip(true, 0.16)
		await get_tree().create_timer(0.04).timeout
	board_revealed = 3

func reveal_turn() -> void:
	await board_cards[3].flip(true, 0.16)
	board_revealed = 4

func reveal_river() -> void:
	await board_cards[4].flip(true, 0.16)
	board_revealed = 5
