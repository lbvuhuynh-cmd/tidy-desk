# Bộ hình thiết bị (2D vector, nhìn từ trên xuống)

Danh sách đầy đủ, tình trạng từng hình, kích thước canvas: chạy `python tools/check_assets.py`.
Prompt Recraft cho từng hình: [ART_PROMPTS.md](ART_PROMPTS.md).

## Quy tắc đặt tên
- Tên file = `imageName` trong file màn, viết **snake_case**, ví dụ `keyboard_mechanical.svg`.
- **Một tên = một kích thước ô.** Ví dụ bàn phím có 3 hình riêng: `keyboard_compact` (3×1), `keyboard_mechanical` (4×1), `keyboard_fullsize` (5×1). Script và unit test sẽ báo lỗi nếu cùng một tên bị dùng cho hai kích thước khác nhau.

| Tên | Ô (rộng × cao) | Canvas gợi ý (pt) |
|---|---|---|
| `coffee_mug`, `mouse_wireless`, `plant`, `webcam` | 1×1 | 128×128 |
| `desk_lamp`, `microphone`, `notebook`, `phone`, `speaker` | 1×2 | 128×256 |
| `desk_lamp_tall`, `mic_boom`, `speaker_tower` | 1×3 | 128×384 |
| `cable_bundle`, `game_controller`, `mouse_on_mat` | 2×1 | 256×128 |
| `desk_mat`, `headphones`, `laptop_gaming`, `tablet`, `wifi_router` | 2×2 | 256×256 |
| `keyboard_compact`, `power_strip` | 3×1 | 384×128 |
| `laptop`, `monitor` | 3×2 | 384×256 |
| `keyboard_mechanical` | 4×1 | 512×128 |
| `monitor_ultrawide` | 4×2 | 512×256 |
| `keyboard_fullsize` | 5×1 | 640×128 |

**Góc làm vườn (chương 4, chưa có hình, đang dùng SF Symbol):**

| Tên | Ô (rộng × cao) | Canvas gợi ý (pt) |
|---|---|---|
| `seed_packet`, `succulent_pot`, `birdhouse` | 1×1 | 128×128 |
| `flower_pot`, `pruning_shears`, `garden_gloves` | 1×2 | 128×256 |
| `grow_light` | 1×3 | 128×384 |
| `seedling_tray` | 2×1 | 256×128 |
| `watering_can`, `monstera_pot` | 2×2 | 256×256 |
| `herb_planter` | 3×1 | 384×128 |
| `garden_basket` | 3×2 | 384×256 |
| `flower_box` | 4×1 | 512×128 |
| `soil_bag` | 2×3 | 256×384 |

## Cách vẽ
- **Nhìn thẳng từ trên xuống**, nền **trong suốt**, vẽ theo **hướng gốc** (`gridWidth × gridHeight`; ví dụ bàn phím nằm ngang). Khi người chơi xoay, game tự xoay cả hình 90° theo chiều kim đồng hồ, nên không cần vẽ bản xoay.
- **Canvas đúng tỉ lệ ô**: 128 pt cho mỗi ô, theo bảng trên. Vẽ **sát mép canvas**, không chừa lề: game tự thêm khoảng đệm (khoảng 6% mỗi bên cộng phần cách giữa các ô).
- **Không vẽ sẵn bóng đổ** bên dưới vật. Game tự tạo bóng từ đường viền của hình (bóng tiếp xúc khi nằm yên, bóng đổ lớn dần khi nhấc). Bóng nhẹ *bên trong* vật (các mặt khối) thì vẫn vẽ được.
- Ánh sáng thống nhất từ góc **trên-trái**. Màu dịu, hợp với mặt bàn gỗ sồi (sáng) và gỗ óc chó (tối).
- Trên điện thoại, mỗi ô chỉ khoảng **42–84 pt**, tức canvas bị thu nhỏ còn khoảng 1/3 đến 2/3. Tránh nét mảnh dưới 3 pt (tính trên canvas 128 pt/ô) và chữ nhỏ.

