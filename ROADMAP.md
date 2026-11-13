# Lộ trình phát triển: Tidy Desk: Tech & Setup

> Cập nhật: 2026-11-13. Kế hoạch làm hình theo ngày: [ART_PLAN.md](ART_PLAN.md). Làm xong việc nào thì đánh `[x]`. Chi tiết kỹ thuật và lịch sử xem `PROJECT_NOTES.md`.

## Hiện trạng
- **Chơi:** 38 màn, 4 chương (First Desks, Office Hours, Gaming Den, Garden Corner), kéo thả, xoay, sao, điểm, mở khóa tuần tự (đang mở hết cho TestFlight).
- **Baby Corner:** bé lớn theo tháng (0–36), 6 giai đoạn, 18 cột mốc và Sổ tay em bé; ăn, chơi, tắm, ru ngủ, thay đồ.
- **Hình:** 22 hình thiết bị và đồ vườn, 1/6 hình em bé; phần còn lại dùng icon iPhone hoặc bé vẽ bằng code.
- **TestFlight:** đã có bản 5; bản 6 chờ Mac build.

---

## Giai đoạn 1: Ổn định bản beta (đang làm)
Mục tiêu: bản TestFlight chơi mượt, không lỗi, có ý kiến người chơi thật (cả trẻ em).
- [ ] Mac build và upload **TestFlight bản 6** (Baby Corner giai đoạn A, 38 màn, hình vườn)
- [ ] Hình em bé: `baby_infant` (bỏ gối), `baby_roller`, nhóm `baby_crawler` / `baby_toddler` / `baby_explorer`
- [ ] Hình thiết bị còn thiếu (19 món, xem `ART_PROMPTS.md`), ưu tiên món ở các màn đầu: `desk_lamp_tall`, `desk_lamp`, `plant`, `notebook`, `phone`, `monitor`, `laptop`
- [ ] Cho 3–5 người thử (có trẻ em), ghi lại: màn nào khó hoặc dễ quá, chỗ nào khó hiểu, bé có hấp dẫn không
- [ ] Chỉnh cảm giác kéo thả, âm lượng, nhịp thưởng xu (bảng thông số trong `PROJECT_NOTES.md`, mục 4)
- [ ] Kiểm tra trên iPhone màn nhỏ (SE) và iPad

## Giai đoạn 2: Baby Corner giai đoạn B và C
Mục tiêu: người chơi muốn quay lại mỗi ngày, nhưng không bị phạt khi vắng mặt.
- [ ] Trò chơi nhỏ: **đút ăn** (kéo thìa "máy bay" vào miệng bé), **ú òa** (chạm để bé che mặt rồi cười)
- [ ] **Điều bé muốn hôm nay:** mỗi ngày một mong muốn nhỏ, làm thì thưởng thêm, không có chuỗi ngày bị đứt
- [ ] **Trang trí phòng bé** bằng xu: nôi, đồ treo nôi, giấy dán tường, thảm
- [ ] **Chọn ngoại hình bé:** màu da, kiểu tóc (khi tạo bé)
- [ ] Âm thanh riêng: bong bóng, hát ru

## Giai đoạn 3: Gameplay sâu hơn
Mục tiêu: người chơi lớn cũng thấy hay và có chiều sâu.
- [ ] **Nút gợi ý:** `TilingSolver` đã sẵn sàng; có thể giới hạn số lần, hoặc đổi bằng xu
- [ ] **"Vị trí đẹp" thưởng thêm:** chuột cạnh bàn phím, đèn ở góc, cây gần cửa sổ…
- [ ] **Chương 5: Phòng em bé:** dọn nôi, bình sữa, đồ chơi lên kệ (nối hai phần của game)
- [ ] Món hình chữ L, món dây cáp nối 2 thiết bị
- [ ] Thêm chương theo mùa: Giáng Sinh, Tết, Halloween

## Giai đoạn 4: Chuẩn bị phát hành App Store
Mục tiêu: phát hành dưới tài khoản riêng, đúng quy định.
- [ ] **Tài khoản Apple Developer riêng** (hiện đang mượn team Retalix cho TestFlight), dùng bundle ID thật `com.powervh.tidydesk`
- [ ] **Quyết định:** có vào mục **Kids** của App Store không (nếu có: không quảng cáo, không theo dõi người dùng, có cổng phụ huynh trước link và mua hàng)
- [ ] **Quyết định cách kiếm tiền** (xem bên dưới)
- [ ] Tắt `BetaConfig.unlockAllLevels` và `BetaConfig.unlockAllBabyContent`
- [ ] Icon app thật, âm thanh thật (thay các file WAV tạm)
- [ ] Ngôn ngữ: tiếng Anh + tiếng Việt (Localizable.xcstrings)
- [ ] Chính sách quyền riêng tư (app không thu thập dữ liệu), xếp hạng độ tuổi
- [ ] Ảnh chụp App Store, mô tả, từ khóa, video ngắn
- [ ] Kiểm tra trợ năng (VoiceOver, Reduce Motion)
- [ ] Xem lại điều khoản thương mại của hình AI, hoặc thuê họa sĩ vẽ lại hình chính

## Giai đoạn 5: Sau khi phát hành
- [ ] Ra chương mới đều đặn (ví dụ mỗi tháng một chương)
- [ ] Sự kiện theo mùa
- [ ] Đọc đánh giá trên App Store và sửa lỗi nhanh

---

## Các quyết định cần chủ dự án chốt
| Câu hỏi | Lựa chọn | Ghi chú |
|---|---|---|
| Cách kiếm tiền | (a) trả tiền một lần khi tải, (b) miễn phí + mua một lần để mở chương sau, (c) miễn phí hoàn toàn | Game cho trẻ em: nên tránh quảng cáo; (b) phổ biến và thân thiện |
| Mục Kids của App Store | Có / Không | Vào Kids thì dễ được phụ huynh tin, nhưng quy định chặt hơn |
| Ngày phát hành dự kiến | … | Giúp chia nhỏ việc theo tuần |
| Tài khoản Apple Developer | Cá nhân / Công ty | Cần trước giai đoạn 4 |
