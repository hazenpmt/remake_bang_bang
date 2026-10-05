extends TextureButton

var tween: Tween

func _ready():
    var tooltip_theme := Theme.new()
    tooltip_theme.set_stylebox("panel", "TooltipPanel", StyleBoxEmpty.new())
    theme = tooltip_theme

    mouse_entered.connect(_on_hover_enter)
    mouse_exited.connect(_on_hover_exit)
    button_down.connect(_on_button_down)
    button_up.connect(_on_button_up)

func _on_hover_enter():
    if disabled: return
    _glow(Color(1.3, 1.3, 1.3)) # Cả khung sáng rực lên 30%

func _on_hover_exit():
    if disabled: return
    _glow(Color(1.0, 1.0, 1.0)) # Trở về độ sáng bình thường

func _on_button_down():
    if disabled: return
    _glow(Color(0.8, 0.8, 0.8)) # Hơi sẫm lại khi nhấn chuột xuống

func _on_button_up():
    if disabled: return
    if is_hovered():
        _glow(Color(1.3, 1.3, 1.3))
    else:
        _glow(Color(1.0, 1.0, 1.0))

func _glow(target_color: Color):
    if tween: tween.kill()
    tween = create_tween()
    tween.tween_property(self, "modulate", target_color, 0.1)


func _make_custom_tooltip(for_text: String) -> Object:
    if for_text.strip_edges().is_empty():
        return null

    var tooltip := PanelContainer.new()
    tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var background := StyleBoxFlat.new()
    background.bg_color = Color("#e9f9ff")
    background.border_color = Color("#bddded")
    background.set_border_width_all(1)
    background.corner_radius_top_left = 2
    background.corner_radius_top_right = 2
    background.corner_radius_bottom_right = 2
    background.corner_radius_bottom_left = 2
    background.content_margin_left = 4.0
    background.content_margin_top = 1.0
    background.content_margin_right = 4.0
    background.content_margin_bottom = 2.0
    tooltip.add_theme_stylebox_override("panel", background)

    var font := SystemFont.new()
    font.font_names = PackedStringArray(["Verdana"])
    font.font_weight = 700

    var label := Label.new()
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.text = for_text
    label.add_theme_font_override("font", font)
    label.add_theme_font_size_override("font_size", 14)
    label.add_theme_color_override("font_color", Color("#086da5"))
    tooltip.add_child(label)

    return tooltip
