extends Node2D

const CardOutline = preload("res://ui/card_outline.gd")
const PlayerDefeat = preload("res://ui/player_defeat.gd")
const FACE_SHADER = preload("res://ui/joker_revival.gdshader")
const AURA_SHADER = preload("res://ui/joker_revival_aura.gdshader")
const FRAME = preload("res://assets/cards/jokers-gothic-layered-v1/牌框-B-240x336.png")
const BIG_CROWN = preload("res://assets/cards/jokers-gothic-layered-v1/大王-王冠-240x336.png")
const SMALL_CROWN = preload("res://assets/cards/jokers-gothic-layered-v1/小王-王冠-240x336.png")
const BIG_SIGIL = preload("res://assets/cards/jokers-gothic-layered-v1/大王-魔法纹路-240x336.png")
const SMALL_SIGIL = preload("res://assets/cards/jokers-gothic-layered-v1/小王-魔法纹路-240x336.png")
const CARD_SIZE := CardOutline.ART_SIZE
const AURA_SIZE := Vector2(660, 640)
const FLIGHT_TIME := 0.64
# 原 0.8 秒的发光段按 0.8 倍速播放。
const CHARGE_TIME := 1.0
const PEAK_HOLD := 0.35
const SHATTER_WINDUP := FLIGHT_TIME + CHARGE_TIME + PEAK_HOLD
const SHATTER_TIME := 1.12
const DISSOLVE_TIME := 0.78
const CROWN_SEAMS := [
	[Vector2(33, 110), Vector2(33, 252)],
	[Vector2(72, 110), Vector2(72, 162), Vector2(76, 175), Vector2(80, 181),
		Vector2(78, 188), Vector2(83, 197), Vector2(86, 208), Vector2(88, 252)],
	[Vector2(121, 110), Vector2(121, 134), Vector2(123, 146), Vector2(126, 154),
		Vector2(124, 161), Vector2(130, 171), Vector2(128, 181), Vector2(136, 191),
		Vector2(137, 203), Vector2(140, 215), Vector2(140, 252)],
	[Vector2(163, 110), Vector2(163, 152), Vector2(167, 168), Vector2(164, 177),
		Vector2(164, 188), Vector2(160, 201), Vector2(158, 213), Vector2(158, 252)],
	[Vector2(207, 110), Vector2(207, 252)],
]
const SHARD_VELOCITIES := [Vector2(-128, -88), Vector2(-48, -142), Vector2(52, -116), Vector2(130, -70)]
const SHARD_SPINS := [-1.45, -1.10, 1.20, 1.42]

var _duration_scale: float
var _card := Node2D.new()
var _aura := ColorRect.new()
var _aura_material := ShaderMaterial.new()
var _face_material := ShaderMaterial.new()
var _motion: Tween
var _crown: Texture2D
var _glow_ink: Color
var _core_ink: Color
var _flare_ink: Color
var _shatter_age := -1.0
var _fragments: Array[Dictionary] = []
var _particles: Array[Dictionary] = []


func _init(duration_scale: float) -> void:
	name = "JokerRevival"
	_duration_scale = duration_scale
	texture_filter = TEXTURE_FILTER_NEAREST
	_card.name = "Card"
	_card.show_behind_parent = true
	add_child(_card)
	_aura.name = "Aura"
	_aura.position = -AURA_SIZE / 2.0
	_aura.size = AURA_SIZE
	_aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aura_material.shader = AURA_SHADER
	_aura.material = _aura_material
	_aura.hide()
	_card.add_child(_aura)
	var face := Polygon2D.new()
	face.position = -CARD_SIZE / 2.0
	face.polygon = PackedVector2Array(CardOutline.JOKER)
	face.uv = face.polygon
	face.texture = FRAME
	_face_material.shader = FACE_SHADER
	face.material = _face_material
	_card.add_child(face)
	_prepare_fragments()
	_prepare_particles()
	hide()


static func hold_for_step(step: Dictionary) -> float:
	if step.kind == "joker_spent":
		return PlayerDefeat.REVEAL_TIME + SHATTER_WINDUP + SHATTER_TIME + 0.08
	return 0.0


func play(joker: String, origin: Rect2, center: Vector2, takeoff: Callable) -> void:
	reset()
	var big := joker == "big"
	_crown = BIG_CROWN if big else SMALL_CROWN
	_glow_ink = Color("ed9d29") if big else Color("84152e")
	_core_ink = Color("ffe9a8") if big else Color("c4364e")
	_flare_ink = Color("fff6d3") if big else Color("ffb3b4")
	_face_material.set_shader_parameter("sigil", BIG_SIGIL if big else SMALL_SIGIL)
	_face_material.set_shader_parameter("crown", _crown)
	_face_material.set_shader_parameter("glow_ink", _glow_ink)
	_face_material.set_shader_parameter("core_ink", _core_ink)
	_face_material.set_shader_parameter("flare_ink", _flare_ink)
	_aura_material.set_shader_parameter("halo_ink", Color("ffb145") if big else Color("dd2147"))
	_aura_material.set_shader_parameter("flare_ink", _flare_ink)
	_face_material.set_shader_parameter("dissolve", 0.0)
	_face_material.set_shader_parameter("crown_opacity", 1.0)
	_set_charge(0.0)
	_flight_frame(0.0, origin, center)
	show()
	_motion = create_tween().set_ignore_time_scale(true).set_speed_scale(1.0 / _duration_scale)
	_motion.tween_interval(PlayerDefeat.REVEAL_TIME)
	_motion.tween_callback(func():
		takeoff.call()
		_card.show()
	)
	_motion.tween_method(_flight_frame.bind(origin, center), 0.0, 1.0, FLIGHT_TIME)
	_motion.tween_method(_set_charge, 0.0, 1.0, CHARGE_TIME)
	_motion.tween_interval(PEAK_HOLD)
	_motion.tween_callback(_face_material.set_shader_parameter.bind("crown_opacity", 0.0))
	_motion.tween_method(_shatter_frame, 0.0, SHATTER_TIME, SHATTER_TIME)
	_motion.tween_callback(hide)


