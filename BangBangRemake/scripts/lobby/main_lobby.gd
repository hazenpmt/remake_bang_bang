extends Control

signal lobby_action_requested(action: StringName)

const QUEUE_SCENE := "res://scenes/auth/AdmissionQueue.tscn"
const MALE_AVATAR := preload("res://assets/ui/profile/avatar_male.png")
const FEMALE_AVATAR := preload("res://assets/ui/profile/avatar_female.png")
const ALPHA_DISCARD_SHADER := preload("res://assets/shaders/alpha_discard.gdshader")
const LEVEL_FX_11_20 := "res://assets/animations/profile_level_11_20_effect1_compact/timeline.json"
const LEVEL_FX_21_30 := "res://assets/animations/profile_level_21_30_fx_compact/timeline.json"
const LEVEL_FX_31_35 := "res://assets/animations/profile_level_31_35_fx_compact/timeline.json"
const LEVEL_FX_36_40 := "res://assets/animations/profile_level_36_40_fx_compact/timeline.json"
const ProfileProgression := preload("res://scripts/data/profile_progression.gd")
const TankSkinCatalog := preload("res://scripts/lobby/tank_skin_catalog.gd")
const AssetPathAliases := preload("res://scripts/data/asset_path_aliases.gd")
const ShopCatalog := preload("res://scripts/data/shop_catalog.gd")
const PRIMARY_TANK_TEXTURES: Dictionary = {
	"gangtiexia03": preload("res://assets/ui/tank/tank_ironman_reward.png"),
}
const PVP_MODAL_TARGETS: Array[StringName] = [
	&"tank",
	&"military_rank",
	&"profile",
	&"purchase",
	&"friend",
	&"bag",
]

@export_range(0, 40, 1) var preview_level_override: int = 0

const BUTTON_ACTIONS: Dictionary = {
	^"CenterPlatform/Btn_PVP": &"pvp",
	^"CenterPlatform/Btn_PVE": &"pve",
	^"CenterPlatform/Btn_League": &"league",
	^"CenterPlatform/Btn_LanhTho": &"territory",
	^"CenterPlatform/SmallMenu/Btn_Rank": &"rank",
	^"CenterPlatform/SmallMenu/Btn_Guild": &"guild",
	^"CenterPlatform/SmallMenu/Btn_Shop": &"shop",
	^"BottomBar/Btn_Shop": &"shop",
	^"BottomBar/Btn_Friend": &"friend",
	^"BottomBar/Btn_MilitaryRank": &"military_rank",
	^"BottomBar/Btn_Crystal": &"crystal",
	^"BottomBar/Btn_Tank": &"tank",
	^"BottomBar/Btn_Assistant": &"assistant",
	^"BottomBar/Btn_Bag": &"bag",
	^"CurrencyDisplay/Xu/BtnPlus": &"add_xu",
	^"CurrencyDisplay/LockedXu/BtnPlus": &"add_locked_xu",
	^"CurrencyDisplay/Silver/BtnPlus": &"add_silver",
	^"RightQuickMenu/Btn_Community": &"community",
	^"RightQuickMenu/Btn_Mail": &"mail",
	^"RightQuickMenu/Btn_Tasks": &"tasks",
	^"RightQuickMenu/Btn_Settings": &"settings",
	^"RightQuickMenu/Btn_Return": &"return",
}

