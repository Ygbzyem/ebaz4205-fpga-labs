# Lab 01 — Nháy LED: Đặc tả (v1.0)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Mục tiêu

Nháy LED kép trên board (xanh và đỏ) ngược pha nhau với tần số 1 Hz, dùng clock 50 MHz của PL. Đây là vòng đầu tiên đi trọn quy trình RTL → mô phỏng → bitstream → chạy trên board.

## 2. File

```
lab01_blink/
├── docs/spec.md, spec.vi.md
├── rtl/
│   ├── blink_core.v         # bạn viết
│   └── lab01_top.v          # bạn viết
├── constraints/
│   └── lab01_top.xdc        # bạn viết (chép dòng từ board/ebaz4205_master.xdc)
├── tb/
│   ├── tb_blink_core.v      # Claude (đã có)
│   └── tb_lab01_top.v       # Claude (thêm khi đã có lab01_top)
└── scripts/
    └── create_project.tcl   # Claude
```

## 3. Phân cấp module

```
lab01_top            lớp bọc board: reset khi bật nguồn, cực tính LED, gán chân
└── blink_core       bộ chia tần + logic đảo trạng thái LED
```

## 4. `blink_core`

### Giao tiếp

| Tín hiệu | Hướng | Độ rộng | Mô tả |
|---|---|---|---|
| `clk` | in | 1 | Clock, tích cực cạnh lên |
| `rst` | in | 1 | Reset đồng bộ, tích cực mức cao |
| `led_g` | out | 1 | LED xanh, logic bật = 1 |
| `led_r` | out | 1 | LED đỏ, logic bật = 1, luôn bằng `~led_g` |

| Tham số | Mặc định | Mô tả |
|---|---|---|
| `HALF_PERIOD` | 25_000_000 | Số chu kỳ clock giữa hai lần đảo (≥ 2). 25 000 000 × 20 ns = 0.5 s → nháy 1 Hz |

### Hành vi

- Khi `rst` được lấy mẫu bằng 1 tại cạnh lên: `led_g = 0`, `led_r = 1`.
- Sau khi nhả reset, `led_g` giữ 0 đúng `HALF_PERIOD` chu kỳ, rồi giữ 1 trong `HALF_PERIOD` chu kỳ, cứ thế lặp lại.
- Reset tại bất kỳ thời điểm nào, kể cả đúng cạnh lẽ ra phải đảo, luôn được ưu tiên và đếm lại từ 0.
- Bộ đếm phải chứa được giá trị `HALF_PERIOD − 1`. Độ rộng của nó suy ra từ tham số (Verilog-2001 không có `$clog2`; dùng constant function hoặc tham số độ rộng). Với giá trị mặc định là 25 bit.
- Ngõ ra là thanh ghi hoặc chỉ suy ra từ thanh ghi; không có latch.

## 5. `lab01_top`

### Giao tiếp

| Tín hiệu | Hướng | Độ rộng | Chân | Mô tả |
|---|---|---|---|---|
| `clk_50m` | in | 1 | N18 | Thạch anh 50 MHz của PL (X5) |
| `led_g_n` | out | 1 | W13 | LED xanh, **active-low** |
| `led_r_n` | out | 1 | W14 | LED đỏ, **active-low** |

| Tham số | Mặc định | Mô tả |
|---|---|---|
| `HALF_PERIOD` | 25_000_000 | Truyền xuống `blink_core`; khi mô phỏng thì ghi đè bằng giá trị nhỏ |
| `POR_CYCLES` | 16 | Độ dài reset khi bật nguồn, tính bằng chu kỳ clock |

### Hành vi

- **Reset khi bật nguồn (power-on reset):** board không có nút reset cho PL. `lab01_top` tự tạo tín hiệu `rst` nội bộ, tích cực mức cao, được giữ từ lúc cấu hình xong cho tới khi đi qua `POR_CYCLES` cạnh lên của `clk_50m`, sau đó giữ ở mức 0. Hiện thực bằng một thanh ghi có giá trị khởi tạo (Vivado nạp giá trị khởi tạo của thanh ghi lúc cấu hình), ví dụ một bộ đếm hoặc một thanh ghi dịch.
- **Cực tính:** `led_g_n = ~led_g`, `led_r_n = ~led_r` (LED sáng khi chân bằng 0).
- Kết quả nhìn thấy: xanh và đỏ luân phiên, mỗi màu sáng 0.5 s.

## 6. Constraint (`lab01_top.xdc`)

| Mục | Giá trị |
|---|---|
| `clk_50m` | `PACKAGE_PIN N18`, `IOSTANDARD LVCMOS33`, `create_clock -period 20.000` |
| `led_g_n` | `PACKAGE_PIN W13`, `IOSTANDARD LVCMOS33` |
| `led_r_n` | `PACKAGE_PIN W14`, `IOSTANDARD LVCMOS33` |

## 7. Kế hoạch kiểm tra

| ID | Mức | Kiểm tra gì | Tiêu chí đạt |
|---|---|---|---|
| T1 | `blink_core` | Giá trị trong lúc reset | `led_g = 0`, `led_r = 1` |
| T2 | `blink_core` | Đảo tự do qua 6 chu kỳ | Khớp từng chu kỳ với golden model |
| T3 | `blink_core` | Reset giữa lúc đang đếm | Đếm lại từ 0 |
| T4 | `blink_core` | Reset đúng cạnh lẽ ra phải đảo | Reset thắng, không đảo |
| T5 | `blink_core` | Xung reset dài 1 chu kỳ | Như T3 |
| T6 | `lab01_top` | Độ dài power-on reset | Ngõ ra giữ giá trị reset trong `POR_CYCLES` chu kỳ |
| T7 | `lab01_top` | Cực tính | `led_g_n == ~led_g`, hai LED luân phiên |
| S1 | Synthesis | Không sinh latch | 0 warning về latch |
| S2 | Implementation | Timing ở 50 MHz | WNS ≥ 0, TNS = 0, không có clock chưa constrain |
| H1 | Board | Quan sát | Xanh/đỏ luân phiên; 10 chu kỳ đầy đủ ≈ 10 s (bấm giờ hoặc quay video) |
| H2 | Board | Trạng thái cấu hình | `REGISTER.IR` báo `DONE = 1` sau khi nạp; ghi lại trạng thái LED Done |

`tb_blink_core` chạy với `HALF_PERIOD` = 2, 5 và 16.

## 8. Lệnh

```bat
:: Mô phỏng (Vivado xsim, cmd của Windows, đứng tại labs\lab01_blink)
xvlog tb\tb_blink_core.v rtl\blink_core.v
xelab tb_blink_core -s tb_sim
xsim tb_sim -R

:: Tạo project Vivado (tham chiếu file tại chỗ, không copy)
vivado -mode batch -source scripts\create_project.tcl
```

## 9. Sản phẩm cần nộp

- [ ] `blink_core.v`, `lab01_top.v`, `lab01_top.xdc` (bạn)
- [ ] Log `TEST PASSED` của T1–T7
- [ ] Báo cáo utilization và timing trong `results/`
- [ ] Ảnh hoặc video board
- [ ] README của lab (log) — Claude
