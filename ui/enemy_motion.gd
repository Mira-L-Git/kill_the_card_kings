extends Node2D

const BURN_SHADER = preload("res://ui/enemy_burn.gdshader")
const PORTRAIT_SIZE := Vector2(424.0, 632.0)
const ENTRANCE_SECONDS := 1.24
const PACIFY_SECONDS := 0.86
const BURN_SECONDS := 1.10
const ASH_END := 2.0
const CUE_MARGIN := 0.035
const LOWER_CORNER := Vector2(0.08, 0.91)
const UPPER_CORNER := Vector2(0.90, 0.14)

var _art: TextureRect
var _scroll: Scroll
var _ash: Ash
var _burn := ShaderMaterial.new()
var _prepared_portrait: Texture2D
var _tween: Tween
var _duration_scale: float


func _init(art: TextureRect, duration_scale: float) -> void:
	name = "Motion"
	_art = art
	_duration_scale = duration_scale
	_scroll = Scroll.new()
	_scroll.texture_filter = TEXTURE_FILTER_NEAREST
	_scroll.hide()
	add_child(_scroll)
	_ash = Ash.new()
	_ash.hide()
	add_child(_ash)
	_burn.shader = BURN_SHADER


static func hold_for_step(step: Dictionary) -> float:
	match step.kind:
		"enemy_appeared":
			return ENTRANCE_SECONDS + CUE_MARGIN
		"enemy_defeated":
			return (PACIFY_SECONDS if step.data.pacified else ASH_END) + CUE_MARGIN
	return 0.0


func reset() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_scroll.hide()
	_ash.hide()
	_art.material = null
	_art.modulate.a = 1.0
	_art.visible = _art.texture != null


func play_entrance() -> void:
	reset()
	_prepare_portrait()
	_entrance_frame(0.0)
	_tween = create_tween().set_ignore_time_scale(true).set_speed_scale(1.0 / _duration_scale)
	_tween.tween_method(_entrance_frame, 0.0, ENTRANCE_SECONDS, ENTRANCE_SECONDS)


func play_defeat(pacified: bool) -> void:
	reset()
	_tween = create_tween().set_ignore_time_scale(true).set_speed_scale(1.0 / _duration_scale)
	if pacified:
		_tween.tween_method(_pacify_frame, 0.0, PACIFY_SECONDS, PACIFY_SECONDS)
	else:
		_prepare_portrait()
		_art.material = _burn
		_ash.show()
		_burn_frame(0.0)
		_tween.tween_method(_burn_frame, 0.0, ASH_END, ASH_END)
	_tween.tween_callback(_finish_defeat)


func _entrance_frame(age: float) -> void:
	_scroll.fade = smoothstep(0.15, 0.42, age)
	_scroll.open = smoothstep(0.45, ENTRANCE_SECONDS, age)
	_scroll.visible = _scroll.open < 1.0
	_art.visible = not _scroll.visible
	_scroll.queue_redraw()


func _burn_frame(age: float) -> void:
	var progress := clampf(age / BURN_SECONDS, 0.0, 1.0)
	_burn.set_shader_parameter("age", age)
	_burn.set_shader_parameter("radius", 0.63 * pow(progress, 1.13) - 0.018)
	_art.visible = age < BURN_SECONDS + 0.04
	_ash.age = age
	_ash.queue_redraw()


func _pacify_frame(age: float) -> void:
	_art.modulate.a = 1.0 - smoothstep(0.04, PACIFY_SECONDS, age)


func _finish_defeat() -> void:
	_art.hide()
	_ash.hide()


func _prepare_portrait() -> void:
	if _prepared_portrait == _art.texture:
		return
	_prepared_portrait = _art.texture
	var image := _prepared_portrait.get_image()
	var lower_ignition := _ignition_on_paper(image, LOWER_CORNER)
	var upper_ignition := _ignition_on_paper(image, UPPER_CORNER)
	_burn.set_shader_parameter("lower_ignition", lower_ignition)
	_burn.set_shader_parameter("upper_ignition", upper_ignition)
	_scroll.set_portrait(_prepared_portrait, image)
	_ash.set_portrait(image, lower_ignition, upper_ignition)


