extends RefCounted

const DEFAULT_VOLUME := 0.8

var music_volume := DEFAULT_VOLUME
var sfx_volume := DEFAULT_VOLUME
var fullscreen := false
var _path: String


func _init(path: String = "user://preferences.cfg") -> void:
	_path = path


func load_preferences() -> Error:
	var config := ConfigFile.new()
	var error := config.load(_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		apply()
		return error
	# 旧版总音量分别作为两条总线的初始值。
	var legacy_volume := _read_volume(config, "volume", DEFAULT_VOLUME)
	music_volume = _read_volume(config, "music_volume", legacy_volume)
	sfx_volume = _read_volume(config, "sfx_volume", legacy_volume)
	var stored_fullscreen = config.get_value("settings", "fullscreen", false)
	fullscreen = stored_fullscreen if stored_fullscreen is bool else false
	apply()
	return OK


func set_music_volume(value: float) -> Error:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volume(&"Music", music_volume)
	return _save()


func set_sfx_volume(value: float) -> Error:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volume(&"SFX", sfx_volume)
	return _save()


func set_fullscreen(value: bool) -> Error:
	fullscreen = value
	_apply_display()
	return _save()


func apply() -> void:
	_apply_volume(&"Music", music_volume)
	_apply_volume(&"SFX", sfx_volume)
	_apply_display()


func _read_volume(config: ConfigFile, key: String, fallback: float) -> float:
	var value: Variant = config.get_value("settings", key, fallback)
	return clampf(float(value), 0.0, 1.0) if value is float or value is int else fallback


func _apply_volume(bus_name: StringName, volume: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus, volume == 0.0)


func _apply_display() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func _save() -> Error:
	var config := ConfigFile.new()
	config.set_value("settings", "music_volume", music_volume)
	config.set_value("settings", "sfx_volume", sfx_volume)
	config.set_value("settings", "fullscreen", fullscreen)
	return config.save(_path)
