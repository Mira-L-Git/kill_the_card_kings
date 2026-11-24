extends Control

const Session = preload("res://app/session_controller.gd")
const UserSettings = preload("res://app/user_settings.gd")
const BattleScreen = preload("res://ui/battle_screen.gd")
const EnemyMotion = preload("res://ui/enemy_motion.gd")
const HandView = preload("res://ui/hand_view.gd")
const CombatEffects = preload("res://ui/combat_effects.gd")
const PlayerDefeat = preload("res://ui/player_defeat.gd")
const JokerRevival = preload("res://ui/joker_revival.gd")
const BattleResult = preload("res://ui/battle_result.gd")
const SettingsPanel = preload("res://ui/settings_panel.gd")
const TutorialOverlay = preload("res://ui/tutorial_overlay.gd")
const RulesReference = preload("res://ui/rules_reference.gd")
const Style = preload("res://ui/ui_style.gd")
const BACKGROUND_PATH := "res://assets/backgrounds/dark-card-table-2560x1440-v1.png"
const MENU_TITLE_ART = preload("res://assets/ui-art/main-menu/title.svg")
const MENU_BUTTON_FRAME := "res://assets/ui-art/controls/rule_setting.png"
const BASE_STEP_SECONDS := 0.12

const TUTORIAL_RULES := """目标：击败四位 J 级牌王，完成新手教程。

出牌：一张普通牌（4—10）或将军牌（J/Q/K=11/12/13）；一张或多张同点数的 2/3；或者一张主牌搭配最多一张 A。可以先选 A，再选主牌，但 A 不能单独提交，也不能搭配 2/3。点击已选牌可取消，再点击“出牌”统一提交。

结算：所有出牌数值相加为 X，先造成 X 点基础伤害，再按红桃 → 方片 → 梅花 → 黑桃结算，每种花色只触发一次，均使用总数值 X。牌王同花色只封锁效果，不封锁基础伤害。
红桃：从弃牌堆随机回收最多 X 张，洗入抽牌堆底部。
方片：抽最多 X 张，手牌上限 8；普通抽空不自动回洗。
梅花：追加 X 点伤害。黑桃：本回合抵挡 X 点攻击。
本次出牌在所有效果结束后才进入弃牌堆，不能被本次红桃回收。

感化：全部效果结束后，牌王生命恰好为 0 才获得对应将军牌；手满则放抽牌堆顶。负生命只算击杀。击败的牌王不再反击。

抵伤：护盾先抵扣本回合攻击，再逐张点击手牌立即弃置，足额后自动结束。已弃牌不可撤回，A 与王牌不能抵伤。剩余牌总值不足也继续等待逐张弃置，不会替你弃牌。

死亡与复活：仅在出牌开始和敌方伤害阶段检查；手空或只剩 A 即死亡，最后一张牌即使足额抵伤也适用。先消耗大王，再消耗小王：旧手牌全弃，先抽现有抽牌堆，再仅随机回收缺牌张数并补至 8 张。敌方伤害阶段复活会结束该次伤害，护盾不跨回合。
合法提交后先完整结算，不会因中间手牌暂空而中断。击败非最终牌王后在下一场出牌开始检查死亡；击败最终牌王直接通关。没有王牌可复活时失败。

抽牌堆与弃牌堆仅显示数量。打开设置或规则时结算继续，但不能操作下方手牌。只记住本机设置，不保存单局进度。"""

var preferences_path := "user://preferences.cfg"
var step_seconds := BASE_STEP_SECONDS
var session: Node
var settings: UserSettings
var battle: BattleScreen
var _main: Control
var _menu_fade: Tween
var _overlay: ColorRect
var _settings_panel: SettingsPanel
var _rules_panel: Panel
var _tutorial_overlay: TutorialOverlay
var _rules_reference: RulesReference
var _result: BattleResult
var _menu_blackout: ColorRect
var _result_transition: Tween
var _rules_continue: Button
var _focus_route: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _make_theme()
	settings = UserSettings.new(preferences_path)
	var loaded := settings.load_preferences()
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color("17171f")
	background.size = Vector2(2560, 1440)
	background.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(background)
	var backdrop := TextureRect.new()
	backdrop.name = "Backdrop"
	backdrop.size = Vector2(2560, 1440)
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(BACKGROUND_PATH):
		backdrop.texture = load(BACKGROUND_PATH)
	add_child(backdrop)
	# 加速试玩或测试时，战斗动效与表现步进保持同一速度。
	var duration_scale := step_seconds / BASE_STEP_SECONDS
	session = Session.new(step_seconds, func(step):
		return max(
			EnemyMotion.hold_for_step(step), HandView.hold_for_step(step),
			CombatEffects.hold_for_step(step), PlayerDefeat.hold_for_step(step),
			JokerRevival.hold_for_step(step)
		) * duration_scale
	)
	session.name = "Session"
	add_child(session)
	battle = BattleScreen.new(duration_scale)
	battle.name = "BattleScreen"
	add_child(battle)
	battle.card_clicked.connect(func(id): session.click_card(id))
	battle.submit_requested.connect(func(): session.submit_play())
	battle.overlay_requested.connect(func(kind): session.open_overlay(kind))
	_build_main()
	_tutorial_overlay = TutorialOverlay.new()
	_tutorial_overlay.advanced.connect(func(): session.advance_tutorial())
	add_child(_tutorial_overlay)
	_rules_reference = RulesReference.new()
	_rules_reference.closed.connect(func(): session.close_overlay())
	add_child(_rules_reference)
	_build_overlay()
	_build_result()
	_menu_blackout = _modal("MenuBlackout")
	_menu_blackout.color = Color.BLACK
	_menu_blackout.focus_mode = Control.FOCUS_ALL
	_menu_blackout.gui_input.connect(func(_event): _menu_blackout.accept_event())
	_menu_blackout.hide()
	_settings_panel.show_load_status(loaded)
	session.view_changed.connect(_refresh)
	_refresh()


