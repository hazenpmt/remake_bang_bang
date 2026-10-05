# Quy trình animation SWF gọn cho Godot

Tài liệu này là quy tắc làm việc cho người và AI tiếp theo. Mục tiêu là giữ
chuyển động của game gốc nhưng không xuất mỗi frame thành một ảnh PNG toàn màn
hình.

## Nguyên tắc bắt buộc

- Không tự vẽ hoặc tự chế asset.
- Không đổi tỉ lệ, vị trí hay UI đã căn.
- Không đoán chuyển động bằng mắt nếu SWF còn đọc được.
- Luôn giữ bản animation PNG cũ để so sánh; chỉ thay trong scene chính sau khi
  người dùng xem và đồng ý.
- Mỗi SWF phải xem `conversion_report.json`. Nếu có cảnh báo thì chưa được coi
  là chuyển đổi hoàn chỉnh.

## Cơ chế

SWF không chỉ chứa ảnh. Timeline của nó lưu danh sách đối tượng theo từng frame:
shape nào được đặt ở depth nào, matrix vị trí/xoay/co giãn, mask, blend mode và
frame của sprite con.

Tool đọc trực tiếp các lệnh timeline đó từ XML do FFDec xuất. Nó chỉ xuất các
`DefineShape` duy nhất thành PNG cắt gọn, rồi ghi công thức ghép thật của SWF vào
`timeline.json`. Godot dùng lại các PNG và áp matrix theo từng frame.

Đây không phải animation được đoán hoặc dựng lại thủ công.

## Tool

- Tool chính: `C:\Users\ycao7\Downloads\asset_1\tool\swf_to_godot_timeline.py`
- Bản bấm chạy dễ dùng:
  `C:\Users\ycao7\Downloads\asset_1\tool\4_Xuat_Animation_Godot_Nhe.bat`
- Bộ phát Godot:
  `res://scripts/animation/swf_timeline_player.gd`

Yêu cầu:

- Python 3.
- FFDec CLI, mặc định:
  `C:\Program Files (x86)\FFDec\ffdec-cli.exe`
- Tên gói chỉ được dùng chữ, số, `_` và `-`.

Ví dụ lệnh đã dùng cho bệ sảnh:

```powershell
python tool\swf_to_godot_timeline.py `
  --swf rez\zh_CN\gui_summer\controls\main\360\aeacc768b6b7be867377bbd55c246106.swf `
  --project BangBangRemake `
  --name main_360_plat_compact `
  --logical-name zh_CN/gui_summer/controls/main/360/plat.swf
```

Không dùng `--force` nếu chưa xác nhận muốn tạo lại gói đã tồn tại.

## Kết quả của một gói

```text
assets/animations/<tên_gói>/
├── shapes/                 PNG thành phần cắt gọn
├── timeline.json           công thức ghép từng frame
└── conversion_report.json  thống kê và cảnh báo
```

Để dùng trong scene:

1. Tạo `Node2D`.
2. Gắn `res://scripts/animation/swf_timeline_player.gd`.
3. Đặt `timeline_path` tới `timeline.json`.
4. Giữ nguyên position/scale của node animation cũ.

`content_offset` trong timeline giữ cùng gốc tọa độ với animation PNG cũ. Không
cần căn lại các nút hoặc đổi tỉ lệ ảnh.

`swf_timeline_player.gd` chạy ở chế độ `@tool`: trong editor 2D nó dựng frame đầu
và đứng yên để có thể chọn node, kéo và chỉnh `position` trực quan. Khi chạy game,
`autoplay` mới phát timeline bình thường.

Lưu ý cho runtime: số trong JSON có thể được Godot đọc thành số thực. ID shape
phải được ép về `int` rồi mới đổi thành chuỗi để tra texture (`5.0` phải tra bằng
khóa `5`). Không bỏ bước chuẩn hóa này, nếu không timeline vẫn chạy nhưng toàn
bộ sprite sẽ không có texture và scene chỉ còn nền.

Các sprite cùng nằm trong một clip mask phải dùng chung `z_index = 0` tương đối
với node mask. Sắp thứ tự các sprite con bằng `move_child`, không tăng z-index
từng sprite. Nếu tăng z-index, Godot sẽ tách sprite đó khỏi draw group của mask;
quầng LED vốn phải bị cắt vào viền mỏng sẽ tràn ra ngoài thành đốm sáng lớn.

Toàn bộ shape/mask bên trong player cũng phải giữ `z_index = 0` và sắp depth
bằng thứ tự node con. Không dùng z-index lớn để mô phỏng depth SWF, vì z-index
đó sẽ thoát khỏi phạm vi player và làm bệ che các nút UI vốn nằm phía trên.

## Bệ sảnh đã chuyển đổi

Nguồn thật:

```text
rez/zh_CN/gui_summer/controls/main/360/aeacc768b6b7be867377bbd55c246106.swf
```

Tên logic:

```text
zh_CN/gui_summer/controls/main/360/plat.swf
```

Kết quả:

- 24 FPS.
- 191 frame.
- 37 ảnh thành phần.
- 4 timeline sprite con.
- Có 2 đến 4 mask mỗi frame.
- Có lớp sáng dùng blend cộng.
- Không có filter, morph hoặc ActionScript cần mô phỏng.
- Bản cũ trước khi xóa: 191 PNG kích thước 1800 x 1400, khoảng 294 MB tính cả
  file import.
