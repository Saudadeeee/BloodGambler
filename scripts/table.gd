# res://scripts/Table.gd
extends Node2D

@export var players: int = 4
@export var card_scene: PackedScene
@export var deal_face_up_for_player0: bool = true

@onready var deck_spot: Node2D = $DeckSpot
@onready var p_spots: Array[Node2D] = [$P0Spot, $P1Spot, $P2Spot, $P3Spot]

@export var bet_small: int = 4     # preflop, flop
@export var bet_big: int = 8       # turn, river
@export var max_raises: int = 3

@export var board_spacing_px: float = 72.0
@onready var board_spot: Node2D = $BoardSpot
@export var predeal_board_facedown: bool = true   # BẬT: chia sẵn 5 lá úp, lật theo street

var board_ids: Array[int] = []       # id 5 lá board
var board_cards: Array[Card] = []    # node Card 5 lá trên bàn
var deck: Deck = Deck.new()

# ------------------------------------------------------
# HOLE CARDS
# ------------------------------------------------------
func deal_opening_hole_cards() -> void:
	deck.reset()
	var rounds: int = 2
	for r in range(rounds):
		for seat in range(players):
			var card_id: int = deck.draw_one()
			var face_up: bool = deal_face_up_for_player0 and (seat == 0)
			await _spawn_and_fly(card_id, seat, r, face_up)

func _spawn_and_fly(card_id: int, seat: int, r_index: int, face_up: bool) -> void:
	if card_scene == null:
		push_error("Chưa gán card_scene (Card.tscn) cho Table.")
		return
	var spot: Node2D = p_spots[seat]

	var card: Card = card_scene.instantiate() as Card
	add_child(card)
	card.position = deck_spot.global_position
	card.scale = Vector2(1, 1)
	card.set_card(card_id, false)   # tạo úp trước

	var offset: Vector2 = Vector2(48.0 * float(r_index), 0.0)
	var target: Vector2 = spot.global_position + offset

	var tw: Tween = create_tween()
	tw.tween_property(card, "position", target, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished

	if face_up:
		await card.flip(true, 0.16)

	await get_tree().create_timer(0.06).timeout

# ------------------------------------------------------
# BOARD LAYOUT + SPAWN
# ------------------------------------------------------
func _board_pos(i: int) -> Vector2:
	# i: 0..4
	var total_w: float = board_spacing_px * 4.0
	var base_x: float = -total_w * 0.5
	return board_spot.global_position + Vector2(base_x + float(i) * board_spacing_px, 0.0)

func _spawn_board_card(card_id: int, i: int) -> Card:
	var card: Card = card_scene.instantiate() as Card
	add_child(card)
	card.position = deck_spot.global_position
	card.set_card(card_id, false) # úp
	board_cards.append(card)
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "position", _board_pos(i), 0.22)
	return card

# ------------------------------------------------------
# PREDEAL 5 LÁ ÚP + REVEAL THEO STREET
# ------------------------------------------------------
func _predeal_board_facedown() -> void:
	board_ids.clear()
	board_cards.clear()

	# burn1 + flop(3)
	deck.draw_one()                            # burn 1
	var flop: Array[int] = deck.draw_many(3)

	# burn2 + turn(1)
	deck.draw_one()                            # burn 2
	var turn: int = deck.draw_one()

	# burn3 + river(1)
	deck.draw_one()                            # burn 3
	var river: int = deck.draw_one()

	board_ids.append_array([flop[0], flop[1], flop[2], turn, river])

	# Spawn 5 lá úp sẵn
	for i in range(5):
		_spawn_board_card(board_ids[i], i)
		await get_tree().process_frame
		await get_tree().create_timer(0.04).timeout

func _reveal_flop() -> void:
	for i in range(3):
		await board_cards[i].flip(true, 0.16)
		await get_tree().create_timer(0.04).timeout

func _reveal_turn() -> void:
	await board_cards[3].flip(true, 0.16)

func _reveal_river() -> void:
	await board_cards[4].flip(true, 0.16)

# ------------------------------------------------------
# CÁC HÀNH VI CŨ (fallback nếu tắt predeal)
# ------------------------------------------------------
func _burn_one() -> void:
	deck.draw_one()

func _deal_flop() -> void:
	board_ids.clear()
	board_cards.clear()
	_burn_one()
	var three: Array[int] = deck.draw_many(3)
	for i in range(3):
		board_ids.append(three[i])
		_spawn_board_card(three[i], i)
		await get_tree().process_frame
	for i in range(3):
		await board_cards[i].flip(true, 0.16)
		await get_tree().create_timer(0.04).timeout

