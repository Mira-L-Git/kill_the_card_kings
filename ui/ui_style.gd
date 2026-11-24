extends RefCounted

const SUITS := {"hearts": "红桃 ♥", "diamonds": "方片 ♦", "clubs": "梅花 ♣", "spades": "黑桃 ♠"}
const PAPER := Color("e9e4d8")


static func rank_text(rank: int) -> String:
	return {1: "A", 11: "J", 12: "Q", 13: "K"}.get(rank, str(rank))


static func box(color: Color, border: Color = Color("53566c"), width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = 18
	style.content_margin_right = 18
	return style


static func label(parent: Node, node_name: String, text: String, rect: Rect2, font_size: int = 28) -> Label:
	var item := Label.new()
	item.name = node_name
	item.text = text
	item.position = rect.position
	item.size = rect.size
	item.add_theme_font_size_override("font_size", font_size)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item


static func result_glow(parent: Control, node_name: String, colors: PackedColorArray) -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.37, 0.72, 1.0])
	gradient.colors = colors
	var light := GradientTexture2D.new()
	light.gradient = gradient
	light.fill = GradientTexture2D.FILL_RADIAL
	light.fill_from = Vector2(0.5, 0.33)
	light.fill_to = Vector2(1.0, 0.53)
	light.width = 640
	light.height = 360
	var glow := TextureRect.new()
	glow.name = node_name
	glow.texture = light
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = parent.size
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(glow)
	return glow


static func result_divider(parent: Control, line: Color, diamond: Color) -> Control:
	var rule := Control.new()
	rule.position = Vector2(parent.size.x * 0.5, 345)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rule)
	rule.draw.connect(func():
		rule.draw_line(Vector2(-312, 0), Vector2(-21, 0), line, 2, true)
		rule.draw_line(Vector2(21, 0), Vector2(312, 0), line, 2, true)
		rule.draw_colored_polygon(PackedVector2Array([Vector2(0, -8), Vector2(12, 0), Vector2(0, 8), Vector2(-12, 0)]), diamond)
	)
	return rule


static func button(parent: Node, node_name: String, text: String, rect: Rect2, action: Callable) -> Button:
	var item := Button.new()
	item.name = node_name
	item.text = text
	item.position = rect.position
	item.size = rect.size
	item.pressed.connect(action)
	parent.add_child(item)
	return item


static func texture_box(path: String, tint: Color = Color.WHITE) -> StyleBox:
	if not ResourceLoader.exists(path):
		return box(Color("2a2a37"))
	var style := StyleBoxTexture.new()
	style.texture = load(path)
	style.modulate_color = tint
	style.texture_margin_left = 0.0
	style.texture_margin_top = 0.0
	style.texture_margin_right = 0.0
	style.texture_margin_bottom = 0.0
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	return style


static func textured_button(parent: Node, node_name: String, text: String, rect: Rect2, path: String, action: Callable) -> Button:
	var item := button(parent, node_name, text, rect, action)
	item.add_theme_stylebox_override("normal", texture_box(path))
	item.add_theme_stylebox_override("hover", texture_box(path, Color(1.12, 1.12, 1.12)))
	item.add_theme_stylebox_override("pressed", texture_box(path, Color(0.88, 0.88, 0.88)))
	item.add_theme_stylebox_override("disabled", texture_box(path, Color(0.55, 0.55, 0.55, 0.8)))
	item.add_theme_stylebox_override("focus", texture_box(path))
	item.add_theme_color_override("font_color", Color("e9e4d8"))
	item.add_theme_color_override("font_hover_color", Color.WHITE)
	item.add_theme_color_override("font_pressed_color", Color("d8d0c0"))
	item.add_theme_color_override("font_disabled_color", Color("8c877d"))
	return item
