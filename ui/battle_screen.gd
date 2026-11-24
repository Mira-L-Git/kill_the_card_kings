extends Control

signal card_clicked(card_id: String)
signal submit_requested
signal overlay_requested(kind: String)

const Style = preload("res://ui/ui_style.gd")
const HandView = preload("res://ui/hand_view.gd")
const BattleProgress = preload("res://ui/battle_progress.gd")
const EnemyMotion = preload("res://ui/enemy_motion.gd")
const PlayedCardsView = preload("res://ui/played_cards_view.gd")
const CombatEffects = preload("res://ui/combat_effects.gd")
const PlayerDefeat = preload("res://ui/player_defeat.gd")
const JokerRevival = preload("res://ui/joker_revival.gd")
const CardView = preload("res://ui/card_view.gd")
const CardShadow = preload("res://ui/card_shadow.gd")
const CardOutline = preload("res://ui/card_outline.gd")
const ENEMY_POSITION := Vector2(592, 248)
# 按两位攻击数值居中，数值变化时保持图标位置固定。
const STATUS_X := ENEMY_POSITION.x + 74.0
const STAT_CENTER_Y := ENEMY_POSITION.y - 48.0
const ATTACK_X := STATUS_X + 176.0
const STAT_FONT_SIZE := 44
const HEALTH_ICON = preload("res://assets/ui-art/controls/enemy-health.svg")
const ATTACK_ICON = preload("res://assets/ui-art/controls/enemy-attack.svg")
const SCYTHE_ICON = preload("res://assets/ui-art/controls/defense-scythe.svg")
const BATTLE_NUMERALS = preload("res://assets/ui-art/controls/enemy-numerals.ttf")
const STAT_COLOR := Color("e7d1af")
const STAT_WARNING_COLOR := Color("ef7c8b")
const PREVIEW_CARDS = preload("res://assets/ui-art/controls/play-preview-cards.svg")
const PREVIEW_SUIT_ART = preload("res://assets/ui-art/controls/play-preview-suits.svg")
const PREVIEW_SUIT_ORDER := ["hearts", "diamonds", "clubs", "spades"]
const PREVIEW_SUIT_CELL := 36
const ENEMY_ART_ROOT := "res://assets/enemies"
const BIG_JOKER_ART := "res://assets/cards/jokers-gothic-layered-v1/大王-成品-240x336.png"
const SMALL_JOKER_ART := "res://assets/cards/jokers-gothic-layered-v1/小王-成品-240x336.png"
const PILE_UI := "res://assets/ui-art/controls/pile.png"
const PLAY_UI := "res://assets/ui-art/controls/play.png"
const RULE_SETTING_UI := "res://assets/ui-art/controls/rule_setting.png"
const PILE_SIZE := Vector2(160, 160)
const PILE_TEXT_OFFSET := Vector2(-7, 7)
const JOKER_SIZE := Vector2(200, 280)
const BIG_JOKER_POSITION := Vector2(80, 1040)
const SMALL_JOKER_STACK_SCALE := 0.8
const SMALL_JOKER_STACK_POSITION := Vector2(226.6667, 1096)

var hand: HandView
var progress: BattleProgress
var health: Label
var attack: Label
var _health_icon: TextureRect
var _attack_icon: TextureRect
var enemy_name: Label
var enemy_art: TextureRect
var played_cards: PlayedCardsView
var preview: Label
var _preview_suits: Dictionary = {}
var defense_remaining: Label
var _defense_badge: Control
var draw_count: Label
var discard_count: Label
var big_joker: Control
var small_joker: Control
var _small_joker_shadow: CardShadow
var submit: Button
var _step_key: Array = []
var _session_id := -1
var _absorbed := 0
var _enemy_art_path := ""
var _enemy_motion: EnemyMotion
var _duration_scale: float
var _effects: CombatEffects
var _player_defeat: PlayerDefeat
var _joker_revival: JokerRevival
var _health_before_hit: Variant = null
var _pending_suit := ""


func _init(duration_scale: float = 1.0) -> void:
	_duration_scale = duration_scale