@onready var _profile_avatar: TextureButton = $PlayerProfile/Btn_Avatar
@onready var _profile_level: TextureRect = $PlayerProfile/Level/Base
@onready var _profile_level_effect: SwfTimelinePlayer = $PlayerProfile/Level/Effect
@onready var _profile_name: Label = $PlayerProfile/Name
@onready var _exp_bar_animation: SwfTimelinePlayer = $PlayerProfile/ExpBar/Animation
@onready var _exp_value: Label = $PlayerProfile/ExpBar/Value
@onready var _stamina_bar_animation: SwfTimelinePlayer = $PlayerProfile/StaminaBar/Animation
@onready var _stamina_value: Label = $PlayerProfile/StaminaBar/Value
@onready var _xu_value: Label = $CurrencyDisplay/Xu/Value
@onready var _locked_xu_value: Label = $CurrencyDisplay/LockedXu/Value
@onready var _silver_value: Label = $CurrencyDisplay/Silver/Value
@onready var _profile_modal: Control = $ProfileModal
@onready var _purchase_modal: Control = $PurchaseModal
@onready var _purchase_item: TextureRect = $PurchaseModal/Window/Item
@onready var _purchase_item_name: Label = $PurchaseModal/Window/ItemName
@onready var _purchase_description: Label = $PurchaseModal/Window/Description
@onready var _purchase_quantity_label: Label = $PurchaseModal/Window/Quantity
@onready var _purchase_confirm: TextureButton = $PurchaseModal/Window/Btn_Confirm
@onready var _purchase_minus: TextureButton = $PurchaseModal/Window/Btn_Minus
@onready var _purchase_plus: TextureButton = $PurchaseModal/Window/Btn_Plus
@onready var _lobby_notification: Control = $LobbyNotification
@onready var _tank_panel: Control = $TankPanel
@onready var _main_tank_image: TextureRect = $CenterPlatform/PrimaryTankDisplay/TankImage
@onready var _main_tank_level: TextureRect = $CenterPlatform/PrimaryTankDisplay/TankLevel
@onready var _main_tank_name: Label = $CenterPlatform/PrimaryTankDisplay/TankName
@onready var _change_tank_button: TextureButton = \
	$CenterPlatform/PrimaryTankDisplay/BtnChangeTank
@onready var _newcomer_tank_reward: Control = $NewcomerTankReward
@onready var _military_rank_panel: Control = $MilitaryRankPanel
@onready var _pvp_room_view: Control = $PvpRoomLayer/PvpRoomView
@onready var _friend_panel: Control = $FriendPanel
@onready var _inventory_panel: Control = $InventoryPanel
@onready var _shop_panel: Control = $ShopPanel
@onready var _community_button: TextureButton = $RightQuickMenu/Btn_Community
@onready var _mail_button: TextureButton = $RightQuickMenu/Btn_Mail

var _purchase_quantity := 1
var _purchase_offer: Dictionary = {}
var _purchase_idempotency_key := ""
var _purchase_quantity_max := 99
var _alpha_discard_material := ShaderMaterial.new()
var _main_tank_animation: SwfTimelinePlayer
var _restore_friend_panel_after_profile := false
var _friend_profile_opened_inside_pvp := false


func _ready() -> void:
	_alpha_discard_material.shader = ALPHA_DISCARD_SHADER
	_apply_alpha_discard($PlayerProfile)
	_apply_alpha_discard($CurrencyDisplay)
	if not GameSession.admission_lost.is_connected(_on_admission_lost):
		GameSession.admission_lost.connect(_on_admission_lost)
	for button_path: NodePath in BUTTON_ACTIONS:
		var button := get_node_or_null(button_path) as BaseButton
		if button == null:
			push_warning("Không tìm thấy nút sảnh: %s" % button_path)
			continue

		var action: StringName = BUTTON_ACTIONS[button_path]
		button.pressed.connect(_on_lobby_button_pressed.bind(action))
	_profile_avatar.pressed.connect(_open_profile_modal)
	$PlayerProfile/Btn_AddExp.pressed.connect(_open_purchase_modal.bind(&"exp"))
	$PlayerProfile/Btn_AddStamina.pressed.connect(_open_purchase_modal.bind(&"stamina"))
	$PurchaseModal/Window/Btn_Close.pressed.connect(_close_purchase_modal)
	$PurchaseModal/Window/Btn_Confirm.pressed.connect(_confirm_purchase_modal)
	$PurchaseModal/Window/Btn_Minus.pressed.connect(_change_purchase_quantity.bind(-1))
	$PurchaseModal/Window/Btn_Plus.pressed.connect(_change_purchase_quantity.bind(1))
	_change_tank_button.pressed.connect(_on_lobby_button_pressed.bind(&"tank"))
	if _friend_panel.has_signal("profile_requested"):
		_friend_panel.connect(
			"profile_requested",
			_open_friend_player_profile
		)
	_profile_modal.visibility_changed.connect(
		_on_profile_modal_visibility_changed
	)
	if _tank_panel.has_signal("primary_tank_changed"):
		_tank_panel.connect("primary_tank_changed", _on_primary_tank_changed)
	if _inventory_panel.has_signal("inventory_action_requested"):
		_inventory_panel.connect(
			"inventory_action_requested",
			_on_inventory_action_requested
		)
	if _shop_panel.has_signal("shop_action_requested"):
		_shop_panel.connect(
			"shop_action_requested",
			_on_shop_action_requested
		)
	if _tank_panel.has_signal("military_rank_requested"):
		_tank_panel.connect(
			"military_rank_requested",
			_on_tank_military_rank_requested
		)
	if _newcomer_tank_reward.has_signal("reward_claimed"):
		_newcomer_tank_reward.connect(
			"reward_claimed",
			_on_newcomer_tank_reward_claimed
		)
	_pvp_room_view.call(
		"bind_shared_controls",
		$ChatLayer/LobbyChat,
		$BottomBar,
		$RightQuickMenu
	)
	_pvp_room_view.call(
		"bind_modal_controls",
		_tank_panel,
		_profile_modal,
		_purchase_modal,
		_military_rank_panel,
		_friend_panel,
		_inventory_panel
	)
	_refresh_profile()
	call_deferred("_show_pending_newcomer_tank_reward")


