# Battle protocol v2

## Ranh giới tin cậy

Client chỉ gửi input/ý định:

- `move {x,y}`;
- `basic_attack {target_x,target_y}`;
- `skill {slot,target_x,target_y}`;
- `skill_aim`, `skill_cancel`, `respawn`, `surrender`.

Server bỏ mọi trường thừa và tự lấy Tank, chỉ số, skin bonus, quân hàm, map,
vị trí, tầm bắn, mục tiêu trúng, damage, critical, cooldown và kết quả từ dữ
liệu server. Không có API nhận HP, điểm, K/D/A, giá trị damage hay phần thưởng
do client cung cấp.

## Sequence, retry và reconnect

Mỗi account trong một match có sequence bắt đầu từ 1 và phải tăng đúng một.
Server lưu SHA-256 của payload đã chuẩn hóa cùng response:

- cùng sequence + cùng payload: trả response cũ, không chạy lệnh lần hai;
- cùng sequence + payload khác: `BATTLE_SEQUENCE_CONFLICT`;
- bỏ số: `BATTLE_SEQUENCE_GAP` kèm số server đang chờ.

Sau timeout, client phải lấy snapshot trước. Nếu snapshot đã có sequence đó thì
không gửi lại; nếu chưa có thì chỉ retry chính xác sequence/payload cũ. Snapshot
cũ có revision thấp hơn trong cùng `state_epoch` không được rollback trạng thái
client. Khi lease chuyển sang worker mới, `state_epoch` tăng; client chấp nhận
checkpoint bền vững của epoch mới dù revision/sequence input liên tục thấp hơn.
Snapshot sai `match_id` hoặc sai `protocol_version` khóa điều khiển và không được
rơi về damage local.

## Transport realtime v3

Client desktop dùng session đăng nhập qua HTTPS để gọi
`POST /api/rooms/match/battle/realtime-ticket`, rồi ưu tiên
`WS /api/realtime/battle`. Vé ngẫu nhiên 256-bit chỉ lưu SHA-256 trong DB, dùng
đúng một handshake, mặc định hết hạn sau 30 giây và bị khóa theo account/session/
match/worker route/epoch. WebSocket chỉ gửi `X-Battle-Ticket`; session dài hạn và
vé đều không nằm trong URL. Server gửi `hello` chứa `transport_version=3` và
`protocol_version=2`, sau đó push snapshot khoảng 10 Hz. Client chỉ coi socket
sẵn sàng sau khi nhận đúng hello và snapshot đầu tiên.

Snapshot đầu tiên và mỗi lần resync là
`snapshot {snapshot_serial,snapshot}`. Các lần tiếp theo ưu tiên
`snapshot_delta {base_snapshot_serial,snapshot_serial,match_id,state_epoch,
base_revision,revision,delta}`; delta top-level có `set`/`unset`, còn participant
được khóa bằng `(team_no,slot_no)` và world entity bằng `entity_key`. Thêm/xóa hay
đổi thứ tự identity sẽ ép gửi full thay vì đoán. Server cũng ép full mặc định mỗi
5 giây và gửi full nếu payload delta vượt 85% payload full; hai ngưỡng được cấu
hình bằng `BATTLE_REALTIME_FULL_SNAPSHOT_MS` và
`BATTLE_REALTIME_DELTA_MAX_RATIO_BASIS_POINTS`.

Client chỉ áp dụng delta khi serial liền nhau, match/epoch đúng và base revision
khớp snapshot push đang giữ. Bất kỳ lệch baseline hoặc patch trỏ tới entity không
tồn tại đều fail-closed: realtime lập tức thành unavailable, socket đóng mã 1002,
HTTP tiếp quản tạm thời và reconnect phải xin ticket mới để nhận full snapshot.
`command_result` và `snapshot_result` là phản hồi riêng, không được thay baseline
của stream; nhờ vậy response xen giữa hai push không làm delta kế tiếp bị lệch.

Message client được giới hạn 16 KiB và chỉ có ba dạng:

- `command {request_id,sequence,command}`;
- `snapshot_request {request_id}` để đồng bộ/reconnect;
- `ping {client_time}` cho kiểm tra tầng ứng dụng khi cần.

Mỗi socket xử lý message theo hàng đợi tuần tự. Rate limit bám theo account và
không reset khi thay socket; backpressure đóng client nhận quá chậm. Ping/pong
phát hiện kết nối chết. Một account chỉ giữ một battle socket; kết nối mới đánh
dấu socket cũ hết quyền trước khi đóng. Logout thu hồi socket ngay và session
cũng được kiểm tra định kỳ để bắt trường hợp admin thu hồi ở tiến trình khác.

Nếu socket mất khi command có thể đã commit, client dùng HTTP snapshot để kiểm
tra `last_processed_sequence`; chỉ gửi lại đúng sequence/payload cũ khi server
chưa xử lý. Vì command database đã idempotent, chuyển transport không tạo damage
hay skill lần hai. HTTP battle API vẫn là fallback, không còn là đường snapshot
polling chính khi WebSocket hoạt động.

