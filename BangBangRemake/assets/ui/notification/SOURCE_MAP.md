# Reusable notification UI source map

The notification scene is
`res://scenes/ui/ReusableNotification.tscn`.

Original assets copied byte-for-byte from
`C:/Users/ycao7/Downloads/asset_1/rez/zh_CN/gui_summer/controls`:

- `message_corner.png` <- `public/msg_box_r.png` (`99x51`)
- `message_horizontal.png` <- `public/msg_box_h.png` (`1x21`)
- `message_vertical.png` <- `public/msg_box_v.png` (`22x1`)
- `guide.png` <- `tips/jiaoguan04.png` (`180x292`)
- `button_green.png` <- `public/button_2_green.png` (`96x28`)
- `button_blue.png` <- `public/button_2_blue.png` (`96x28`)
- `ok_text.png` <- `title/title_confirm_green_t.png` (`40x21`)
- `cancel_text.png` <- `title/title_cancel_t.png` (`40x21`)

`spiral_source.png` is a byte-for-byte copy of the already documented
user-provided `assets/ui/inventory/tui_do_panel.png`.

`notification_panel_complete.png` is the single `360x190` image currently
used by the scene. Its blue interior is the native-size `324x154` crop at
`(270,207)` from `spiral_source.png`, placed at `(18,18)`. The complete yellow
frame `khung_vang_CAN_CHUAN_360x190.png` is then placed above it without
scaling. This replaces all separate corner, edge, clipping, and fallback-fill
nodes, so there are no runtime seams between pieces.
