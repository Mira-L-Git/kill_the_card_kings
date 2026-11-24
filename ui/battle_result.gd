extends Control

signal replay_requested
signal menu_requested
signal quit_requested

const Style = preload("res://ui/ui_style.gd")
const ResultSeals = preload("res://ui/result_seals.gd")
const BUTTON_FRAME := "res://assets/ui-art/controls/rule_setting.png"
const GOLD := Color("edd4a4")
const BRASS := Color("9a7350")
const RED := Color("d57580")
const CRIMSON := Color("83444e")

var _shade: ColorRect
var _amber_glow: TextureRect
var _red_glow: TextureRect
var _gold_divider: Control
var _red_divider: Control
var _title: Label
var _summary: Label
var _ledger: ResultSeals
var _replay: Button
var _menu: Button
var _quit: Button
var _actions: Array[Button] = []
var _reveal: Tween


func _ready() -> void:
	name = "ResultPanel"
	size = Vector2(2560, 1440)
	mouse_filter = MOUSE_FILTER_STOP
	focus_mode = FOCUS_CLICK
	_build_backdrop()
	_title = _centered_label("Title", Rect2(760, 150, 1040, 163), 120)
	_title.add_theme_constant_override("shadow_offset_y", 5)
	_summary = _centered_label("Summary", Rect2(760, 373, 1040, 62), 39)
	_ledger = ResultSeals.new()
	add_child(_ledger)
	_replay = _add_action("Restart", "再来一局", Rect2(1000, 1012, 560, 102), func(): replay_requested.emit(), true)
	_menu = _add_action("MainMenu", "返回主菜单", Rect2(912, 1144, 350, 82), func(): menu_requested.emit())
	_quit = _add_action("Quit", "退出游戏", Rect2(1298, 1144, 350, 82), func(): quit_requested.emit())
	hide()


func present(battle: Dictionary, tutorial: bool) -> void:
	if visible:
		return
	var lost: bool = battle.phase == "lost"
	var rows := 1 if tutorial else 3
	var offset := 130.0 if tutorial else 0.0
	var title_y := 162.0 if lost else 150.0
	_title.text = "失败" if lost else "通关"
	_replay.text = "再来一局"
	if tutorial:
		_title.text = "教程失败" if lost else "教程通过"
		_replay.text = "再试一次" if lost else "开始游戏"
	_title.add_theme_font_size_override("font_size", 106 if tutorial else (142 if lost else 120))
	_title.add_theme_color_override("font_color", RED if lost else GOLD)
	_title.add_theme_color_override("font_shadow_color", Color("370e1d") if lost else Color("501e11"))
	_summary.text = "击败 %d / %d 位牌王" % [battle.defeated, battle.battle_total]
	_summary.add_theme_color_override("font_color", Color("e0aeb6") if lost else Color("dec19a"))
	_summary.position.y = 373 + offset
	_ledger.position.y = 465 + offset
	_ledger.present(battle.enemy.rank, battle.defeated_suits, rows)
	_amber_glow.visible = not lost
	_red_glow.visible = lost
	_gold_divider.visible = not lost
	_red_divider.visible = lost
	var divider := _red_divider if lost else _gold_divider
	divider.position.y = 345 + offset
	var glow := _red_glow if lost else _amber_glow
	_shade.color = Color(0.024, 0.010, 0.021, 0.82) if lost else Color(0.035, 0.026, 0.032, 0.78)
	_shade.modulate.a = 0.78
	glow.modulate.a = 0.0
	divider.modulate.a = 0.0
	_title.modulate.a = 0.0
	_title.position.y = title_y + offset + 12
	_summary.modulate.a = 0.0
	_ledger.modulate.a = 0.0
	for row in _ledger.rows:
		row.modulate.a = 0.12
	_replay.position.y = 849 if tutorial else 1012
	_menu.position = Vector2(1105, 977) if tutorial else Vector2(912, 1144)
	_actions.assign([_replay, _menu] if tutorial else [_replay, _menu, _quit])
	lock_actions()
	for button in [_replay, _menu, _quit]:
		button.hide()
		button.modulate.a = 0.0
	show()
	_reveal = create_tween().set_ignore_time_scale(true).set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_reveal.tween_property(_shade, "modulate:a", 1.0, 0.46)
	_reveal.tween_property(glow, "modulate:a", 1.0, 0.72 if lost else 0.66)
	_reveal.tween_property(divider, "modulate:a", 1.0, 0.48).set_delay(0.25 if lost else 0.0)
	_reveal.tween_property(_title, "modulate:a", 1.0, 0.82 if lost else 0.48)
	_reveal.tween_property(_title, "position:y", title_y + offset, 0.82 if lost else 0.48)
	_reveal.tween_property(_summary, "modulate:a", 1.0, 0.36).set_delay(0.38 if lost else 0.18)
	_reveal.tween_property(_ledger, "modulate:a", 1.0, 0.44).set_delay(0.30 if lost else 0.24)
	for i in range(rows):
		_reveal.tween_property(_ledger.rows[i], "modulate:a", 1.0, 0.32).set_delay((0.46 if lost else 0.36) + 0.17 * i)
	# 等最后一排印记完全点亮，再播放按钮淡入。
	_reveal.chain().tween_interval(0.12)
	_reveal.chain().tween_callback(_show_actions)
	for button in _actions:
		_reveal.tween_property(button, "modulate:a", 1.0, 0.32)
	_reveal.chain().tween_callback(_enable_actions)


