extends Node2D

const CardBack = preload("res://ui/card_back.gd")
const CardView = preload("res://ui/card_view.gd")
const PlayedCards = preload("res://ui/played_cards_view.gd")
const HandView = preload("res://ui/hand_view.gd")
const SUIT_SHAKE := 0.12
const HIT_TIME := 0.35
const NUMBER_CHANGE := 0.095
const SHIELD_FORM := 0.19
const TRANSFER_FLIGHT := 0.25
const DEFENSE_ENTER := 0.15
const DISCARD_FLIGHT := 0.25
const DEFENSE_FADE := 0.095
const MARGIN := 0.05
const SLASH_HALF_DIAGONAL := Vector2(232.0, -346.0)

var _duration_scale: float
var _tweens: Array[Tween] = []
var _origins: Dictionary = {}
var _tokens: Array[Node2D] = []
var _discard_card: CardView
var _delta: Label
var _slash_center := Vector2.ZERO
var _slash_age := 1.0
var _shield_age := 1.0


func _init(duration_scale: float) -> void:
	name = "CombatEffects"
	_duration_scale = duration_scale
	_delta = Label.new()
	_delta.name = "Delta"
	_delta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_delta.add_theme_font_size_override("font_size", 34)
	_delta.add_theme_color_override("font_outline_color", Color("18101b"))
	_delta.add_theme_constant_override("outline_size", 5)
	_delta.hide()
	add_child(_delta)


static func hold_for_step(step: Dictionary) -> float:
	match step.kind:
		"play_committed": return PlayedCards.FLY_IN + 0.10
		"base_damage": return HIT_TIME + MARGIN
		"clubs_damage": return SUIT_SHAKE + HIT_TIME + MARGIN
		"hearts_recycled": return SUIT_SHAKE + transfer_duration(step.data.count) + MARGIN
		"cards_drawn":
			if step.data.reason == "diamonds":
				return SUIT_SHAKE + HandView.hold_for_step(step) + MARGIN
		"shield_gained": return SUIT_SHAKE + SHIELD_FORM + HIT_TIME + MARGIN
		"played_discarded": return PlayedCards.discard_duration(step.data.card_ids.size()) + MARGIN
		"defense_ready": return DEFENSE_ENTER + MARGIN
		"defense_discarded": return DISCARD_FLIGHT + HIT_TIME + MARGIN
	return 0.0


static func _transfer_gap(count: int) -> float:
	return minf(0.046, 0.32 / maxi(1, count - 1))


static func transfer_duration(count: int) -> float:
	return TRANSFER_FLIGHT + _transfer_gap(count) * (count - 1) if count > 0 else 0.0


func timeline() -> Tween:
	var tween := create_tween().set_ignore_time_scale(true).set_speed_scale(1.0 / _duration_scale)
	_tweens.append(tween)
	return tween


func reset() -> void:
	for tween in _tweens:
		tween.kill()
	_tweens.clear()
	for visual: Control in _origins:
		visual.position = _origins[visual]
	_origins.clear()
	for token in _tokens:
		token.hide()
		token.queue_free()
	_tokens.clear()
	_clear_discard_card()
	_delta.hide()
	_slash_age = 1.0
	_shield_age = 1.0
	queue_redraw()


func slash(body: Control, center: Vector2) -> void:
	_slash_center = center
	_shake(body, 15.0, 0.18)
	timeline().tween_method(func(age: float):
		_slash_age = age
		queue_redraw()
	, 0.0, 1.0, 0.30)


func change_number(number: Label, amount: int, tint: Color, commit: Callable, beat: Tween = null) -> void:
	if beat == null:
		beat = timeline()
	if amount <= 0:
		beat.tween_callback(commit)
		return
	var parent := number.get_parent() as CanvasItem
	var anchor := to_local(parent.get_global_transform() * number.position)
	beat.tween_callback(_shake.bind(number, 9.0, 0.16))
	beat.tween_interval(NUMBER_CHANGE)
	beat.tween_callback(func():
		commit.call()
		_delta.text = "−%d" % amount
		_delta.add_theme_font_override("font", number.get_theme_font("font"))
		_delta.add_theme_color_override("font_color", tint)
		_delta.position = anchor + Vector2(number.get_minimum_size().x + 7.0, 25.0)
		_delta.modulate.a = 1.0
		_delta.show()
	)
	beat.tween_method(func(age: float):
		_delta.position.y = anchor.y + 25.0 - 14.0 * age
		_delta.modulate.a = 1.0 - smoothstep(0.35, 1.0, age)
	, 0.0, 1.0, HIT_TIME - NUMBER_CHANGE)
	beat.tween_callback(_delta.hide)


