extends Node2D

const CARD_SIZE := Vector2(240, 336)
const GOLD := Color("b48b6d")
const INNER := Color("78566e")

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, CARD_SIZE), Color("38243c"))
	draw_rect(Rect2(8, 9, 224, 318), GOLD, false, 5.0)
	draw_rect(Rect2(15, 16, 210, 304), INNER, false, 2.0)
	var crest := PackedVector2Array([Vector2(120, 71), Vector2(186, 168), Vector2(120, 265), Vector2(54, 168), Vector2(120, 71)])
	draw_polyline(crest, GOLD, 2.4)
	draw_arc(Vector2(120, 168), 38.0, 0.0, TAU, 48, INNER, 3.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(120, 135), Vector2(139, 168), Vector2(120, 201), Vector2(101, 168)]), GOLD)
	for spot in [Vector2(30, 32), Vector2(210, 32), Vector2(30, 304), Vector2(210, 304)]:
		draw_line(spot - Vector2(8, 0), spot + Vector2(8, 0), GOLD, 2.0)
		draw_line(spot - Vector2(0, 8), spot + Vector2(0, 8), GOLD, 2.0)
