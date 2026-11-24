extends Node2D

const REAPER := preload("res://assets/effects/grim-reaper.png")
const SLASH := preload("res://ui/player_defeat_slash.gdshader")
const REVEAL_TIME := 0.64
const EYES_TIME := 0.18
const EYES_HOLD := 0.25
const SLASH_TIME := 0.56
const PORTRAIT_SIZE := Vector2(492, 738)
const EYE_POSITIONS := [Vector2(344, 168), Vector2(374, 172)]

var _field: Rect2
var _portrait: Rect2
var _duration_scale: float
var _motion: Tween
var _slash: ColorRect
var _slash_material: ShaderMaterial
var _reveal := 0.0
var _eyes := 0.0
var _cut_age := 0.0


func _init(field_size: Vector2, resolution_center: Vector2, duration_scale: float) -> void:
	name = "PlayerDefeat"
	_field = Rect2(Vector2.ZERO, field_size)
	_duration_scale = duration_scale
	# 按可见部分定位，整体从结算区中心略向左移。
	var portrait_anchor := PORTRAIT_SIZE * Vector2(0.436, 0.5)
	_portrait = Rect2(resolution_center - portrait_anchor - Vector2(48, 10), PORTRAIT_SIZE)
	texture_filter = TEXTURE_FILTER_NEAREST
	_slash_material = ShaderMaterial.new()
	_slash_material.shader = SLASH
	_slash_material.set_shader_parameter("field_size", field_size)
	_slash = ColorRect.new()
	_slash.name = "Slash"
	_slash.size = field_size
	_slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slash.material = _slash_material
	add_child(_slash)
	reset()


static func hold_for_step(step: Dictionary) -> float:
	if step.kind == "run_lost" and step.data.context == "defense":
		# 留一帧余量，确保动效先收尾再切入结果。
		return REVEAL_TIME + EYES_TIME + EYES_HOLD + SLASH_TIME + 0.08
	return 0.0


func play() -> void:
	var beat := _start_reveal()
	beat.tween_method(_eyes_frame, 0.0, 1.0, EYES_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	beat.tween_interval(EYES_HOLD)
	beat.tween_callback(_slash.show)
	beat.tween_method(_slash_frame, 0.0, 1.0, SLASH_TIME)
	beat.tween_callback(_slash.hide)


func play_revival(hold_after_reveal: float, fade_seconds: float) -> void:
	var beat := _start_reveal()
	beat.tween_method(_eyes_frame, 0.0, 1.0, EYES_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	beat.tween_interval(hold_after_reveal - EYES_TIME)
	beat.tween_method(_reveal_frame, 1.0, 0.0, fade_seconds).set_trans(Tween.TRANS_SINE)
	beat.tween_callback(hide)


func _start_reveal() -> Tween:
	reset()
	show()
	_motion = create_tween().set_ignore_time_scale(true).set_speed_scale(1.0 / _duration_scale)
	_motion.tween_method(_reveal_frame, 0.0, 1.0, REVEAL_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	return _motion


func reset() -> void:
	if _motion != null:
		_motion.kill()
		_motion = null
	_reveal = 0.0
	_eyes = 0.0
	_cut_age = 0.0
	_slash_frame(0.0)
	_slash.hide()
	hide()


func _reveal_frame(value: float) -> void:
	_reveal = value
	queue_redraw()


func _eyes_frame(value: float) -> void:
	_eyes = value
	queue_redraw()


func _slash_frame(value: float) -> void:
	_cut_age = value
	_slash_material.set_shader_parameter("age", value)
	queue_redraw()


func _draw() -> void:
	if _reveal <= 0.0:
		return
	draw_rect(_field, Color(0.024, 0.016, 0.044, _reveal * lerpf(0.30, 0.66, _cut_age)))
	var portrait_alpha := _reveal * (1.0 - smoothstep(0.22, 0.86, _cut_age))
	draw_texture_rect(REAPER, _portrait, false, Color(1.18, 1.18, 1.25, portrait_alpha))
	if _eyes > 0.0:
		for source_point: Vector2 in EYE_POSITIONS:
			var center := (_portrait.position + source_point * _portrait.size / REAPER.get_size()).snapped(Vector2(2, 2))
			_draw_eye(center, portrait_alpha * _eyes)


func _draw_eye(center: Vector2, power: float) -> void:
	# 扫过兜帽时只强化一瞬，亮点周围保留像素台阶。
	var flare := 1.0 - smoothstep(0.0, 0.26, absf(_cut_age - 0.16))
	var glow := power * lerpf(0.72, 1.0, flare * smoothstep(0.0, 0.12, _cut_age))
	draw_rect(Rect2(center - Vector2(12, 4), Vector2(24, 8)), Color(0.60, 0.015, 0.085, glow * 0.32))
	draw_rect(Rect2(center - Vector2(8, 8), Vector2(16, 16)), Color(0.66, 0.02, 0.10, glow * 0.36))
	draw_rect(Rect2(center - Vector2(8, 2), Vector2(16, 4)), Color(0.97, 0.07, 0.19, glow))
	draw_rect(Rect2(center - Vector2(4, 4), Vector2(8, 6)), Color(1.0, 0.24, 0.30, power))
	draw_rect(Rect2(center - Vector2(2, 2), Vector2(4, 2)), Color(1.0, 0.63, 0.56, power))