func _make_theme() -> Theme:
	var result := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
	result.default_font = font
	result.default_font_size = 28
	result.set_stylebox("normal", "Button", Style.box(Color("2a2a37")))
	result.set_stylebox("hover", "Button", Style.box(Color("373747"), Color("a5c8de")))
	result.set_stylebox("pressed", "Button", Style.box(Color("414153"), Color("a5ddf5")))
	result.set_stylebox("disabled", "Button", Style.box(Color("22222b"), Color("353540")))
	return result


func _build_main() -> void:
	_main = Control.new()
	_main.name = "MainMenu"
	_main.size = Vector2(2560, 1440)
	_main.mouse_filter = MOUSE_FILTER_IGNORE
	_main.hide()
	add_child(_main)
	var title := TextureRect.new()
	title.name = "Title"
	title.accessibility_name = "Kill the Card Kings"
	title.texture = MENU_TITLE_ART
	title.size = MENU_TITLE_ART.get_size()
	title.position = Vector2((_main.size.x - title.size.x) / 2.0, 234)
	title.mouse_filter = MOUSE_FILTER_IGNORE
	_main.add_child(title)
	_main_menu_button("Start", "开始游戏", 568, func(): session.new_run())
	_main_menu_button("Tutorial", "新手教程", 688, func(): session.new_tutorial())
	_main_menu_button("Settings", "设置", 808, func(): session.open_overlay("settings"))
	_main_menu_button("Quit", "退出游戏", 928, func(): get_tree().quit())
	_main.visibility_changed.connect(_animate_main_menu)


func _main_menu_button(node_name: String, caption: String, y: float, action: Callable) -> void:
	var item := Style.textured_button(_main, node_name, caption, Rect2(1056, y, 448, 96), MENU_BUTTON_FRAME, action)
	item.add_theme_font_size_override("font_size", 32)
	for state in ["normal", "pressed", "disabled", "focus"]:
		var skin := item.get_theme_stylebox(state) as StyleBoxTexture
		if skin == null:
			continue
		# 只拉伸边框中段，保留原素材的切角和描边。
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			skin.set_texture_margin(side, 20)
	var outline := item.get_theme_stylebox("focus") as StyleBoxTexture
	if outline != null:
		outline.draw_center = false
		outline.modulate_color = Color(1.45, 1.3, 1.13)
		item.add_theme_stylebox_override("hover", item.get_theme_stylebox("normal"))
		item.add_theme_color_override("font_hover_color", Style.PAPER)
		# 悬停复用焦点亮边；焦点已经画出时不叠加。
		item.draw.connect(func():
			if item.get_draw_mode() == BaseButton.DRAW_HOVER and not item.has_focus(true):
				item.draw_style_box(outline, Rect2(Vector2.ZERO, item.size))
		)


func _animate_main_menu() -> void:
	if _menu_fade != null:
		_menu_fade.kill()
	if _main.is_visible_in_tree():
		_main.modulate.a = 0.35
		_menu_fade = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_menu_fade.tween_property(_main, "modulate:a", 1.0, 0.24)


func _modal(node_name: String) -> ColorRect:
	var shade := ColorRect.new()
	shade.name = node_name
	shade.color = Color(0.03, 0.03, 0.05, 0.88)
	shade.size = Vector2(2560, 1440)
	shade.mouse_filter = MOUSE_FILTER_STOP
	add_child(shade)
	return shade


func _build_overlay() -> void:
	_overlay = _modal("Overlay")
	_overlay.gui_input.connect(_on_overlay_gui_input)
	var panel := Panel.new()
	_rules_panel = panel
	panel.name = "Panel"
	panel.position = Vector2(560, 160)
	panel.size = Vector2(1440, 1120)
	panel.add_theme_stylebox_override("panel", Style.box(Color("22222f")))
	_overlay.add_child(panel)
	Style.label(panel, "Title", "规则说明", Rect2(40, 24, 1360, 96), 40)
	var rules_text := RichTextLabel.new()
	rules_text.name = "RulesText"
	rules_text.position = Vector2(40, 140)
	rules_text.size = Vector2(1360, 700)
	rules_text.text = TUTORIAL_RULES
	rules_text.add_theme_font_size_override("normal_font_size", 26)
	panel.add_child(rules_text)
	_rules_continue = Style.button(panel, "Continue", "继续战斗", Rect2(40, 920, 280, 90), func(): session.close_overlay())
	Style.button(panel, "Restart", "重新开始", Rect2(360, 920, 280, 90), func(): session.restart())
	Style.button(panel, "MainMenu", "返回主菜单", Rect2(680, 920, 320, 90), func(): session.return_to_main_menu())
	Style.button(panel, "Quit", "退出游戏", Rect2(1040, 920, 320, 90), func(): get_tree().quit())
	_settings_panel = SettingsPanel.new(settings, func(): session.close_overlay(),
		func(): session.return_to_main_menu(), func(): get_tree().quit())
	_overlay.add_child(_settings_panel)


