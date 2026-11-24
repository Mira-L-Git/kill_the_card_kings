extends Button

signal hand_moved

const Style = preload("res://ui/ui_style.gd")
const HandShadow = preload("res://ui/hand_shadow.gd")
const CardOutline = preload("res://ui/card_outline.gd")
const CardBack = preload("res://ui/card_back.gd")

const SUIT_ART := {
	"hearts": "hearts/红桃",
	"diamonds": "diamonds/方片",
	"clubs": "clubs/梅花",
	"spades": "spades/黑桃",
}
const RANK_ART := {1: "A", 11: "J", 12: "Q", 13: "K"}
const LIFT_SECONDS := 0.14
const FRAME_FADE_SECONDS := 0.18
static var _art_cache: Dictionary = {}

var card_id := ""
var _rank: Label
var _suit: Label
var _art: TextureRect
var _shadow: HandShadow
var _frame: Control
var _back: CardBack
var _outline := PackedVector2Array()
var _selected := false
var _can_hover := false
var _pointer_over := false
var _hand_origin := Vector2.ZERO
var _hand_offset := Vector2.ZERO
var _lift_amount := 0.0
var _lift_target := 0.0
var _lift_tween: Tween
var _frame_tween: Tween


func _init() -> void:
	_art = TextureRect.new()
	_art.name = "Art"
	_art.position = Vector2.ZERO
	_art.size = Vector2(240, 336)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.visible = false
	add_child(_art)
	_shadow = HandShadow.new()
	_shadow.visible = false
	add_child(_shadow)
	_frame = Control.new()
	_frame.name = "SelectionFrame"
	_frame.position = Vector2.ZERO
	_frame.size = Vector2(240, 336)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_selection_frame)
	_frame.visible = false
	add_child(_frame)
	_rank = Style.label(self, "Rank", "", Rect2(18, 16, 200, 64), 32)
	_suit = Style.label(self, "Suit", "", Rect2(18, 84, 200, 64), 28)
	clip_contents = true
	mouse_entered.connect(_set_pointer_over.bind(true))
	mouse_exited.connect(_set_pointer_over.bind(false))


func _has_point(point: Vector2) -> bool:
	var bounds := Rect2(Vector2.ZERO, size)
	if bounds.has_point(point):
		return true
	# 悬停时保留原位命中，防止上移动画把静止的鼠标甩出底边。
	if not _pointer_over or not _can_hover or _hand_offset.is_zero_approx():
		return false
	var original_point := point + (position - _hand_origin).rotated(-rotation)
	return bounds.has_point(original_point)


func set_hand_pose(origin: Vector2, angle: float, offset: Vector2) -> void:
	_hand_origin = origin
	_hand_offset = offset
	rotation_degrees = angle
	position = _hand_origin + _hand_offset * _lift_amount
	_update_lift()


func _set_pointer_over(over: bool) -> void:
	_pointer_over = over
	_update_lift()


func _update_lift() -> void:
	if _hand_offset.is_zero_approx() or not is_inside_tree():
		return
	var target := 1.0 if _selected or (_pointer_over and _can_hover) else 0.0
	if target == _lift_target:
		return
	_lift_target = target
	if _lift_tween != null:
		_lift_tween.kill()
	_lift_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_lift_tween.tween_method(_apply_lift, _lift_amount, target, LIFT_SECONDS)


func _apply_lift(amount: float) -> void:
	_lift_amount = amount
	position = _hand_origin + _hand_offset * amount
	hand_moved.emit()


func stop_lift_for_draw() -> void:
	if _lift_tween != null:
		_lift_tween.kill()
	_lift_amount = 0.0
	_lift_target = 0.0
	position = _hand_origin


func show_draw_back(show_back: bool) -> void:
	if _back == null:
		if not show_back:
			return
		_back = CardBack.new()
		_back.name = "Back"
		add_child(_back)
	_back.visible = show_back
	var has_art := _art.texture != null
	_art.visible = has_art and not show_back
	_rank.visible = not has_art and not show_back
	_suit.visible = not has_art and not show_back


