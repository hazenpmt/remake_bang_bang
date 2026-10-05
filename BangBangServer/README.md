# BangBang Remake server

Backend đầu tiên cho luồng đăng ký, đăng nhập, tạo nhân vật và lấy dữ liệu sảnh.
Backend này nằm ngoài thư mục `BangBangRemake`, nên không được đóng gói khi
Godot xuất bản client.

## Chạy local

PostgreSQL 18 đã được cài local. Lần đầu tiên:

```powershell
cmd /c npm run setup-db
```

Nhập mật khẩu `postgres` đã đặt trong trình cài. Ký tự mật khẩu được che.
Lệnh này tự tạo:

- database `bangbang`;
- user riêng `bangbang_app`;
- file bí mật `.env`;
- toàn bộ bảng ban đầu.

Sau đó chạy backend:

```powershell
cmd /c npm start
```

Có thể nhấp lần lượt `1_SETUP_DATABASE.bat`, rồi `2_START_SERVER.bat`.
API mặc định chạy tại `http://127.0.0.1:8080`.

Tài liệu bảo mật, quyền admin và checklist đưa server lên Internet nằm tại
`SECURITY_AND_DEPLOYMENT.md`.
Quy trình vận hành Redis, health/metrics, cảnh báo, backup/restore và failover nằm
tại `OPS_RUNBOOK.md`.

Không đưa file `.env` hoặc mật khẩu database vào bản game Godot.

## Hàng chờ và giới hạn người online

Sức chứa được chỉnh trong `.env`:

```text
MAX_ONLINE_PLAYERS=100
```

Sau khi đổi giá trị, tắt và bật lại `2_START_SERVER.bat`.

Các thiết lập liên quan:

- `PRESENCE_LEASE_SECONDS=90`: tự giải phóng suất nếu client mất heartbeat.
- `HEARTBEAT_INTERVAL_SECONDS=20`: chu kỳ heartbeat từ Godot.
- `QUEUE_TICKET_SECONDS=900`: thời gian vé chờ nếu client ngừng kiểm tra.
- `QUEUE_POLL_SECONDS=3`: thời gian giữa hai lần kiểm tra thứ tự.
- `LOGIN_RATE_LIMIT=8`: tối đa 8 lần đăng nhập/đăng ký mỗi IP trong 60 giây.
- `QUEUE_POLL_RATE_LIMIT=30`: giới hạn spam kiểm tra hàng chờ.

## Giới hạn tạo tài khoản

Mỗi mã cài đặt của client chỉ được tạo một tài khoản sau mỗi 3 giờ. Mỗi IP được tạo tối đa
5 tài khoản trong cùng khoảng 3 giờ để không chặn nhầm quán net/gia đình dùng chung mạng.
Thời gian được chỉnh trong `.env`:

```text
REGISTRATION_COOLDOWN_SECONDS=10800
REGISTRATION_IP_LIMIT=5
TRUST_PROXY=false
```

Client gửi mã cài đặt qua header `X-Device-Id`. Server chỉ lưu HMAC-SHA256
của IP và mã cài đặt trong bảng `account_registrations`, không lưu giá trị gốc.
Khóa HMAC nằm trong `REGISTRATION_HASH_SECRET` và không được đưa vào client.

Giữ `TRUST_PROXY=false` khi backend mở trực tiếp. Chỉ bật thành `true` khi
backend nằm sau reverse proxy đáng tin cậy và kết nối trực tiếp đã bị chặn.

API hàng chờ:

- `POST /api/admission/join`
- `GET /api/admission/status`
- `POST /api/admission/heartbeat`
- `POST /api/admission/leave`

## Phòng PvP

Người chơi phải có phiên đăng nhập và suất online hợp lệ. Các tab thường chỉ trả
phòng thật do người chơi tạo; tab `test` chỉ trả các phòng cố định do hệ thống
khởi tạo.

