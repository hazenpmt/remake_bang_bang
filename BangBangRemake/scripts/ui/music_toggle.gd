extends TextureButton

const MUSIC_ON_TEXTURE := preload("res://assets/auth/music_on.png")
const MUSIC_OFF_TEXTURE := preload("res://assets/auth/music_off.png")


func _ready() -> void:
	pressed.connect(MusicManager.toggle_music)
	MusicManager.music_enabled_changed.connect(_update_button)
	_update_button(MusicManager.music_enabled)


func _update_button(is_enabled: bool) -> void:
	var texture := MUSIC_ON_TEXTURE if is_enabled else MUSIC_OFF_TEXTURE
	texture_normal = texture
	texture_pressed = texture
	texture_hover = texture
	tooltip_text = "Tắt nhạc nền" if is_enabled else "Bật nhạc nền"
