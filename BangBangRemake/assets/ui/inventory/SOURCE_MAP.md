# Inventory UI source map

All source PNG files in the subfolders are byte-for-byte copies of original
files from `C:/Users/ycao7/Downloads/asset_1/rez`.

- `tui_do_panel.png`: cleaned from the user-provided
  `C:/Users/ycao7/Downloads/tui_do.png`. It keeps the original `861x565`
  canvas and preserves all RGB pixels. Only the outer stray cyan/green/orange
  border pixels were changed to alpha, revealing the rounded white corners.
  The frame, title cap, inner blue border, and spiral were not resized,
  cropped, recolored, or regenerated.
- `inventory_content_test.png`: byte-for-byte copy of the user-provided
  `C:/Users/ycao7/Downloads/Dự án mới (2).png`. This is an opaque white
  `612x453` temporary size-check image, not a finished content-frame asset and
  no longer referenced by the scene.
- `inventory_content_frame.png`: byte-for-byte copy of the user-provided
  `C:/Users/ycao7/Downloads/ive.png`. This is the finished `612x453` inner
  content frame, including the user's original transparent rounded corners.

- `public/`: original reusable window/frame/pager pieces from
  `rez/zh_CN/gui_summer/controls/public`.
- `tabs/shop_navItem_s*.png`: original 91x29 normal/selected tab backgrounds
  from `rez/zh_CN/gui_summer/controls/shop`.
- `tabs/nav_*.png`: the six original Vietnamese tab-title images from
  `rez/zh_CN/gui_summer/controls/title`.
- `tankbarn/`: original inventory-specific slot, fashion, achievement, and
  spray UI from `rez/zh_CN/gui_summer/controls/tankbarn`. The VP action
  captions `title_itemsorting_t.png`, `title_sell_t.png`,
  `word_akeyopenpacks_t.png`, and `word_goshop_t.png` are copied from this
  folder as well.
- `public/button_2_green.png`, `public/button_2_orange.png`, and
  `public/button_2_s_blue.png`: original native-size VP action-button
  backgrounds from `rez/zh_CN/gui_summer/controls/public`.
- `public/label138x21.png`: byte-for-byte copy of the original 138x21 dark
  rounded value background from
  `rez/zh_CN/gui_summer/controls/public/label138x21.png`. The KHO profile
  uses four native-size copies behind Guild, wins, run rate, and daily-team
  values; they are not drawn or stretched in code.
- The 26x26 Xu, locked-Xu, and Silver icons are reused directly from
  `assets/ui/currency/icon_xu.png`, `icon_xu_locked.png`, and
  `icon_silver.png`. Those files came from the original currency UI mapping
  already used by MainLobby.
- `preview/boy001.png`: original 180x240 character image from
  `rez/zh_CN/char/boy001.png`.
- `preview/level015.png`: original 80x40 level badge from
  `rez/zh_CN/gui_summer/level/level015.png`.
- `preview/icon_record*.png`: original 48x48 achievement icons from
  `rez/zh_CN/icon/achievement`.
- `preview/spray*.png`: original spray images from `rez/zh_CN/spray`.
- `preview/spraycan.png`: byte-for-byte copy of the original 100x100
  `rez/zh_CN/icon/item/spraycan.png`.
- `tankbarn/Lable66x28.png` and `tankbarn/title_choise_t.png`: byte-for-byte
  copies of the original achievement-value background and CHỌN caption.
- `tankbarn/options_bk.png`: byte-for-byte copy of the original 269x38 common
  frame behind the three achievement filters.
- `tankbarn/achievement_medal_frame.png`: byte-for-byte copy of the
  user-provided `C:/Users/ycao7/Downloads/v_d.png`. It is the finished 492x64
  source frame. The achievement view keeps its native 492 px width and its
  native 18 px top/bottom caps, then tiles the original 1 px middle row
  vertically to produce the requested 492x84 medal area. No source pixel is
  enlarged and the rounded caps are not resized.
- `public/tick.png`: byte-for-byte copy of the original 34x34 selected mark
  from `rez/zh_CN/gui_summer/controls/public/tick.png`.

`Ach_BK.png` is a 540x400 canvas containing two disconnected frames. The
mission UI uses its exact large-frame atlas region `(36,143,495,251)` at native
size. The old small medal-frame region is `(39,37,492,64)` and is no longer
shown; it has been replaced by the finished user-provided
`achievement_medal_frame.png`.

`Ach_sBK.png` has a 485x59 canvas, but its visible alpha ends at source
`x=462`; source columns `463..484` are fully transparent. Each achievement row
keeps the original image at native size, then extends only its right side from
the same source pixels: the straight 1x59 strip at `(440,0)` is tiled, and the
native 15x59 right cap `(448,0,15,59)` is placed at the new edge. No source
image is resized, recolored, or replaced with a code-drawn background.

`InventoryPanel.tscn` now uses `tui_do_panel.png` as its single outer
background. The old composed outer-frame nodes and their resource references
were removed. The separate inner content boundary now uses the single
native-size `inventory_content_frame.png`; the nine `bk3_*` nodes and their
resource references are no longer active in the scene.

All complete images are displayed at their native pixel dimensions. Oversized
spray art is clipped by the original 78x78 spray cell instead of being scaled.

The reusable confirmation dialog used by `InventoryPanel` is documented
separately in `assets/ui/notification/SOURCE_MAP.md`. It is instantiated from
`scenes/ui/ReusableNotification.tscn`, so future disconnect or confirmation
messages can call the same component without duplicating the VP layout.