func _ready() -> void:
	size = Vector2(2560, 1440)
	mouse_filter = MOUSE_FILTER_IGNORE
	progress = BattleProgress.new()
	progress.position = Vector2(76, 26)
	add_child(progress)
	_health_icon = _make_stat_icon("HealthIcon", HEALTH_ICON, STATUS_X)
	_attack_icon = _make_stat_icon("AttackIcon", ATTACK_ICON, ATTACK_X)
	health = _make_stat_label("Health", STATUS_X + 48, 92, STAT_FONT_SIZE)
	attack = _make_stat_label("Attack", ATTACK_X + 48, 68, STAT_FONT_SIZE)
	health.add_theme_font_override("font", BATTLE_NUMERALS)
	attack.add_theme_font_override("font", BATTLE_NUMERALS)
	var enemy := Control.new()
	enemy.name = "Enemy"
	enemy.position = ENEMY_POSITION
	enemy.size = Vector2(424, 632)
	enemy.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(enemy)
	enemy_art = TextureRect.new()
	enemy_art.name = "Art"
	enemy_art.position = Vector2.ZERO
	enemy_art.size = enemy.size
	enemy_art.mouse_filter = MOUSE_FILTER_IGNORE
	enemy_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_art.stretch_mode = TextureRect.STRETCH_SCALE
	enemy_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	enemy_art.visible = false
	enemy.add_child(enemy_art)
	_enemy_motion = EnemyMotion.new(enemy_art, _duration_scale)
	enemy.add_child(_enemy_motion)
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			_enemy_motion.reset()
			hand.cancel_draw()
			_effects.reset()
			_player_defeat.reset()
			_joker_revival.reset()
			played_cards.clear()
			_defense_badge.hide()
	)
	enemy_name = Style.label(enemy, "Identity", "", Rect2(0, 246, 424, 140), 32)
	enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	played_cards = PlayedCardsView.new()
	played_cards.position = Vector2(1248, 496)
	add_child(played_cards)
	_make_play_preview()
	big_joker = _make_joker("BigJoker", BIG_JOKER_ART, BIG_JOKER_POSITION)
	small_joker = _make_joker("SmallJoker", SMALL_JOKER_ART, SMALL_JOKER_STACK_POSITION)
	small_joker.clip_contents = true
	_small_joker_shadow = CardShadow.new()
	small_joker.add_child(_small_joker_shadow)
	move_child(big_joker, -1)
	_make_pile_art("DrawPileArt", Vector2(2144, 1216))
	_make_pile_art("DiscardPileArt", Vector2(2320, 1216))
	# pile.png 前方牌面中心在 (73,87)，相对整图中心 (80,80) 左移 7、下移 7。
	draw_count = Style.label(self, "DrawPile", "", Rect2(2144 + PILE_TEXT_OFFSET.x, 1216 + PILE_TEXT_OFFSET.y, PILE_SIZE.x, PILE_SIZE.y), 24)
	discard_count = Style.label(self, "DiscardPile", "", Rect2(2320 + PILE_TEXT_OFFSET.x, 1216 + PILE_TEXT_OFFSET.y, PILE_SIZE.x, PILE_SIZE.y), 24)
	for pile in [draw_count, discard_count]:
		pile.add_theme_color_override("font_color", Color("e9e4d8"))
		pile.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pile.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_make_defense_badge()
	hand = HandView.new()
	add_child(hand)
	hand.card_clicked.connect(func(id): card_clicked.emit(id))
	_effects = CombatEffects.new(_duration_scale)
	add_child(_effects)
	submit = Style.textured_button(self, "Submit", "出牌", Rect2(1968, 1120, 160, 96), PLAY_UI, func(): submit_requested.emit())
	Style.textured_button(self, "Rules", "规则", Rect2(2152, 40, 160, 72), RULE_SETTING_UI, func(): overlay_requested.emit("rules"))
	Style.textured_button(self, "Settings", "设置", Rect2(2336, 40, 160, 72), RULE_SETTING_UI, func(): overlay_requested.emit("settings"))
	_player_defeat = PlayerDefeat.new(size, played_cards.position + played_cards.size / 2.0, _duration_scale)
	add_child(_player_defeat)
	_joker_revival = JokerRevival.new(_duration_scale)
	add_child(_joker_revival)


