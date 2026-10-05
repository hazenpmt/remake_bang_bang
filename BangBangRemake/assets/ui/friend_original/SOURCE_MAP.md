# Friend UI original asset map

The encrypted source file is preserved unchanged at:

`rez/zh_CN/module/FriendView.swf`

The main window now uses the single user-supplied composite:

`panel_friend.png` — 324×606.

Its unwanted cyan outer margin was removed to alpha and the four outer corners
were rounded. The original 324×606 canvas, frame pixels, and blue spiral center
were preserved. The previous `frame_*` assembly images were removed.

The old inner `listbk_*` border assembly is no longer displayed. The requested
plain white list and player-menu backgrounds are clipped to rounded corners by
`assets/shaders/rounded_solid.gdshader`.

Other files copied without resizing or repainting:

- `avatar_frame.png` from `controls/friends/head_bk.png`
- `row_button_*.png` from the corresponding `controls/public/button_2_ss_*.png`
- `row_word_view.png` from `controls/friends/word_view_t.png`
- `search_results_bg.png` from `controls/friends/findfriend_bk.png`
- `add_friend_panel.png` comes from the user-supplied
  `C:/Users/ycao7/Downloads/add_friend.png`. Only the connected cyan area
  outside the complete panel was removed, the corner alpha was softened, and
  the transparent padding was cropped. The game asset is 314x280; the panel
  pixels inside the frame were not redrawn.
- `add_friend_input.png` from `controls/public/input_bk_m.png` (210x35)
- `add_friend_ok.png` from `controls/public/button_window_green.png` (120x35)
- `scrollbar_up.png`, `scrollbar_down.png`, `scrollbar_thumb.png`, and
  `scrollbar_track.png` from the corresponding
  `controls/gameroom/scrollbar_up.png`, `scrollbar_down.png`,
  `scrollbar_block.png`, and `scrollbar_bk.png`

The following images were embedded in the encrypted `FriendView.swf`. They were
exported from the decoded SWF without repainting:

- `search_bg.png`, `search_icon.png`
- `button_add_friend.png`, `button_block_list.png`
- `tree_open.png`, `tree_closed.png`
- `status_male_online.png`, `status_female_online.png`, `status_offline.png`

The decoded `mxml.friends.FriendsFrame` layout defines a 324×606 window. The
Godot scene keeps its original positions for the avatar, search box, list, close
button, and two bottom buttons.

The add-friend modal now uses the supplied complete 314x280 panel as one
TextureRect. There is no assembled `add_friend_frame/` node tree or source-piece
folder in the game anymore. The input and confirmation controls remain separate
so their interaction still works.