func _apply_alpha_discard(node: Node) -> void:
	if node == $PlayerProfile/Level:
		return
	if node is CanvasItem:
		(node as CanvasItem).material = _alpha_discard_material
	for child in node.get_children():
		_apply_alpha_discard(child)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _newcomer_tank_reward.visible:
		return
	if _military_rank_panel.visible:
		_military_rank_panel.call("close")
		get_viewport().set_input_as_handled()
		return
	if _tank_panel.visible:
		return
	if _inventory_panel.visible:
		_inventory_panel.call("close")
		get_viewport().set_input_as_handled()
		return
	if _shop_panel.visible:
		_shop_panel.call("close")
		get_viewport().set_input_as_handled()
		return
	if _purchase_modal.visible:
		_close_purchase_modal()
		get_viewport().set_input_as_handled()
	elif _profile_modal.visible:
		_close_profile_modal()
		get_viewport().set_input_as_handled()
	elif _friend_panel.visible:
		_friend_panel.call("close")
		get_viewport().set_input_as_handled()
	elif _pvp_room_view.visible:
		_pvp_room_view.call("close")
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if (
		mouse_event == null
		or not mouse_event.pressed
		or mouse_event.button_index != MOUSE_BUTTON_LEFT
	):
		return
	if not is_instance_valid(_mail_button) or not _mail_button.visible:
		return
	if (
		_mail_button.get_global_rect().has_point(mouse_event.position)
		or (
			is_instance_valid(_community_button)
			and _community_button.get_global_rect().has_point(mouse_event.position)
		)
	):
		return
	_close_community_popout()


func _on_admission_lost(_message: String) -> void:
	get_tree().change_scene_to_file(QUEUE_SCENE)


func _on_lobby_button_pressed(action: StringName) -> void:
	if action == &"community":
		if is_instance_valid(_mail_button):
			_mail_button.visible = not _mail_button.visible
	elif action == &"friend":
		_close_community_popout()
		if _friend_panel.visible:
			_friend_panel.call("close")
		else:
			_prepare_primary_panel_switch(&"friend")
			_friend_panel.call("open")
	elif action == &"pvp":
		_close_community_popout()
		_prepare_primary_panel_switch(&"pvp")
		_pvp_room_view.call("open")
	elif action == &"tank":
		_prepare_primary_panel_switch(&"tank")
		_tank_panel.call("open")
	elif action == &"military_rank":
		_prepare_primary_panel_switch(&"military_rank")
		_military_rank_panel.call("open")
	elif action == &"bag":
		_close_community_popout()
		if _inventory_panel.visible:
			_inventory_panel.call("close")
		else:
			_prepare_primary_panel_switch(&"bag")
			_inventory_panel.call("open")
	elif action == &"shop":
		_close_community_popout()
		if _shop_panel.visible:
			_shop_panel.call("close")
		else:
			_prepare_primary_panel_switch(&"shop")
			_shop_panel.call("open")

	lobby_action_requested.emit(action)
	print("Lobby action: ", action)


func _close_community_popout() -> void:
	if is_instance_valid(_mail_button):
		_mail_button.visible = false


func _on_inventory_action_requested(action: StringName) -> void:
	if action != &"go_shop":
		if action in [
			&"sell", &"open_all", &"sell_materials", &"sort",
			&"sort_materials", &"cancel_decoration",
		]:
			var inventory_notification: Control = _inventory_panel.call(
				"get_notification"
			)
			inventory_notification.call(
				"show_message",
				"Thao tác này cần API máy chủ và hiện chưa được mở.",
				false,
				&"server_feature_pending"
			)
		return
	_prepare_primary_panel_switch(&"shop")
	_shop_panel.call("open")
	lobby_action_requested.emit(&"shop")