func render(view: Dictionary) -> void:
	if view.session_id != _session_id:
		_session_id = view.session_id
		_step_key = []
		_absorbed = 0
		_effects.reset()
		_player_defeat.reset()
		_joker_revival.reset()
		_pending_suit = ""
		_health_before_hit = null
		hand.cancel_draw()
		_enemy_motion.reset()
		progress.reset()
		played_cards.clear()
		_defense_badge.hide()
	if view.screen == "result" and _player_defeat.visible:
		_player_defeat.reset()
	var step: Dictionary = view.step
	var cue := ""
	if not step.is_empty():
		var key: Array = [view.session_id, step.playback_id, step.index]
		if key != _step_key:
			_step_key = key
			cue = step.kind
			_effects.reset()
			if not _pending_suit.is_empty():
				played_cards.resolve_suit(_pending_suit)
				_pending_suit = ""
			if cue in ["enemy_defeated", "enemy_damage_started"]:
				played_cards.clear()
			_health_before_hit = step.data.health_before if cue in ["base_damage", "clubs_damage"] else null
			if step.kind in ["run_started", "play_started", "turn_ended", "enemy_appeared"]:
				_absorbed = 0
			elif step.kind == "shield_applied":
				_absorbed = step.data.absorbed
	var state: Dictionary = view.battle
	var enemy: Dictionary = state.get("enemy", {})
	progress.present(enemy.get("rank", 11), state.get("defeated_suits", []))
	_update_enemy_stats(enemy)
	_update_enemy_art(enemy)
	if enemy_art.texture != null:
		match cue:
			"enemy_appeared":
				_enemy_motion.play_entrance()
			"enemy_defeated":
				_enemy_motion.play_defeat(step.data.pacified)
	var moving_piles: bool = step.get("kind") in ["hearts_recycled", "played_discarded"]
	if not moving_piles and not (view.busy and step.get("kind") == "defense_discarded"):
		_set_discard_count(state.get("discard_count", 0))
	if not cue.is_empty():
		_play_combat_cue(step, state, enemy)
	# 消耗的 Joker 由演出接管，剩下的小王等碎裂结束才移到前面。
	if step.get("kind") != "joker_spent":
		_layout_jokers(state)
	preview.text = str(view.preview.total_value)
	preview.accessibility_name = "出牌数值 " + preview.text
	for suit in _preview_suits:
		_preview_suits[suit].visible = suit in view.preview.effective_suits
	var stock: int = state.get("draw_count", 0)
	var cards: Array = state.get("hand", [])
	var diamond_draw: bool = step.get("kind") == "cards_drawn" and step.data.reason == "diamonds"
	if not diamond_draw:
		if cue == "cards_drawn" and not step.data.card_ids.is_empty():
			_play_hand_draw(cards, step.data.card_ids, stock)
		elif not hand.is_drawing() or not cue.is_empty():
			if not moving_piles:
				_set_draw_count(stock)
			var guide: Dictionary = view.get("guide", {})
			if view.overlay == "rules" and not view.get("tutorial_active", false):
				# 规则页的遮罩统一控制明暗，手牌保持原亮度。
				guide = {"focus": ["hand"]}
			hand.render(cards, view.selected_ids, view.clickable_ids, guide)
	submit.disabled = not view.can_submit
	submit.focus_mode = Control.FOCUS_ALL if view.can_submit else Control.FOCUS_NONE


func guide_targets(focus: Array, cards: Array = []) -> Array[Control]:
	var targets: Array[Control] = []
	if focus.is_empty() and cards.is_empty():
		return targets
	if "stats" in focus:
		targets.append_array([_health_icon, health, _attack_icon, attack])
	if "progress" in focus:
		targets.append(progress)
	if "enemy" in focus:
		targets.append(enemy_art)
	if "piles" in focus:
		targets.append_array([get_node("DrawPileArt"), get_node("DiscardPileArt")])
	if "submit" in focus:
		targets.append(submit)
	if "defense" in focus:
		targets.append_array([_defense_badge.get_child(0), defense_remaining])
	if "jokers" in focus:
		targets.append_array([big_joker, small_joker])
	for card in hand.get_children():
		if "hand" in focus or card.card_id in cards:
			targets.append(card)
	return targets


func _set_draw_count(stock: int) -> void:
	draw_count.text = "抽牌堆\n\n%d" % stock


func _set_discard_count(stock: int) -> void:
	discard_count.text = "弃牌堆\n\n%d" % stock


