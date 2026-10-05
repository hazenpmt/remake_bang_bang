extends Control

const CHARACTER_SCENE := "res://scenes/auth/CharacterSelect.tscn"
const CHARACTER_ROSTER_SCENE := "res://scenes/auth/CharacterRoster.tscn"
const LOGIN_PREFERENCES_FILE := "user://login_preferences.cfg"
const ADMIN_LOGIN_USERNAME := "admin"
const MIN_CREDENTIAL_LENGTH := 6
const MAX_CREDENTIAL_LENGTH := 15

@onready var login_form: VBoxContainer = %LoginForm
@onready var register_form: VBoxContainer = %RegisterForm
@onready var login_username: LineEdit = %LoginUsername
@onready var login_password: LineEdit = %LoginPassword
@onready var register_username: LineEdit = %RegisterUsername
@onready var register_password: LineEdit = %RegisterPassword
@onready var register_password_confirm: LineEdit = %RegisterPasswordConfirm
@onready var remember_account: CheckBox = %RememberAccount
@onready var login_agreement: CheckBox = %LoginAgreement
@onready var register_agreement: CheckBox = %RegisterAgreement
@onready var toggle_login_password: Button = %BtnToggleLoginPassword
@onready var toggle_register_password: Button = %BtnToggleRegisterPassword
@onready var toggle_register_confirm: Button = %BtnToggleRegisterConfirm
@onready var status_label: Label = %StatusLabel
@onready var busy_indicator: ProgressBar = %BusyIndicator
@onready var controls: Control = %Controls


func _ready() -> void:
	%BtnLogin.pressed.connect(_on_login_pressed)
	%BtnOpenRegister.pressed.connect(_show_register)
	%BtnRegister.pressed.connect(_on_register_pressed)
	%BtnBackToLogin.pressed.connect(_show_login)
	toggle_login_password.toggled.connect(
		func(is_visible: bool) -> void:
			_set_password_visible(login_password, toggle_login_password, is_visible)
	)
	toggle_register_password.toggled.connect(
		func(is_visible: bool) -> void:
			_set_password_visible(register_password, toggle_register_password, is_visible)
	)
	toggle_register_confirm.toggled.connect(
		func(is_visible: bool) -> void:
			_set_password_visible(
				register_password_confirm,
				toggle_register_confirm,
				is_visible
			)
	)
	remember_account.toggled.connect(_on_remember_account_toggled)
	login_password.text_submitted.connect(func(_value: String) -> void: _on_login_pressed())
	register_password_confirm.text_submitted.connect(
		func(_value: String) -> void: _on_register_pressed()
	)
	_load_login_preferences()

	if not GameSession.token.is_empty():
		await _resume_saved_session()
	else:
		login_username.grab_focus()


func _resume_saved_session() -> void:
	_set_busy(true, "Đang kiểm tra phiên đăng nhập...")
	var result: Dictionary = await GameSession.validate_saved_session()
	if result.get("ok", false):
		_route_after_auth(result)
		return
	_set_busy(false, "")
	login_username.grab_focus()


func _on_login_pressed() -> void:
	if login_username.text.strip_edges().is_empty() or login_password.text.is_empty():
		_show_error("Hãy nhập tài khoản và mật khẩu.")
		return
	if not _login_credentials_have_valid_length(
		login_username.text,
		login_password.text
	):
		_show_error(
			"Tài khoản phải dài từ 6 đến 15 ký tự "
			+ "(riêng admin được phép 5 ký tự)."
		)
		return
	if not login_agreement.button_pressed:
		_show_error("Bạn phải tích “Đã đọc và đồng ý” trước khi đăng nhập.")
		return

	_set_busy(true, "Đang đăng nhập...")
	var result: Dictionary = await GameSession.login_account(
		login_username.text,
		login_password.text
	)
	if result.get("ok", false):
		_save_login_preferences()
		_route_after_auth(result)
		return
	_set_busy(false, "")
	_show_error(_error_message(result))


