extends Control

signal advanced

const Style = preload("res://ui/ui_style.gd")
const CardView = preload("res://ui/card_view.gd")
const SHADE = preload("res://ui/tutorial_shade.gdshader")
const MAX_TARGETS := 16

var _shade_material := ShaderMaterial.new()
var _targets: Array[Control] = []
var _panel: Panel
var _title: Label
var _body: Label
var _hint: Label
var _diagram: Control


func _ready() -> void:
	name = "TutorialOverlay"
	size = Vector2(2560, 1440)
	hide()
	set_process(false)
	var shade := ColorRect.new()
	shade.size = size
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	_shade_material.shader = SHADE
	shade.material = _shade_material
	add_child(shade)
	_panel = Panel.new()
	_panel.position = Vector2(1232, 192)
	_panel.size.x = 1120
	_panel.mouse_filter = MOUSE_FILTER_IGNORE
	var surface := Style.box(Color("251e23"), Color("b19165"), 3)
	surface.set_corner_radius_all(14)
	_panel.add_theme_stylebox_override("panel", surface)
	add_child(_panel)
	_title = Style.label(_panel, "Title", "", Rect2(52, 32, 1016, 64), 46)
	_title.add_theme_color_override("font_color", Color("e9c88c"))
	_body = Style.label(_panel, "Body", "", Rect2(52, 112, 1016, 132), 34)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_color_override("font_color", Style.PAPER)
	_hint = Style.label(_panel, "Hint", "点击任意位置继续", Rect2(52, 0, 1016, 52), 28)
	_hint.add_theme_color_override("font_color", Color("c4ab89"))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_build_diagram()


func present(guide: Dictionary, targets: Array[Control]) -> void:
	_targets = targets
	if guide.is_empty():
		hide()
		set_process(false)
		return
	mouse_filter = MOUSE_FILTER_STOP if guide.explanation else MOUSE_FILTER_IGNORE
	focus_mode = FOCUS_ALL if guide.explanation else FOCUS_NONE
	accessibility_name = guide.title + "。" + guide.text
	_title.text = guide.title
	_body.text = guide.text
	_diagram.visible = guide.diagram
	_hint.visible = guide.explanation
	_body.size.y = _body.get_minimum_size().y
	var content_bottom := _body.position.y + _body.size.y
	if _diagram.visible:
		_diagram.position.y = content_bottom + 24
		content_bottom = _diagram.position.y + _diagram.size.y
	_hint.position.y = content_bottom + 16
	_panel.size.y = content_bottom + (84 if _hint.visible else 46)
	show()
	set_process(true)
	_process(0.0)


func _process(_delta: float) -> void:
	var rectangles := PackedVector4Array()
	var angles := PackedFloat32Array()
	rectangles.resize(MAX_TARGETS)
	angles.resize(MAX_TARGETS)
	var local_from_global := get_global_transform().affine_inverse()
	var count := 0
	for target in _targets:
		if not is_instance_valid(target) or not target.is_visible_in_tree():
			continue
		var transform := local_from_global * target.get_global_transform()
		var center := transform * (target.size * 0.5)
		var half := target.size * transform.get_scale() * 0.5 + Vector2(9, 9)
		rectangles[count] = Vector4(center.x, center.y, half.x, half.y)
		angles[count] = transform.get_rotation()
		count += 1
	_shade_material.set_shader_parameter("targets", rectangles)
	_shade_material.set_shader_parameter("angles", angles)
	_shade_material.set_shader_parameter("target_count", count)


func _gui_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed
	var tap: bool = event is InputEventScreenTouch and not event.pressed
	if click or tap or (event.is_action_pressed("ui_accept") and not event.is_echo()):
		# 先消耗输入，再切换引导，避免当前点击穿到手牌。
		accept_event()
		advanced.emit()


func _build_diagram() -> void:
	_diagram = Panel.new()
	_diagram.name = "DiamondExample"
	_diagram.position.x = 52
	_diagram.size = Vector2(1016, 188)
	_diagram.mouse_filter = MOUSE_FILTER_IGNORE
	_diagram.add_theme_stylebox_override("panel", Style.box(Color("191419"), Color("574335")))
	_panel.add_child(_diagram)
	var card := TextureRect.new()
	card.name = "ExampleCard"
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.texture = load(CardView.art_path({"suit": "diamonds", "rank": 4}))
	card.mouse_filter = MOUSE_FILTER_IGNORE
	_diagram.add_child(card)
	card.position = Vector2(32, 22)
	card.size = Vector2(102, 144)
	Style.label(_diagram, "Request", "请求抽 4 张", Rect2(168, 54, 230, 72), 34)
	Style.label(_diagram, "Arrow", "→", Rect2(402, 49, 84, 80), 46)
	Style.label(_diagram, "Capacity", "手牌空 2 格\n实际抽 2 张", Rect2(512, 45, 245, 108), 32)
	for i in range(2):
		var slot := Panel.new()
		slot.position = Vector2(794 + 92 * i, 38)
		slot.size = Vector2(72, 108)
		slot.mouse_filter = MOUSE_FILTER_IGNORE
		var edge := Style.box(Color("382a28"), Color("b19165"), 3)
		edge.set_corner_radius_all(8)
		slot.add_theme_stylebox_override("panel", edge)
		_diagram.add_child(slot)
		var filled := Style.label(slot, "Drawn", "+1", Rect2(0, 0, 72, 108), 30)
		filled.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		filled.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