func _make_defense_badge() -> void:
	_defense_badge = Control.new()
	_defense_badge.name = "DefenseBadge"
	_defense_badge.position = played_cards.position + played_cards.size / 2.0 - Vector2(156, 52)
	_defense_badge.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_defense_badge)
	var icon := TextureRect.new()
	icon.texture = SCYTHE_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = Vector2(104, 104)
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	_defense_badge.add_child(icon)
	defense_remaining = Style.label(_defense_badge, "Remaining", "", Rect2(110, 0, 100, 104), 66)
	defense_remaining.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	defense_remaining.add_theme_font_override("font", BATTLE_NUMERALS)
	defense_remaining.add_theme_color_override("font_color", STAT_COLOR)
	defense_remaining.add_theme_color_override("font_outline_color", Color("1d151e"))
	defense_remaining.add_theme_constant_override("outline_size", 4)
	_defense_badge.hide()


func _set_defense_remaining(amount: int) -> void:
	defense_remaining.text = str(amount)
	defense_remaining.accessibility_name = "待抵伤 " + defense_remaining.text


func _play_hand_draw(cards: Array, ids: Array, stock: int) -> void:
	hand.play_draw(cards, ids, draw_count.position + PILE_SIZE / 2.0, _duration_scale, func(remaining):
		_set_draw_count(stock + remaining)
	)


func _make_play_preview() -> void:
	var row := HBoxContainer.new()
	row.name = "PlayPreview"
	row.position = Vector2(640, 900)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_add_preview_icon(row, "Cards", PREVIEW_CARDS)
	preview = Style.label(row, "Total", "0", Rect2(), 40)
	preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview.add_theme_font_override("font", BATTLE_NUMERALS)
	preview.add_theme_color_override("font_color", STAT_COLOR)
	for i in range(PREVIEW_SUIT_ORDER.size()):
		var suit: String = PREVIEW_SUIT_ORDER[i]
		var texture := AtlasTexture.new()
		texture.atlas = PREVIEW_SUIT_ART
		texture.region = Rect2(i * PREVIEW_SUIT_CELL, 0, PREVIEW_SUIT_CELL, PREVIEW_SUIT_CELL)
		texture.filter_clip = true
		var icon := _add_preview_icon(row, suit, texture)
		icon.accessibility_name = "生效花色 " + Style.SUITS[suit].get_slice(" ", 0)
		icon.hide()
		_preview_suits[suit] = icon


