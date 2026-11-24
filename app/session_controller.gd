extends Node

signal view_changed

const Rules = preload("res://core/game_rules.gd")
const StepPlayer = preload("res://presentation/step_player.gd")
const Tutorial = preload("res://app/tutorial_script.gd")

var _rules: Rules
var _player: StepPlayer
var _session_id := 0
var _playback_id := -1
var _screen := "main_menu"
var _overlay := ""
var _busy := false
var _selected: Array = []
var _shown: Dictionary = {}
var _shown_step: Dictionary = {}
var _tutorial_active := false
var _tutorial_index := 0


func _init(step_seconds: float = 0.12, duration_for_step: Callable = Callable()) -> void:
	_player = StepPlayer.new(step_seconds, duration_for_step)
	add_child(_player)
	_player.step_shown.connect(_on_step_shown)
	_player.playback_finished.connect(_on_playback_finished)


func new_run(seed_value: int = -1) -> Dictionary:
	if not is_inside_tree() or is_queued_for_deletion():
		return _response(false, "not_ready")
	_clear_session()
	_screen = "battle"
	_rules = Rules.new()
	return _play_result(_rules.new_run(seed_value))


func restart(seed_value: int = -1) -> Dictionary:
	if _tutorial_active:
		return new_tutorial()
	return new_run(seed_value)


func new_tutorial() -> Dictionary:
	if not is_inside_tree() or is_queued_for_deletion():
		return _response(false, "not_ready")
	_clear_session()
	_tutorial_active = true
	_screen = "battle"
	_rules = Rules.new()
	return _play_result(_rules.new_tutorial_run(Tutorial.CARD_ORDER, Tutorial.ENEMY_SUITS))


func retry_tutorial() -> Dictionary:
	if not _tutorial_active or _screen != "result" or _shown.phase != "lost":
		return _response(false, "retry_unavailable")
	var operation := _rules.retry_tutorial()
	if not operation.ok:
		return _response(false, operation.error)
	_session_id += 1
	_shown = {}
	_shown_step = {}
	_screen = "battle"
	return _play_result(operation)


func advance_tutorial() -> Dictionary:
	var step := _tutorial_step()
	if _busy or not _overlay.is_empty() or step.is_empty() or step.has("play") or step.has("discard"):
		return _response(false, "no_tutorial_explanation")
	_tutorial_index += 1
	view_changed.emit()
	return _response(true)


func return_to_main_menu() -> Dictionary:
	_clear_session()
	view_changed.emit()
	return _response(true)


func get_view() -> Dictionary:
	var query := {"can_submit": false, "addable_ids": [], "total_value": 0, "effective_suits": []}
	var clickable: Array = []
	var guide := _tutorial_step()
	var input_open := _input_allowed()
	var at_play: bool = _screen == "battle" and not _busy and _shown.get("phase", "") == "play"
	if at_play:
		query = _rules.query_selection(_selected)
		if input_open:
			clickable = _selected + query.addable_ids
	elif input_open and _shown.get("phase", "") == "defense":
		clickable = _rules.query_defense()
	if not guide.is_empty():
		clickable = clickable.filter(func(id): return _tutorial_allows_card(guide, id))
	var can_submit: bool = at_play and input_open and query.can_submit and _tutorial_allows_submit(guide)
	var result: Dictionary = {}
	if _screen == "result":
		result = {"outcome": _shown.phase, "defeated": _shown.defeated, "reason": _shown.end_reason}
	return {
		"screen": _screen,
		"overlay": _overlay,
		"busy": _busy,
		"session_id": _session_id,
		"battle": _shown.duplicate(true),
		"step": _shown_step.duplicate(true),
		"selected_ids": _selected.duplicate(),
		"preview": {"total_value": query.total_value, "effective_suits": query.effective_suits.duplicate()},
		"clickable_ids": clickable.duplicate(),
		"can_submit": can_submit,
		"can_clear_selection": at_play and input_open and not _selected.is_empty(),
		"result": result,
		"tutorial_active": _tutorial_active,
		"guide": _guide_view(guide, can_submit),
	}


func click_card(card_id: String) -> Dictionary:
	if not _input_allowed():
		return _response(false, "input_locked")
	var guide := _tutorial_step()
	if not guide.is_empty() and not _tutorial_allows_card(guide, card_id):
		return _response(false, "card_not_selectable")
	if _shown.phase == "defense":
		return _play_result(_rules.discard_for_damage(card_id), not guide.is_empty())
	if _shown.phase != "play":
		return _response(false, "wrong_phase")
	if card_id in _selected:
		_selected.erase(card_id)
	elif card_id in _rules.query_selection(_selected).addable_ids:
		_selected.append(card_id)
	elif not _selected.is_empty() and _has_hand_card(card_id):
		# 已选牌时点击变暗的不可选手牌，直接清空本次选择。
		_selected = []
	else:
		return _response(false, "card_not_selectable")
	view_changed.emit()
	return _response(true)


