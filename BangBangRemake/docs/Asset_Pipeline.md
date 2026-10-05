# Quy Trình Lấy Tài Nguyên (SWF -> Godot)

Tài liệu này lưu lại toàn bộ quá trình đã được setup để đảm bảo AI (và con người) không bao giờ quên các bước thực hiện khi cần thêm tài nguyên mới.

## 1. Công Cụ Đã Thiết Lập
Tất cả công cụ đều nằm trong thư mục `tool/` và có thể nháy đúp để chạy trên Windows:
- `1_Tim_Kiem_File.bat`: Dùng để tìm tên file `.swf` gốc dựa trên từ khóa (vd: plat, pvp, pve).
- `2_Xuat_Anh_Dong.bat`: Dùng công cụ nội bộ (`ffdec-cli.exe`) để tự động mở rộng viền Sân khấu (+ 400 pixel) nhằm chống xén mép, sau đó xuất ra toàn bộ khung hình ảnh động (PNG) với nền trong suốt (`-ignorebackground`).
- `3_Giam_Dung_Luong.bat`: (Tùy chọn) Bỏ bớt frame ảnh nếu animation quá nặng.
- `gen_tres.js`: Script ẩn giúp tạo file Resource `.tres` tự động cho Godot nếu số lượng frame quá lớn.

## 2. Bài Học Quan Trọng Đã Giải Quyết
- **Lỗi viền xám / mất góc**: Do hệ thống Mask và Stage của Flash. Đã fix triệt để trong `xuat_anh_dong.js` bằng cách can thiệp header của SWF để ép mở rộng `displayRect` ra cực lớn.
- **Tỉ lệ khung hình**: Dù mở rộng khung hình khiến ảnh gốc trông bị nhỏ bé ở giữa vùng trong suốt, nhưng khi vào Godot nó vẫn giữ tỉ lệ chuẩn xác và bảo toàn tuyệt đối chi tiết.

## 3. Kiến Trúc Sảnh Chính (Main Lobby)
- `MainLobby.tscn` được dọn dẹp để xây lại từ đầu.
- `CenterPlatform`: Node trung tâm, chứa bệ đỡ `AnimatedSprite2D` tải từ `.tres`. Các nút bấm sẽ được gắn đè lên node này để hưởng cùng tọa độ trung tâm, giúp dễ dàng di chuyển cả cụm.