func _add_preview_icon(row: HBoxContainer, node_name: String, texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = node_name
	icon.texture = texture
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(icon)
	return icon


func _make_joker(node_name: String, path: String, at: Vector2) -> Control:
	var item := Control.new()
	item.name = node_name
	item.position = at
	item.size = JOKER_SIZE
	item.mouse_filter = MOUSE_FILTER_IGNORE
	item.clip_children = CLIP_CHILDREN_ONLY
	var outline := PackedVector2Array(CardOutline.JOKER)
	item.draw.connect(func():
		var ratio := item.size / CardOutline.ART_SIZE
		var resize := Transform2D(Vector2(ratio.x, 0), Vector2(0, ratio.y), Vector2.ZERO)
		item.draw_colored_polygon(resize * outline, Color.WHITE)
	)
	item.resized.connect(item.queue_redraw)
	var art := TextureRect.new()
	art.name = "Art"
	art.mouse_filter = MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(path):
		art.texture = load(path)
	item.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(item)
	return item


func _make_pile_art(node_name: String, at: Vector2) -> TextureRect:
	var item := TextureRect.new()
	item.name = node_name
	item.position = at
	item.size = PILE_SIZE
	item.mouse_filter = MOUSE_FILTER_IGNORE
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_SCALE
	item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(PILE_UI):
		item.texture = load(PILE_UI)
	add_child(item)
	return item


func _layout_jokers(state: Dictionary) -> void:
	var jokers: Array = state.get("jokers", [])
	var has_big := "big" in jokers
	var has_small := "small" in jokers
	big_joker.visible = has_big
	small_joker.visible = has_small
	if has_big:
		big_joker.position = BIG_JOKER_POSITION
		big_joker.size = JOKER_SIZE
		var small_size := JOKER_SIZE * SMALL_JOKER_STACK_SCALE
		small_joker.size = small_size
		small_joker.position = Vector2(
			BIG_JOKER_POSITION.x + JOKER_SIZE.x - small_size.x / 3.0,
			BIG_JOKER_POSITION.y + JOKER_SIZE.y - small_size.y
		)
		if has_small:
			_small_joker_shadow.place(BIG_JOKER_POSITION.x + JOKER_SIZE.x - small_joker.position.x, small_size.x * 0.18, false)
		else:
			_small_joker_shadow.clear()
	elif has_small:
		# 大王碎裂后，小王移到大的位置，保持同一底边。
		small_joker.size = JOKER_SIZE
		small_joker.position = BIG_JOKER_POSITION
		_small_joker_shadow.clear()
	else:
		_small_joker_shadow.clear()


func _make_stat_icon(node_name: String, texture: Texture2D, x: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = node_name
	icon.texture = texture
	icon.position = Vector2(x, STAT_CENTER_Y - 20.0)
	icon.size = Vector2(40, 40)
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(icon)
	return icon


func _make_stat_label(node_name: String, x: float, width: float, font_size: int) -> Label:
	var label := Style.label(self, node_name, "", Rect2(x, STAT_CENTER_Y - 48.0, width, 96), font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", STAT_COLOR)
	label.add_theme_color_override("font_outline_color", Color("1d151e"))
	label.add_theme_constant_override("outline_size", 4)
	return label


func _update_enemy_stats(enemy: Dictionary) -> void:
	var has_enemy := not enemy.is_empty()
	_health_icon.visible = has_enemy
	_attack_icon.visible = has_enemy
	health.visible = has_enemy
	attack.visible = has_enemy
	var remaining_health: int = enemy.get("health", 0) if _health_before_hit == null else _health_before_hit
	health.text = str(remaining_health).replace("-", "−")
	health.accessibility_name = "生命 " + health.text
	health.add_theme_color_override("font_color", STAT_WARNING_COLOR if remaining_health < 10 else STAT_COLOR)
	attack.text = str(maxi(0, enemy.get("attack", 0) - _absorbed))
	attack.accessibility_name = "攻击 " + attack.text
	attack.add_theme_color_override("font_color", STAT_WARNING_COLOR if _absorbed > 0 else STAT_COLOR)


static func enemy_art_path(enemy: Dictionary) -> String:
	var suit: String = str(enemy.get("suit", ""))
	var face: String = {11: "j", 12: "q", 13: "k"}.get(enemy.get("rank", 0), "")
	if suit.is_empty() or face.is_empty():
		return ""
	return "%s/%s-%s.png" % [ENEMY_ART_ROOT, suit, face]


func _update_enemy_art(enemy: Dictionary) -> void:
	if enemy.is_empty():
		_enemy_art_path = ""
		enemy_art.texture = null
		enemy_art.visible = false
		enemy_name.hide()
		enemy_name.text = ""
		return
	var path := enemy_art_path(enemy)
	if path != _enemy_art_path:
		_enemy_art_path = path
		enemy_art.texture = load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
		_enemy_motion.reset()
	enemy_name.visible = enemy_art.texture == null
	enemy_name.text = "%s\n%s" % [Style.SUITS.get(enemy.get("suit", ""), ""), Style.rank_text(enemy.get("rank", 0))] if enemy_name.visible else ""
	enemy_art.tooltip_text = "%s %s" % [Style.SUITS.get(enemy.get("suit", ""), ""), Style.rank_text(enemy.get("rank", 0))]


func _play_combat_cue(step: Dictionary, state: Dictionary, enemy: Dictionary) -> void:
	match step.kind:
		"play_committed":
			played_cards.play_from_hand(state.resolving, hand, _duration_scale)
		"base_damage":
			_pending_suit = enemy.suit
			_strike(enemy, step.data.amount)
			var beat := _effects.timeline()
			beat.tween_interval(CombatEffects.HIT_TIME)
			beat.tween_callback(played_cards.resolve_suit.bind(enemy.suit))
		"clubs_damage":
			var beat := _suit_beat("clubs")
			beat.tween_callback(_strike.bind(enemy, step.data.amount))
			_finish_suit(beat, "clubs", CombatEffects.HIT_TIME)
		"hearts_recycled":
			var beat := _suit_beat("hearts")
			var count: int = step.data.count
			_set_draw_count(state.draw_count - count)
			_set_discard_count(state.discard_count + count)
			beat.tween_callback(_recycle_cards.bind(state, count))
			_finish_suit(beat, "hearts", CombatEffects.transfer_duration(count))
		"cards_drawn":
			if step.data.reason == "diamonds":
				var beat := _suit_beat("diamonds")
				var ids: Array = step.data.card_ids
				_set_draw_count(state.draw_count + ids.size())
				if not ids.is_empty():
					beat.tween_callback(_play_hand_draw.bind(state.hand, ids, state.draw_count))
				_finish_suit(beat, "diamonds", HandView.hold_for_step(step))
		"shield_gained":
			var beat := _suit_beat("spades")
			beat.tween_callback(_effects.shield)
			beat.tween_interval(CombatEffects.SHIELD_FORM)
			beat.tween_callback(_reduce_attack.bind(enemy, state.shield))
			_finish_suit(beat, "spades", CombatEffects.HIT_TIME)
		"suit_blocked":
			played_cards.resolve_suit(step.data.get("suit", ""))
		"played_discarded":
			var before: int = state.discard_count - step.data.card_ids.size()
			_set_draw_count(state.draw_count)
			_set_discard_count(before)
			played_cards.fly_to_discard(discard_count.position + PILE_SIZE / 2.0, _duration_scale, func(arrived):
				_set_discard_count(before + arrived)
			)
		"defense_ready":
			_set_defense_remaining(state.pending_damage)
			_defense_badge.modulate.a = 0.0
			_defense_badge.show()
			_effects.timeline().tween_property(_defense_badge, "modulate:a", 1.0, CombatEffects.DEFENSE_ENTER)
		"defense_discarded":
			_play_defense_discard(step.data, state.pending_damage, state.discard_count)
		"turn_ended":
			if _defense_badge.visible:
				_set_defense_remaining(state.pending_damage)
				var fade := _effects.timeline()
				fade.tween_property(_defense_badge, "modulate:a", 0.0, CombatEffects.DEFENSE_FADE)
				fade.tween_callback(_defense_badge.hide)
		"player_died", "play_started":
			_defense_badge.hide()
		"joker_spent":
			_play_joker_revival(step.data.joker)
		"revival_hand_discarded":
			_joker_revival.reset()
			_player_defeat.reset()
		"run_lost":
			if PlayerDefeat.hold_for_step(step) > 0.0:
				_player_defeat.play()


func _play_joker_revival(joker: String) -> void:
	var source: Control = big_joker if joker == "big" else small_joker
	_player_defeat.play_revival(JokerRevival.SHATTER_WINDUP, JokerRevival.DISSOLVE_TIME)
	_joker_revival.play(joker, source.get_rect(), size / 2.0, func():
		source.hide()
		_small_joker_shadow.clear()
	)


func _play_defense_discard(data: Dictionary, remaining: int, stock: int) -> void:
	_set_defense_remaining(data.damage_before)
	_set_discard_count(stock - 1)
	var source := hand.get_node_or_null(NodePath(data.card_id)) as CardView
	var beat := _effects.fly_discard(source, discard_count.position + PILE_SIZE / 2.0)
	beat.tween_callback(_set_discard_count.bind(stock))
	_effects.change_number(defense_remaining, data.damage_before - remaining, STAT_WARNING_COLOR, _set_defense_remaining.bind(remaining), beat)


func _suit_beat(suit: String) -> Tween:
	_pending_suit = suit
	played_cards.shake_suit(suit, CombatEffects.SUIT_SHAKE, _duration_scale)
	var beat := _effects.timeline()
	beat.tween_interval(CombatEffects.SUIT_SHAKE)
	return beat


func _finish_suit(beat: Tween, suit: String, seconds: float) -> void:
	if seconds > 0.0:
		beat.tween_interval(seconds)
	beat.tween_callback(played_cards.resolve_suit.bind(suit))


func _strike(enemy: Dictionary, amount: int) -> void:
	_effects.slash(enemy_art if enemy_art.visible else enemy_name, ENEMY_POSITION + Vector2(212, 316))
	_effects.change_number(health, amount, STAT_WARNING_COLOR, func():
		_health_before_hit = null
		_update_enemy_stats(enemy)
	)


func _reduce_attack(enemy: Dictionary, shield: int) -> void:
	var absorbed := mini(enemy.attack, shield)
	_effects.change_number(attack, absorbed - _absorbed, Color("98dbf2"), func():
		_absorbed = absorbed
		_update_enemy_stats(enemy)
	)


func _recycle_cards(state: Dictionary, count: int) -> void:
	_effects.transfer(count, discard_count.position + PILE_SIZE / 2.0, draw_count.position + PILE_SIZE / 2.0, func(departed, arrived):
		_set_discard_count(state.discard_count + count - departed)
		_set_draw_count(state.draw_count - count + arrived)
	)


