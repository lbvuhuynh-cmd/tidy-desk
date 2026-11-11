# Tidy Desk: Tech & Setup

Game iOS thể loại Cozy Tidy / Organization Puzzle: bàn làm việc đang bừa bộn (bàn phím nằm lệch, cốc cà phê chắn chỗ, dây cáp lung tung…). Người chơi kéo thả thiết bị từ **ngăn kéo phụ kiện** lên **mặt bàn dạng lưới**, dời những món đang nằm sai chỗ, sao cho mọi thứ vừa khít, không món nào đè lên nhau.
SwiftUI · SwiftData · iOS 17+ · giao diện tiếng Anh (thị trường toàn cầu).

## Chạy thử trên Simulator
Cần máy Mac có **Xcode 16+** và [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
cd tidy-desk
xcodegen generate                 # tạo TidyDesk.xcodeproj
open TidyDesk.xcodeproj           # scheme TidyDesk → simulator iPhone → Run
# hoặc chạy unit test:
xcodebuild -project TidyDesk.xcodeproj -scheme TidyDesk \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Rung (haptic) chỉ cảm nhận được trên iPhone thật: đặt `DEVELOPMENT_TEAM` trong `project.yml`.

## Cấu trúc
```
TidyDesk/
  App/                 TidyDeskApp (SwiftData container + LevelManager vào environment)
  Data/                LevelManager (đọc level_<n>.json, availableLevels, isUnlocked, loadLevel, nextLevel)
  Domain/Models/       TechItem (+ ItemCategory), DeskGrid, LevelData (Decodable theo schema), LevelProgress (@Model), GridPoint
  Domain/Logic/        SnapMath (hít vào ô), TilingSolver (kiểm tra màn giải được), LevelValidator, StarRating
  Features/Desk/       DeskDragViewModel (engine kéo thả), DeskGameplayView, DeskSurfaceView, AccessoryDrawerView,
                       FloatingItemLayer, DraggableItemView, ItemTileView, SetupCompleteView (+ confetti)
  Features/Levels/     LevelSelectView (chọn bàn, sao, mở khóa tuần tự)
  Services/Audio/      SoundManager (singleton, AVAudioPlayer, preload), ToneSynth (âm thanh dự phòng tổng hợp trong bộ nhớ)
  Services/Haptics/    HapticManager (singleton: light / selection / rigid / soft / warning / success)
  Services/Feedback/   GameFeedback (protocol) + FeedbackEngine (nối mỗi khoảnh khắc chơi → 1 haptic + 1 âm thanh)
  Shared/              Theme (sáng/tối, màu theo nhóm đồ, dải LED), FramePreferenceKey, FlowLayout
  Resources/           Levels/level_1.json … level_8.json, Assets.xcassets, Sounds/*.wav
TidyDeskTests/         lưới, va chạm, solver, snap, drag engine, bàn bừa bộn ban đầu, LevelManager, âm thanh
schema/level_schema.json   JSON Schema của một màn (VS Code dùng nó để gợi ý và báo lỗi khi viết màn)
tools/check_levels.py      kiểm tra mọi file level_<n>.json
tools/generate_sounds.py   tạo 6 file .wav tạm
tools/check_assets.py      danh sách 27 hình thiết bị + nhập hình (--import); quy cách vẽ: ASSETS.md
MAC_BUILD.md               quy trình build/test/chụp màn hình trên Mac; ảnh nằm trong screenshots/ (app/, art/)
```

## Màn chơi (mỗi màn = 1 file JSON)
Thêm màn mới: tạo `TidyDesk/Resources/Levels/level_<n>.json` (n = `levelId`), chạy `python tools/check_levels.py`, rồi chạy lại `xcodegen generate`. **Không cần sửa code Swift.**

```json
{
  "$schema": "../../../schema/level_schema.json",
  "levelId": 9,
  "levelName": "Cozy Reading Nook",
  "gridRows": 4, "gridCols": 5,
  "items": [
    { "id": "keyboard", "name": "Mechanical Keyboard", "gridWidth": 4, "gridHeight": 1,
      "initialPosition": { "row": 3, "col": 1 },
      "correctPosition": { "row": 2, "col": 0 },
      "imageName": "keyboard.fill", "category": "peripheral" }
  ]
}
```
| Trường | Ý nghĩa |
|---|---|
| `levelId` | Số thứ tự màn (1, 2, 3…), phải trùng số trong tên file. Thứ tự mở khóa đi theo số này |
| `levelName` | Tên hiển thị |
| `gridRows`, `gridCols` | Kích thước bàn (tối đa khoảng 8 cột trên iPhone) |
| `items[].id` | Mã duy nhất trong màn |
| `gridWidth`, `gridHeight` | Số ô chiếm (theo hướng gốc; người chơi có thể chạm để xoay) |
| `initialPosition` | Ô trên-trái nếu món **nằm sẵn trên bàn** (bừa bộn); `null` hoặc bỏ trống = nằm trong ngăn kéo |
| `correctPosition` | Không bắt buộc. Nếu có: màn chỉ qua khi món nằm **đúng ô này, đúng hướng gốc**, và bàn hiện viền mờ chỗ đích. Không có = đặt đâu vừa cũng được |
| `imageName` | Tên ảnh trong Assets; nếu không có ảnh thì dùng SF Symbol cùng tên |
| `category` | Không bắt buộc (mặc định `peripheral`): `peripheral`, `display`, `audio`, `mobile`, `power`, `cozy` |

Luật: tổng diện tích các món = `gridRows × gridCols`, và phải còn ít nhất 1 món trong ngăn kéo. Với màn tự do có món bừa bộn, script còn kiểm tra rằng **để nguyên các món đó thì không thể xếp xong** (kể cả khi xoay đồ).
Nếu một file bị lỗi, `LevelManager` bỏ qua file đó (game không bị crash) và ở bản Debug, lỗi được hiện ngay trên màn chọn bàn.

## Thay hình & âm thanh thật
- **Hình:** xem **[ASSETS.md](ASSETS.md)** (tên, kích thước canvas, cách vẽ top-down, SVG + Preserve Vector Data). Nhập hình: `python3 tools/check_assets.py --import <thư mục>`. Món chưa có hình thì hiện SF Symbol trong trường `symbol`.
- **Âm thanh:** `TidyDesk/Resources/Sounds/` có sẵn 6 file tạm (`pickup`, `snap`, `error`, `complete`, `drop`, `rotate`.wav) do `python tools/generate_sounds.py` tạo ra. Muốn dùng âm thanh thật thì ghi đè file cùng tên (chấp nhận `.wav`/`.mp3`/`.caf`/`.m4a`; hoặc tạo Data Set cùng tên trong Assets.xcassets), rồi chạy lại `xcodegen generate`. Nếu thiếu file, `SoundManager` tự tổng hợp âm thanh thay thế nên game không bao giờ bị câm. File SFX nên ngắn (< 1 s) và để ở dạng `.wav`/`.caf` để phát không trễ.
