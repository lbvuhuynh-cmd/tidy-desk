# Kế hoạch làm hình theo ngày

> Mỗi **ngày** = một buổi khoảng 15–20 phút với Gemini (hoặc Recraft): gửi 1–2 prompt, tải hình về, báo Claude cắt và nhập vào game. Rảnh lúc nào làm ngày tiếp theo lúc đó. Xong ngày nào thì đánh `[x]`.
> Đi theo thứ tự [ROADMAP.md](ROADMAP.md). Quy tắc chung và prompt từng món lẻ xem [ART_PROMPTS.md](ART_PROMPTS.md).

## Cách làm mỗi ngày
1. Mở Gemini, **cùng một cuộc trò chuyện cho cả nhóm** (thiết bị một cuộc, em bé một cuộc), để hình giữ cùng style.
2. Copy prompt của ngày đó, gửi đi. Chưa đẹp thì bảo Gemini sửa ("make the items bigger", "remove the shadow"…).
3. Tải về, **đặt tên đúng cột "Lưu thành"**, bỏ vào thư mục ghi trong ngày.
4. Nhắn Claude: *"xong ngày N"*. Claude sẽ cắt, nhập vào game, đánh dấu file này và push.

**Câu thêm vào cuối mọi prompt nhóm** (đã có sẵn trong các prompt dưới):
`Each object stands alone with lots of empty space around it, objects never touch or overlap, no shadows, no text, no labels, no numbers, plain light gray background, large and high resolution.`

---

## Giai đoạn 1: Bản beta (làm trước)
Thứ tự theo **màn xuất hiện sớm nhất** và **số màn có món đó**: món ở màn 2–6 làm trước, vì người chơi gặp ngay.

### ✅ Ngày 1: Em bé 2 và 3 · thư mục `tidy-art\baby`
| Xong | Lưu thành | Nội dung |
|---|---|---|
| [x] | `baby_infant.jpeg` | Làm lại, bỏ gối |
| [x] | `baby_roller.jpeg` | Bé nằm sấp ngẩng đầu |

Gửi trong **cuộc trò chuyện đã làm `baby_newborn`**:
```
Perfect baby! Please redraw the 3-month-old image but remove the pillow / cushion behind the baby completely. The baby sits alone with nothing behind or under it, on a plain light gray background only. Keep everything else exactly the same. Square image, the baby fills most of the image.
```
```
Same baby, exact same art style, colors, outlines and plain light gray background, nothing else in the picture (no pillow, no blanket, no floor). Now 5 months old: tummy time, lying on its belly facing the viewer, head and chest lifted, hands flat in front, little feet kicking up behind, delighted smile, plain cream onesie. Square image, the baby fills most of the image.
```

### Ngày 2: Em bé 4, 5, 6 (một hình) · thư mục `tidy-art\baby`
| Xong | Lưu thành | Món (trái → phải) |
|---|---|---|
| [ ] | `baby_group.jpeg` | baby_crawler, baby_toddler, baby_explorer |
```
Same baby, exact same art style, colors and outlines. Show the same baby at three ages side by side in ONE horizontal row, from left to right: 1) 7 months old crawling toward the viewer on hands and knees, one tiny front tooth; 2) 1 year old standing with wobbly first steps, arms out for balance, small fringe; 3) 2 years old standing confidently and waving hello, fuller hair with a soft fringe, cream short-sleeve romper and little sneakers. All wear plain cream clothes. Each child stands alone with lots of empty space around it, they never touch or overlap, nothing else in the picture (no pillow, no blanket, no floor), no shadows, no text, plain light gray background, large and high resolution.
```

