# Tidy Desk: Tech & Setup — Hướng dẫn cho Claude

Đọc `README.md` (build, cấu trúc, định dạng file màn) và `PROJECT_NOTES.md` (đã làm gì, lịch sử) trước khi sửa.
Trên Mac, khi được nhờ "build & test": làm theo **`MAC_BUILD.md`** (build, test, ảnh từng hình, ảnh chụp app vào `screenshots/`, ghi chép, push).

## Bối cảnh
- Game giải đố cozy: kéo thiết bị (bàn phím, chuột, màn hình…) từ ngăn kéo lên mặt bàn dạng lưới cho vừa khít; có món nằm sẵn sai chỗ cần dọn. SwiftUI + SwiftData, iOS 17+, project sinh bằng XcodeGen (`project.yml`). Giao diện và code bằng tiếng Anh.
- Code ban đầu được viết trên máy Windows (không có Xcode). Máy Windows vẫn sửa repo này, nên code mới từ đó có thể chưa từng được build — lỗi biên dịch là bình thường, sửa chúng.
- Repo: https://github.com/lbvuhuynh-cmd/tidy-desk (private, nhánh `main`).

## Quy tắc làm việc
1. Trả lời người dùng bằng **tiếng Việt**. Code, comment, chữ trong app: **tiếng Anh**.
2. Trước khi làm: `git pull`. Xong: commit message rõ ràng rồi `git push`. Không force-push, không rewrite history.
3. `TidyDesk.xcodeproj` được sinh ra và nằm trong .gitignore: sau mỗi lần pull hoặc thêm/xoá file chạy `xcodegen generate`. Không commit .xcodeproj.
4. Build / test (simulator iPhone 17):
   - Build: `xcodebuild -project TidyDesk.xcodeproj -scheme TidyDesk -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build/DD build`
   - Test: như trên, thay `build` bằng `test`.
5. Sửa lỗi biên dịch **tối thiểu**, giữ nguyên hành vi game. Không xoá tính năng, không tắt test, không sửa giá trị mong đợi trong test chỉ để pass. Test fail vì logic sai thật → giải thích nguyên nhân và cách sửa cho người dùng.
6. Kiến trúc cần giữ:
   - `DeskDragViewModel`: phần luật (`place` / `returnToDrawer` / `rotate`) tách khỏi phần cử chỉ (`dragChanged` / `dragEnded`).
   - Rung và âm thanh luôn đi qua protocol `GameFeedback` → `FeedbackEngine` → `HapticManager` / `SoundManager`. Không gọi thẳng hai manager từ logic kéo thả.
   - Màn chơi là file `TidyDesk/Resources/Levels/level_<n>.json` (schema `schema/level_schema.json`), do `LevelManager` nạp. Không hard-code màn trong Swift.
7. Sửa/thêm màn: chạy `python3 tools/check_levels.py`, phải "OK" hết. `imageName` là tên asset snake_case, một tên = một kích thước ô (xem `ASSETS.md`); `symbol` là SF Symbol dự phòng. Nhập hình mới: `python3 tools/check_assets.py --import <thư mục>`. Món bừa bộn (`initialPosition`) phải buộc người chơi dời đi, kể cả khi được xoay đồ.
8. Trước khi phát hành App Store: `BetaConfig.unlockAllLevels = false` và `BetaConfig.unlockAllBabyContent = false`. Không ghi Team ID hay bundle ID thật vào `project.yml` (`DEVELOPMENT_TEAM` để trống). Chạy trên iPhone thật thì truyền qua dòng lệnh hoặc chọn trong Xcode, không commit.
9. `PROJECT_NOTES.md` (tiếng Việt) là nhật ký dự án. Sau mỗi thay đổi đáng kể thêm một dòng ở đầu mục "Lịch sử". Sau mỗi lần build/test ghi đè kết quả mới nhất vào mục "5. Kết quả build/test trên Mac" (ngày, commit, phiên bản Xcode, kết quả build, số test pass/fail, file phải sửa và vì sao).
10. Auth GitHub chỉ cấu hình **cục bộ trong repo này**; không dùng lại token của repo khác, không cấu hình credential global. Identity commit: `lbvuhuynh-cmd` / `353136233+lbvuhuynh-cmd@users.noreply.github.com`.
