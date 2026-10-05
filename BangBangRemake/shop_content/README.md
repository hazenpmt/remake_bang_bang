# Thêm vật phẩm Shop mà không mở Godot

Không sửa scene, script hoặc tọa độ UI cho từng vật phẩm. Card, xuống dòng và
phân trang được tạo tự động. Ở game online, PostgreSQL là nguồn quyết định giá,
điều kiện và quyền sở hữu; thư mục này là nguồn xuất bản catalog và ảnh client.

## Cách nhanh nhất

Mở PowerShell tại thư mục này và chạy:

```powershell
.\Add-ShopItem.ps1 `
  -ItemId "thor_red" `
  -ItemType "consumable" `
  -Name "Trứng Thor Đỏ" `
  -Description "Mở ra vật liệu Tank hiếm." `
  -ImagePath "D:\anh_item\thor_red.png" `
  -ShelfIds "recommend","material" `
  -Currency "locked_xu" `
  -Price 499 `
  -Badge "new"
```

Script sẽ:

1. Tạo `packages/thor_red/manifest.json`.
2. Chép nguyên file ảnh vào `packages/thor_red/assets/`, không sửa ảnh nguồn.
3. Gắn cùng `offer_id` vào mọi shelf trong `ShelfIds`.
4. Tạo quy tắc cấp item phía server theo đúng `ItemType`.

Publish catalog vào database:

```powershell
cd ..\..\BangBangServer
npm run sync-shop
```

Sau đó đóng/mở lại Shop trong game. Không cần mở Godot hay sửa code. Phải đặt
cùng package ảnh trong `shop_content` của bản client/export để client hiển thị
được asset key mà server trả về. Ảnh không lưu trong PostgreSQL; server chỉ lưu
đường dẫn logic, giá và quy tắc giao dịch.

## Giá trị và quy tắc cấp item

- `ItemType`: `tank`, `tank_skin`, `avatar_fashion`, `profile_decoration`,
  `vip_pass`, `material`, `assistant`, `consumable`, `bundle`.
- `ShelfIds`: `recommend`, `tank`, `skin`, `fashion`, `decoration`, `vip`,
  `material`, `assistant`. Một offer có thể nằm trong nhiều shelf.
- `Currency`: `xu`, `locked_xu`, `silver`.
- `Badge`: để trống, `hot`, `new`, `sale`.
- `tank`: bắt buộc `-TankKey`; key phải tồn tại trong bảng `tanks` khi mua.
- `tank_skin`: bắt buộc `-TankKey` và `-SkinKey`; người mua phải có Tank gốc.
- `vip_pass`: bắt buộc `-VipDurationDays` từ 1 đến 3650.
- `material`, `consumable`, `bundle`: cộng dồn số lượng trong inventory.
- `avatar_fashion`, `profile_decoration`, `assistant`: chỉ sở hữu một lần.

Các tham số offer gồm `OriginalPrice`, `PurchaseLimit`, `Giftable`,
`RequiredLevel`, `RequiredVip`, `StartAt`, `EndAt`, `SortPriority`,
`MaxQuantityPerOrder` và `PreviewEnabled`. Tham số trình bày gồm
`SkillImagePaths`, `ProgressMax` và `BundleItemIds`.

Thời gian dùng ISO-8601, ví dụ `2026-08-13T18:00:00+07:00`. Để trống nghĩa là
không giới hạn. SALE hiện khi badge là `sale` hoặc `OriginalPrice > Price`.

Nếu cấu hình cấp item sai, transaction mua bị rollback toàn bộ: không có trường
hợp đã trừ tiền nhưng không nhận vật phẩm.

## Package thủ công hoặc nhận từ người khác

```text
packages/
  ten_package/
    manifest.json
    assets/
      anh_item.png
```

Có thể sao chép `packages/_template/manifest.example.json` làm mẫu. `catalog.json`
chứa catalog gốc; package chỉ bổ sung dữ liệu. `item_id` và `offer_id` phải duy
nhất. Giá/HOT/NEW/SALE/thời hạn/giới hạn mua nằm trong offer, không nằm trong
item. Sau khi sao package thủ công vẫn phải chạy `npm run sync-shop` trên server.

## Bản game export và server khác máy

Đặt nguyên thư mục `shop_content` cạnh file `.exe`, hoặc đặt biến
`BANGBANG_SHOP_CONTENT_DIR` trỏ tới thư mục catalog. Trên server có thể dùng cùng
biến hoặc truyền đường dẫn:

```powershell
npm run sync-shop -- D:\shop_content
```

Client không gửi giá, tiền tệ hay item nhận được khi mua. Client chỉ gửi
`offer_id`, số lượng và `Idempotency-Key`; server đọc giá đã publish trong SQL,
khóa giao dịch theo account, kiểm tra số dư/giới hạn/thời hạn/quyền sở hữu, rồi
trừ tiền và cấp item trong cùng transaction.