static func _ignition_on_paper(image: Image, target: Vector2) -> Vector2:
	var image_size := Vector2(image.get_size())
	var center := Vector2i(target * image_size)
	var best := center
	var best_distance := INF
	# 透明边缘各不相同，火种落在离目标角最近的实纸上。
	for y in range(maxi(3, center.y - 76), mini(image.get_height() - 3, center.y + 77), 3):
		for x in range(maxi(3, center.x - 76), mini(image.get_width() - 3, center.x + 77), 3):
			var distance := Vector2(x - center.x, y - center.y).length_squared()
			if distance >= best_distance:
				continue
			if image.get_pixel(x, y).a < 0.70 or image.get_pixel(x - 3, y).a < 0.55 or image.get_pixel(x + 3, y).a < 0.55:
				continue
			best = Vector2i(x, y)
			best_distance = distance
	return (Vector2(best) + Vector2(0.5, 0.5)) / image_size


class Scroll extends Node2D:
	const MAX_RADIUS := 54.0
	const ARC_STEPS := 24
	var open := 0.0
	var fade := 0.0
	var _portrait: Texture2D
	var _right_edges := PackedFloat32Array()

	func set_portrait(portrait: Texture2D, image: Image) -> void:
		_portrait = portrait
		_right_edges.clear()
		for y in range(image.get_height()):
			var edge := PORTRAIT_SIZE.x * 0.88
			for x in range(image.get_width() - 1, -1, -1):
				if image.get_pixel(x, y).a > 0.6:
					edge = float(x)
					break
			_right_edges.append(edge)

	func _draw() -> void:
		if fade <= 0.0:
			return
		var released := PORTRAIT_SIZE.y * open
		var remaining := PORTRAIT_SIZE.y - released
		var radius := MAX_RADIUS * tanh(remaining / (PI * MAX_RADIUS))
		_draw_roll_end(released, radius)
		if released > 0.05:
			_draw_strip(0.0, released, Vector3.ZERO, Vector3(0.0, -released, 0.0))
		# 平面与可见卷面共用接缝，随展开移动，避免叠层换序。
		for i in range(ARC_STEPS):
			var a := PI * i / ARC_STEPS
			var b := PI * (i + 1) / ARC_STEPS
			_draw_strip(released + radius * a, released + radius * b, _roll_point(released, radius, a), _roll_point(released, radius, b))

	func _roll_point(released: float, radius: float, angle: float) -> Vector3:
		var curve := 1.0 - cos(angle)
		return Vector3(radius * sin(angle) * 0.20, -released - radius * curve, radius * curve * 0.09)

	func _project(x: float, y: float) -> Vector2:
		return Vector2(x + 16.0 * (1.0 - open), PORTRAIT_SIZE.y + y - 270.0 * (1.0 - open))

	func _strip_point(u: float, row: Vector3) -> Vector2:
		var bow := 4.0 * u * (1.0 - u) * row.z
		return _project(PORTRAIT_SIZE.x * u + row.x, row.y - bow)

	func _draw_strip(from_bottom: float, to_bottom: float, start: Vector3, end: Vector3) -> void:
		if start.y - end.y < 0.015:
			return
		var a := 1.0 - from_bottom / PORTRAIT_SIZE.y
		var b := 1.0 - to_bottom / PORTRAIT_SIZE.y
		# 只改透明度，牌面的 RGB 直接取原立绘。
		var tint := PackedColorArray([Color(1.0, 1.0, 1.0, fade)])
		var columns := 6 if end.z > 0.0 else 1
		for i in range(columns):
			var left := float(i) / columns
			var right := float(i + 1) / columns
			var points := PackedVector2Array([_strip_point(left, start), _strip_point(right, start),
				_strip_point(right, end), _strip_point(left, end)])
			var uv := PackedVector2Array([Vector2(left, a), Vector2(right, a), Vector2(right, b), Vector2(left, b)])
			draw_polygon(points, tint, uv, _portrait)

	func _draw_roll_end(released: float, radius: float) -> void:
		# 只剩最外层纸面时，卷筒端面已经展开，没有内圈可画。
		var inside_wrap := PORTRAIT_SIZE.y - released - PI * radius
		var opacity := fade * smoothstep(24.0, 74.0, inside_wrap)
		if opacity < 0.01:
			return
		var row := PORTRAIT_SIZE.y - released - radius * PI * 0.5
		var rim_x := 0.0
		for delta in [-18.0, -9.0, 0.0, 9.0, 18.0]:
			var y := clampf(row + delta, 0.0, PORTRAIT_SIZE.y - 2.0)
			var index := floori(y)
			rim_x += lerpf(_right_edges[index], _right_edges[index + 1], y - index) / 5.0
		var center := _project(rim_x + radius * 0.24, -released - radius)
		var cap_size := Vector2(radius * 0.28, radius * 0.93)
		var cap := PackedVector2Array()
		for i in range(32):
			var angle := TAU * i / 32.0
			cap.append(center + Vector2(cos(angle), sin(angle)) * cap_size)
		draw_colored_polygon(cap, Color(0.29, 0.19, 0.13, opacity))
		var spiral := PackedVector2Array()
		for i in range(45):
			var t := float(i) / 44.0
			var angle := -0.45 + TAU * 1.65 * t
			spiral.append(center + Vector2(cos(angle), sin(angle)) * cap_size * lerpf(0.92, 0.22, t))
		draw_polyline(spiral, Color(0.76, 0.57, 0.38, opacity), 2.0)