func _on_register_pressed() -> void:
	if register_password.text != register_password_confirm.text:
		_show_error("Hai mật khẩu chưa giống nhau.")
		return
	if register_username.text.strip_edges().is_empty():
		_show_error("Hãy nhập tên tài khoản.")
		return
	if not _credentials_have_valid_length(register_username.text, register_password.text):
		_show_error("Tài khoản và mật khẩu phải dài từ 6 đến 15 ký tự.")
		return
	if not register_agreement.button_pressed:
		_show_error("Bạn phải tích “Đã đọc và đồng ý” trước khi đăng ký.")
		return

	_set_busy(true, "Đang tạo tài khoản...")
	var result: Dictionary = await GameSession.register_account(
		register_username.text,
		register_password.text
	)
	if result.get("ok", false):
		get_tree().change_scene_to_file(CHARACTER_SCENE)
		return
	_set_busy(false, "")
	_show_error(_error_message(result))


func _route_after_auth(result: Dictionary) -> void:
	if result.get("needs_character", true):
		get_tree().change_scene_to_file(CHARACTER_SCENE)
	else:
		get_tree().change_scene_to_file(CHARACTER_ROSTER_SCENE)


func _show_register() -> void:
	login_form.visible = false
	register_form.visible = true
	status_label.text = ""
	register_username.grab_focus()


func _show_login() -> void:
	register_form.visible = false
	login_form.visible = true
	status_label.text = ""
	login_username.grab_focus()


func _credentials_have_valid_length(username: String, password: String) -> bool:
	var username_length := username.strip_edges().length()
	return (
		username_length >= MIN_CREDENTIAL_LENGTH
		and username_length <= MAX_CREDENTIAL_LENGTH
		and password.length() >= MIN_CREDENTIAL_LENGTH
		and password.length() <= MAX_CREDENTIAL_LENGTH
	)


func _login_credentials_have_valid_length(username: String, password: String) -> bool:
	var normalized_username := username.strip_edges().to_lower()
	var username_length := normalized_username.length()
	var username_is_valid := (
		normalized_username == ADMIN_LOGIN_USERNAME
		or (
			username_length >= MIN_CREDENTIAL_LENGTH
			and username_length <= MAX_CREDENTIAL_LENGTH
		)
	)
	return (
		username_is_valid
		and password.length() >= MIN_CREDENTIAL_LENGTH
		and password.length() <= MAX_CREDENTIAL_LENGTH
	)


func _set_password_visible(field: LineEdit, button: Button, is_visible: bool) -> void:
	field.secret = not is_visible
	button.modulate.a = 1.0 if is_visible else 0.7
	button.tooltip_text = "Ẩn mật khẩu" if is_visible else "Hiện mật khẩu"


func _load_login_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(LOGIN_PREFERENCES_FILE) != OK:
		remember_account.set_pressed_no_signal(false)
		return
	var remember_enabled := bool(
		config.get_value("login", "remember_account", false)
	)
	remember_account.set_pressed_no_signal(remember_enabled)
	if not remember_enabled:
		return
	var saved_username := String(config.get_value("login", "username", ""))
	if saved_username.is_empty():
		return
	login_username.text = saved_username


func _save_login_preferences() -> void:
	var config := ConfigFile.new()
	config.load(LOGIN_PREFERENCES_FILE)
	config.set_value("login", "remember_account", remember_account.button_pressed)
	if remember_account.button_pressed:
		config.set_value("login", "username", login_username.text.strip_edges())
	else:
		config.erase_section_key("login", "username")
	var error := config.save(LOGIN_PREFERENCES_FILE)
	if error != OK:
		push_warning("Không thể lưu tùy chọn ghi nhớ tài khoản.")


func _on_remember_account_toggled(is_enabled: bool) -> void:
	var config := ConfigFile.new()
	config.load(LOGIN_PREFERENCES_FILE)
	config.set_value("login", "remember_account", is_enabled)
	if not is_enabled:
		config.erase_section_key("login", "username")
	var error := config.save(LOGIN_PREFERENCES_FILE)
	if error != OK:
		push_warning("Không thể lưu tùy chọn ghi nhớ tài khoản.")


func _set_busy(is_busy: bool, message: String) -> void:
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE if is_busy else Control.MOUSE_FILTER_PASS
	controls.modulate.a = 0.55 if is_busy else 1.0
	busy_indicator.visible = is_busy
	status_label.text = message
	status_label.modulate = Color.WHITE


func _show_error(message: String) -> void:
	status_label.text = message
	status_label.modulate = Color(1.0, 0.55, 0.55)


func _error_message(result: Dictionary) -> String:
	var error: Dictionary = result.get("error", {})
	return String(error.get("message", "Có lỗi xảy ra."))
