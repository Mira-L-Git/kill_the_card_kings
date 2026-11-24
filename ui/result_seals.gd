extends Panel

const Style = preload("res://ui/ui_style.gd")
const BattleProgress = preload("res://ui/battle_progress.gd")
const BRASS := Color("9a7350")

var rows: Array[BattleProgress] = []
var _shown_rows := 3


func _init() -> void:
	name = "Seals"
	position = Vector2(805, 465)
	size = Vector2(950, 459)
	mouse_filter = MOUSE_FILTER_IGNORE
	var frame := Style.box(Color(0.07, 0.045, 0.042, 0.88), BRASS, 2)
	frame.set_corner_radius_all(12)
	frame.shadow_color = Color(0.02, 0.012, 0.016, 0.56)
	frame.shadow_size = 22
	add_theme_stylebox_override("panel", frame)
	for i in range(3):
		var row := BattleProgress.new()
		row.name = ["J", "Q", "K"][i]
		row.position = Vector2(110, 20 + i * 146)
		row.scale = Vector2.ONE * 1.9
		add_child(row)
		rows.append(row)


func present(rank: int, defeated_suits: Array, shown_rows: int) -> void:
	_shown_rows = shown_rows
	size.y = 21 + shown_rows * 146
	queue_redraw()
	for i in range(rows.size()):
		var tier := i + 11
		var row := rows[i]
		row.visible = i < shown_rows
		var suits: Array = BattleProgress.SUIT_ORDER if tier < rank else []
		if tier == rank:
			suits = defeated_suits
		row.reset()
		row.present(tier, suits)


func _draw() -> void:
	var line := Color(BRASS, 0.42)
	draw_rect(Rect2(12, 12, 926, size.y - 24), line, false, 2.0, true)
	for i in range(1, _shown_rows):
		var y := 10 + 146 * i
		draw_line(Vector2(65, y), Vector2(885, y), Color(BRASS, 0.33), 2, true)