func _has_hand_card(card_id: String) -> bool:
	for card in _shown.get("hand", []):
		if card.id == card_id:
			return true
	return false


func clear_selection() -> Dictionary:
	if not _input_allowed():
		return _response(false, "input_locked")
	if _shown.phase != "play":
		return _response(false, "wrong_phase")
	if not _selected.is_empty():
		_selected = []
		view_changed.emit()
	return _response(true)


func submit_play() -> Dictionary:
	if not _input_allowed():
		return _response(false, "input_locked")
	if _shown.phase != "play":
		return _response(false, "wrong_phase")
	var guide := _tutorial_step()
	if not _tutorial_allows_submit(guide):
		return _response(false, "tutorial_selection_incomplete")
	return _play_result(_rules.submit_play(_selected), not guide.is_empty())


func open_overlay(kind: String) -> Dictionary:
	if kind not in ["settings", "rules"]:
		return _response(false, "invalid_overlay")
	if _screen == "result":
		return _response(false, "result_visible")
	if _overlay != kind:
		_overlay = kind
		view_changed.emit()
	return _response(true)


func close_overlay() -> Dictionary:
	if not _overlay.is_empty():
		_overlay = ""
		view_changed.emit()
	return _response(true)


func _input_allowed() -> bool:
	var step := _tutorial_step()
	var explanation := not step.is_empty() and not step.has("play") and not step.has("discard")
	return _screen == "battle" and not _busy and not explanation and _overlay.is_empty() and not is_queued_for_deletion()


func _tutorial_step() -> Dictionary:
	if _tutorial_active and _screen == "battle" and _tutorial_index < Tutorial.STEPS.size():
		return Tutorial.STEPS[_tutorial_index]
	return {}


func _tutorial_allows_card(step: Dictionary, id: String) -> bool:
	return id in step.get("play", []) or id == step.get("discard", "")


func _tutorial_allows_submit(step: Dictionary) -> bool:
	return step.is_empty() or (step.has("play") and _selected.size() == step.play.size())


func _guide_view(step: Dictionary, can_submit: bool) -> Dictionary:
	if step.is_empty() or _busy or not _overlay.is_empty():
		return {}
	var cards: Array = step.get("play", step.get("cards", [])).duplicate()
	if step.has("discard"):
		cards.append(step.discard)
	var focus: Array = step.get("focus", []).duplicate()
	if can_submit:
		focus.append("submit")
	return {"id": _tutorial_index, "title": step.title, "text": step.text, "focus": focus,
		"cards": cards, "explanation": not step.has("play") and not step.has("discard"),
		"diagram": step.get("diagram", false)}


func _play_result(operation: Dictionary, advance_guide: bool = false) -> Dictionary:
	if not operation.ok:
		return _response(false, operation.error)
	if advance_guide:
		_tutorial_index += 1
	_selected = []
	_busy = true
	_playback_id = _player.play(operation.steps)
	# 只发变化通知；订阅方读取当前视图，避免重入后传播旧快照。
	view_changed.emit()
	return _response(true)


func _on_step_shown(id: int, index: int, step: Dictionary) -> void:
	if not _busy or id != _playback_id:
		return
	_shown = step.state.duplicate(true)
	_shown_step = {"playback_id": id, "index": index, "kind": step.kind, "data": step.data.duplicate(true)}
	view_changed.emit()


func _on_playback_finished(id: int) -> void:
	if not _busy or id != _playback_id:
		return
	_busy = false
	_playback_id = -1
	if _shown.get("phase", "") in ["won", "lost"]:
		_overlay = ""
		_screen = "result"
	# 订阅回调可重开或退出，发出后不再改写状态。
	view_changed.emit()


func _clear_session() -> void:
	_session_id += 1
	_player.cancel()
	_playback_id = -1
	_busy = false
	_overlay = ""
	_selected = []
	_shown = {}
	_shown_step = {}
	_rules = null
	_tutorial_active = false
	_tutorial_index = 0
	_screen = "main_menu"


func _response(ok: bool, error: String = "") -> Dictionary:
	return {"ok": ok, "error": error}


func _exit_tree() -> void:
	_clear_session()
