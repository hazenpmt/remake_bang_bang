# Content delivery và quản trị Shop

Trang `/admin` của BangBangWeb có công cụ upload ảnh gốc, tạo item/offer, lưu nháp,
publish và rollback. Ảnh chỉ nhận PNG/JPEG/WebP tối đa 16 MiB, được giữ nguyên byte,
đặt tên lưu theo SHA-256 và không cho ghi đè một `asset_id` bằng nội dung khác.

Catalog dùng URI `content://asset_id`. Client tải manifest, kiểm tra dung lượng và
SHA-256 rồi cache vào `user://content_cache`. Các đường dẫn `res://` hiện có vẫn là
nội dung nền và có thể dùng làm `fallback_image`; không cần di chuyển khỏi client.

Local dùng `CONTENT_STORAGE_ROOT=./content_storage` và để
`CONTENT_PUBLIC_BASE_URL=` trống. Production bắt buộc URL HTTPS trỏ tới CDN/origin;
`CONTENT_STORAGE_ROOT` phải là volume bền vững dùng chung hoặc được đồng bộ nguyên trạng
tới object storage. Không dùng ổ đĩa tạm của một container làm nguồn duy nhất.

API liên quan:

- `GET /api/content/manifest` và `GET /content/...`: public, chỉ chứa release đã publish.
- `GET /api/admin/shop/editor`: catalog live, draft, asset và lịch sử release.
- `POST /api/admin/content/assets`: upload nhị phân với `X-Asset-Id`.
- `POST /api/admin/shop/draft`, `/publish`, `/rollback`: chỉ role admin.

Tank hoặc skin chỉ cần ảnh mới để xuất hiện trong Shop nếu logic gameplay tương ứng đã
có sẵn. Một tank hoàn toàn mới còn cần dữ liệu tank/skill/animation authoritative phía
server và resource gameplay tương thích phía client; không cho panel phát hành code hay
PCK không ký vì đó là đường đưa mã độc vào game.
