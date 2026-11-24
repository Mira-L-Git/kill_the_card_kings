extends ColorRect

const SHADER = preload("res://ui/hand_shadow.gdshader")
const MAX_OUTLINE_POINTS := 20

var _material: ShaderMaterial
var _upper_outline := PackedVector2Array()


func _init() -> void:
	name = "Shadow"
	mouse_filter = MOUSE_FILTER_IGNORE
	size = Vector2(240, 336)
	color = Color.WHITE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material = _material
	visible = false


func set_upper(center: Vector2, upper_size: Vector2, angle: float, outline: PackedVector2Array) -> void:
	_material.set_shader_parameter("card_size", size)
	_material.set_shader_parameter("upper_center", center)
	_material.set_shader_parameter("upper_size", upper_size)
	_material.set_shader_parameter("upper_angle", angle)
	if outline != _upper_outline:
		_upper_outline = outline
		# 两套手牌轮廓共用 shader 的固定数组，尾部补齐但不参与计算。
		var points := outline.duplicate()
		points.resize(MAX_OUTLINE_POINTS)
		_material.set_shader_parameter("upper_outline", points)
		_material.set_shader_parameter("upper_vertex_count", outline.size())
	visible = true


func clear() -> void:
	visible = false