### Ngày 3: Đồ đứng A (màn 2–4) · thư mục `tidy-art\tech`
| Xong | Lưu thành | Món (trái → phải) |
|---|---|---|
| [ ] | `tech_1.jpeg` | desk_lamp_tall, mic_boom, speaker, phone |
```
A sprite sheet of 4 separate tall desk objects standing upright in ONE horizontal row, in this exact order from left to right: 1) a slim LED desk lamp lying along its length, round base at the bottom, long arm (very tall and thin, shape 1:3), 2) a podcast microphone on a long boom arm lying along its length, mic at the top end, clamp at the bottom (very tall, 1:3), 3) a small bookshelf speaker with two round drivers (1:2, twice as tall as wide), 4) a smartphone lying face up with a soft glowing screen with simple app icons, no text (1:2). Flat 2D vector illustration, strictly top-down view (looking straight down from above), cozy pastel palette (lavender, soft pink, cream, muted purple), clean outlines. Each object stands alone with lots of empty space around it, objects never touch or overlap, no shadows, no text, no labels, no numbers, plain light gray background, large and high resolution.
```

### Ngày 4: Đồ đứng B · thư mục `tidy-art\tech`
| Xong | Lưu thành | Món (trái → phải) |
|---|---|---|
| [ ] | `tech_2.jpeg` | notebook, microphone, desk_lamp |
```
Same art style as the previous image. A sprite sheet of 3 separate tall desk objects standing upright in ONE horizontal row, in this exact order from left to right: 1) a closed spiral notebook with a pastel cover and an elastic band (shape 1:2, twice as tall as wide), 2) a small desktop microphone on a round stand, mesh head at the top (1:2), 3) a small desk lamp with a round base, short bent arm and lamp head (1:2). Flat 2D vector illustration, strictly top-down view, cozy pastel palette (lavender, soft pink, cream, muted purple), clean outlines. Each object stands alone with lots of empty space around it, objects never touch or overlap, no shadows, no text, no labels, no numbers, plain light gray background, large and high resolution.
```

### Ngày 5: Đồ vuông · thư mục `tidy-art\tech`
| Xong | Lưu thành | Món (hàng trên trái → phải, rồi hàng dưới) |
|---|---|---|
| [ ] | `tech_3.jpeg` | desk_mat, tablet, wifi_router, laptop_gaming, plant, webcam |
```
Same art style as the previous image. A sprite sheet of 6 separate square desk objects arranged in a 3 x 2 grid, in this exact order (top row left to right, then bottom row left to right): 1) a soft fabric mouse pad with rounded corners and a subtle pattern, 2) a tablet lying face up in a slim case with a simple drawing app on the screen, 3) a Wi-Fi router lying flat with two short antennas and small status lights, 4) a compact gaming laptop opened flat with an RGB keyboard and glowing screen, 5) a small potted plant with leafy green leaves seen from above, 6) a small round webcam with the lens in the middle. Every object has a square shape. Flat 2D vector illustration, strictly top-down view, cozy pastel palette (lavender, soft pink, cream, muted purple), clean outlines. Each object stands alone with lots of empty space around it, objects never touch or overlap, no shadows, no text, no labels, no numbers, plain light gray background, large and high resolution.
```

### Ngày 6: Đồ nằm ngang · thư mục `tidy-art\tech`
| Xong | Lưu thành | Món (trên → dưới) |
|---|---|---|
| [ ] | `tech_4.jpeg` | game_controller, mouse_on_mat, power_strip |
```
Same art style as the previous image. A sprite sheet of 3 separate wide desk objects stacked in ONE vertical column, in this exact order from top to bottom: 1) a gamepad controller lying flat with two thumbsticks, a d-pad and four round buttons (shape 2:1, twice as wide as tall), 2) a wireless mouse resting on a small rectangular mouse mat (2:1), 3) a power strip with four sockets and a switch (very wide, 3:1). Flat 2D vector illustration, strictly top-down view, cozy pastel palette (lavender, soft pink, cream, muted purple), clean outlines. Each object stands alone with lots of empty space around it, objects never touch or overlap, no shadows, no text, no labels, no numbers, plain light gray background, large and high resolution.
```