func dismiss() -> void:
	if _reveal != null:
		_reveal.kill()
		_reveal = null
	hide()


func lock_actions() -> void:
	for button in _actions:
		button.disabled = true
		button.focus_mode = FOCUS_NONE


func _show_actions() -> void:
	for button in _actions:
		button.show()


func _enable_actions() -> void:
	for button in _actions:
		button.disabled = false
		button.focus_mode = FOCUS_ALL
	_actions.front().grab_focus()


func _build_backdrop() -> void:
	_shade = ColorRect.new()
	_shade.name = "Shade"
	_shade.color = Color(0.035, 0.026, 0.032, 0.78)
	_shade.size = size
	_shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_shade)
	_amber_glow = Style.result_glow(self, "AmberLight", PackedColorArray([
		Color(0.48, 0.32, 0.20, 0.80),
		Color(0.41, 0.25, 0.13, 0.54),
		Color(0.23, 0.13, 0.09, 0.24),
		Color(0.23, 0.13, 0.09, 0.0),
	]))
	_red_glow = Style.result_glow(self, "CrimsonLight", PackedColorArray([
		Color(0.47, 0.095, 0.135, 0.78),
		Color(0.35, 0.045, 0.084, 0.55),
		Color(0.17, 0.027, 0.05, 0.24),
		Color(0.17, 0.027, 0.05, 0.0),
	]))
	_gold_divider = Style.result_divider(self, BRASS, GOLD)
	_red_divider = Style.result_divider(self, CRIMSON, RED)


func _centered_label(node_name: String, rect: Rect2, font_size: int) -> Label:
	var label := Style.label(self, node_name, "", rect, font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _add_action(node_name: String, caption: String, rect: Rect2, action: Callable, primary := false) -> Button:
	var button := Style.textured_button(self, node_name, caption, rect, BUTTON_FRAME, action)
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 35 if primary else 28)
	var text_color := GOLD if primary else Style.PAPER
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_disabled_color", text_color)
	var tint := Color(1.42, 1.27, 1.1) if primary else Color(0.86, 0.81, 0.77)
	var colors := {
		"normal": tint,
		"disabled": tint,
		"hover": tint * Color(1.12, 1.12, 1.12),
		"pressed": tint * Color(0.87, 0.87, 0.87),
		"focus": Color(1.54, 1.39, 1.2),
	}
	for state in colors:
		var skin := Style.texture_box(BUTTON_FRAME, colors[state])
		if skin is StyleBoxTexture:
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				skin.set_texture_margin(side, 20)
			skin.draw_center = state != "focus"
		button.add_theme_stylebox_override(state, skin)
	return button
