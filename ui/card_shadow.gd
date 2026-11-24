extends TextureRect


func _init() -> void:
	name = "Shadow"
	mouse_filter = MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture = _make_gradient()
	visible = false


func place(boundary_x: float, width: float, upper_on_right: bool) -> void:
	var parent_size: Vector2 = get_parent().size
	if width <= 0.0 or boundary_x <= 0.0 or boundary_x >= parent_size.x:
		visible = false
		return
	size = Vector2(width, parent_size.y)
	position.y = 0.0
	if upper_on_right:
		position.x = clampf(boundary_x - width, 0.0, parent_size.x - width)
		flip_h = false
	else:
		position.x = clampf(boundary_x, 0.0, parent_size.x - width)
		flip_h = true
	visible = true


func clear() -> void:
	visible = false


func _make_gradient() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0))
	gradient.set_color(1, Color(0, 0, 0, 0.55))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 4
	texture.fill_from = Vector2(0, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	return texture
