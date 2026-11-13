# Prompt vẽ hình (Recraft)

> Làm theo từng ngày: xem [ART_PLAN.md](ART_PLAN.md) (đã có sẵn prompt nhóm cho từng buổi).

Mở file này khi cần tạo hình. Làm xong hình nào thì đánh dấu `[x]` ở cột **Xong**. Muốn thêm hình mới thì chép một dòng có sẵn rồi sửa.

## Cách làm chung
1. **Style:** Vector illustration (hình phẳng 2D). Mọi hình trong cùng một nhóm phải dùng **cùng một style**.
2. **Tỉ lệ khung:** theo cột **Khung** trong từng bảng. Recraft chỉ cho tối đa 2:1, nên hình 3:1, 4:1, 5:1 thì chọn khung 2:1 và ghi rõ tỉ lệ trong prompt.
3. **Tải về:** dạng **PNG**. Đặt tên file đúng cột **Tên file** (ví dụ `desk_lamp_tall.png`), bỏ vào thư mục `Downloads\tidy-art`.
4. Nếu nền không trong suốt, bấm **Remove background** trước khi tải. Game cũng tự xóa nền trắng khi nhập hình.
5. Tải xong thì báo Claude để đưa hình vào game: `python tools/check_assets.py --import <thư mục>`.

**Mẹo giữ cùng phong cách:** chọn một hình đẹp nhất làm mẫu, rồi tạo **Custom Style** từ hình đó (hoặc dùng *Use as reference*) cho các hình sau.

---

## Làm theo nhóm (nhiều món trong một hình)

Một lượt AI có thể vẽ **4–6 món cùng lúc**. Các món sẽ cùng style và tốn ít lượt hơn. Sau đó công cụ `tools/split_sheet.py` tự xóa nền, tìm từng món và cắt ra **theo thứ tự đọc**: hàng trên từ trái sang phải, rồi tới hàng dưới.

**Mẫu prompt nhóm** (thay danh sách món, giữ đúng thứ tự):
```
A sprite sheet of 6 separate objects arranged in a 3 x 2 grid, in this exact order (top row left to right, then bottom row): 1) ..., 2) ..., 3) ..., 4) ..., 5) ..., 6) ... . Flat 2D vector illustration, strictly top-down view, cozy pastel palette, clean outlines. Each object stands alone with lots of empty space around it, objects never touch or overlap, no shadows, no text, no labels, no numbers, plain light gray background.
```

**Mẹo:**
- Gom các món **cùng dáng** vào một nhóm: nhóm vuông (1×1, 2×2), nhóm đứng (1×2, 1×3), nhóm nằm ngang (2×1, 3×1). Món rất dài (4×1, 5×1) nên làm riêng.
- Tối đa khoảng 6 món mỗi hình. Nhiều hơn thì mỗi món bị nhỏ và mờ.
- Em bé: có thể làm cả 3 tuổi trên một hình, ví dụ *"the same baby at three ages side by side, left to right: 7 months crawling, 1 year standing, 2 years waving"*. Đây cũng là cách giữ bé giống nhau tốt nhất.

**Cắt hình** (Claude chạy giúp):
```
python tools/split_sheet.py <hình nhóm> <thư mục ra> ten_mon_1 ten_mon_2 ...
python tools/check_assets.py --import <thư mục ra>
```
Nếu số món tìm thấy khác số tên, công cụ lưu thành `item_01.png`, `item_02.png`… để xem rồi đặt tên lại.

---

## 1. Thiết bị trên bàn (nhìn thẳng từ trên xuống)

Mỗi prompt ghép từ hai phần: **đoạn chung** (dán trước) + **mô tả món** (cột Mô tả).

**Đoạn chung (dán trước mô tả):**
```
Flat 2D vector illustration, strictly top-down view (looking straight down from above), cozy pastel palette (lavender, soft pink, cream, muted purple), clean outlines, no text, no shadow, plain white background, object fills the whole frame edge to edge,
```