func _on_shop_action_requested(action: StringName, offer: Dictionary) -> void:
	if action == &"open_bag":
		_prepare_primary_panel_switch(&"bag")
		_inventory_panel.call("open")
		lobby_action_requested.emit(&"bag")
		return
	if action in [&"buy", &"claim"]:
		_open_shop_purchase_modal(offer)
		return
	if action == &"error":
		var status := int(offer.get("status", -1))
		if status == 0 or status >= 500:
			return
		_lobby_notification.call(
			"show_message",
			String(offer.get("message", "Không thể mở Shop.")),
			false,
			&"shop_error"
		)
		return
	if action == &"gift":
		_lobby_notification.call(
			"show_message",
			"Tặng quà cần chọn người nhận và API chống gian lận; hiện chưa mở.",
			false,
			&"server_feature_pending"
		)
		return
	if action == &"try":
		_lobby_notification.call(
			"show_message", "Chế độ xem thử vật phẩm hiện chưa mở.",
			false, &"server_feature_pending"
		)


func _on_tank_military_rank_requested() -> void:
	_close_primary_panel(_profile_modal)
	_close_primary_panel(_purchase_modal)
	_close_primary_panel(_friend_panel)
	_close_primary_panel(_inventory_panel)
	_close_primary_panel(_shop_panel)
	_military_rank_panel.call("open")
	lobby_action_requested.emit(&"military_rank")
	print("Lobby action: military_rank")


func _open_friend_player_profile(player: Dictionary) -> void:
	_close_primary_panel(_purchase_modal)
	var requested_inside_pvp := _pvp_room_view.visible
	_restore_friend_panel_after_profile = _friend_panel.visible
	_friend_profile_opened_inside_pvp = requested_inside_pvp
	if _friend_panel.visible:
		_friend_panel.call("close")
		await _friend_panel.visibility_changed
		if (
			not is_instance_valid(_profile_modal)
			or not _restore_friend_panel_after_profile
			or (requested_inside_pvp and not _pvp_room_view.visible)
		):
			_restore_friend_panel_after_profile = false
			return
	_profile_modal.call(
		"show_profile",
		player,
		{"id": String(player.get("account_id", "—"))}
	)


func _on_profile_modal_visibility_changed() -> void:
	if _profile_modal.visible or not _restore_friend_panel_after_profile:
		return
	var restore_inside_pvp := _friend_profile_opened_inside_pvp
	_restore_friend_panel_after_profile = false
	_friend_profile_opened_inside_pvp = false
	if restore_inside_pvp != _pvp_room_view.visible:
		return
	_friend_panel.call("open")


func _prepare_primary_panel_switch(target: StringName) -> void:
	_restore_friend_panel_after_profile = false
	_friend_profile_opened_inside_pvp = false
	# PvP reparents shared modal nodes while it is open, so it must restore them
	# before the remaining lobby panels are closed.
	var keep_pvp_open := (
		_pvp_room_view.visible
		and target in PVP_MODAL_TARGETS
	)
	if target != &"pvp" and not keep_pvp_open:
		_close_primary_panel(_pvp_room_view)
	if target != &"tank":
		_close_primary_panel(_tank_panel)
	if target != &"military_rank":
		_close_primary_panel(_military_rank_panel)
	if target != &"profile":
		_close_primary_panel(_profile_modal)
	if target != &"purchase":
		_close_primary_panel(_purchase_modal)
	if target != &"friend":
		_close_primary_panel(_friend_panel)
	if target != &"bag":
		_close_primary_panel(_inventory_panel)
	if target != &"shop":
		_close_primary_panel(_shop_panel)


func _close_primary_panel(panel: Control) -> void:
	if panel == null or not panel.visible:
		return
	if panel.has_method("close"):
		panel.call("close")
	else:
		panel.visible = false