func reset() -> void:
	if _motion != null:
		_motion.kill()
		_motion = null
	_shatter_age = -1.0
	_card.hide()
	hide()
	queue_redraw()


func _flight_frame(age: float, origin: Rect2, center: Vector2) -> void:
	var travel := smoothstep(0.0, 1.0, age)
	var arc := sin(PI * travel)
	_card.position = origin.get_center().lerp(center, travel) - Vector2(0, 120.0 * arc)
	_card.scale = (origin.size / CARD_SIZE).lerp(Vector2(2, 2), travel)
	_card.rotation = -0.18 * arc


func _set_charge(amount: float) -> void:
	_face_material.set_shader_parameter("charge", amount)
	_set_radiance(smoothstep(0.14, 1.0, amount))


func _set_radiance(amount: float) -> void:
	_aura.visible = amount > 0.0
	_aura_material.set_shader_parameter("radiance", amount)
	_face_material.set_shader_parameter("radiance", amount)


func _shatter_frame(age: float) -> void:
	_shatter_age = age
	_set_radiance(1.0 - smoothstep(0.05, 0.46, age))
	_face_material.set_shader_parameter("dissolve", minf(age / DISSOLVE_TIME, 1.0))
	queue_redraw()


func _prepare_fragments() -> void:
	# 相邻碎片共享裂痕折线，破裂前后共用同一套王冠像素。
	for i in range(CROWN_SEAMS.size() - 1):
		var left := PackedVector2Array(CROWN_SEAMS[i])
		var right := PackedVector2Array(CROWN_SEAMS[i + 1])
		right.reverse()
		var points := left + right
		var uvs := PackedVector2Array()
		var pivot := Vector2((left[0].x + right[-1].x) / 2.0, 177)
		for point in points:
			uvs.append(point / CARD_SIZE)
		_fragments.append({"points": points, "uv": uvs, "pivot": pivot})


func _prepare_particles() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 24336
	for y in range(9, int(CARD_SIZE.y) - 6, 13):
		for x in range(9, int(CARD_SIZE.x) - 6, 13):
			var point := Vector2(x + random.randf_range(-4, 4), y + random.randf_range(-4, 4))
			var nearest := point.min(CARD_SIZE - point) - Vector2(9, 9)
			var distance := nearest.max(Vector2.ZERO).length()
			var time := (distance + 8.0) / 221.0 * DISSOLVE_TIME
			var direction := (point - CARD_SIZE / 2.0).normalized().rotated(random.randf_range(-0.42, 0.42))
			_particles.append({
				"point": point, "time": time, "life": random.randf_range(0.22, 0.35),
				"velocity": direction * random.randf_range(46, 152) + Vector2(0, -29),
				"edge": random.randf_range(1.25, 3.7),
			})


func _draw() -> void:
	if _shatter_age < 0.0:
		return
	draw_set_transform(_card.position - CARD_SIZE * _card.scale / 2.0, 0.0, _card.scale)
	_draw_crown_fragments()
	_draw_grains()


func _draw_crown_fragments() -> void:
	var opacity := 1.0 - smoothstep(0.36, 0.92, _shatter_age)
	if opacity <= 0.0:
		return
	var tint := Color(1.0, 1.0, 1.0, opacity)
	for i in range(_fragments.size()):
		var fragment: Dictionary = _fragments[i]
		var vertices := PackedVector2Array()
		var offset: Vector2 = SHARD_VELOCITIES[i] * _shatter_age + Vector2(0, 160 * pow(_shatter_age, 2))
		var angle: float = SHARD_SPINS[i] * _shatter_age
		for point: Vector2 in fragment.points:
			vertices.append(fragment.pivot + (point - fragment.pivot).rotated(angle) + offset)
		draw_polygon(vertices, PackedColorArray([tint]), fragment.uv, _crown)


func _draw_grains() -> void:
	for grain in _particles:
		var elapsed: float = _shatter_age - grain.time
		if elapsed < 0.0 or elapsed >= grain.life:
			continue
		var alpha := 1.0 - smoothstep(0.07, grain.life, elapsed)
		var point: Vector2 = grain.point + grain.velocity * elapsed
		point = point.snapped(Vector2(1.5, 1.5))
		var edge: float = grain.edge * lerpf(1.0, 0.42, elapsed / grain.life)
		var spark := _flare_ink.lerp(_core_ink, smoothstep(0.0, 0.11, elapsed))
		draw_rect(Rect2(point - Vector2.ONE * edge, Vector2.ONE * edge * 2.0), Color(_glow_ink, alpha * 0.30))
		draw_rect(Rect2(point - Vector2.ONE * edge / 2.0, Vector2.ONE * edge), Color(spark, alpha))