| Xong | Tên file | Ô | Khung | Mô tả món (dán sau đoạn chung) |
|---|---|---|---|---|
| [ ] | `desk_lamp_tall` | 1×3 | 1:2 | a slim LED desk lamp lying along its length, round base at the bottom, long arm, very tall vertical 1:3 shape |
| [ ] | `desk_lamp` | 1×2 | 1:2 | a small desk lamp seen from above, round base and short bent arm with lamp head, tall vertical 1:2 shape |
| [ ] | `plant` | 1×1 | 1:1 | a small potted plant seen from above, round pot rim with leafy green leaves spreading out, square composition |
| [ ] | `webcam` | 1×1 | 1:1 | a small round webcam lying flat, lens in the middle, tiny status light, square composition |
| [ ] | `notebook` | 1×2 | 1:2 | a closed spiral notebook with a pastel cover and an elastic band, tall vertical 1:2 shape |
| [ ] | `phone` | 1×2 | 1:2 | a smartphone lying face up, rounded corners, soft glowing screen with simple app icons (no text), tall vertical 1:2 shape |
| [ ] | `microphone` | 1×2 | 1:2 | a small desktop microphone on a round stand, mesh head at the top, tall vertical 1:2 shape |
| [ ] | `speaker` | 1×2 | 1:2 | a small bookshelf speaker seen from above, two round drivers, tall vertical 1:2 shape |
| [ ] | `mic_boom` | 1×3 | 1:2 | a podcast microphone on a long boom arm lying along its length, mic at the top end, clamp at the bottom, very tall vertical 1:3 shape |
| [ ] | `game_controller` | 2×1 | 2:1 | a gamepad controller lying flat, two thumbsticks, d-pad and four round buttons, wide horizontal 2:1 shape |
| [ ] | `mouse_on_mat` | 2×1 | 2:1 | a wireless mouse resting on a small rectangular mouse mat, wide horizontal 2:1 shape |
| [ ] | `desk_mat` | 2×2 | 1:1 | a soft fabric mouse pad / desk mat with rounded corners and a subtle pattern, square composition |
| [ ] | `tablet` | 2×2 | 1:1 | a tablet lying face up with a slim case, soft glowing screen with a simple drawing app (no text), square composition |
| [ ] | `wifi_router` | 2×2 | 1:1 | a Wi-Fi router lying flat, rounded square body, two short antennas, small status lights, square composition |
| [ ] | `laptop_gaming` | 2×2 | 1:1 | a compact gaming laptop opened flat, RGB keyboard and glowing screen, square composition |
| [ ] | `power_strip` | 3×1 | 2:1 | a power strip with four sockets and a switch, very wide horizontal 3:1 shape |
| [ ] | `laptop` | 3×2 | 2:1 | an open laptop seen from above, keyboard and trackpad in front, screen folded back, horizontal 3:2 shape |
| [ ] | `monitor` | 3×2 | 2:1 | a computer monitor seen from above, slim screen edge with a stand base behind it, horizontal 3:2 shape |
| [ ] | `monitor_ultrawide` | 4×2 | 2:1 | an ultrawide curved monitor seen from above, long gentle curve and a stand base, wide horizontal 2:1 shape |

Đã có hình (không cần làm lại): `keyboard_compact`, `keyboard_mechanical`, `keyboard_fullsize`, `headphones`, `speaker_tower`, `cable_bundle`, `coffee_mug`, `mouse_wireless`.

---

## 2. Góc làm vườn (chương 4): ✅ đã có đủ 14 hình (Gemini, 13/11)

Vẫn dùng **đoạn chung** ở mục 1, nhưng thay phần màu bằng bảng màu vườn cho tươi hơn:
```
Flat 2D vector illustration, strictly top-down view (looking straight down from above), fresh pastel garden palette (sage green, terracotta, cream, soft yellow, lavender), clean outlines, no text, no shadow, plain white background, object fills the whole frame edge to edge,
```

| Xong | Tên file | Ô | Khung | Mô tả món |
|---|---|---|---|---|
| [x] | `seed_packet` | 1×1 | 1:1 | a paper seed packet with a picture of a flower on it (no text), square composition |
| [x] | `succulent_pot` | 1×1 | 1:1 | a small succulent in a round terracotta pot, rosette of plump leaves, square composition |
| [x] | `birdhouse` | 1×1 | 1:1 | a small wooden birdhouse seen from above, pitched roof, square composition |
| [x] | `flower_pot` | 1×2 | 1:2 | a tall flower pot with tulips seen from above, tall vertical 1:2 shape |
| [x] | `pruning_shears` | 1×2 | 1:2 | garden pruning shears lying flat, closed blades, colorful handles, tall vertical 1:2 shape |
| [x] | `garden_gloves` | 1×2 | 1:2 | a pair of garden gloves lying flat, one on top of the other, tall vertical 1:2 shape |
| [x] | `grow_light` | 1×3 | 1:2 | a slim plant grow light bar lying along its length with a warm glowing strip, very tall vertical 1:3 shape |
| [x] | `seedling_tray` | 2×1 | 2:1 | a seedling tray with small cells and tiny green sprouts, wide horizontal 2:1 shape |
| [x] | `watering_can` | 2×2 | 1:1 | a watering can seen from above, round body, long spout and handle, square composition |
| [x] | `monstera_pot` | 2×2 | 1:1 | a monstera plant in a round pot seen from above, big split leaves spreading out, square composition |
| [x] | `herb_planter` | 3×1 | 2:1 | a long rectangular herb planter with basil, mint and parsley, very wide horizontal 3:1 shape |
| [x] | `garden_basket` | 3×2 | 2:1 | a woven harvest basket full of vegetables (carrots, tomatoes, lettuce), horizontal 3:2 shape |
| [x] | `flower_box` | 4×1 | 2:1 | a long window flower box with colorful flowers in a row, extremely wide horizontal 4:1 shape |
| [x] | `soil_bag` | 2×3 | 1:2 | a bag of potting soil lying flat with a leaf picture on it (no text), vertical 2:3 shape |