func _build_result() -> void:
	_result = BattleResult.new()
	_result.replay_requested.connect(_replay_after_result)
	_result.menu_requested.connect(func(): _transition_from_result(session.return_to_main_menu))
	_result.quit_requested.connect(func(): _transition_from_result(get_tree().quit, false))
	add_child(_result)


func _refresh() -> void:
	var view: Dictionary = session.get_view()
	var modal_open: bool = not view.overlay.is_empty() or view.screen == "result" or _menu_blackout.visible
	var guide: Dictionary = view.guide
	var explaining: bool = guide.get("explanation", false)
	for child in _main.get_children():
		if child is Button:
			child.disabled = modal_open
			child.focus_mode = Control.FOCUS_NONE if modal_open else Control.FOCUS_ALL
	for node_name in ["Settings", "Rules"]:
		var button: Button = battle.get_node(NodePath(node_name))
		button.disabled = modal_open or explaining
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
	_main.visible = view.screen == "main_menu"
	battle.visible = view.screen in ["battle", "result"]
	if battle.visible:
		if _menu_blackout.visible:
			view.clickable_ids = []
			view.can_submit = false
		battle.render(view)
	_tutorial_overlay.present(guide, battle.guide_targets(guide.get("focus", []), guide.get("cards", [])))
	var reference_open: bool = view.overlay == "rules" and not view.tutorial_active
	if reference_open:
		_rules_reference.show_on(battle)
	else:
		_rules_reference.dismiss()
	_overlay.visible = not view.overlay.is_empty() and not reference_open
	_overlay.color.a = 0.75 if view.overlay == "settings" else 0.88
	_rules_panel.visible = view.overlay == "rules" and view.tutorial_active
	_settings_panel.visible = view.overlay == "settings"
	_settings_panel.present(view.screen == "battle")
	if view.screen == "result":
		_result.present(view.battle, view.tutorial_active)
	else:
		_result.dismiss()
	var route: Array = [view.screen, view.overlay, _menu_blackout.visible, guide.get("id", -1)]
	if route != _focus_route:
		_focus_route = route
		# 只在路由变化时移交焦点，结算刷新不能打断滑块和键盘操作。
		if _menu_blackout.visible:
			_menu_blackout.grab_focus()
		elif _result.visible:
			_result.grab_focus()
		elif _settings_panel.visible:
			_settings_panel.continue_button.grab_focus()
		elif reference_open:
			_rules_reference.grab_focus()
		elif _rules_panel.visible:
			_rules_continue.grab_focus()
		elif _main.visible:
			_main.get_node("Start").grab_focus(true)
		elif explaining:
			_tutorial_overlay.grab_focus()
		elif not guide.is_empty() and not view.clickable_ids.is_empty():
			battle.hand.get_node(NodePath(view.clickable_ids.front())).grab_focus()
		else:
			battle.get_node("Settings").grab_focus()


func _replay_after_result() -> void:
	var view: Dictionary = session.get_view()
	var retry: bool = view.tutorial_active and view.result.get("outcome") == "lost"
	_transition_from_result(session.retry_tutorial if retry else session.new_run)


func _transition_from_result(change_page: Callable, reveal := true) -> void:
	if _result_transition != null or not _result.visible:
		return
	_result.lock_actions()
	_menu_blackout.color.a = 0.0
	_menu_blackout.show()
	_menu_blackout.grab_focus()
	_result_transition = create_tween().set_ignore_time_scale(true)
	_result_transition.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_result_transition.tween_property(_menu_blackout, "color:a", 1.0, 0.45)
	# 在全黑时切换页面，淡入结束后再恢复新页面操作。
	_result_transition.tween_callback(change_page)
	if not reveal:
		return
	_result_transition.tween_interval(0.08)
	_result_transition.tween_property(_menu_blackout, "color:a", 0.0, 0.62)
	_result_transition.tween_callback(func():
		_result_transition = null
		_menu_blackout.hide()
		_refresh()
	)


func _on_overlay_gui_input(event: InputEvent) -> void:
	if _settings_panel.visible and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_overlay.accept_event()
		session.close_overlay()


func _unhandled_key_input(event: InputEvent) -> void:
	if _menu_blackout.visible:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		var view: Dictionary = session.get_view()
		if not view.overlay.is_empty():
			session.close_overlay()
		elif view.screen != "result":
			session.open_overlay("settings")
		get_viewport().set_input_as_handled()
