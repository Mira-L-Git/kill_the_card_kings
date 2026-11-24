extends RefCounted

const Config = preload("res://core/rules_config.gd")
const RunState = preload("res://core/run_state.gd")

var _state: RefCounted = RunState.new()
var _rng := RandomNumberGenerator.new()
var _steps: Array = []
var _tutorial_checkpoint: RunState
var _tutorial_rng_state: int
var _checkpoint_battle := 0


func new_run(seed_value: int = -1) -> Dictionary:
	_state = RunState.new()
	_tutorial_checkpoint = null
	_checkpoint_battle = 0
	if seed_value == -1:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	var actual_seed: int = _rng.seed
	for suit in Config.SUITS:
		for rank in range(1, 11):
			_state.draw_pile.append(_card(suit, rank))
	_shuffle(_state.draw_pile)
	for rank in range(11, 14):
		var group: Array = []
		for suit in Config.SUITS:
			group.append(_card(suit, rank))
		_shuffle(group)
		_state.enemy_order.append_array(group)
	var result := _open_run()
	# 种子只用于开发复现，不属于公开状态或表现步骤。
	result["seed"] = actual_seed
	return result


func new_tutorial_run(card_order: Array, enemy_suits: Array) -> Dictionary:
	_state = RunState.new()
	_tutorial_checkpoint = null
	_checkpoint_battle = 3
	_rng.seed = 0
	var stock := {}
	for suit in Config.SUITS:
		for rank in range(1, 11):
			var card := _card(suit, rank)
			stock[card.id] = card
	for id in card_order:
		_state.draw_pile.append(stock[id])
		stock.erase(id)
	_state.draw_pile.append_array(stock.values())
	for suit in enemy_suits:
		_state.enemy_order.append(_card(suit, 11))
	return _open_run()


func retry_tutorial() -> Dictionary:
	if _tutorial_checkpoint == null:
		return _rejected("no_tutorial_checkpoint")
	_state = _tutorial_checkpoint.copy()
	_rng.state = _tutorial_rng_state
	_steps = []
	_spawn_enemy()
	_begin_play()
	return _result()


func _open_run() -> Dictionary:
	_steps = []
	_step("run_started")
	_draw(Config.HAND_LIMIT, "opening")
	_spawn_enemy()
	_begin_play()
	return _result()


func get_public_state() -> Dictionary:
	return {
		"phase": _state.phase,
		"hand": _state.hand.duplicate(true),
		"resolving": _state.resolving.duplicate(true),
		"draw_count": _state.draw_pile.size(),
		"discard_count": _state.discard_pile.size(),
		"jokers": _state.jokers.duplicate(),
		"enemy": _state.enemy.duplicate(true),
		"defeated": _state.defeated,
		"defeated_suits": _defeated_suits_at_current_rank(),
		# 编号跟随登场敌人，击败后的清理步骤仍属于旧战斗。
		"battle_number": _state.enemy_index + 1,
		"battle_total": _state.enemy_order.size(),
		"shield": _state.shield,
		"pending_damage": _state.pending_damage,
		"end_reason": _state.end_reason,
	}


func _defeated_suits_at_current_rank() -> Array:
	var suits: Array = []
	var rank: int = _state.enemy.get("rank", 0)
	for i in range(_state.defeated):
		var enemy: Dictionary = _state.enemy_order[i]
		if enemy.rank == rank:
			suits.append(enemy.suit)
	return suits


func query_selection(card_ids: Array) -> Dictionary:
	var cards := _selected_cards(card_ids)
	var owned := cards.size() == card_ids.size()
	var selectable: Array = []
	if _state.phase == "play" and owned:
		for card in _state.hand:
			if card.id in card_ids:
				continue
			var expanded: Array = cards.duplicate()
			expanded.append(card)
			if _valid_partial(expanded):
				selectable.append(card.id)
	var total := 0
	var suits: Array = []
	if owned:
		for card in cards:
			total += card.rank
		for suit in Config.SUITS:
			if suit != _state.enemy.get("suit", "") and _has_suit(cards, suit):
				suits.append(suit)
	var can_submit: bool = _state.phase == "play" and owned and _valid_play(cards)
	var error := ""
	if _state.phase != "play":
		error = "wrong_phase"
	elif not owned:
		error = "invalid_card_ids"
	elif not _valid_partial(cards):
		error = "invalid_combination"
	elif not can_submit:
		error = "incomplete_selection"
	return {
		"can_submit": can_submit,
		"addable_ids": selectable,
		"total_value": total,
		"effective_suits": suits,
		"error": error,
	}


