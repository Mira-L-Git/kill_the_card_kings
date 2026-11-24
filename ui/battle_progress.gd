extends Control

const RANK_ART = preload("res://assets/ui-art/battle-progress/ranks.svg")
const SUIT_ORDER := ["hearts", "diamonds", "clubs", "spades"]
const SUIT_NAMES := ["红桃", "方片", "梅花", "黑桃"]
const SUIT_ART := [
	preload("res://assets/ui-art/battle-progress/hearts.svg"),
	preload("res://assets/ui-art/battle-progress/diamonds.svg"),
	preload("res://assets/ui-art/battle-progress/clubs.svg"),
	preload("res://assets/ui-art/battle-progress/spades.svg"),
]
const RANK_CELL := 72
const LAST_FRACTURE_HOLD := 0.20
const FADE_OUT := 0.14
const FADE_IN := 0.18

var _glyph: TextureRect
var _seals: Array[SuitSeal] = []
var _rank := 0
var _target_rank := 11
var _target_suits: Array = []
var _rank_tween: Tween


func _init() -> void:
	name = "Progress"
	size = Vector2(388, 74)
	mouse_filter = MOUSE_FILTER_IGNORE
	_glyph = TextureRect.new()
	_glyph.name = "Rank"
	_glyph.mouse_filter = MOUSE_FILTER_IGNORE
	_glyph.size = Vector2(RANK_CELL, RANK_CELL)
	add_child(_glyph)
	for i in range(SUIT_ORDER.size()):
		var seal := SuitSeal.new(SUIT_ART[i], SUIT_NAMES[i])
		seal.name = SUIT_ORDER[i]
		seal.position = Vector2(88 + i * 74, 4)
		add_child(seal)
		_seals.append(seal)


func reset() -> void:
	if _rank_tween != null:
		_rank_tween.kill()
		_rank_tween = null
	_rank = 0
	_target_suits = []
	_glyph.modulate.a = 1.0
	for seal in _seals:
		seal.set_broken(false, false)


func present(rank: int, defeated_suits: Array) -> void:
	_target_rank = rank
	_target_suits = defeated_suits
	if _rank_tween != null:
		if _rank == _target_rank:
			_update_suits(true)
		return
	if _rank == rank:
		_update_suits(true)
	elif rank == _rank + 1 and _seals.all(func(seal): return seal.broken):
		_switch_rank()
	else:
		_show_target_rank(false)


func _update_suits(animated: bool) -> void:
	for i in range(SUIT_ORDER.size()):
		_seals[i].set_broken(SUIT_ORDER[i] in _target_suits, animated)


func _show_target_rank(animated: bool) -> void:
	_rank = _target_rank
	var art := AtlasTexture.new()
	art.atlas = RANK_ART
	art.region = Rect2((_rank - 11) * RANK_CELL, 0, RANK_CELL, RANK_CELL)
	art.filter_clip = true
	_glyph.texture = art
	_glyph.accessibility_name = ["J", "Q", "K"][_rank - 11]
	for seal in _seals:
		seal.set_broken(false, false)
	_update_suits(animated)


func _switch_rank() -> void:
	# 第四枚裂开后短暂停留，旧字母全暗时才换字母并重置花色。
	_rank_tween = create_tween()
	_rank_tween.tween_interval(LAST_FRACTURE_HOLD)
	_rank_tween.tween_property(_glyph, "modulate:a", 0.0, FADE_OUT)
	_rank_tween.tween_callback(_show_target_rank.bind(true))
	_rank_tween.tween_property(_glyph, "modulate:a", 1.0, FADE_IN)
	_rank_tween.finished.connect(_on_switch_finished)


func _on_switch_finished() -> void:
	_rank_tween = null
	present(_target_rank, _target_suits)


class SuitSeal extends Control:
	const CELL := 64
	const FRACTURE_SECONDS := 0.22
	const SETTLED_COLOR := Color(0.83, 0.80, 0.79)

	var broken := false
	var _suit_label: String
	var _whole: TextureRect
	var _pieces: Array[TextureRect] = []
	var _tween: Tween

	func _init(atlas: Texture2D, suit_label: String) -> void:
		_suit_label = suit_label
		accessibility_name = _suit_label + "未击破"
		size = Vector2(CELL, CELL)
		mouse_filter = MOUSE_FILTER_IGNORE
		_whole = _make_cell(atlas, 0, "Intact")
		_pieces = [_make_cell(atlas, 1, "LeftPiece"), _make_cell(atlas, 2, "RightPiece")]
		for piece in _pieces:
			piece.hide()

	func _make_cell(atlas: Texture2D, index: int, node_name: String) -> TextureRect:
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(index * CELL, 0, CELL, CELL)
		texture.filter_clip = true
		var cell := TextureRect.new()
		cell.name = node_name
		cell.texture = texture
		cell.size = Vector2(CELL, CELL)
		cell.pivot_offset = cell.size / 2.0
		cell.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(cell)
		return cell

	func set_broken(is_broken: bool, animated: bool) -> void:
		if broken == is_broken:
			return
		broken = is_broken
		accessibility_name = _suit_label + ("已击破" if broken else "未击破")
		if _tween != null:
			_tween.kill()
		_whole.visible = not broken
		if broken and animated:
			_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		for i in range(_pieces.size()):
			var piece := _pieces[i]
			piece.visible = broken
			if not broken:
				continue
			var direction := -1.0 if i == 0 else 1.0
			var rest := Vector2(4.5, 1.8) * direction
			var angle := 6.0 * direction
			if animated:
				piece.position = Vector2.ZERO
				piece.rotation_degrees = 0.0
				piece.modulate = Color(1.5, 1.38, 1.30)
				_tween.tween_property(piece, "position", rest, FRACTURE_SECONDS)
				_tween.tween_property(piece, "rotation_degrees", angle, FRACTURE_SECONDS)
				_tween.tween_property(piece, "modulate", SETTLED_COLOR, FRACTURE_SECONDS)
			else:
				piece.position = rest
				piece.rotation_degrees = angle
				piece.modulate = SETTLED_COLOR
