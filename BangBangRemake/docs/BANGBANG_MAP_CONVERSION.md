# Chuyển map gốc BangBang sang Godot

Map Maya hiện dùng file gốc `data1_c.map`. File nhị phân này không được đọc trực tiếp
mỗi frame trong game. Công cụ chuyển đổi đọc file một lần và xuất JSON để Godot dùng.

Lệnh tạo lại dữ liệu:

```powershell
python tool\convert_bangbang_map.py `
  "rez\zh_CN\map\data1_c.map" `
  --output "BangBangRemake\assets\battle\maps\Maya Tiên tri(Tính điểm)\data1_c.godot.json" `
  --preview "test_export\data1_c_godot_collision_preview.jpg"
```

## Phần đã xác nhận

- Header chứa kích thước map `2160 x 1413`.
- Section 2 chứa 45 NPC/công trình và tọa độ.
- Section 3 chứa 10 điểm xuất phát thật của hai đội.
- Section 4 và 5 chứa các điểm gameplay bổ sung.
- Section 6 là lưới chiếm chỗ, mỗi ô `24 x 24` px.
- Giá trị âm trong lưới là địa hình tĩnh.
- Giá trị dương là ID NPC/công trình.

Godot runtime hiện tạo va chạm từ các ô âm đã gộp thành hình chữ nhật. Các ô
dương được lưu trong JSON và được `EditorMapPreview` vẽ cùng hình NPC để kiểm tra,
nhưng chưa tạo physics runtime. Làm như vậy tránh xuất hiện vật cản vô hình trước
khi logic NPC/công trình tương ứng được xây dựng.

`data1_c.map` nguyên gốc cũng được giữ cạnh JSON để có thể đối chiếu hoặc chuyển
lại về sau. Section 7 trở đi chưa được dùng; công cụ ghi lại offset và type để tiếp
tục phân tích khi làm các luật chơi/nút đường riêng của map.

## Áp dụng cho map khác

1. Tra `MapTemplate_table.xml` để lấy đúng file `.map` và ảnh nền của map.
2. Chạy công cụ chuyển đổi với đường dẫn nguồn và đích mới.
3. Tạo folder riêng cho map trong `assets/battle/maps`.
4. Trỏ scene/script của map mới tới JSON mới.
5. Chỉ bật va chạm NPC sau khi đã dựng đúng hình và logic của NPC đó.

## Xem map trong Godot mà không chạy F6

1. Mở `scenes/battle/PvpBattleMap.tscn`.
2. Chuyển sang cửa sổ `2D`.
3. Trong Scene Tree, mở:
   `ViewportContainer/WorldViewport/World`.
4. Chọn `Background` rồi nhấn `F` nếu cần đưa toàn bộ map vào giữa màn hình.
5. Chọn node `EditorMapPreview` để bật/tắt từng lớp trong Inspector.

Các tùy chọn của `EditorMapPreview`:

- `Show Npc Visuals`: hình thật của NPC, công trình và vật phẩm.
- `Show Static Collision`: va chạm địa hình màu đỏ.
- `Show Npc Collision`: vùng chiếm chỗ của NPC/công trình màu cam.
- `Show Team Spawns`: điểm xuất phát; xanh là đội 1, đỏ là đội 2.
- `Show Gameplay Points`: mốc đội và điểm đặc biệt trong file map.
- `Show Labels`: tên, unique ID và template ID.
- `Collision Opacity`: độ trong suốt của lớp va chạm.

Node này có script `@tool`, chỉ vẽ dữ liệu khi đang ở Godot Editor và tự ẩn
khi chạy game. Va chạm NPC màu cam hiện mới là dữ liệu xem trước; chưa được bật
thành physics runtime cho đến khi logic NPC tương ứng được xây dựng.