### Góc làm vườn theo nhóm (Gemini)
Gửi lần lượt trong cùng một cuộc trò chuyện. Từ nhóm 2 trở đi, thêm ở đầu: *"Same art style as the previous image."* Lưu thành `garden_1.jpeg` … `garden_4.jpeg` trong `Downloads\tidy-art\garden`.

| Xong | Hình | Món (theo thứ tự cắt) |
|---|---|---|
| [x] | `garden_1` | seed_packet, succulent_pot, birdhouse, watering_can, monstera_pot |
| [x] | `garden_2` | flower_pot, pruning_shears, garden_gloves, grow_light, soil_bag |
| [x] | `garden_3` | seedling_tray, herb_planter, garden_basket |
| [x] | `garden_4` | flower_box |

**Nhóm 1 (vuông, một hàng):**
```
A sprite sheet of 5 separate garden objects in ONE horizontal row, in this exact order from left to right: 1) a paper seed packet with a flower picture on it (no text), 2) a small succulent in a round terracotta pot, 3) a small wooden birdhouse, 4) a watering can with a long spout and handle, 5) a monstera plant in a round pot with big split leaves. Every object has a square shape. Flat 2D vector illustration, strictly top-down view (looking straight down from above), fresh pastel garden palette (sage green, terracotta, cream, soft yellow, lavender), clean soft outlines. Each object stands alone with lots of empty space around it, objects never touch or overlap, no shadows, no text, no labels, no numbers, plain light gray background.
```

**Nhóm 2 (đứng, một hàng):**
```
A sprite sheet of 5 separate tall garden objects standing upright in ONE horizontal row, in this exact order from left to right: 1) a tall flower pot with tulips (shape 1:2, twice as tall as wide), 2) garden pruning shears with closed blades (1:2), 3) a pair of garden gloves lying one on top of the other (1:2), 4) a slim plant grow light bar with a warm glowing strip (very tall and thin, 1:3), 5) a bag of potting soil with a leaf picture on it, no text (2:3). Flat 2D vector illustration, strictly top-down view, fresh pastel garden palette (sage green, terracotta, cream, soft yellow, lavender), clean soft outlines. Each object stands alone with lots of empty space around it, objects never touch or overlap, no shadows, no text, no labels, no numbers, plain light gray background.
```

**Nhóm 3 (nằm ngang, xếp chồng):**
```
A sprite sheet of 3 separate wide garden objects stacked in ONE vertical column, in this exact order from top to bottom: 1) a seedling tray with small cells and tiny green sprouts (shape 2:1, twice as wide as tall), 2) a long rectangular herb planter with basil, mint and parsley (very wide, 3:1), 3) a woven harvest basket full of carrots, tomatoes and lettuce (3:2). Flat 2D vector illustration, strictly top-down view, fresh pastel garden palette (sage green, terracotta, cream, soft yellow, lavender), clean soft outlines. Each object stands alone with lots of empty space around it, objects never touch or overlap, no shadows, no text, no labels, no numbers, plain light gray background.
```

**Nhóm 4 (hộp hoa, làm riêng):**
```
A long window flower box full of colorful flowers in a row, extremely wide horizontal shape (4 times as wide as tall), seen strictly from above. Flat 2D vector illustration, fresh pastel garden palette (sage green, terracotta, cream, soft yellow, lavender), clean soft outlines, single object, no shadow, no text, plain light gray background, the object fills the width of the image.
```

---

## 3. Em bé (Baby Corner)

Khác với thiết bị: bé **nhìn chính diện** (không nhìn từ trên xuống), **khung 1:1**, **nền trong suốt**. Cả 6 hình phải là **cùng một em bé** lớn dần. Làm `baby_newborn` trước, rồi dùng nó làm mẫu (*Custom Style* / *Use as reference*) cho 5 hình sau.

**Đoạn chung (dán SAU mô tả):**
```
cute chibi baby character, same baby in every picture: round head, big round cheeks with soft pink blush, warm peach skin, small dark brown hair curl on top, tiny dark eyes, plain cream-colored onesie, soft pastel flat vector style, clean rounded shapes, thick soft outlines, gentle top-left lighting, front view, full body, centered, fills the frame, transparent background, no floor, no shadow, no text, kawaii, for a kids game
```

