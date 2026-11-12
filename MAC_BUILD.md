# Build, test & chụp màn hình trên Mac

Quy trình chuẩn mỗi khi máy Windows đẩy code mới. Claude trên Mac: đọc `CLAUDE.md` trước, rồi làm lần lượt các bước dưới đây. Báo cáo bằng tiếng Việt.

## 1. Lấy code, sinh project
```bash
git pull
xcodegen generate
```

## 2. Build + test
```bash
xcodebuild -project TidyDesk.xcodeproj -scheme TidyDesk \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build/DD build
xcodebuild -project TidyDesk.xcodeproj -scheme TidyDesk \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build/DD test
```
- Lỗi biên dịch: sửa **tối thiểu**, giữ nguyên hành vi (xem quy tắc 5 trong `CLAUDE.md`). Code từ Windows chưa từng được build nên có lỗi là bình thường.
- Ghi lại số test pass/fail. `ArtPreviewTests` báo *skipped* ở bước này là đúng (nó chỉ chạy ở bước 4).
- Chú ý warning của asset catalog (`Assets.xcassets`), nhất là về các file `.svg`.

## 3. Kiểm tra dữ liệu
```bash
python3 tools/check_levels.py     # phải "All ... OK"
python3 tools/check_assets.py     # bảng tình trạng hình; WARN tỉ lệ (aspect) là cảnh báo, không phải lỗi
```

## 4. Ảnh từng hình thiết bị (không cần bấm gì)
```bash
TEST_RUNNER_TIDY_SNAPSHOTS=1 xcodebuild -project TidyDesk.xcodeproj -scheme TidyDesk \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build/DD \
  test -only-testing:TidyDeskTests/ArtPreviewTests
```
Kết quả nằm trong `screenshots/art/`:
- `<imageName>.png`: món đó ở 3 trạng thái: nằm yên, đang nhấc (1.08×, bóng đổ), đã xoay.
- `_all_light.png` / `_all_dark.png`: tất cả các món trên cùng một tấm, giao diện sáng và tối.

Món ghi `ASSET` là đang dùng hình thật; ghi `fallback` là đang dùng SF Symbol.

## 5. Ảnh chụp app trên simulator
```bash
mkdir -p screenshots/app
xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcrun simctl install booted build/DD/Build/Products/Debug-iphonesimulator/TidyDesk.app

shoot() {  # shoot <tên file> <light|dark> [level id | nursery]
  xcrun simctl ui booted appearance "$2"
  if [ "$3" = "nursery" ]; then
    xcrun simctl launch --terminate-running-process booted com.powervh.tidydesk -openNursery YES -babyName Bean
  elif [ -n "$3" ]; then
    xcrun simctl launch --terminate-running-process booted com.powervh.tidydesk -openLevel "$3"
  else
    xcrun simctl launch --terminate-running-process booted com.powervh.tidydesk
  fi
  sleep 4
  xcrun simctl io booted screenshot "screenshots/app/$1.png"
}
shoot menu_light       light
shoot level1_light     light 1    # có keyboard_compact
shoot level5_light     light 5    # có mouse_wireless
shoot level5_dark      dark  5
shoot nursery_light    light nursery   # Baby Corner (phòng bé)
shoot nursery_dark     dark  nursery
xcrun simctl ui booted appearance light
```
`-openLevel <id>` là cờ chỉ có ở bản Debug: mở thẳng màn đó, bỏ qua khóa. `-openNursery YES -babyName Bean` (cũng chỉ Debug) mở thẳng Baby Corner và đặt tên bé để bỏ qua bảng đặt tên. Nếu ảnh chụp ra trống hoặc vẫn ở menu thì tăng `sleep`.

**Xem lại các ảnh vừa chụp** (đọc file PNG) và nhận xét ngắn: hình có rõ không, có bị nhòe hay méo không, bóng đổ có hợp lý không, hình có quá nhỏ trong ô không.

## 6. Ghi chép, commit, push
- `PROJECT_NOTES.md`:
  - Ghi đè mục **"5. Kết quả build/test trên Mac"**: ngày, commit, phiên bản Xcode, build OK hay lỗi, số test pass/fail/skip, file nào phải sửa và vì sao, nhận xét về ảnh.
  - Thêm một dòng ở đầu mục **"Lịch sử"**.
- `screenshots/` **được commit** (ảnh mới ghi đè ảnh cũ, để repo không phình ra).
```bash
git add -A
git commit -m "Mac build/test + screenshots (<commit đã build>)"
git push
```

## 7. Báo lại người dùng (tiếng Việt)
- Build OK hay không; số test pass, fail, skip.
- Đã sửa gì (file nào, vì sao).
- Nhận xét về ảnh chụp, và đường dẫn tới `screenshots/`.