func _refresh_profile() -> void:
	var data := GameSession.profile.duplicate()
	data.merge(GameSession.lobby_data, true)
	if GameSession.token.is_empty() and GameSession.lobby_data.is_empty():
		data.merge(ProfileProgression.OFFLINE_PREVIEW, true)

	var display_name := String(data.get("display_name", "Nhân vật"))
	var gender := String(data.get("gender", "male"))
	var level := clampi(int(data.get("level", 1)), 0, 40)
	if preview_level_override > 0:
		level = preview_level_override
	var experience := maxi(0, int(data.get("experience", 0)))
	var experience_max := maxi(
		0,
		int(
			data.get(
				"experience_max",
				ProfileProgression.experience_max_for_level(level)
			)
		)
	)
	var stamina := maxi(0, int(data.get("stamina", 0)))
	var stamina_max := maxi(1, int(data.get("stamina_max", 100)))
	var is_female := gender == "female"

	_profile_avatar.texture_normal = FEMALE_AVATAR if is_female else MALE_AVATAR
	_refresh_level_badge(level)
	_profile_name.text = display_name

	var exp_ratio := 0.0
	if experience_max > 0:
		exp_ratio = clampf(float(experience) / float(experience_max), 0.0, 1.0)
		_exp_value.text = "%d/%d(%d%%)" % [
			experience,
			experience_max,
			roundi(exp_ratio * 100.0),
		]
	else:
		_exp_value.text = "%d(0%%)" % experience
	_exp_bar_animation.seek_frame(clampi(roundi(exp_ratio * 99.0) + 1, 1, 100))

	var stamina_ratio := clampf(float(stamina) / float(stamina_max), 0.0, 1.0)
	_stamina_bar_animation.seek_frame(
		clampi(roundi(stamina_ratio * 99.0) + 1, 1, 100)
	)
	_stamina_value.text = "%d/%d(%d%%)" % [
		stamina,
		stamina_max,
		roundi(stamina_ratio * 100.0),
	]

	var is_scene_preview := (
		GameSession.profile.is_empty() and GameSession.lobby_data.is_empty()
	)
	var xu_fallback := 100 if is_scene_preview else 0
	var locked_xu_fallback := 1000 if is_scene_preview else 0
	var silver_fallback := 10000 if is_scene_preview else 0
	var xu := maxi(0, _safe_int(data.get("xu", xu_fallback), xu_fallback))
	var locked_xu := maxi(
		0,
		_safe_int(data.get("locked_xu", locked_xu_fallback), locked_xu_fallback)
	)
	var silver := maxi(
		0,
		_safe_int(data.get("silver", silver_fallback), silver_fallback)
	)
	_xu_value.text = str(xu)
	_locked_xu_value.text = str(locked_xu)
	_silver_value.text = str(silver)
	_refresh_primary_tank_display(data)


func _refresh_primary_tank_display(data: Dictionary = {}) -> void:
	var source := data
	if source.is_empty():
		source = GameSession.profile.duplicate()
		source.merge(GameSession.lobby_data, true)

	var tank_key := _safe_string(source.get("tank_key", ""))
	var tank_name := _safe_string(source.get("tank_name", ""))
	var tank_level := clampi(_safe_int(source.get("tank_level", 1), 1), 1, 6)
	if tank_key.is_empty() and GameSession.lobby_data.is_empty():
		tank_key = "gangtiexia03"
		tank_name = "Iron Man"
		tank_level = 1

	var tank_data := TankSkinCatalog.find_owned_tank(source, tank_key)
	var equipped_skin_key := TankSkinCatalog.equipped_skin_key(tank_data)
	_refresh_primary_tank_visual(tank_data, tank_key, equipped_skin_key)
	_main_tank_name.text = tank_name
	var level_texture := AssetPathAliases.load_texture(
		"res://assets/ui/tank/tank_level_%d.png" % tank_level
	)
	_main_tank_level.texture = level_texture


func _refresh_primary_tank_visual(
	tank_data: Dictionary,
	tank_key: String,
	equipped_skin_key: String
) -> void:
	var animation_path := TankSkinCatalog.animation_path(equipped_skin_key)
	if not animation_path.is_empty():
		_main_tank_image.visible = false
		if _main_tank_animation == null:
			_main_tank_animation = SwfTimelinePlayer.new()
			_main_tank_animation.name = "TankAnimation"
			_main_tank_animation.position = (
				_main_tank_image.position + _main_tank_image.size * 0.5
			)
			_main_tank_animation.timeline_path = animation_path
			$CenterPlatform/PrimaryTankDisplay.add_child(_main_tank_animation)
		elif _main_tank_animation.timeline_path != animation_path:
			_main_tank_animation.load_timeline(animation_path)
		_main_tank_animation.visible = true
		_main_tank_animation.play()
		return

	if _main_tank_animation != null:
		_main_tank_animation.stop()
		_main_tank_animation.visible = false
	var texture := TankSkinCatalog.texture_for(
		tank_data,
		tank_key,
		equipped_skin_key
	)
	if texture == null:
		texture = PRIMARY_TANK_TEXTURES.get(tank_key) as Texture2D
	_main_tank_image.texture = texture
	_main_tank_image.visible = texture != null