## Định dạng
- **Nên dùng SVG** (hoặc PDF), một kích thước duy nhất (*Single Scale*), bật **Preserve Vector Data**. Nhờ vậy hình luôn sắc nét khi phóng to 1.08× lúc nhấc lên.
- SVG trong Xcode chỉ hỗ trợ một phần chuẩn SVG: **không dùng filter, blur, mask phức tạp, chữ dạng text** (chuyển chữ thành outline). Gradient tuyến tính/tròn thì dùng được.
- PNG cũng được nếu cần: xuất **256 px mỗi ô** (ví dụ bàn phím 4×1 là 1024×256), nền trong suốt.

## Đưa vào game
1. Thả các file `<tên>.svg` (hoặc `.pdf` / `.png`) vào một thư mục bất kỳ, ví dụ `~/Downloads/tidy-art/`.
2. Chạy:
   ```bash
   python3 tools/check_assets.py --import ~/Downloads/tidy-art
   ```
   Script tạo `Assets.xcassets/<tên>.imageset` với đúng cấu hình: Single Scale, Preserve Vector Data. File tên sai sẽ bị bỏ qua và báo lại.
3. `xcodegen generate`, rồi build. Món nào đã có hình thì tự hiện hình thật; món chưa có vẫn hiện SF Symbol như trước, nên có thể thêm dần từng hình.
4. Trước khi phát hành: `python3 tools/check_assets.py --strict` phải không còn hình nào MISSING hay WARN.

Thay một hình: ghi đè file trong `<tên>.imageset/`, hoặc chạy lại `--import`.

## Hình từ công cụ AI (Recraft, …)
- Đổi tên file thành đúng tên asset trước khi import (ví dụ `flat-2d-vector-icon-of-a-mechanical-keyboard--top-.svg` → `keyboard_compact.svg`).
- Các công cụ này thường xuất canvas vuông 1024×1024 có nền trắng đục. `--import` tự **bỏ nền** và **cắt canvas sát hình**, rồi in ra những gì đã sửa. Áp dụng cho cả SVG và PNG (với PNG cần cài Pillow: `pip install pillow`).
- Mảng cùng màu nền nằm **bên trong** món đồ (ví dụ lõi giữa cuộn dây) thì được giữ lại, vì bên dưới thường là lớp viền tô đặc.
- SVG từ Recraft đôi khi có **nền bị cắt thành nhiều mảnh** (không phải một hình chữ nhật) nên `--import` không bỏ được nền (xem trước sẽ thấy nền trắng/kem). Khi đó tải **PNG** thay vì SVG (hoặc render SVG ra PNG) rồi import lại: PNG được xóa nền bằng flood fill.
- Nhưng script không kéo giãn hình: nếu hình bàn phím có tỉ lệ 2:1 mà ô là 4:1 thì hình chỉ phủ khoảng một nửa ô. Script sẽ báo `WARNING aspect …`. Khi tạo hình, ghi rõ tỉ lệ trong prompt (ví dụ *"wide 4:1 horizontal composition, top-down, transparent background"*) hoặc chỉnh khung trong trình vẽ.

## Hình em bé (Baby Corner)
Bé đang được vẽ bằng code (`BabyAvatarView`). Khi có hình thật, nhập 6 hình vuông (khoảng 512×512, nền trong suốt, cùng một em bé lớn dần, nhìn chính diện, toàn thân): `baby_newborn` (0–2 tháng, quấn khăn, ngủ), `baby_infant` (2–4 tháng, nằm cười), `baby_roller` (4–6 tháng, nằm sấp ngẩng đầu), `baby_crawler` (6–9 tháng, ngồi/bò), `baby_toddler` (9–18 tháng, đứng chập chững), `baby_explorer` (18–36 tháng, bé lớn đứng vững). App tự dùng hình thật thay cho bản vẽ code; trang phục khi đó hiện bằng một huy hiệu nhỏ. Nhập bằng `check_assets.py --import` như hình thiết bị.