class Ash extends Node2D:
	var age := -1.0
	var _particles: Array[Dictionary] = []

	func set_portrait(portrait: Image, lower_ignition: Vector2, upper_ignition: Vector2) -> void:
		_particles.clear()
		var random := RandomNumberGenerator.new()
		random.seed = 1129
		for i in range(154):
			var uv := Vector2(random.randf(), random.randf())
			if portrait.get_pixelv(Vector2i(uv * PORTRAIT_SIZE)).a < 0.75:
				continue
			var aspect := Vector2(0.67, 1.0)
			var distance := minf(((uv - lower_ignition) * aspect).length(), ((uv - upper_ignition) * aspect).length())
			var ignited := BURN_SECONDS * pow((distance + 0.018) / 0.63, 1.0 / 1.13)
			_particles.append({"origin": uv * PORTRAIT_SIZE, "time": ignited,
				"velocity": Vector2(random.randf_range(-125, 125), random.randf_range(-146, -23)),
				"life": random.randf_range(0.42, 0.89), "size": random.randf_range(1.8, 8.0),
				"warmth": random.randf()})

	func _draw() -> void:
		for speck in _particles:
			var elapsed: float = age - speck.time
			if elapsed < 0.0 or elapsed >= speck.life:
				continue
			var point: Vector2 = speck.origin + speck.velocity * elapsed + Vector2(0.0, 385.0 * elapsed * elapsed)
			point.y = minf(point.y, PORTRAIT_SIZE.y + 28.0 + speck.warmth * 25.0)
			var tint := Color(0.66, 0.60, 0.56).lerp(Color(1.0, 0.42 + speck.warmth * 0.2, 0.085), 1.0 - smoothstep(0.02, 0.15, elapsed))
			tint.a = 0.95 * (1.0 - smoothstep(speck.life * 0.52, speck.life, elapsed))
			var tip := Vector2(speck.size, -speck.size * 0.4).rotated(elapsed * 8.0 + speck.warmth * TAU)
			draw_colored_polygon(PackedVector2Array([point - tip, point + tip, point + tip.orthogonal() * 0.7]), tint)
