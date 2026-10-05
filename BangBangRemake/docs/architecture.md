# BangBang Remake - Cẩm Nang Kiến Trúc & Lưu Trữ (Memory)

> [!IMPORTANT]
> Đây là file lưu trữ trí nhớ dài hạn của AI (Long-term Context).
> Mỗi khi phiên làm việc bị ngắt hoặc context quá dài khiến AI quên, hãy yêu cầu AI đọc lại file này trước khi tiếp tục.

## 1. Cấu Trúc Dự Án (Godot 4)
- `assets/`: Đồ họa, âm thanh đã được chọn lọc và đổi tên.
  - `assets/ui/`: Ảnh giao diện.
  - `assets/audio/`: Âm thanh sfx.
  - `assets/tanks/`: Sprite của Tank.
- `core/`: Các script chạy ngầm toàn thời gian (Autoload/Singleton) (VD: `game_manager.gd`, `network.gd`).
- `data/`: Cấu hình JSON, CSV hoặc Godot Resources.
- `scenes/`: Giao diện và Object.
  - `scenes/lobby/`: Sảnh chính.
  - `scenes/gameplay/`: Các màn chơi.
  - `scenes/entities/`: Các vật thể (Tank, Đạn, Item).
- `scripts/`: Code GDScript (phân chia thư mục tương tự `scenes/`).
- `docs/`: Tài liệu hệ thống và trí nhớ AI.

## 2. Quy Chuẩn Đặt Tên (Bắt buộc tuân thủ)
- **Thư mục & File**: `snake_case` (VD: `main_lobby.tscn`, `player.gd`).
- **Tên Node (Cây Scene)**: `PascalCase` (VD: `PlayerTank`, `HealthBar`).
- **UI Node Prefix**: 
  - `Btn_`: Button/TextureButton (VD: `Btn_Play`).
  - `Lbl_`: Label/RichTextLabel (VD: `Lbl_Score`).
  - `Tex_`: TextureRect/Sprite2D (VD: `Tex_Background`).
  - `Pnl_`: Panel/PanelContainer.
- **Biến trong Code**: `snake_case` (VD: `current_hp`).
- **Signals**: Tên thì quá khứ hoặc động từ (VD: `on_tank_destroyed`, `game_started`).

## 3. Kiến Trúc Lập Trình (Component-based)
- Không viết logic dồn cục vào một script duy nhất.
- Entity (ví dụ: `Tank`) sẽ là một Physics Node rỗng, chứa các Node con (Component) để xử lý tính năng:
  - `HealthComponent`: Quản lý máu, nhận sát thương.
  - `WeaponComponent`: Logic bắn, hồi chiêu.
  - `MovementComponent`: Tốc độ, xoay, di chuyển.
- Xử lý tương tác xa (UI <-> Gameplay) thông qua **Event/Signal Bus** (Khai báo trong thư mục `core/`).