### Ngày 7: Màn hình và laptop · thư mục `tidy-art\tech`
| Xong | Lưu thành | Món (trên → dưới) |
|---|---|---|
| [ ] | `tech_5.jpeg` | monitor, laptop, monitor_ultrawide |
```
Same art style as the previous image. A sprite sheet of 3 separate screen devices stacked in ONE vertical column, in this exact order from top to bottom: 1) a computer monitor seen from above, slim screen edge with a stand base behind it (shape 3:2), 2) an open laptop seen from above, keyboard and trackpad in front, screen folded back (3:2), 3) an ultrawide curved monitor seen from above with a long gentle curve and a stand base (2:1, twice as wide as tall). Flat 2D vector illustration, strictly top-down view, cozy pastel palette (lavender, soft pink, cream, muted purple), clean outlines. Each object stands alone with lots of empty space around it, objects never touch or overlap, no shadows, no text, no labels, no numbers, plain light gray background, large and high resolution.
```

### Ngày 8: Vẽ lại các hình chưa vừa ô · thư mục `tidy-art\fix`
Những hình này đang chỉ lấp 30–80% ô (`check_assets.py` báo WARN). Không gấp.
| Xong | Lưu thành | Món | Vấn đề |
|---|---|---|---|
| [ ] | `grow_light.jpeg` | grow_light (1×3) | quá mảnh, lấp ~31% |
| [ ] | `mouse_wireless.jpeg` | mouse_wireless (1×1) | hơi dài, lấp ~68% |
| [ ] | `keyboard_fullsize.jpeg` | keyboard_fullsize (5×1) | chưa đủ dài, lấp ~76% |
| [ ] | `watering_can.jpeg` | watering_can (2×2) | hơi bẹt, lấp ~74% |

Prompt mẫu (đổi tên món và tỉ lệ):
```
Redraw the grow light from before, same style, but as a wider LED grow light panel so the whole object is exactly 3 times as tall as wide (1:3), filling the frame, strictly top-down view, no shadow, no text, plain light gray background, large and high resolution.
```

**Hết giai đoạn 1: game có hình thật cho mọi món đang dùng.**

---

## Giai đoạn 2: Baby Corner B và C
Cần **thêm code** để dùng các hình này (hiện game dùng emoji). Làm hình trước cũng được: Claude sẽ nối vào khi làm tính năng.

### Ngày 9: Đồ ăn · thư mục `tidy-art\baby-shop`
Kiểu **sticker nhìn chính diện** (không phải nhìn từ trên xuống), cùng style với em bé.
| Xong | Lưu thành | Món (trái → phải) |
|---|---|---|
| [ ] | `shop_food.jpeg` | shop_milk, shop_porridge, shop_banana, shop_cookie, shop_pasta |
```
Same cute art style as the baby. A sprite sheet of 5 separate baby food icons in ONE horizontal row, from left to right: 1) a baby milk bottle, 2) a small bowl of porridge with a spoon, 3) a peeled banana, 4) a round chocolate chip cookie, 5) a small bowl of pasta. Cute kawaii sticker style, soft pastel colors, thick soft outlines, front view. Each object stands alone with lots of empty space around it, objects never touch or overlap, no shadows, no text, no labels, plain light gray background, large and high resolution.
```

### Ngày 10: Đồ chơi · thư mục `tidy-art\baby-shop`
| Xong | Lưu thành | Món (hàng trên trái → phải, rồi hàng dưới) |
|---|---|---|
| [ ] | `shop_toys.jpeg` | shop_rattle, shop_duck, shop_teddy, shop_ball, shop_car, shop_blocks, shop_crayons |
```
Same cute art style as the baby. A sprite sheet of 7 separate baby toy icons in two rows (4 on top, 3 below), in this exact order: top row left to right: 1) a baby rattle, 2) a yellow rubber duck, 3) a teddy bear, 4) a soft colorful ball; bottom row left to right: 5) a small toy car, 6) a stack of wooden alphabet blocks without letters, 7) a few crayons. Cute kawaii sticker style, soft pastel colors, thick soft outlines, front view. Each object stands alone with lots of empty space around it, objects never touch or overlap, no shadows, no text, no labels, plain light gray background, large and high resolution.
```

