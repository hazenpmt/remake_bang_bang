extends Node

signal music_enabled_changed(is_enabled: bool)

const MUSIC_BUS := &"Music"
const LOGIN_BGM := preload("res://assets/audio/login_bgm.mp3")

var music_enabled := true
var _player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_music_bus()

	_player = AudioStreamPlayer.new()
	_player.name = "LoginBackgroundMusic"
	_player.bus = MUSIC_BUS

	var looping_stream := LOGIN_BGM.duplicate() as AudioStreamMP3
	looping_stream.loop = true
	_player.stream = looping_stream
	_player.finished.connect(_restart_music)
	add_child(_player)

	_apply_mute_state()
	_player.play()


func toggle_music() -> void:
	set_music_enabled(not music_enabled)


func set_music_enabled(is_enabled: bool) -> void:
	if music_enabled == is_enabled:
		return
	music_enabled = is_enabled
	_apply_mute_state()
	music_enabled_changed.emit(music_enabled)


func _restart_music() -> void:
	if _player != null:
		_player.play()


func _apply_mute_state() -> void:
	var bus_index := AudioServer.get_bus_index(MUSIC_BUS)
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, not music_enabled)


func _ensure_music_bus() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS) >= 0:
		return
	AudioServer.add_bus()
	var bus_index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, MUSIC_BUS)
	AudioServer.set_bus_send(bus_index, &"Master")