| Xong | Tên file | Tuổi | Mô tả (dán TRƯỚC đoạn chung) |
|---|---|---|---|
| [x] | `baby_newborn` | 0–2 tháng | A sleeping newborn baby swaddled snugly in a cream blanket like a little bean, only the round face showing, eyes peacefully closed as curved lines, tiny content smile, one small hair curl. |
| [ ] | `baby_infant` | 2–4 tháng | A 3-month-old baby sitting propped up, chubby arms raised happily, big open gummy smile, bright open eyes, two small hair curls, cream onesie with tiny feet showing. |
| [ ] | `baby_roller` | 4–6 tháng | A 5-month-old baby doing tummy time: lying on its belly facing the viewer, head and chest lifted, hands flat in front, little feet kicking up behind, delighted smile, three small hair curls, cream onesie. |
| [ ] | `baby_crawler` | 6–9 tháng | A 7-month-old baby crawling toward the viewer on hands and knees, head up, curious happy face with one tiny front tooth, short fluffy brown hair, cream onesie. |
| [ ] | `baby_toddler` | 9–18 tháng | A 1-year-old toddler standing with wobbly first steps, arms stretched out for balance, big excited smile, short fluffy brown hair with a small fringe, chubby legs, cream onesie, tiny bare feet. |
| [ ] | `baby_explorer` | 18–36 tháng | A 2-year-old child standing confidently and waving hello with one hand, cheerful open smile, slightly taller and slimmer than a toddler but still chubby-cheeked, fuller brown hair with a soft fringe, cream short-sleeve romper, little sneakers. |

### Làm bằng Gemini (đang dùng)
`baby_newborn` đã làm bằng Gemini. Muốn 5 hình sau giống **đúng em bé đó**, gõ tiếp **trong cùng cuộc trò chuyện** với Gemini, mỗi lần một câu dưới đây. Tải về dạng `.jpeg` hay `.png` đều được: công cụ nhập hình tự xóa nền xám và cắt sát vào bé.

| Xong | Tên file | Câu gửi Gemini |
|---|---|---|
| [x] | `baby_newborn` | (prompt ở bảng trên) |
| [ ] | `baby_infant` | Same baby, exact same art style, colors, outlines and plain light gray background, nothing else in the picture (no pillow, no blanket, no floor). Now 3 months old: sitting propped up, chubby arms raised happily, big open gummy smile, bright open eyes, two small hair curls, plain cream onesie, tiny bare feet. Square image, the baby fills most of the image. |
| [ ] | `baby_roller` | Same baby, exact same art style, colors, outlines and plain light gray background, nothing else in the picture (no pillow, no blanket, no floor). Now 5 months old: tummy time, lying on its belly facing the viewer, head and chest lifted, hands flat in front, little feet kicking up behind, delighted smile, plain cream onesie. Square image, the baby fills most of the image. |
| [ ] | `baby_crawler` | Same baby, exact same art style, colors, outlines and plain light gray background, nothing else in the picture (no pillow, no blanket, no floor). Now 7 months old: crawling toward the viewer on hands and knees, head up, curious happy face with one tiny front tooth, short fluffy brown hair, plain cream onesie. Square image, the baby fills most of the image. |
| [ ] | `baby_toddler` | Same baby, exact same art style, colors, outlines and plain light gray background, nothing else in the picture (no pillow, no blanket, no floor). Now 1 year old: standing with wobbly first steps, arms stretched out for balance, big excited smile, short fluffy brown hair with a small fringe, plain cream onesie, tiny bare feet. Square image, the baby fills most of the image. |
| [ ] | `baby_explorer` | Same baby, exact same art style, colors, outlines and plain light gray background, nothing else in the picture (no pillow, no blanket, no floor). Now 2 years old: standing confidently and waving hello with one hand, cheerful open smile, a little taller but still chubby-cheeked, fuller brown hair with a soft fringe, plain cream short-sleeve romper, little sneakers. Square image, the baby fills most of the image. |

**Khi chọn hình bé, kiểm tra:**
- Bé nằm giữa khung, **chiếm gần hết khung**.
- Không có nền, sàn hay bóng.
- Áo **màu kem trơn**, không họa tiết (trang phục người chơi chọn sẽ hiện bằng một huy hiệu nhỏ).
- Cả 6 hình cùng màu da, cùng màu tóc, cùng nét vẽ.

---

## Ghi chú
- Kích thước từng ô và quy tắc vẽ chi tiết: xem [ASSETS.md](ASSETS.md).
- Xem hình nào đã có, hình nào còn thiếu: `python tools/check_assets.py`.