### Ngày 11: Quần áo · thư mục `tidy-art\baby-shop`
| Xong | Lưu thành | Món (hàng trên trái → phải, rồi hàng dưới) |
|---|---|---|
| [ ] | `shop_outfits.jpeg` | shop_onesie, shop_bunny, shop_stars, shop_bear, shop_sunhat, shop_dino |
```
Same cute art style as the baby. A sprite sheet of 6 separate baby outfit icons laid flat, arranged in a 3 x 2 grid, in this exact order (top row left to right, then bottom row): 1) a plain cream onesie, 2) a pink bunny suit with ears on the hood, 3) blue star pajamas, 4) a brown bear hoodie with round ears, 5) a yellow sun hat, 6) a green dinosaur suit with soft spikes. Cute kawaii sticker style, soft pastel colors, thick soft outlines, front view. Each object stands alone with lots of empty space around it, objects never touch or overlap, no shadows, no text, no labels, plain light gray background, large and high resolution.
```

### Ngày 12: Trang trí phòng bé · thư mục `tidy-art\nursery`
Dùng cho tính năng "trang trí phòng bé bằng xu" (giai đoạn 2C).
| Xong | Lưu thành | Món (hàng trên trái → phải, rồi hàng dưới) |
|---|---|---|
| [ ] | `nursery_decor.jpeg` | decor_crib, decor_mobile, decor_rug, decor_shelf, decor_nightlight, decor_plant |
```
Same cute art style as the baby. A sprite sheet of 6 separate nursery decoration items, arranged in a 3 x 2 grid, in this exact order (top row left to right, then bottom row): 1) a wooden baby crib, 2) a hanging baby mobile with clouds and stars, 3) a round soft play rug, 4) a small wall shelf with toys, 5) a cute moon-shaped night light, 6) a potted plant. Cute kawaii sticker style, soft pastel colors, thick soft outlines, front view. Each object stands alone with lots of empty space around it, objects never touch or overlap, no shadows, no text, no labels, plain light gray background, large and high resolution.
```

### Ngày 13–14: Ngoại hình bé (tùy chọn)
Khi làm tính năng "chọn ngoại hình bé": mỗi màu da hoặc kiểu tóc cần đủ **6 hình** (6 tuổi). Cách làm giống ngày 1–2, thêm vào prompt: *"same baby but with [darker brown skin / light skin / black curly hair / red hair]"*. Chốt số lựa chọn trước khi làm, vì 3 lựa chọn đã là 18 hình.

---

## Giai đoạn 3: Chương 5 "Phòng em bé" (màn chơi mới)
Đồ để **dọn trong màn chơi**: nhìn **từ trên xuống** như thiết bị, nhưng dùng bảng màu em bé. Claude sẽ tạo màn khi có tính năng.

**Đoạn chung cho chương này:**
`Flat 2D vector illustration, strictly top-down view (looking straight down from above), soft baby nursery palette (baby blue, blush pink, cream, butter yellow, mint), clean soft outlines, ...` + câu cuối nhóm.

### Ngày 15: Đồ vuông phòng bé · thư mục `tidy-art\babyroom`
| Xong | Lưu thành | Món (hàng trên → hàng dưới) | Ô |
|---|---|---|---|
| [ ] | `babyroom_1.jpeg` | milk_bottle, pacifier, rubber_duck, stacking_rings, teddy_bear, toy_basket | 1×1 ×4, 2×2 ×2 |
```
A sprite sheet of 6 separate baby nursery objects arranged in a 3 x 2 grid, in this exact order (top row left to right, then bottom row): 1) a baby bottle lying flat, 2) a pacifier, 3) a yellow rubber duck, 4) colorful stacking rings toy, 5) a teddy bear lying on its back, 6) a round woven toy basket full of soft toys. Every object has a square shape. Flat 2D vector illustration, strictly top-down view (looking straight down from above), soft baby nursery palette (baby blue, blush pink, cream, butter yellow, mint), clean soft outlines. Each object stands alone with lots of empty space around it, objects never touch or overlap, no shadows, no text, no labels, no numbers, plain light gray background, large and high resolution.
```