func _on_primary_tank_changed(lobby_data: Dictionary) -> void:
	_refresh_profile()
	_pvp_room_view.call("refresh_current_player_tank", lobby_data)


func _show_pending_newcomer_tank_reward() -> void:
	var reward_value: Variant = GameSession.lobby_data.get(
		"pending_tank_reward",
		null
	)
	if reward_value is Dictionary and not reward_value.is_empty():
		_newcomer_tank_reward.call("show_reward", reward_value)


func _on_newcomer_tank_reward_claimed(_lobby_data: Dictionary) -> void:
	_refresh_profile()


func _refresh_level_badge(level: int) -> void:
	var texture_path := "res://assets/ui/profile/level/level_%d.png" % level
	_profile_level.texture = AssetPathAliases.load_texture(texture_path)

	var effect_path := ""
	if level >= 36:
		effect_path = LEVEL_FX_36_40
	elif level >= 31:
		effect_path = LEVEL_FX_31_35
	elif level >= 21:
		effect_path = LEVEL_FX_21_30
	elif level >= 11:
		effect_path = LEVEL_FX_11_20

	if effect_path.is_empty():
		_profile_level_effect.stop()
		_profile_level_effect.visible = false
		return

	var is_level_11_to_20 := level >= 11 and level <= 20
	_profile_level_effect.scale = (
		Vector2(0.44, 0.44)
		if is_level_11_to_20
		else Vector2(0.5, 0.5)
	)
	_profile_level_effect.modulate.a = 1.0
	if _profile_level_effect.timeline_path != effect_path:
		_profile_level_effect.load_timeline(effect_path)
	_profile_level_effect.visible = true
	_profile_level_effect.play()


func _open_profile_modal() -> void:
	_prepare_primary_panel_switch(&"profile")
	_refresh_profile()
	var data := GameSession.profile.duplicate()
	data.merge(GameSession.lobby_data, true)
	var account := GameSession.account.duplicate()
	if GameSession.profile.is_empty() and GameSession.lobby_data.is_empty():
		data = {
			"display_name": "Beenn",
			"gender": "male",
			"level": 15,
			"owned_tanks": [
				{
					"tank_key": "gangtiexia03",
					"tank_name": "Iron Man",
					"tank_level": 1,
					"tank_damage_type": "physical",
					"is_primary": true,
					"skin_collection_bonus": {
						"frame_tier": "orange",
					},
				},
			],
		}
		account = {"id": 10341}
	_profile_modal.call("show_profile", data, account)


func _close_profile_modal() -> void:
	_profile_modal.call("hide_view")


func _open_purchase_modal(kind: StringName) -> void:
	_prepare_primary_panel_switch(&"purchase")
	_purchase_offer.clear()
	_purchase_idempotency_key = ""
	_purchase_quantity_max = 99
	_purchase_quantity = 1
	_purchase_quantity_label.text = "1"
	_purchase_item.visible = kind == &"exp"
	if kind == &"stamina":
		_purchase_item_name.text = "Bổ sung thể lực"
		_purchase_description.text = (
			"Giá và giao dịch bổ sung thể lực sẽ do máy chủ xác thực."
		)
	else:
		_purchase_item_name.text = "Bổ sung EXP"
		_purchase_description.text = (
			"Giá và giao dịch mua EXP sẽ do máy chủ xác thực."
		)
	_purchase_modal.visible = true


func _close_purchase_modal() -> void:
	_purchase_modal.visible = false
	_purchase_offer.clear()
	_purchase_idempotency_key = ""
	_set_purchase_controls_enabled(true)


func _change_purchase_quantity(delta: int) -> void:
	_purchase_quantity = clampi(
		_purchase_quantity + delta, 1, _purchase_quantity_max
	)
	_purchase_quantity_label.text = str(_purchase_quantity)
	if not _purchase_offer.is_empty():
		_purchase_idempotency_key = _new_idempotency_key()
		_refresh_shop_purchase_description()


