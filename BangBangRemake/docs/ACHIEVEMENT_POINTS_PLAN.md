# Kế hoạch logic nhiệm vụ và điểm thành tích

Tài liệu này chỉ chốt hướng triển khai. UI hiện tại chưa tự cộng điểm và chưa
ghi tiến độ nhiệm vụ vào server.

## 1. Server là nguồn dữ liệu duy nhất

- Client chỉ gửi sự kiện gameplay hoặc nhận snapshot; client không được tự cộng
  tiến độ hay điểm thành tích.
- Mỗi nhiệm vụ có `achievement_id`, loại điều kiện, mục tiêu, điểm thưởng,
  trạng thái mở/ẩn và cờ cho phép tính hồi tố.
- Mỗi tài khoản lưu riêng `progress`, `completed_at` và `points_awarded`.
  Khóa duy nhất `(account_id, achievement_id)` ngăn cộng thưởng hai lần.

## 2. Danh mục nhiệm vụ

Ví dụ dữ liệu cấu hình:

```json
{
  "achievement_id": "battle_play_10",
  "category": "battle",
  "event": "battle_finished",
  "counter": "matches_played",
  "target": 10,
  "points": 20,
  "retroactive": true
}
```

Những nhóm đầu tiên nên triển khai:

- Số trận đã đấu: 1, 10, 100, 500.
- Số trận thắng: 1, 10, 100.
- Hạ gục, hỗ trợ, chuỗi thắng và MVP.
- Sở hữu/nâng cấp Tank, skin và cấp nhân vật.
- Hoạt động xã hội: kết bạn, Guild, đội và phòng PvP.

## 3. Luồng cập nhật

1. Trận đấu hoặc chức năng server phát sự kiện chuẩn hóa kèm `event_id`.
2. Achievement service ghi nhận `event_id` để chống xử lý lặp.
3. Service tìm các nhiệm vụ cùng loại sự kiện và tăng tiến độ bằng transaction.
4. Khi lần đầu đạt mục tiêu, cùng transaction sẽ đặt `completed_at`, cộng điểm
   và đánh dấu `points_awarded=true`.
5. Server đẩy snapshot mới về lobby hiện tại để UI đổi ngay, không cần đăng nhập
   lại hoặc reset server.

## 4. Payload gửi về client

```json
{
  "achievement_points": 40,
  "achievement_completed": 1,
  "achievement_total": 239,
  "achievements": [
    {
      "achievement_id": "battle_play_1",
      "name": "Lính Mới",
      "description": "Đấu 1 trận",
      "progress": 0,
      "target": 1,
      "points": 6,
      "completed": false,
      "icon": "icon_record001"
    }
  ],
  "medals": []
}
```

Client lọc `Tất cả / Đã xong / Chưa xong` từ snapshot này. Thanh cuộn và các
dòng phải sinh theo số phần tử thật; không dùng danh sách fake khi online.

## 5. Quy tắc cần chốt trước khi viết database

- Thành tích nào được tính hồi tố từ thống kê cũ.
- Thành tích ẩn có hiện tên trước khi hoàn thành hay không.
- Có thành tích theo mùa và thời điểm reset hay không.
- Điểm thành tích chỉ là điểm hồ sơ hay được dùng đổi thưởng.
- Khi xóa/đổi cấu hình nhiệm vụ cũ có giữ điểm đã nhận hay không.

## 6. Kiểm thử bắt buộc

- Một `event_id` gửi hai lần chỉ tăng tiến độ một lần.
- Hai request đồng thời hoàn thành cùng nhiệm vụ chỉ cộng điểm một lần.
- Tiến độ không vượt mục tiêu hiển thị.
- Đăng nhập lại, đổi server hoặc mất kết nối không làm mất tiến độ.
- Client đang mở KHO nhận snapshot mới và cập nhật ngay.
- Bộ lọc, cuộn và tổng `đã hoàn thành/tổng nhiệm vụ` đúng với payload.