func submit_play(card_ids: Array) -> Dictionary:
	var query := query_selection(card_ids)
	if not query.can_submit:
		return _rejected(query.error)
	_steps = []
	var cards := _selected_cards(card_ids)
	_state.phase = "resolving"
	for card in cards:
		_state.hand.erase(card)
	_state.resolving = cards
	_step("play_committed", {"card_ids": card_ids.duplicate(), "total_value": query.total_value})
	_damage(query.total_value, "base_damage")
	for suit in Config.SUITS:
		if not _has_suit(cards, suit):
			continue
		if suit == _state.enemy.suit:
			_step("suit_blocked", {"suit": suit})
			continue
		match suit:
			"hearts":
				_recycle(query.total_value, "hearts_recycled")
			"diamonds":
				_draw(query.total_value, "diamonds")
			"clubs":
				_damage(query.total_value, "clubs_damage")
			"spades":
				_state.shield = query.total_value
				_step("shield_gained", {"amount": query.total_value})
	_state.discard_pile.append_array(_state.resolving)
	_state.resolving = []
	_step("played_discarded", {"card_ids": card_ids.duplicate()})
	# 全部花色结束后才判断敌方死亡与感化。
	if _state.enemy.health <= 0:
		_defeat_enemy()
	else:
		_begin_defense()
	return _result()


func query_defense() -> Array:
	var ids: Array = []
	if _state.phase == "defense":
		for card in _state.hand:
			if card.rank != 1:
				ids.append(card.id)
	return ids


func discard_for_damage(card_id: String) -> Dictionary:
	if _state.phase != "defense":
		return _rejected("wrong_phase")
	if not card_id in query_defense():
		return _rejected("invalid_defense_card")
	_steps = []
	var card: Dictionary = _selected_cards([card_id])[0]
	_state.hand.erase(card)
	_state.discard_pile.append(card)
	var before: int = _state.pending_damage
	_state.pending_damage = maxi(0, before - card.rank)
	_step("defense_discarded", {"card_id": card_id, "value": card.rank, "damage_before": before})
	# 达标也先查死亡，不能让最后一张牌成为免死例外。
	if _check_death("defense"):
		if _state.phase != "lost":
			_finish_turn()
	elif _state.pending_damage == 0:
		_finish_turn()
	return _result()


func _card(suit: String, rank: int) -> Dictionary:
	return {"id": "%s_%d" % [suit, rank], "suit": suit, "rank": rank}


func _selected_cards(ids: Array) -> Array:
	var cards: Array = []
	var seen: Array = []
	for id in ids:
		if not id is String or id in seen:
			return []
		seen.append(id)
		var found := false
		for card in _state.hand:
			if card.id == id:
				cards.append(card)
				found = true
				break
		if not found:
			return []
	return cards


func _valid_play(cards: Array) -> bool:
	return not cards.is_empty() and _valid_partial(cards) and not (cards.size() == 1 and cards[0].rank == 1)


func _valid_partial(cards: Array) -> bool:
	if cards.is_empty():
		return true
	var rank: int = cards[0].rank
	if rank == 2 or rank == 3:
		for card in cards:
			if card.rank != rank:
				return false
		return true
	if cards.size() == 1:
		return true
	return cards.size() == 2 and ((rank == 1 and cards[1].rank >= 4) or (rank >= 4 and cards[1].rank == 1))


func _has_suit(cards: Array, suit: String) -> bool:
	for card in cards:
		if card.suit == suit:
			return true
	return false


func _shuffle(cards: Array) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap = cards[i]
		cards[i] = cards[j]
		cards[j] = swap


func _draw(amount: int, reason: String) -> void:
	var drawn: Array = []
	for i in range(mini(amount, Config.HAND_LIMIT - _state.hand.size())):
		if _state.draw_pile.is_empty():
			break
		var card: Dictionary = _state.draw_pile.pop_front()
		_state.hand.append(card)
		drawn.append(card.id)
	_step("cards_drawn", {"reason": reason, "requested": amount, "card_ids": drawn})


func _recycle(amount: int, kind: String) -> void:
	var recovered: Array = []
	for i in range(mini(amount, _state.discard_pile.size())):
		var index := _rng.randi_range(0, _state.discard_pile.size() - 1)
		recovered.append(_state.discard_pile.pop_at(index))
	_shuffle(recovered)
	# 只随机排列回收部分，现有抽牌堆顺序不动，尾端为堆底。
	_state.draw_pile.append_array(recovered)
	_step(kind, {"requested": amount, "count": recovered.size()})