- Gói mới: khoảng 2.04 MB tính cả file import hiện tại.

Scene thử `PlatformCompactTest.tscn` đã hoàn thành nhiệm vụ và được xóa ngày
19/07/2026. Node `Anim_Platform` trong `MainLobby.tscn` là bản đang dùng thật,
giữ đúng position `(-137, -53)`.

## Kiểm tra bắt buộc

1. Chạy import/parse:

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --editor `
  --path C:\Users\ycao7\Downloads\asset_1\BangBangRemake --quit
```

2. Chạy chính scene đang sử dụng animation đủ lâu để đi qua trọn một vòng:

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless `
  --path C:\Users\ycao7\Downloads\asset_1\BangBangRemake `
  --quit-after 200 res://scenes/lobby/MainLobby.tscn
```

Nếu môi trường kiểm thử không cho Godot ghi vào AppData, đặt `APPDATA` và
`LOCALAPPDATA` vào một thư mục ghi được trước khi chạy. Đây là lỗi môi trường,
không phải lỗi animation.

3. Trước khi xóa PNG cũ, tạo scene so sánh tạm cũ–mới và render GPU:

- vị trí và kích thước;
- thứ tự lớp;
- vùng bị mask;
- tia sáng/additive blend;
- tốc độ và điểm lặp.

Sau khi thay vào scene chính, phải chạy lại chính `MainLobby.tscn` ít nhất 200
frame để kiểm tra node mới trong đầy đủ UI.

## Trường hợp tool phải cảnh báo hoặc cần xử lý riêng

Tool hiện phát hiện và ghi cảnh báo cho các tính năng không được đảm bảo:

- filter;
- morph shape không phải mặt nạ chữ nhật dịch chuyển;
- ActionScript điều khiển timeline;
- mask lồng nhau;
- blend mode ở cả một group/sprite.

Mặt nạ morph hình chữ nhật dịch chuyển theo `ratio`, mặt nạ là sprite con chứa
một shape, color transform RGBA và blend add/overlay/hard-light đã được đọc từ
SWF và áp tại runtime. Vẫn phải so GPU vì blend theo cả group có thể khác Flash.

Nếu `warnings` không rỗng, phải soi SWF đó riêng. Có thể mở rộng bộ phát hoặc
giữ phương án full-frame cho riêng hiệu ứng khó; không được âm thầm bỏ hiệu ứng.

## Quy tắc tối ưu các animation tiếp theo

- Đây là cách mặc định bắt buộc cho animation SWF trong dự án. AI sau phải đọc
  tài liệu này và chạy tool trước khi cân nhắc full-frame.
- SWF kiểu ghép shape + matrix như bệ sảnh: dùng tool này.
- SWF chỉ xoay/co giãn vài phần: vẫn dùng tool này, kết quả sẽ rất gọn.
- SWF có filter/morph/script: đọc cảnh báo rồi bổ sung đúng tính năng.
- Chỉ dùng hàng trăm PNG toàn frame làm phương án dự phòng cuối cùng.

## Các animation đang dùng đã chuyển ngày 19/07/2026

Đã thay trong scene thật và xóa bộ PNG toàn-frame cũ sau khi so GPU:

- bệ sảnh: `main_360_plat_compact`;
- vòng loading hàng chờ: `admission_queue_loading_compact`;
- nhân vật nam/nữ ở màn tạo nhân vật:
  `character_select_boy_compact`, `character_select_girl_compact`;
- hiệu ứng cấp 11–20, 21–30, 31–35 và 36–40:
  `profile_level_*_fx_compact`.

Màn chọn nhân vật chỉ chạy đoạn frame 14–91 khi được chọn; trạng thái đứng dùng
frame 1. `content_scale = (0.8, 0.8)` và
`content_position_adjust = (84, 41)` là hiệu chỉnh nội bộ để khớp chính bộ PNG
cũ; không được bỏ hoặc đổi nếu chưa so lại bằng GPU.

Đã chuyển nốt các animation trước đây từng dùng atlas:

- thanh tải thật: `loading_bar_compact`, 100 frame từ 5 shape;
- thanh EXP: `profile_exp_bar_compact`, 100 frame từ 4 shape;
- thanh thể lực: `profile_stamina_bar_compact`, 100 frame từ 4 shape;
- hiệu ứng Shop: `main_360_shop_cover_compact`, 75 frame từ 3 shape.
- hiệu ứng hạng Platinum chưa dùng:
  `ladder_section_icon_platnum_compact`, 60 frame từ 19 shape. Gói này còn cảnh
  báo filter Flash; không đưa vào scene thật trước khi xử lý và so GPU.

Hai thanh phần trăm dùng mặt nạ morph chữ nhật theo ratio thật. Script điều khiển
gọi `seek_frame()` thay cho thuộc tính `frame` của `AnimatedSprite2D`. Bốn atlas
và bốn `.tres` SpriteFrames cũ đã bị xóa. Tool atlas cũ chỉ còn để truy vết lịch
sử và đã bị loại khỏi quy trình; không được khôi phục phương án atlas hoặc PNG
nguyên frame.

Bộ 60 PNG rời `ladder_section_icon_platnum` cũng đã bị xóa sau khi tạo gói
timeline thay thế; không còn animation frame rời trong `assets/animations`.
