# Kiểm thử Tank, xem PostgreSQL và thêm Tank mới

## 1. Chạy bản hiện tại để kiểm thử quà Iron Man

Mở PowerShell thứ nhất:

```powershell
cd C:\Users\ycao7\Downloads\asset_1\BangBangServer
cmd /c npm run migrate
cmd /c npm start
```

Giữ cửa sổ server đang chạy. Trong Godot, mở dự án
`C:\Users\ycao7\Downloads\asset_1\BangBangRemake` rồi nhấn **F6** ở scene đăng
nhập, hoặc nhấn **F5** để chạy cả dự án. Đăng nhập vào tài khoản có nhân vật.

Kết quả đúng:

1. Vào sảnh thì bảng nhận Iron Man xuất hiện.
2. Animation chạy frame 1 đến 97 một lần, sau đó lặp frame 80 đến 97.
3. Nhấn `OK` thì server mới cấp Tank.
4. Mở bảng `TANK`: ô đầu tiên là Iron Man cấp 1 và là Tank chủ chiến.
5. Thoát rồi đăng nhập lại: bảng quà không xuất hiện lần thứ hai.

Muốn thử lại bằng cùng một tài khoản:

```powershell
cd C:\Users\ycao7\Downloads\asset_1\BangBangServer
cmd /c npm run reset-newcomer-tank -- TEN_TAI_KHOAN CONFIRM
```

Lệnh này chỉ xóa quyền sở hữu Iron Man và đưa quà tân thủ của đúng tài khoản
được nhập về trạng thái `pending`. Không dùng lệnh này cho tài khoản thật đang
chơi.

## 2. Xem SQL trực quan bằng pgAdmin 4

Dự án dùng **PostgreSQL**, vì vậy phpMyAdmin trong ảnh (dành cho MySQL/MariaDB)
không xem được database này. Máy hiện đã có:

```text
C:\Program Files\PostgreSQL\18\pgAdmin 4\runtime\pgAdmin4.exe
```

Mở pgAdmin 4 và tạo kết nối:

1. Bấm chuột phải `Servers` → `Register` → `Server`.
2. Tab `General`, đặt tên: `BangBang Local`.
3. Tab `Connection`:
   - Host: `127.0.0.1`
   - Port: `5432`
   - Maintenance database: `bangbang`
   - Username: `bangbang_app`
   - Password: xem phần `DATABASE_URL` trong
     `C:\Users\ycao7\Downloads\asset_1\BangBangServer\.env`
4. Bấm `Save`.

Đường dẫn xem bảng:

```text
Servers
└─ BangBang Local
   └─ Databases
      └─ bangbang
         └─ Schemas
            └─ public
               └─ Tables
```

Chuột phải vào bảng → `View/Edit Data` → `All Rows`. Các bảng Tank quan trọng:

- `tanks`: catalog Tank toàn server.
- `tank_level_stats`: chỉ số của từng cấp.
- `tank_skills`: skill và sát thương/cooldown.
- `tank_skins`: catalog skin.
- `player_tanks`: Tank từng tài khoản đang sở hữu.
- `player_tank_skins`: skin từng tài khoản đang sở hữu.
- `player_rewards`: trạng thái quà Iron Man (`pending` hoặc `claimed`).

Trong `Query Tool`, có thể dùng truy vấn chỉ đọc:

```sql
SELECT tank_key, display_name, max_level, enabled
FROM tanks
ORDER BY id;

SELECT
    account.username,
    tank.tank_key,
    tank.display_name,
    owned.level,
    owned.is_primary,
    owned.acquired_at
FROM player_tanks owned
JOIN accounts account ON account.id = owned.account_id
JOIN tanks tank ON tank.id = owned.tank_id
ORDER BY account.username, tank.tank_key;

SELECT
    account.username,
    reward.reward_key,
    reward.status,
    reward.offered_at,
    reward.claimed_at
FROM player_rewards reward
JOIN accounts account ON account.id = reward.account_id
ORDER BY account.username, reward.reward_key;
```

## 3. Quy trình thêm Tank mới sau này

Không sửa trực tiếp migration cũ. Sao chép file:

```text
BangBangServer\sql\examples\008_add_tank_template.sql.example
```

thành migration có số tiếp theo, ví dụ:

```text
BangBangServer\sql\009_add_<tank_key>.sql
```

Số `008` đã được dùng cho catalog 9 Skin Iron Man, nên Tank mới bắt đầu từ
`009` và tiếp tục tăng dần.

Sau đó:

1. Điền `tank_key` duy nhất, tên, level tối đa và đúng key asset gốc.
2. Điền đủ chỉ số từng level vào `tank_level_stats`.
3. Điền skill, damage, tăng damage theo level và cooldown vào `tank_skills`.
4. Điền skin mặc định và các skin khác vào `tank_skins`.
5. Chép đúng asset đã có vào client, giữ nguyên kích thước 1:1.
6. Thêm `tank_key` vào một ô trống trong `TANK_KEYS` và map đúng ảnh ô/ảnh lớn
   trong `BangBangRemake\scripts\lobby\tank_panel.gd`.
7. Nếu Tank có thể làm chủ chiến ngoài sảnh, map ảnh lớn trong
   `BangBangRemake\scripts\lobby\main_lobby.gd`.
8. Tạo cách nhận Tank ở **server** (quà, shop, nhiệm vụ hoặc admin). Client chỉ
   hiển thị dữ liệu server trả về, không tự cấp Tank.
9. Chạy `cmd /c npm run migrate`, sau đó kiểm tra bằng pgAdmin và vào game.

Không điền đại chỉ số hoặc tự chế asset. Khi thêm Tank mới cần cung cấp tối thiểu:
key/tên Tank, ảnh ô, ảnh lớn, skin, ba skill, bộ chỉ số level 1–6 và cách nhận.