func _damage(amount: int, kind: String) -> void:
	var before: int = _state.enemy.health
	_state.enemy.health -= amount
	_step(kind, {"amount": amount, "health_before": before})


func _spawn_enemy() -> void:
	_state.enemy = _state.enemy_order[_state.enemy_index].duplicate(true)
	var stats: Dictionary = Config.ENEMIES[_state.enemy.rank]
	_state.enemy["health"] = stats.health
	_state.enemy["max_health"] = stats.health
	_state.enemy["attack"] = stats.attack
	_state.phase = "resolving"
	_step("enemy_appeared")


func _defeat_enemy() -> void:
	_state.defeated += 1
	_step("enemy_defeated", {"pacified": _state.enemy.health == 0})
	if _state.enemy.health == 0:
		var card := _card(_state.enemy.suit, _state.enemy.rank)
		var destination := "hand"
		if _state.hand.size() < Config.HAND_LIMIT:
			_state.hand.append(card)
		else:
			_state.draw_pile.push_front(card)
			destination = "draw_top"
		_step("enemy_pacified", {"card": card.duplicate(true), "destination": destination})
	else:
		_state.removed_enemies.append(_state.enemy.id)
	_clear_shield()
	if _state.defeated == _state.enemy_order.size():
		_state.phase = "won"
		_state.end_reason = "all_enemies_defeated"
		_step("run_won")
		return
	_state.enemy_index += 1
	_spawn_enemy()
	_begin_play()
	if _state.enemy_index + 1 == _checkpoint_battle:
		_tutorial_checkpoint = _state.copy()
		_tutorial_rng_state = _rng.state


func _begin_defense() -> void:
	_state.phase = "resolving"
	_step("enemy_damage_started")
	if _check_death("defense"):
		if _state.phase != "lost":
			_finish_turn()
		return
	var shield_before: int = _state.shield
	_state.pending_damage = maxi(0, _state.enemy.attack - shield_before)
	_state.shield = maxi(0, shield_before - _state.enemy.attack)
	_step("shield_applied", {"attack": _state.enemy.attack, "shield_before": shield_before, "absorbed": mini(_state.enemy.attack, shield_before)})
	if _state.pending_damage == 0:
		_finish_turn()
	else:
		_state.phase = "defense"
		_step("defense_ready")


func _check_death(context: String) -> bool:
	for card in _state.hand:
		if card.rank != 1:
			return false
	_step("player_died", {"context": context})
	if _state.jokers.is_empty():
		_state.phase = "lost"
		_state.end_reason = "no_playable_cards"
		_state.pending_damage = 0
		_clear_shield()
		_step("run_lost", {"context": context})
		return true
	var joker: String = _state.jokers.pop_front()
	_state.spent_jokers.append(joker)
	_step("joker_spent", {"joker": joker})
	var old_hand: Array = _state.hand.duplicate(true)
	_state.discard_pile.append_array(_state.hand)
	_state.hand = []
	_step("revival_hand_discarded", {"cards": old_hand})
	_draw(Config.HAND_LIMIT, "revival_existing")
	var missing: int = Config.HAND_LIMIT - _state.hand.size()
	if missing > 0:
		_recycle(missing, "revival_recycled")
		_draw(missing, "revival_refill")
	_state.pending_damage = 0
	_clear_shield()
	_step("player_revived", {"context": context})
	return true


func _clear_shield() -> void:
	if _state.shield != 0:
		var before: int = _state.shield
		_state.shield = 0
		_step("shield_cleared", {"amount": before})


func _finish_turn() -> void:
	_state.pending_damage = 0
	_clear_shield()
	_step("turn_ended")
	_begin_play()


func _begin_play() -> void:
	_state.phase = "resolving"
	_step("play_started")
	_check_death("play")
	if _state.phase != "lost":
		_state.phase = "play"
		_step("play_ready")


func _step(kind: String, data: Dictionary = {}) -> void:
	_steps.append({"kind": kind, "data": data.duplicate(true), "state": get_public_state()})


func _result() -> Dictionary:
	return {"ok": true, "error": "", "steps": _steps.duplicate(true), "state": get_public_state()}


func _rejected(error: String) -> Dictionary:
	return {"ok": false, "error": error, "steps": [], "state": get_public_state()}