func _draw() -> void:
	if not _outline.is_empty():
		draw_colored_polygon(_outline, Color.WHITE)


func _draw_selection_frame() -> void:
	if _outline.is_empty():
		return
	var closed := _outline.duplicate()
	closed.append(_outline[0])
	# 描边跨在轮廓上，外侧一半由同一轮廓裁掉。
	_frame.draw_polyline(closed, Color("a5ddf5"), 10.0, true)


func _set_selection_frame(show_frame: bool) -> void:
	if _frame.visible == show_frame:
		return
	if _frame_tween != null:
		_frame_tween.kill()
	_frame.modulate.a = 0.0
	_frame.visible = show_frame
	if not show_frame:
		return
	if not is_inside_tree():
		_frame.modulate.a = 1.0
		return
	_frame_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_frame_tween.tween_property(_frame, "modulate:a", 1.0, FRAME_FADE_SECONDS)


static func art_path(card: Dictionary) -> String:
	var prefix: String = SUIT_ART.get(card.get("suit", ""), "")
	if prefix.is_empty():
		return ""
	var rank: String = RANK_ART.get(card.get("rank", 0), str(card.get("rank", 0)))
	return "res://assets/cards/%s%s.png" % [prefix, rank]


static func _load_art(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _art_cache.has(path):
		return _art_cache[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	if texture != null:
		_art_cache[path] = texture
	return texture


func configure(card: Dictionary, selected: bool, clickable: bool, cancel_target: bool = false, highlighted: bool = false) -> void:
	card_id = card.id
	name = card.id
	_selected = selected
	_can_hover = clickable
	size = Vector2(240, 336)
	pivot_offset = size / 2
	disabled = not (clickable or cancel_target)
	focus_mode = Control.FOCUS_ALL if clickable else Control.FOCUS_NONE
	text = ""
	var texture := _load_art(art_path(card))
	var has_art := texture != null
	_art.texture = texture
	_art.visible = has_art
	# 一次裁切牌面、叠压阴影和选中描边，保留矩形点击区。
	var outline: Array = CardOutline.GENERAL if card.rank >= 11 else CardOutline.STANDARD
	_outline = PackedVector2Array(outline) if has_art else PackedVector2Array()
	clip_children = CLIP_CHILDREN_ONLY if has_art else CLIP_CHILDREN_DISABLED
	queue_redraw()
	_frame.queue_redraw()
	_rank.visible = not has_art
	_suit.visible = not has_art
	_set_selection_frame(has_art and selected)
	_rank.text = Style.rank_text(card.rank)
	_suit.text = Style.SUITS[card.suit]
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	var ink := Color("9c293c") if card.suit in ["hearts", "diamonds"] else Color("242633")
	_rank.modulate = ink
	_suit.modulate = ink
	add_theme_font_size_override("font_size", 32)
	add_theme_color_override("font_color", ink)
	add_theme_color_override("font_hover_color", ink)
	add_theme_color_override("font_pressed_color", ink)
	add_theme_color_override("font_disabled_color", ink)
	var border := Color("a5ddf5") if selected else Color("606575")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		if has_art:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		else:
			add_theme_stylebox_override(state, Style.box(Style.PAPER, border, 5 if selected else 2))
	modulate = Color.WHITE if clickable or selected or highlighted else Color(0.48, 0.48, 0.48)
	accessibility_name = "%s %s" % [Style.SUITS[card.suit], Style.rank_text(card.rank)]


func get_card_outline() -> PackedVector2Array:
	return _outline


func set_overlap_shadow(upper_center: Vector2, upper_size: Vector2, upper_angle: float, upper_outline: PackedVector2Array) -> void:
	_shadow.set_upper(upper_center, upper_size, upper_angle, upper_outline)


func clear_overlap_shadow() -> void:
	_shadow.clear()