func _deal_turn() -> void:
	_burn_one()
	var id: int = deck.draw_one()
	board_ids.append(id)
	var c: Card = _spawn_board_card(id, 3)
	await get_tree().process_frame
	await c.flip(true, 0.16)

func _deal_river() -> void:
	_burn_one()
	var id: int = deck.draw_one()
	board_ids.append(id)
	var c: Card = _spawn_board_card(id, 4)
	await get_tree().process_frame
	await c.flip(true, 0.16)

# ------------------------------------------------------
# UI / BOT / BET ROUND (đơn giản)
# ------------------------------------------------------
func _ask_player_action(street: String, need: int, bet_unit: int, can_raise: bool, can_allin: bool) -> String:
	if has_node("BettingUI"):
		var ui: BettingUI = $BettingUI as BettingUI
		ui.prompt(street, need, bet_unit, can_raise, can_allin)
		await ui.action_chosen
		return String(ui.get_choice())
	if need == 0:
		return "check"
	else:
		return "call"

func _bot_action(need: int, bet_unit: int, raises: int) -> String:
	if need == 0:
		if (randi() % 5 == 0 and raises < max_raises):
			return "raise"
		else:
			return "check"
	else:
		if need >= bet_unit * 2 and (randi() % 4 == 0):
			return "fold"
		if raises < max_raises and (randi() % 6 == 0):
			return "raise"
		return "call"

func _bet_round(active_seats: Array[int], street: String, bet_unit: int) -> bool:
	if active_seats.size() <= 1:
		return true
	var contrib: Dictionary = {}
	for s in active_seats:
		contrib[s] = 0
	var to_call: int = 0
	var raises: int = 0
	var players_to_act: int = active_seats.size()
	var idx: int = 0

	while true:
		if active_seats.size() <= 1:
			return true
		var seat: int = active_seats[idx]
		var need: int = to_call - int(contrib[seat])
		if need < 0:
			need = 0

		var can_raise: bool = (raises < max_raises)
		var act: String = ""
		if seat == 0:
			act = await _ask_player_action(street, need, bet_unit, can_raise, true)
		else:
			act = _bot_action(need, bet_unit, raises)

		var advance_idx: bool = true

		match act:
			"fold":
				active_seats.erase(seat)
				players_to_act = max(players_to_act - 1, 0)
				advance_idx = false
				if active_seats.size() <= 1:
					return true
				if idx >= active_seats.size():
					idx = 0
			"check":
				if need != 0:
					act = "call"
					continue
				players_to_act -= 1
			"call":
				var pay: int = min(need, 999999)
				players_to_act -= 1
			"raise":
				if raises >= max_raises:
					act = "call"
					continue
				var pay_need: int = need
				var add: int = bet_unit
				to_call += (pay_need + add)
				raises += 1
				players_to_act = active_seats.size() - 1
			_:
				var pay2: int = min(need, 999999)
				players_to_act -= 1

		if players_to_act <= 0:
			break
		if advance_idx:
			idx = (idx + 1) % active_seats.size()

	return false

# ------------------------------------------------------
# FLOW 1 VÁN
# ------------------------------------------------------
func run_hand_with_board() -> void:
	var active: Array[int] = []
	var total_players: int = players
	for s in range(total_players):
		active.append(s)

	# PRE-FLOP: chia sẵn 5 lá úp nếu bật cờ
	if predeal_board_facedown:
		await _predeal_board_facedown()

	var ended: bool = await _bet_round(active, "preflop", bet_small)
	if ended:
		return

	# FLOP
	if predeal_board_facedown:
		await _reveal_flop()
	else:
		await _deal_flop()
	ended = await _bet_round(active, "flop", bet_small)
	if ended:
		return

	# TURN
	if predeal_board_facedown:
		await _reveal_turn()
	else:
		await _deal_turn()
	ended = await _bet_round(active, "turn", bet_big)
	if ended:
		return

	# RIVER
	if predeal_board_facedown:
		await _reveal_river()
	else:
		await _deal_river()
	ended = await _bet_round(active, "river", bet_big)
	if ended:
		return
	# SHOWDOWN: (để sau)

# ------------------------------------------------------
# READY
# ------------------------------------------------------
func _ready() -> void:
	if p_spots.size() < players:
		push_error("Thiếu Node P#Spot so với số người chơi.")
		return
	await deal_opening_hole_cards()
	await run_hand_with_board()