### Ngày 16: Đồ đứng và nằm ngang phòng bé · thư mục `tidy-art\babyroom`
| Xong | Lưu thành | Món | Ô |
|---|---|---|---|
| [ ] | `babyroom_2.jpeg` | diaper_stack, nursery_cam, toy_blocks, star_blanket | 1×2, 1×2, 2×1, 3×2 |
```
Same art style as the previous image. A sprite sheet of 4 separate baby nursery objects in ONE horizontal row, in this exact order from left to right: 1) a neat stack of folded diapers (shape 1:2, twice as tall as wide), 2) a baby monitor camera with a small screen unit (1:2), 3) a row of wooden toy blocks without letters (2:1, twice as wide as tall), 4) a folded soft baby blanket with a star pattern (3:2). Flat 2D vector illustration, strictly top-down view, soft baby nursery palette (baby blue, blush pink, cream, butter yellow, mint), clean soft outlines. Each object stands alone with lots of empty space around it, objects never touch or overlap, no shadows, no text, no labels, no numbers, plain light gray background, large and high resolution.
```

### Ngày 17: Chương theo mùa: Giáng Sinh · thư mục `tidy-art\xmas`
| Xong | Lưu thành | Món (hàng trên trái → phải, rồi hàng dưới) |
|---|---|---|
| [ ] | `xmas_1.jpeg` | gift_box, candy_cane, xmas_candle, mini_xmas_tree, cocoa_mug, snow_globe |
```
A sprite sheet of 6 separate cozy Christmas desk objects arranged in a 3 x 2 grid, in this exact order (top row left to right, then bottom row): 1) a small wrapped gift box with a bow, 2) a candy cane, 3) a red candle with holly, 4) a mini Christmas tree in a pot, 5) a mug of hot cocoa with marshmallows, 6) a snow globe. Flat 2D vector illustration, strictly top-down view, cozy pastel winter palette (soft red, pine green, cream, gold), clean soft outlines. Each object stands alone with lots of empty space around it, objects never touch or overlap, no shadows, no text, no labels, no numbers, plain light gray background, large and high resolution.
```

---

## Giai đoạn 4: Chuẩn bị phát hành
### Ngày 18: Icon app · thư mục `tidy-art\icon`
| Xong | Lưu thành | Nội dung |
|---|---|---|
| [ ] | `app_icon.jpeg` | Icon 1024×1024, không trong suốt, không chữ |
```
An iOS app icon for a cozy desk-tidying puzzle game: a neat pastel desk seen from above with a small keyboard, a coffee mug and a tiny plant arranged perfectly in a grid, a cute baby face peeking from the corner. Soft pastel palette (lavender, soft pink, cream, sage green), flat vector style, rounded shapes, simple and readable at small size, fills the whole square, no text, no border, no rounded corners (iOS adds them).
```

### Ngày 19: Hình quảng bá App Store · thư mục `tidy-art\store`
| Xong | Lưu thành | Nội dung |
|---|---|---|
| [ ] | `store_banner.jpeg` | Ảnh nền cho trang App Store và màn chào |
```
A wide cozy illustration for an app store banner: a pastel desk setup being tidied, a happy chibi baby (same style as before) waving next to it, a few garden plants, soft lavender and pink background, flat vector style, lots of empty space at the top for a title, no text.
```
Ảnh chụp màn hình App Store: Mac tự chụp từ simulator (`MAC_BUILD.md`), không cần AI.

---

## Tổng kết
| Giai đoạn | Ngày | Số hình | Kết quả |
|---|---|---|---|
| 1. Beta | 1–8 | 5 bé + 19 thiết bị + 4 vẽ lại | Mọi món trong 38 màn có hình thật |
| 2. Baby Corner B/C | 9–14 | 18 đồ cửa hàng + 6 trang trí (+ ngoại hình) | Cửa hàng và phòng bé đẹp hơn |
| 3. Chương mới | 15–17 | 10 đồ phòng bé + 6 Giáng Sinh | Chương 5 và chương mùa đông |
| 4. Phát hành | 18–19 | Icon + banner | Sẵn sàng lên App Store |
