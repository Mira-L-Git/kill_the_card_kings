extends Control

signal card_clicked(card_id: String)

const CardView = preload("res://ui/card_view.gd")

const CARD_SIZE := Vector2(240, 336)
const CARD_STEP := 132.0
# 10° 步进对应的扇形圆心约在牌列下方 760 像素。
const FAN_CENTER := Vector2(1280, 1945)
const OUTWARD_OFFSET := 24.0
const DRAW_FLIGHT := 0.30
const DRAW_INTERVAL := 0.052
const DRAW_MARGIN := 0.035

var _layout_order: Array[CardView] = []
var _draw_tween: Tween


func _init() -> void:
	name = "HandView"
	mouse_filter = MOUSE_FILTER_IGNORE
	size = Vector2(2560, 1440)


func render(cards: Array, selected_ids: Array, clickable_ids: Array, guide: Dictionary = {}) -> void:
	cancel_draw()
	var ids: Array = cards.map(func(card): return card.id)
	_layout_order.clear()
	for child in get_children():
		if child.card_id not in ids:
			remove_child(child)
			child.queue_free()
	for i in range(cards.size()):
		var card: Dictionary = cards[i]
		var item := get_node_or_null(NodePath(card.id)) as CardView
		if item == null:
			item = CardView.new()
			add_child(item)
			item.pressed.connect(func(): card_clicked.emit(card.id))
			item.hand_moved.connect(_place_shadows)
		_layout_order.append(item)
		var cancel_target: bool = guide.is_empty() and not selected_ids.is_empty() and card.id not in clickable_ids
		var highlighted: bool = "hand" in guide.get("focus", []) or card.id in guide.get("cards", [])
		item.configure(card, card.id in selected_ids, card.id in clickable_ids, cancel_target, highlighted)
		var middle := (cards.size() - 1) / 2.0
		var t: float = (i - middle) / middle if middle > 0 else 0.0
		# 最大旋转后的最低角约为 1400，保留至少 32 像素。
		var card_position := Vector2(1280 + CARD_STEP * (i - middle), 1185 + 28 * t * t) - CARD_SIZE / 2
		var outward := (card_position + CARD_SIZE / 2 - FAN_CENTER).normalized() * OUTWARD_OFFSET
		item.set_hand_pose(card_position, 10 * t, outward)
	_place_shadows()


static func hold_for_step(step: Dictionary) -> float:
	if step.kind != "cards_drawn" or step.data.card_ids.is_empty():
		return 0.0
	return _draw_duration(step.data.card_ids.size()) + DRAW_MARGIN


static func _draw_duration(count: int) -> float:
	return DRAW_FLIGHT + (count - 1) * DRAW_INTERVAL


func is_drawing() -> bool:
	return _draw_tween != null


func play_draw(cards: Array, drawn_ids: Array, center: Vector2, duration_scale: float, remaining_changed: Callable) -> void:
	var before := {}
	for item in _layout_order:
		before[item.card_id] = Vector3(item.position.x, item.position.y, item.rotation_degrees)
	render(cards, [], [])
	var poses: Array[Dictionary] = []
	for item in _layout_order:
		item.stop_lift_for_draw()
		item.modulate = Color.WHITE
		var rest := Vector3(item.position.x, item.position.y, item.rotation_degrees)
		poses.append({"item": item, "target": rest, "start": before.get(item.card_id, rest), "launch": drawn_ids.find(item.card_id)})
	var duration := _draw_duration(drawn_ids.size())
	var rise := 124.0 if poses.size() == drawn_ids.size() else 94.0
	var animate := _draw_frame.bind(poses, drawn_ids.size(), center, rise, remaining_changed)
	_draw_tween = create_tween().set_ignore_time_scale(true).set_speed_scale(1.0 / duration_scale)
	animate.call(0.0)
	_draw_tween.tween_method(animate, 0.0, duration, duration)
	_draw_tween.finished.connect(func(): _draw_tween = null)


func cancel_draw() -> void:
	if _draw_tween == null:
		return
	_draw_tween.kill()
	_draw_tween = null
	for item in _layout_order:
		item.show()
		item.show_draw_back(false)
		item.scale = Vector2.ONE
		item.z_index = 0


func _draw_frame(age: float, poses: Array[Dictionary], count: int, origin: Vector2, rise: float, remaining_changed: Callable) -> void:
	var grounded: Array[CardView] = []
	var remaining := count
	for pose in poses:
		var item: CardView = pose.item
		var target: Vector3 = pose.target
		if pose.launch < 0:
			var start: Vector3 = pose.start
			var shifted := start.lerp(target, smoothstep(0.0, 0.26, age))
			item.position = Vector2(shifted.x, shifted.y)
			item.rotation_degrees = shifted.z
			grounded.append(item)
			continue
		var since_launch: float = age - pose.launch * DRAW_INTERVAL
		item.visible = since_launch >= 0.0
		if not item.visible:
			continue
		remaining -= 1
		var phase := 1.0 if since_launch >= DRAW_FLIGHT - 0.000001 else since_launch / DRAW_FLIGHT
		var travel := 1.0 - pow(1.0 - phase, 2.0)
		var turn := smoothstep(0.14, 0.68, phase) * PI
		var center := origin.lerp(Vector2(target.x, target.y) + CARD_SIZE / 2.0, travel)
		center.y -= sin(PI * travel) * rise
		item.position = center - CARD_SIZE / 2.0
		var zoom := lerpf(0.37, 1.0, smoothstep(0.04, 0.92, phase))
		item.scale = Vector2(maxf(0.045, absf(cos(turn))) * zoom, zoom)
		item.rotation_degrees = lerpf(-8.0, target.z, travel)
		item.show_draw_back(turn < PI * 0.5)
		item.z_index = 1 + int(pose.launch) if phase < 1.0 else 0
		if phase >= 1.0:
			grounded.append(item)
		else:
			item.clear_overlap_shadow()
	# 空中的牌独立绘制，叠压阴影只跟随已落位的牌。
	_update_shadows(grounded)
	remaining_changed.call(remaining)


func _place_shadows() -> void:
	_update_shadows(_layout_order)


func _update_shadows(order: Array[CardView]) -> void:
	for i in range(maxi(0, order.size() - 1)):
		var lower := order[i]
		var upper := order[i + 1]
		var lower_center: Vector2 = lower.position + lower.size / 2.0
		var upper_center: Vector2 = upper.position + upper.size / 2.0
		var relative_center: Vector2 = (upper_center - lower_center).rotated(-deg_to_rad(lower.rotation_degrees)) + lower.size / 2.0
		var relative_angle: float = deg_to_rad(upper.rotation_degrees - lower.rotation_degrees)
		lower.set_overlap_shadow(relative_center, upper.size, relative_angle, upper.get_card_outline())
	if not order.is_empty():
		order[-1].clear_overlap_shadow()