- `GET /api/rooms?tab=solo`
- `GET /api/rooms/current`
- `GET /api/rooms/maps`
- `POST /api/rooms/create`
- `POST /api/rooms/join`
- `POST /api/rooms/quick-join`
- `POST /api/rooms/map`
- `POST /api/rooms/start`
- `POST /api/rooms/leave`

Phòng mới có tối đa 5 người. Thành viên được xếp theo thứ tự gia nhập; người đầu
tiên là đội trưởng. Khi đội trưởng rời phòng, thành viên kế tiếp tự lên ô đầu và
trở thành đội trưởng, các thành viên còn lại được dồn lên theo đúng thứ tự.

Danh sách bản đồ lấy từ bảng `game_maps`, không hard-code ở client. Chỉ đội
trưởng được đổi bản đồ và bắt đầu trận. Khi thêm bản đồ mới, server cần có bản
ghi `game_maps` đang bật và client cần có asset đúng tại
`thumbnail_asset_path` mà server trả về.

## Phân quyền

Tài khoản đăng ký từ game hoặc website luôn là `player`. Chỉ console của server được đổi quyền:

```powershell
cmd /c npm run set-role -- ten_tai_khoan admin
cmd /c npm run set-role -- ten_tai_khoan player
```

Đổi quyền sẽ thu hồi các session cũ. Session admin mặc định tồn tại 8 giờ qua
`ADMIN_SESSION_HOURS=8`. API quản trị hiện có:

- `GET /api/admin/overview`
- `GET /api/admin/security-events`
- `GET /api/admin/accounts?search=&page=1&page_size=25`

API danh sách tài khoản không trả về password hash, session token, IP hash hoặc
device hash.

## Shop và Kho server-authoritative

Catalog online nằm trong PostgreSQL. Thêm package/ảnh bên ngoài bằng
`BangBangRemake/shop_content/Add-ShopItem.ps1`, sau đó publish atomically:

```powershell
cmd /c npm run migrate
cmd /c npm run sync-shop
```

Có thể dùng catalog ở thư mục khác:

```powershell
cmd /c npm run sync-shop -- D:\shop_content
```

API người chơi:

- `GET /api/shop/catalog`: catalog đang bán, số lần đã mua và trạng thái sở hữu.
- `POST /api/shop/purchases`: body chỉ có `offer_id`, `quantity`; bắt buộc header
  `Idempotency-Key`.
- `GET /api/inventory`: item và entitlement thật của account.

Client không quyết định giá/tiền/item nhận. Server khóa giao dịch theo account,
đọc offer từ SQL, kiểm tra lịch bán/cấp/VIP/giới hạn/sở hữu/số dư, trừ tiền và
cấp item trong cùng PostgreSQL transaction. Retry cùng idempotency key trả lại
kết quả cũ, không trừ tiền hoặc cấp item lần hai. `economy_ledger` là bảng
append-only và purchase/audit history không bị xóa cascade theo account.

Kiểm thử riêng cần PostgreSQL local:

```powershell
cmd /c npm run test:economy-db
cmd /c npm run test:shop-api
```

## PvP server-authoritative v2

Trận online thật (`is_test=false`) dùng server làm nguồn sự thật cho vị trí,
va chạm, HP/khiên, đòn đánh, cooldown, kỹ năng Iron Man, K/D/A, điểm số, hồi
sinh, kết quả và phần thưởng. Sandbox TEST vẫn là mô phỏng local tách biệt và
không được ghi kết quả online.

Protocol v2 đưa toàn bộ world entity của map Maya vào cùng simulation server:
45 công trình/turret, hai Tù trưởng và hai Footpoint. Server quyết định AI,
patrol, mục tiêu, projectile, sát thương, phá hủy, hồi sinh và thời điểm kích
hoạt Footpoint; client chỉ render snapshot và hiệu ứng từ `attack_serial`.
Mỗi trận online được nạp đúng một lần vào match worker trong RAM và mô phỏng bước
cố định 50 ms, nên trận vẫn tiến triển khi không có request người chơi. Worker
checkpoint participant, 49 world entity, projectile, effect, event và command
theo lô xuống PostgreSQL mặc định mỗi 500 ms; không còn đọc/ghi toàn bộ state DB
ở từng tick. Lease 5 giây + epoch trong DB ngăn hai server cùng điều khiển một trận.

