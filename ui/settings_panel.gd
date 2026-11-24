extends Panel

const Style = preload("res://ui/ui_style.gd")
const UserSettings = preload("res://app/user_settings.gd")
const FRAME = preload("res://assets/ui-art/controls/settings-panel.svg")
const MUSIC_ICON = preload("res://assets/ui-art/controls/settings-music.svg")
const SOUND_ICON = preload("res://assets/ui-art/controls/settings-sound.svg")
const SLIDER_GRIP = preload("res://assets/ui-art/controls/settings-slider-grip.svg")
const BUTTON_FRAME := "res://assets/ui-art/controls/rule_setting.png"
const VALUE_COLOR := Color("d4ba93")

var continue_button: Button
var _return_button: Button
var _status: Label


func _init(settings: UserSettings, close: Callable, return_to_menu: Callable, quit: Callable) -> void:
	name = "SettingsPanel"
	size = FRAME.get_size()
	position = (Vector2(2560, 1440) - size) / 2.0
	mouse_filter = MOUSE_FILTER_STOP
	var skin := StyleBoxTexture.new()
	skin.texture = FRAME
	add_theme_stylebox_override("panel", skin)

	var title := Style.label(self, "Title", "设置", Rect2(0, 40, size.x, 68), 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("e7d1af"))
	_make_audio_row("Music", "音乐", MUSIC_ICON, 176, settings.music_volume, settings.set_music_volume)
	_make_audio_row("SFX", "音效", SOUND_ICON, 282, settings.sfx_volume, settings.set_sfx_volume)
	_make_display_modes(settings)

	var actions := VBoxContainer.new()
	actions.name = "Actions"
	actions.position = Vector2(128, 556)
	actions.size.x = 464
	actions.add_theme_constant_override("separation", 20)
	add_child(actions)
	continue_button = _button(actions, "Continue", "继续", Rect2(), close, true)
	_return_button = _button(actions, "MainMenu", "返回主菜单", Rect2(), return_to_menu)
	var quit_button := _button(actions, "Quit", "退出游戏", Rect2(), quit)
	for item in [continue_button, _return_button, quit_button]:
		item.custom_minimum_size.y = 78
	continue_button.add_theme_font_size_override("font_size", 32)
	_status = Style.label(self, "SaveStatus", "", Rect2(56, 868, 608, 50), 23)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color("ef9a92"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func present(in_battle: bool) -> void:
	continue_button.text = "继续" if in_battle else "关闭"
	_return_button.visible = in_battle


func show_load_status(error: Error) -> void:
	_status.text = "" if error == OK else "设置未能读取，当前使用默认值。"


func _make_audio_row(node_name: String, caption: String, texture: Texture2D, y: float, level: float, set_level: Callable) -> void:
	var icon := TextureRect.new()
	icon.name = node_name + "Icon"
	icon.texture = texture
	icon.position = Vector2(60, y + 18)
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(icon)
	var label := Style.label(self, node_name + "Label", caption, Rect2(116, y, 110, 80), 28)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var value := Style.label(self, node_name + "Value", _percent(level * 100), Rect2(560, y, 100, 80), 28)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_color_override("font_color", VALUE_COLOR)

	var slider := HSlider.new()
	slider.name = node_name
	slider.accessibility_name = caption
	slider.position = Vector2(238, y)
	slider.size = Vector2(310, 80)
	slider.max_value = 100
	slider.step = 1
	slider.set_value_no_signal(level * 100)
	slider.add_theme_stylebox_override("slider", _rail(Color("4c3540")))
	slider.add_theme_stylebox_override("grabber_area", _rail(Color("a67a52")))
	slider.add_theme_stylebox_override("grabber_area_highlight", _rail(Color("cfa474")))
	slider.add_theme_icon_override("grabber", SLIDER_GRIP)
	slider.add_theme_icon_override("grabber_highlight", SLIDER_GRIP)
	add_child(slider)
	slider.value_changed.connect(func(amount: float):
		value.text = _percent(amount)
		_show_save_status(set_level.call(amount / 100.0))
	)


func _make_display_modes(settings: UserSettings) -> void:
	var label := Style.label(self, "DisplayLabel", "显示模式", Rect2(60, 398, 210, 72), 28)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var track := Panel.new()
	track.name = "DisplayMode"
	track.position = Vector2(272, 402)
	track.size = Vector2(386, 64)
	var base := Style.box(Color("1a111c"), Color("6d5145"), 2)
	base.set_corner_radius_all(7)
	track.add_theme_stylebox_override("panel", base)
	add_child(track)

	var selected := Style.box(Color("38242d"), Color("bd966b"), 2)
	selected.set_corner_radius_all(4)
	var hover := Style.box(Color("2b1c28"), Color.TRANSPARENT, 0)
	hover.set_corner_radius_all(4)
	var group := ButtonGroup.new()
	for i in range(2):
		var fullscreen := i == 1
		var item := Style.button(track, "Fullscreen" if fullscreen else "Windowed", "全屏" if fullscreen else "窗口",
			Rect2(5 + i * 188, 5, 188, 54), func(): _show_save_status(settings.set_fullscreen(fullscreen)))
		item.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		item.add_theme_stylebox_override("hover", hover)
		item.add_theme_stylebox_override("pressed", selected)
		item.add_theme_stylebox_override("hover_pressed", selected)
		item.add_theme_stylebox_override("focus", _focus_line())
		item.add_theme_color_override("font_color", Style.PAPER)
		item.add_theme_color_override("font_pressed_color", Color("efd4a8"))
		item.add_theme_color_override("font_hover_pressed_color", Color("efd4a8"))
		item.toggle_mode = true
		item.button_group = group
		item.set_pressed_no_signal(settings.fullscreen == fullscreen)


func _button(parent: Control, node_name: String, caption: String, rect: Rect2, action: Callable, primary := false) -> Button:
	var item := Style.button(parent, node_name, caption, rect, action)
	var tints := {
		"normal": Color(1.46, 1.26, 1.05) if primary else Color.WHITE,
		"hover": Color(1.58, 1.39, 1.15) if primary else Color(1.16, 1.10, 1.03),
		"pressed": Color(1.31, 1.18, 1.02),
	}
	for state in tints:
		var skin := Style.texture_box(BUTTON_FRAME, tints[state])
		item.add_theme_stylebox_override(state, skin)
		if skin is StyleBoxTexture:
			# 拉伸时保留边角。
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				skin.set_texture_margin(side, 20)
	item.add_theme_stylebox_override("focus", StyleBoxEmpty.new() if primary else _focus_line())
	item.add_theme_color_override("font_color", Color("f0d4aa") if primary else Style.PAPER)
	if primary:
		item.add_theme_color_override("font_focus_color", Color("f7e0bc"))
	item.add_theme_color_override("font_hover_color", Color("f7e0bc"))
	return item


func _focus_line() -> StyleBoxFlat:
	var mark := StyleBoxFlat.new()
	mark.draw_center = false
	mark.border_color = Color("f1d7a5")
	mark.border_width_bottom = 2
	return mark


func _rail(color: Color) -> StyleBoxFlat:
	var rail := StyleBoxFlat.new()
	rail.bg_color = color
	rail.content_margin_top = 3.0
	rail.content_margin_bottom = 3.0
	return rail


func _percent(value: float) -> String:
	return "%d%%" % roundi(value)


func _show_save_status(error: Error) -> void:
	_status.text = "" if error == OK else "设置未能保存，请确认本机目录可写。"
