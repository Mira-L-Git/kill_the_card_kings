extends Control

const CardView = preload("res://ui/card_view.gd")
const SUIT_ORDER := ["hearts", "diamonds", "clubs", "spades"]
const CARD_SCALE := 2.0 / 3.0
const GAP := 16.0
const FLY_IN := 0.22
const FLY_OUT := 0.29
const OUT_GAP := 0.05
const DIM := Color(0.43, 0.41, 0.46)

var _cards: Array = []
var _motion: Tween
var _shake: Tween


func _init() -> void:
	name = "PlayedCards"
	mouse_filter = MOUSE_FILTER_IGNORE
	size = Vector2(800, 224)


func show_cards(cards: Array) -> void:
	clear()
	_cards = _ordered(cards)
	var width := 240.0 * CARD_SCALE
	var total_width := _cards.size() * width + maxi(0, _cards.size() - 1) * GAP
	var start_x := maxf(0.0, (size.x - total_width) / 2.0)
	for i in range(_cards.size()):
		var item := CardView.new()
		item.configure(_cards[i], false, true)
		item.focus_mode = FOCUS_NONE
		item.mouse_filter = MOUSE_FILTER_IGNORE
		item.scale = Vector2.ONE * CARD_SCALE
		var center := Vector2(start_x + i * (width + GAP) + width / 2.0, 112.0)
		item.position = center - item.pivot_offset
		add_child(item)


func play_from_hand(cards: Array, hand: Control, duration_scale: float) -> void:
	show_cards(cards)
	var to_local := get_global_transform().affine_inverse()
	_motion = create_tween().set_ignore_time_scale(true).set_speed_scale(1.0 / duration_scale)
	_motion.set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for item: CardView in get_children():
		var source := hand.get_node_or_null(NodePath(item.card_id)) as CardView
		if source == null:
			continue
		var target := item.position
		var center := to_local * (source.get_global_transform() * source.pivot_offset)
		item.position = center - item.pivot_offset
		item.rotation_degrees = source.rotation_degrees
		item.scale = source.scale
		_motion.tween_property(item, "position", target, FLY_IN)
		_motion.tween_property(item, "rotation_degrees", 0.0, FLY_IN)
		_motion.tween_property(item, "scale", Vector2.ONE * CARD_SCALE, FLY_IN)


func shake_suit(suit: String, seconds: float, duration_scale: float) -> void:
	var group := _suit_cards(suit)
	if group.is_empty():
		return
	_shake = create_tween().set_ignore_time_scale(true).set_speed_scale(1.0 / duration_scale).set_parallel()
	for item in group:
		var origin := item.position
		_shake.tween_method(func(age: float):
			item.position = origin + Vector2(sin(age * TAU * 2.0) * (1.0 - age) * 12.0, 0.0)
		, 0.0, 1.0, seconds)


func resolve_suit(suit: String) -> void:
	for item in _suit_cards(suit):
		item.modulate = DIM


func _suit_cards(suit: String) -> Array[CardView]:
	var items: Array[CardView] = []
	for i in range(_cards.size()):
		if _cards[i].suit == suit:
			items.append(get_child(i) as CardView)
	return items


static func discard_duration(count: int) -> float:
	return FLY_OUT + OUT_GAP * maxi(0, count - 1)


func fly_to_discard(world_center: Vector2, duration_scale: float, count_changed: Callable) -> void:
	var destination := get_global_transform().affine_inverse() * world_center
	var poses: Array[Vector2] = []
	for item: CardView in get_children():
		poses.append(item.position + item.pivot_offset)
	var seconds := discard_duration(poses.size())
	var animate := _discard_frame.bind(poses, destination, count_changed)
	_motion = create_tween().set_ignore_time_scale(true).set_speed_scale(1.0 / duration_scale)
	_motion.tween_method(animate, 0.0, seconds + 0.00001, seconds)
	_motion.finished.connect(func():
		_motion = null
		clear()
	)


func _discard_frame(age: float, poses: Array[Vector2], destination: Vector2, count_changed: Callable) -> void:
	var arrived := 0
	for i in range(poses.size()):
		var item := get_child(i) as CardView
		var phase := clampf((age - i * OUT_GAP) / FLY_OUT, 0.0, 1.0)
		var travel := phase * phase
		var turn := smoothstep(0.02, 0.64, phase) * PI
		var center := poses[i].lerp(destination, travel) - Vector2(0.0, sin(PI * travel) * 70.0)
		item.position = center - item.pivot_offset
		var zoom := lerpf(CARD_SCALE, 0.34, travel)
		item.scale = Vector2(zoom * maxf(0.04, absf(cos(turn))), zoom)
		item.show_draw_back(turn >= PI * 0.5)
		if turn >= PI * 0.5:
			item.modulate = Color.WHITE
		item.visible = phase < 1.0
		if not item.visible:
			arrived += 1
	count_changed.call(arrived)


func clear() -> void:
	if _motion != null:
		_motion.kill()
		_motion = null
	if _shake != null:
		_shake.kill()
		_shake = null
	_cards.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()


func has_visible_cards() -> bool:
	return not _cards.is_empty()


func visible_card_ids() -> Array:
	return _cards.map(func(card): return card.id)


func _ordered(cards: Array) -> Array:
	var indexed: Array = []
	for i in range(cards.size()):
		indexed.append({"card": cards[i].duplicate(true), "index": i})
	indexed.sort_custom(func(a, b):
		var suit_a: int = SUIT_ORDER.find(a.card.suit)
		var suit_b: int = SUIT_ORDER.find(b.card.suit)
		if suit_a != suit_b:
			return suit_a < suit_b
		# 同花色时主牌在前，宠物 A 居后。
		var pet_a: int = 1 if a.card.rank == 1 else 0
		var pet_b: int = 1 if b.card.rank == 1 else 0
		if pet_a != pet_b:
			return pet_a < pet_b
		return a.index < b.index
	)
	return indexed.map(func(entry): return entry.card)