API trận:

- `POST /api/rooms/match/battle/realtime-ticket`: dùng session HTTPS để lấy vé
  WebSocket một lần, mặc định hết hạn sau 30 giây; vé khóa theo account, session,
  match, worker route và epoch.
- `WS /api/realtime/battle`: transport ưu tiên cho snapshot push và command.
  Handshake chỉ gửi `X-Battle-Ticket`, không đưa session đăng nhập dài hạn hoặc vé
  vào URL. `transport_version=3`; payload gameplay vẫn giữ protocol v2.
- `GET /api/rooms/match/battle`: snapshot có `protocol_version`, `revision` và
  `last_processed_sequence` của người xem; đồng thời là đường reconnect/fallback.
- `POST /api/rooms/match/battle/commands`: client chỉ gửi ý định đã chuẩn hóa;
  không gửi damage, HP, mục tiêu trúng, điểm hay phần thưởng; giữ làm fallback
  idempotent nếu socket mất giữa một command.

WebSocket giới hạn JSON 16 KiB, chỉ nhận text, xử lý command tuần tự, rate-limit
theo account, đóng client có outbound buffer bị nghẽn và dùng ping/pong phát hiện
kết nối chết. Kết nối mới thay socket cũ của cùng account; logout đóng socket
ngay, còn session bị thu hồi từ nơi khác được kiểm tra lại định kỳ. Client tự
reconnect có backoff và trong lúc socket chưa sẵn sàng sẽ dùng HTTP với cùng
sequence, nên không chạy lệnh hai lần.

Transport v3 gửi full snapshot có `snapshot_serial` khi vừa kết nối/reconnect,
sau đó ưu tiên `snapshot_delta` chỉ chứa field/entity thay đổi. Delta khóa theo
`base_snapshot_serial`, `match_id`, `state_epoch` và `base_revision`; client ghép
sai baseline sẽ đóng socket, dùng HTTP fallback và xin ticket mới để lấy full
snapshot. Server vẫn gửi full snapshot định kỳ mặc định 5 giây để tự resync và
tự chọn full nếu delta không nhỏ hơn đủ nhiều. Phản hồi `command_result` hay
`snapshot_result` không thay baseline của luồng push.

Một server local có thể để `BATTLE_PUBLIC_REALTIME_URL=` trống; client tự suy ra
`ws://`/`wss://` từ API URL. Khi chạy nhiều node, đặt `BATTLE_NODE_ID` khác nhau và
`BATTLE_PUBLIC_REALTIME_URL` là URL công khai đầy đủ của từng node, ví dụ
`wss://battle-2.example/api/realtime/battle`. Node heartbeat URL/lease vào
PostgreSQL để endpoint ticket trả đúng route đang sở hữu match.

Mỗi command dùng sequence tăng đúng một. Retry cùng sequence và cùng payload trả
lại response cũ; đổi payload bị chặn. Khi kết trận, EXP/Bạc được cộng đúng một
lần trong transaction và ghi `game_match_battle_rewards` cùng `economy_ledger`
append-only. Chạy kiểm thử PostgreSQL:

```powershell
cmd /c npm run test:battle-db
cmd /c npm run test:battle-memory-db
```

Giao thức, ranh giới tin cậy và giới hạn triển khai hiện tại được ghi tại
`docs/BATTLE_PROTOCOL.md`. Protocol v2 đã hoàn tất authority cho gameplay map
Maya, WebSocket delta và match worker in-memory có checkpoint/lease/fencing. Source
đã có production gate, Redis adapter, health/metrics, security telemetry và
backup-restore drill; vẫn phải triển khai reverse proxy/TLS/load balancer,
Redis/Prometheus HA và autoscaling thật trước khi bật ranked công khai.