func _open_shop_purchase_modal(offer: Dictionary) -> void:
	var item_type := StringName(offer.get("item_type", ""))
	var unique_item := item_type in [
		&"tank", &"tank_skin", &"avatar_fashion",
		&"profile_decoration", &"assistant",
	]
	if unique_item and bool(offer.get("owned", false)):
		_lobby_notification.call(
			"show_message", "Bạn đã sở hữu vật phẩm này.", false, &"shop_owned"
		)
		return
	var remaining: Variant = offer.get("remaining_limit")
	if remaining != null and int(remaining) <= 0:
		_lobby_notification.call(
			"show_message", "Bạn đã đạt giới hạn mua của offer này.",
			false, &"shop_limit"
		)
		return
	_purchase_offer = offer.duplicate(true)
	_purchase_quantity_max = maxi(
		1, int(offer.get("max_quantity_per_order", 99))
	)
	if remaining != null:
		_purchase_quantity_max = mini(_purchase_quantity_max, int(remaining))
	if unique_item:
		_purchase_quantity_max = 1
	_purchase_quantity = 1
	_purchase_quantity_label.text = "1"
	_purchase_idempotency_key = _new_idempotency_key()
	_purchase_item.texture = ShopCatalog.load_texture(String(offer.get("image", "")))
	_purchase_item.visible = _purchase_item.texture != null
	_purchase_item_name.text = String(offer.get("name", "Vật phẩm"))
	_refresh_shop_purchase_description()
	_set_purchase_controls_enabled(true)
	_purchase_modal.visible = true
	_purchase_modal.move_to_front()


func _refresh_shop_purchase_description() -> void:
	if _purchase_offer.is_empty():
		return
	var currency := String(_purchase_offer.get("currency", "xu"))
	var currency_name: String = {
		"xu": "Xu", "locked_xu": "Xu Khóa", "silver": "Bạc",
	}.get(currency, currency)
	var unit_price := maxi(0, int(_purchase_offer.get("price", 0)))
	var total_price := unit_price * _purchase_quantity
	var description := String(_purchase_offer.get("description", "")).strip_edges()
	var price_line := "Giá: %s %s × %d = %s %s" % [
		_format_shop_number(unit_price), currency_name, _purchase_quantity,
		_format_shop_number(total_price), currency_name,
	]
	_purchase_description.text = (
		(description + "\n" if not description.is_empty() else "")
		+ price_line
		+ "\nMáy chủ sẽ xác thực giá, số dư và quyền sở hữu."
	)


func _confirm_purchase_modal() -> void:
	if _purchase_offer.is_empty():
		_close_purchase_modal()
		return
	_set_purchase_controls_enabled(false)
	var result := await GameSession.purchase_shop_offer(
		String(_purchase_offer.get("offer_id", "")),
		_purchase_quantity,
		_purchase_idempotency_key
	)
	if not result.get("ok", false):
		_set_purchase_controls_enabled(true)
		var status := int(result.get("status", 0))
		if status > 0 and status < 500:
			var error: Dictionary = result.get("error", {})
			_lobby_notification.call(
				"show_message",
				String(error.get("message", "Giao dịch không thành công.")),
				false,
				&"shop_purchase_error"
			)
		return
	var purchase: Dictionary = result.get("purchase", {})
	var purchased_name := String(_purchase_offer.get("name", "Vật phẩm"))
	_shop_panel.call("apply_server_purchase", purchase)
	_close_purchase_modal()
	_lobby_notification.call(
		"show_message", "Mua %s thành công." % purchased_name,
		false, &"shop_purchase_success"
	)


func _set_purchase_controls_enabled(enabled: bool) -> void:
	_purchase_confirm.disabled = not enabled
	_purchase_minus.disabled = not enabled or _purchase_quantity_max <= 1
	_purchase_plus.disabled = not enabled or _purchase_quantity_max <= 1


func _new_idempotency_key() -> String:
	return Crypto.new().generate_random_bytes(24).hex_encode()


func _format_shop_number(value: int) -> String:
	var source := str(maxi(0, value))
	var result := ""
	while source.length() > 3:
		result = "," + source.right(3) + result
		source = source.left(source.length() - 3)
	return source + result


func _safe_string(value: Variant) -> String:
	if value == null:
		return ""
	return String(value)


func _safe_int(value: Variant, fallback: int) -> int:
	if value == null:
		return fallback
	if value is int or value is float:
		return int(value)
	var text := String(value).strip_edges()
	return int(text) if text.is_valid_int() else fallback
