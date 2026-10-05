# Bảo mật và triển khai BangBang Server

## Trạng thái hiện tại

Backend local đã đủ để tiếp tục làm UI/asset và thử luồng đăng ký, đăng nhập, tạo nhân vật,
hàng chờ và sảnh. Đây chưa phải cấu hình được phép mở thẳng cổng 8080 ra Internet.

Các lớp bảo vệ đã có:

- Mật khẩu dùng scrypt với salt ngẫu nhiên.
- Database chỉ lưu hash của session token.
- SQL dùng tham số thay vì ghép chuỗi từ dữ liệu client.
- Tài khoản đăng ký luôn có quyền `player`; client không thể tự gửi quyền `admin`.
- API `/api/admin/*` kiểm tra quyền tại backend.
- Session admin hết hạn sau 8 giờ; đổi vai trò sẽ thu hồi toàn bộ session cũ.
- Mỗi mã cài đặt tạo tối đa 1 tài khoản trong 3 giờ.
- Mỗi IP tạo tối đa 5 tài khoản trong 3 giờ.
- Có giới hạn request theo IP và theo tên tài khoản đăng nhập.
- Shop/Inventory dùng dữ liệu PostgreSQL; client không thể tự gửi giá hoặc vật
  phẩm muốn nhận.
- Mua hàng có account advisory lock, giới hạn số lượng, điều kiện cấp/VIP,
  kiểm tra sở hữu và số dư trong cùng transaction.
- `Idempotency-Key` chống double-click/retry trừ tiền hai lần; request hash chặn
  tái dùng cùng key cho nội dung khác.
- Mọi giao dịch thành công ghi order và ledger tiền/item append-only. Audit
  history không bị xóa cascade khi xóa account.
- Combat online dùng server authority: client chỉ gửi input, không quyết định
  vị trí hợp lệ, mục tiêu trúng, damage, critical, cooldown, HP, K/D/A hay kết
  quả. Protocol v2 cũng giữ authority cho turret/công trình, Tù trưởng,
  Footpoint, projectile, AI, phá hủy và hồi sinh của map Maya.
- Command trận có sequence liên tục, hash payload và replay response idempotent;
  reconnect dựa trên revision/snapshot và không chạy lại command đã commit.
- Battle WebSocket v3 dùng vé 256-bit một lần, hạn ngắn, ràng buộc account/session/
  match/worker/epoch; không đưa session đăng nhập hoặc vé vào URL. Message bị giới
  hạn kích thước/loại/tần suất theo account và xử lý tuần tự. Socket cũ
  mất quyền khi reconnect, logout đóng socket ngay, session được kiểm tra định kỳ,
  client chậm bị đóng theo backpressure và kết nối chết bị phát hiện bằng ping.
- Snapshot stream dùng serial + match/epoch/revision baseline, gửi delta theo
  identity ổn định và full-resync định kỳ. Mất/gãy/sai patch làm client đóng
  realtime, chuyển HTTP fallback và xin ticket mới, không tiếp tục với state đoán.
- EXP/Bạc cuối trận do server tính và settlement đúng một lần trong transaction;
  reward snapshot và ledger đều append-only.
- `battle_kit_key` khóa fail-closed: Tank chưa có bộ kỹ năng server không được
  xuất trận online và không thể dùng nhầm kỹ năng của Tank khác.
- Server local mặc định chỉ bind `127.0.0.1`.
- `npm audit --omit=dev` ngày 13/08/2026: không phát hiện lỗ hổng đã công bố.
- HTTP và Battle WebSocket dùng chung token-bucket rate limit qua Redis khi
  production; key chỉ chứa HMAC. Redis lỗi sẽ fail-closed thay vì reset quota.
- Security event được batch vào bảng append-only, tự redaction credential, HMAC
  IP và có endpoint admin/Prometheus alert để điều tra hành vi bất thường.
- Có liveness/readiness riêng, metrics Bearer riêng và backup custom-format kèm
  SHA-256 + restore drill PostgreSQL cô lập kiểm tra row count/trigger audit.

## Khi nào cần bật server?