func _shake(visual: Control, distance: float, seconds: float) -> void:
	var original := visual.position
	_origins[visual] = original
	timeline().tween_method(func(age: float):
		visual.position = original + Vector2(sin(age * TAU * 2.0) * (1.0 - age) * distance, 0.0)
	, 0.0, 1.0, seconds)


func fly_discard(card: CardView, destination: Vector2) -> Tween:
	var beat := timeline()
	if card == null:
		beat.tween_interval(DISCARD_FLIGHT)
		return beat
	var origin := to_local(card.get_global_transform() * card.pivot_offset)
	var angle := card.rotation
	var zoom := card.scale
	card.stop_lift_for_draw()
	card.reparent(self, false)
	card.clear_overlap_shadow()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.focus_mode = Control.FOCUS_NONE
	card.modulate = Color.WHITE
	card.position = origin - card.pivot_offset
	_discard_card = card
	beat.tween_method(func(phase: float):
		var travel := smoothstep(0.0, 1.0, phase)
		var center := origin.lerp(destination, travel) - Vector2(0, 112.0 * sin(PI * travel))
		var turn := smoothstep(0.12, 0.74, phase) * PI
		var size_at_phase := zoom.lerp(Vector2(0.33, 0.33), travel)
		card.position = center - card.pivot_offset
		card.rotation = lerpf(angle, 0.0, travel)
		card.scale = size_at_phase * Vector2(maxf(0.04, absf(cos(turn))), 1.0)
		card.show_draw_back(turn >= PI * 0.5)
	, 0.0, 1.0, DISCARD_FLIGHT)
	beat.tween_callback(_clear_discard_card)
	return beat


func _clear_discard_card() -> void:
	if _discard_card == null:
		return
	_discard_card.hide()
	_discard_card.queue_free()
	_discard_card = null


func shield() -> void:
	timeline().tween_method(func(age: float):
		_shield_age = age
		queue_redraw()
	, 0.0, 1.0, 0.47)


func transfer(count: int, source: Vector2, destination: Vector2, counts_changed: Callable) -> void:
	if count == 0:
		return
	for i in range(count):
		var token := CardBack.new()
		token.scale = Vector2(0.27, 0.27)
		token.hide()
		add_child(token)
		_tokens.append(token)
	var duration := transfer_duration(count)
	timeline().tween_method(_transfer_frame.bind(source, destination, counts_changed), 0.0, duration + 0.00001, duration)


func _transfer_frame(age: float, source: Vector2, destination: Vector2, counts_changed: Callable) -> void:
	var departed := 0
	var arrived := 0
	for i in range(_tokens.size()):
		var time := age - i * _transfer_gap(_tokens.size())
		var token := _tokens[i]
		token.visible = time >= 0.0 and time < TRANSFER_FLIGHT
		departed += int(time >= 0.0)
		arrived += int(time >= TRANSFER_FLIGHT)
		if token.visible:
			var phase := smoothstep(0.0, TRANSFER_FLIGHT, time)
			var center := source.lerp(destination, phase) - Vector2(0.0, sin(PI * phase) * 98.0)
			token.position = center - Vector2(120, 168) * token.scale
	counts_changed.call(departed, arrived)


func _draw() -> void:
	if _slash_age < 1.0:
		_draw_slash()
	if _shield_age < 1.0:
		_draw_shield()


