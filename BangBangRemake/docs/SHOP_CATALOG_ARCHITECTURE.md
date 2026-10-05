# Kiến trúc Shop và phân loại item

## 1. Nguyên tắc

Không dùng tab hiển thị làm `item_type`. Shop tách thành ba lớp:

- `ItemDefinition`: vật phẩm thật, bền vững theo thời gian.
- `ShopOffer`: cách bán vật phẩm tại một thời điểm.
- `Shelf`: nơi trình bày offer trong Shop.

Nhờ vậy cùng một Tank có thể nằm trong tab Tank, Đề cử và SALE mà chỉ có
một bản ghi vật phẩm. Giá, giảm giá, thời gian bán và giới hạn mua không làm
thay đổi định nghĩa Tank.

## 2. Loại vật phẩm chuẩn

| `item_type` | Nội dung | Trạng thái sở hữu |
|---|---|---|
| `tank` | Tank chơi được | một lần, có cấp và skin đang dùng |
| `tank_skin` | Ngoại hình Tank | một lần, gắn với `tank_key` |
| `avatar_fashion` | Trang phục nhân vật | một lần hoặc có hạn dùng |
| `profile_decoration` | Khung/nền/trang trí cá nhân | một lần hoặc có hạn dùng |
| `vip_pass` | Quyền VIP theo thời hạn | cộng dồn ngày hết hạn |
| `material` | Nguyên liệu nâng cấp/chế tạo | xếp chồng theo số lượng |
| `assistant` | Trợ thủ chơi được | một lần, có cấp/EXP |
| `consumable` | Vật phẩm dùng rồi mất | xếp chồng theo số lượng |
| `bundle` | Gói gồm nhiều phần thưởng | mở thành các item con |

## 3. Dữ liệu offer

Mỗi offer nên có các trường:

```text
offer_id, item_id, shelf_ids[], currency, price, original_price,
start_at, end_at, purchase_limit, giftable, badge, sort_priority,
required_level, required_vip, preview_enabled
```

Các trạng thái `HOT`, `NEW`, `SALE`, giới hạn thời gian và giới hạn số lượng
thuộc offer, không thuộc item.

## 4. Shelf và bộ lọc UI

- Tab chính: Đề cử, Tank, Skin, Thời trang, Trang trí, VIP, Nguyên liệu,
  Trợ thủ.
- Bộ lọc ngang: Toàn bộ, SALE, Xu Khóa.
- Đề cử là shelf do máy chủ trả về theo `sort_priority`; không phải loại item.
- Một offer có thể xuất hiện ở nhiều shelf nhưng giao dịch vẫn dùng cùng
  `offer_id` để tránh sai giá và mua trùng.

## 5. Quy tắc giao dịch

- Client chỉ gửi `offer_id` và số lượng; server tự đọc giá, tiền tệ, thời hạn.
- Trừ tiền và cấp item trong cùng transaction.
- Có idempotency key để bấm mua hai lần không bị trừ hai lần.
- Server kiểm tra sở hữu, giới hạn mua, điều kiện cấp/VIP và thời gian bán.
- Lưu ledger cho mọi biến động tiền và vật phẩm.

## 6. Giai đoạn triển khai

1. UI/catalog local: tab, filter, pagination, trạng thái HOT/NEW/đã có.
2. Schema server: đã có `item_definitions`, `shop_offers`, `shop_shelves`,
   `inventory_stacks`, `purchase_orders`, `shop_purchase_counters`,
   `player_entitlements` và `economy_ledger` append-only.
3. API catalog/inventory theo revision đã nối client; ảnh vẫn nằm ở client hoặc
   package ngoài, còn server nắm giá/quyền sở hữu.
4. API mua và popup xác nhận đã hoạt động với idempotency. Tặng/thử/bán/mở bundle
   chưa có API nên client không tự thay đổi dữ liệu.
5. Công cụ quản trị để lên lịch SALE/Đề cử mà không phát hành lại client.

## 7. Triển khai dữ liệu ngoài hiện tại

- Catalog không còn nằm cứng trong GDScript. Nguồn mặc định là
  `shop_content/catalog.json`, tách riêng mảng `items`, `offers` và `shelves`.
- Nội dung bổ sung nằm trong
  `shop_content/packages/<package>/manifest.json`. Mỗi package có thư mục ảnh riêng
  và có thể chép vào/xóa đi mà không sửa scene hoặc code.
- `ShopCatalog.reload()` chạy mỗi lần mở Shop. Card và số trang được dựng theo dữ
  liệu mới ngay trong phiên chạy.
- Ảnh tương đối trong manifest được nạp trực tiếp bằng `Image.load`; không cần tạo
  `.import` hoặc mở Godot. Ảnh `res://` cũ vẫn đi qua alias asset chuẩn.
- Có thể dùng `shop_content/Add-ShopItem.ps1` để tạo package bằng một lệnh. Xem
  `shop_content/README.md` để biết ví dụ và danh sách tham số.
- Bản export ưu tiên thư mục `shop_content` cạnh executable; cũng hỗ trợ
  `BANGBANG_SHOP_CONTENT_DIR` và `user://shop_content` trước catalog đóng gói.
- Khi online, `ShopPanel` không dùng giá local. Server trả catalog đã publish từ
  PostgreSQL; package mới phải chạy `npm run sync-shop` trước khi được bán.
- Client chỉ gửi `offer_id`, số lượng và idempotency key. Mọi giá/tiền/điều kiện/
  grant được đọc và xác thực lại phía server trong một transaction.