Không cần bật PostgreSQL/backend khi chỉ:

- tìm, chép hoặc thay ảnh;
- chỉnh scene, vị trí, kích thước, animation, font;
- chạy kiểm tra import asset hoặc mở scene không cần dữ liệu online.

Cần bật PostgreSQL và `2_START_SERVER.bat` khi thử:

- đăng ký, đăng nhập và khôi phục phiên;
- tạo nhân vật;
- hàng chờ, heartbeat, dữ liệu profile/tank/tiền;
- API hoặc màn hình quản trị;
- migration và kiểm thử tích hợp online.

Khi phát hành thật, backend và PostgreSQL phải chạy liên tục dưới dạng service. Người chơi
không được nhận thư mục `BangBangServer`, file `.env` hay thông tin PostgreSQL.

## Tạo hoặc đổi quyền admin

Tạo tài khoản bình thường trong game trước, sau đó chạy tại thư mục `BangBangServer`:

```powershell
cmd /c npm run set-role -- ten_tai_khoan admin
```

Đổi lại thành người chơi:

```powershell
cmd /c npm run set-role -- ten_tai_khoan player
```

Lệnh này chỉ chạy ở máy server, ghi nhật ký đổi quyền và thu hồi phiên cũ. Tài khoản phải
đăng nhập lại. Không thêm nút hoặc API cho client tự đổi vai trò.

API quản trị đầu tiên: `GET /api/admin/overview`. Người chơi thường nhận HTTP 403.

## Việc bắt buộc trước khi mở Internet

1. Dùng tên miền và HTTPS qua reverse proxy; không gửi mật khẩu/token qua HTTP.
2. Đổi `network/api_base_url` trong `BangBangRemake/project.godot` thành dạng
   `https://api.tenmien.example/api` trước khi export client.
3. Không mở cổng PostgreSQL 5432 ra Internet. Chỉ backend được kết nối database.
4. Chỉ bật `TRUST_PROXY=true` khi backend không thể bị truy cập trực tiếp và proxy đáng tin
   cậy đã ghi đè `X-Forwarded-For`.
5. Lưu `.env` trong kho bí mật của máy chủ; thiết lập backup PostgreSQL và thử phục hồi.
6. Thêm log tập trung, cảnh báo lỗi và theo dõi CPU/RAM/database trước khi có người chơi thật.

## Giới hạn còn lại cần làm sau

- `X-Device-Id` là mã cài đặt, có thể bị người chơi xóa hoặc giả mạo; không phải mã phần cứng.
- Local/test có thể dùng rate limit RAM; `NODE_ENV=production` bắt buộc Redis
  dùng chung và từ chối khởi động nếu cấu hình an toàn còn thiếu.
- Chưa có xác minh email, quên mật khẩu, CAPTCHA hay 2FA cho admin.
- Source đã có health/metrics/alert rules và backup-restore command; reverse proxy,
  TLS, firewall, Redis/Prometheus/Alertmanager và lịch sao chép backup off-site vẫn
  phải được triển khai trên hạ tầng thật theo `OPS_RUNBOOK.md`.
- Battle v2 đã có fixed tick 50 ms độc lập request, toàn bộ world entity map Maya
  nằm trong match worker RAM và client desktop ưu tiên WebSocket snapshot push;
  HTTP giữ làm fallback an toàn. Worker checkpoint theo batch mặc định 500 ms,
  dùng lease/epoch fencing 5 giây và lệnh rời rạc chỉ ACK sau checkpoint.
- Production đông người vẫn cần reverse proxy/gateway realtime triển khai thật,
  autoscaling/failover chủ động,
  replay/spectator và phân tích desync/anti-cheat nâng cao từ telemetry đã thu.
- Production gate đã bắt buộc Redis và metrics bảo vệ; vẫn cần Redis HA, gateway,
  Alertmanager và nơi lưu backup mã hóa/versioned ở môi trường triển khai thật.
- User PostgreSQL local hiện sở hữu schema để tiện migration. Khi triển khai production nên
  tách tài khoản migration và tài khoản runtime có quyền tối thiểu.