func _draw_slash() -> void:
	var end := smoothstep(0.0, 0.36, _slash_age)
	if end <= 0.005:
		return
	var start := 0.24 * smoothstep(0.44, 1.0, _slash_age)
	var opacity := 1.0 - smoothstep(0.32, 1.0, _slash_age)
	var diagonal := SLASH_HALF_DIAGONAL.rotated(deg_to_rad(5.0))
	var normal := Vector2(-diagonal.y, diagonal.x).normalized()
	var edge := PackedVector2Array()
	var skirt := PackedVector2Array()
	var steel := PackedVector2Array()
	var echo := PackedVector2Array()
	for i in range(41):
		var s := i / 40.0
		var t := lerpf(start, end, s)
		var point := _slash_point(t, diagonal, normal)
		var width := 30.0 * pow(sin(PI * s), 1.2) * lerpf(0.55, 1.0, end)
		edge.append(point)
		if i > 0 and i < 40:
			skirt.append(point + normal * width)
			steel.append(point + normal * width * 0.48)
		if s > 0.06 and s < 0.89:
			echo.append(point + normal * (width + 10.0))
	draw_polyline(edge, Color(0.98, 0.30, 0.08, opacity * 0.14), 22.0, true)
	draw_polyline(edge, Color(1.0, 0.52, 0.13, opacity * 0.26), 11.0, true)
	edge.reverse()
	draw_colored_polygon(skirt + edge, Color(0.94, 0.34, 0.12, opacity * 0.72))
	draw_colored_polygon(steel + edge, Color(1.0, 0.69, 0.27, opacity * 0.90))
	draw_polyline(echo, Color(1.0, 0.57, 0.29, opacity * 0.62), 2.0, true)
	draw_polyline(edge, Color(1.0, 0.95, 0.77, opacity), 4.0, true)
	for i in range(15):
		var t := 0.08 + i * 0.062
		if t > end:
			continue
		var travel := maxf(0.0, _slash_age - 0.34 * t)
		var spread := float((i * 11) % 9 - 3)
		var point := _slash_point(t, diagonal, normal) + Vector2(90.0 + spread * 11.0, -55.0 + spread * 18.0) * travel
		var heat := opacity * (1.0 - smoothstep(0.22, 0.74, travel))
		var streak := Vector2(10.0 + float(i % 4) * 4.0, -7.0 - float(i % 3) * 3.0)
		draw_line(point, point - streak, Color(1.0, 0.50, 0.19, heat * 0.6), 5.0, true)
		draw_line(point, point - streak * 0.6, Color(1.0, 0.87, 0.56, heat), 2.0, true)


func _slash_point(t: float, diagonal: Vector2, normal: Vector2) -> Vector2:
	return _slash_center + (2.0 * t - 1.0) * diagonal - normal * (24.0 * sin(PI * t))


func _draw_shield() -> void:
	var sweep := smoothstep(0.0, 0.38, _shield_age)
	var opacity := sweep * (1.0 - smoothstep(0.57, 1.0, _shield_age))
	if sweep <= 0.01:
		return
	var center := Vector2(1280, 1120)
	# 两端要越过单出黑桃后最多七张牌的外沿。
	var arc := PackedVector2Array()
	for i in range(57):
		var angle := -PI * 0.5 + lerpf(-PI * 0.5, PI * 0.5, i / 56.0) * sweep
		arc.append(center + Vector2(cos(angle) * 620.0, sin(angle) * 210.0))
	draw_polyline(arc, Color(0.33, 0.76, 1.0, opacity * 0.22), 15.0, true)
	draw_polyline(arc, Color(0.75, 0.94, 1.0, opacity * 0.92), 5.0, true)
	var mark := center - Vector2(0, lerpf(104.0, 116.0, sweep))
	var rim := PackedVector2Array([Vector2(0, -49), Vector2(36, -33), Vector2(31, 3),
		Vector2(21, 23), Vector2(0, 40), Vector2(-21, 23), Vector2(-31, 3), Vector2(-36, -33)])
	for i in range(rim.size()):
		rim[i] = mark + rim[i] * lerpf(0.85, 1.0, sweep)
	draw_colored_polygon(rim, Color(0.17, 0.37, 0.54, opacity * 0.54))
	rim.append(rim[0])
	draw_polyline(rim, Color(0.75, 0.95, 1.0, opacity), 4.0, true)
	draw_line(mark + Vector2(0, -39), mark + Vector2(0, 24), Color(0.62, 0.89, 1.0, opacity * 0.58), 3.0, true)