Khi socket rớt, client không tái sử dụng vé cũ mà xin vé một lần mới qua HTTPS,
reconnect theo exponential backoff và tiếp tục dùng HTTP fallback trong lúc chờ.
`battle_worker_nodes` heartbeat địa chỉ realtime của từng process; nếu HTTP
gateway nhận yêu cầu trên node không giữ match, vé trả URL của node đang sở hữu
lease. Node/URL thiếu hoặc lease/epoch vừa đổi thì fail-closed và client xin lại.

## Simulation, world entity và settlement

Mỗi match worker giữ toàn bộ state trận trong RAM và chạy bước mô phỏng cố định
50 ms qua một hàng đợi tuần tự riêng. Background tick tiếp tục tiến trận ngay cả
khi không có request; HTTP và WebSocket cùng dùng worker đó, không mô phỏng lại
theo từng viewer. Catch-up có giới hạn để một match bị trễ không giữ event loop
vô hạn. Input di chuyển có lease 300 ms; mất mạng làm Tank
dừng thay vì tiếp tục trôi. Server kiểm tra bounds/collision, ngăn tunnelling và
giữ wall-slide. Đòn đánh/kỹ năng dùng ray/area server, cooldown server và RNG
critical server.

Worker checkpoint state theo batch trong một PostgreSQL transaction mặc định mỗi
500 ms. `move`/`skill_aim` được gom trong cửa sổ này; nếu process chết, hai input
liên tục đó có thể lùi tối đa tới checkpoint gần nhất và client reconcile bằng
`state_epoch`. Lệnh rời rạc như đánh, kỹ năng, hồi sinh và đầu hàng bắt buộc
checkpoint thành công trước khi server ACK, nên không được báo thành công rồi mất
sau crash. Command journal, reward/ledger và event có khóa idempotency; retry một
transaction có kết quả commit chưa rõ không nhân đôi chúng.

PostgreSQL giữ `battle_worker_id`, epoch và lease. Hydrate/claim chạy dưới row lock;
checkpoint chỉ thành công khi cả worker ID và epoch vẫn khớp. Server khác chỉ được
claim lease đã hết, còn worker cũ bị fence và tự loại khỏi registry. Shutdown bình
thường checkpoint rồi nhả lease; process mới hydrate checkpoint và command cache
gần nhất. Mỗi account giữ tối đa 256 response replay gần nhất trong RAM, còn
journal bền vững đầy đủ vẫn nằm trong PostgreSQL.

Protocol v2 quản lý toàn bộ world entity được khai báo của map Maya:

- 45 công trình/turret với HP hoặc số hit phá hủy và collision động;
- hai Tù trưởng với patrol, burst ba phát, projectile và hồi sinh;
- hai Footpoint được kích hoạt khi công trình sinh tương ứng bị phá, tự chọn
  mục tiêu, di chuyển/nổ tiếp xúc và hồi sinh;
- projectile thế giới di chuyển qua nhiều tick và chỉ server quyết định va trúng.

Snapshot phải có đủ đúng tập entity của map. Client phát hiện thiếu, trùng,
không biết hoặc sai protocol sẽ fail-closed và khóa điều khiển; không rơi về AI,
damage hay collision local. `attack_serial` và `last_target_key` chỉ cho client
phát hiệu ứng hình ảnh gốc, không cấp quyền gây damage.

Khi đạt giới hạn điểm, hết giờ hoặc đầu hàng, cùng transaction sẽ:

1. khóa kết quả và tỷ số;
2. đưa room về waiting;
3. tính EXP/Bạc từ K/D/A và đội thắng do server giữ;
4. cập nhật profile/currency đúng một lần;
5. ghi reward snapshot và ledger append-only.

Tank chỉ được xuất trận online khi có `tanks.battle_kit_key`. Hiện catalog runtime
chỉ hỗ trợ `ironman_v1`; điều này cố ý fail-closed để Tank mới không dùng nhầm kỹ
năng Iron Man. `local-test` vẫn là sandbox local riêng và không được ghi kết quả
hay phần thưởng online.

## Giới hạn bắt buộc trước production/ranked

- Client desktop đã nhận full/delta snapshot qua WebSocket, vé reconnect ngắn hạn
  một lần, full-resync định kỳ và HTTP fallback/recovery. Chưa có transport thay
  thế phù hợp cho quy mô rất lớn.
- Match worker in-memory, checkpoint 500 ms và lease/fencing đã có; ticket endpoint
  đọc worker heartbeat để trả đúng URL owner. Chưa có reverse proxy/load balancer
  và autoscaling worker nhiều máy được triển khai ngoài source local.
- Production đông người vẫn cần reverse proxy/gateway triển khai thật, TLS,
  autoscaling theo tải và diễn tập failover/restore định kỳ.
- Production gate bắt buộc Redis rate limit dùng chung; Internet vẫn bắt buộc
  HTTPS/reverse proxy, Redis HA và không mở PostgreSQL.
- Đã có security telemetry append-only và alert rules; chưa có replay/spectator,
  bộ phân tích desync/đối soát trận tự động hoặc hệ thống ban tự động an toàn.

Không gọi v2 là “chống hack tuyệt đối”. Nó đã loại quyền quyết định gameplay map
Maya và kinh tế khỏi client; các hạng mục vận hành/phân tán ở trên vẫn là điều
kiện mở ranked công khai.
