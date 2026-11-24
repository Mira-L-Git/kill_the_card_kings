extends Node

signal step_shown(playback_id: int, step_index: int, step: Dictionary)
signal playback_finished(playback_id: int)

var _step_seconds: float
var _duration_for_step: Callable
var _generation := 0
var _steps: Array = []
var _index := -1
var _playing := false


func _init(step_seconds: float = 0.12, duration_for_step: Callable = Callable()) -> void:
	assert(step_seconds > 0.0)
	_step_seconds = step_seconds
	_duration_for_step = duration_for_step


func play(steps: Array) -> int:
	assert(is_inside_tree() and not steps.is_empty())
	cancel()
	_steps = steps.duplicate(true)
	_playing = true
	var id := _generation
	# 先返回标识，控制器才能在任何显示回调前完成输入锁定。
	_show_next.call_deferred(id)
	return id


func cancel() -> void:
	_generation += 1
	_playing = false
	_steps = []
	_index = -1


func is_playing() -> bool:
	return _playing


func _show_next(id: int) -> void:
	if not _is_current(id):
		return
	_index += 1
	if _index == _steps.size():
		_playing = false
		_steps = []
		# 回调可能立刻开始新播放，发出后不再改写成员。
		playback_finished.emit(id)
		return
	var index := _index
	step_shown.emit(id, index, _steps[index].duplicate(true))
	if not _is_current(id) or _index != index:
		return
	var seconds := _step_seconds
	if _duration_for_step.is_valid():
		seconds = maxf(seconds, _duration_for_step.call(_steps[index]))
	var timer := get_tree().create_timer(seconds, true, false, true)
	timer.timeout.connect(_on_step_elapsed.bind(id, index), CONNECT_ONE_SHOT)


func _on_step_elapsed(id: int, index: int) -> void:
	if not _is_current(id) or index != _index:
		return
	_show_next(id)


func _is_current(id: int) -> bool:
	return _playing and id == _generation and is_inside_tree() and not is_queued_for_deletion()


func _exit_tree() -> void:
	cancel()
