# Lab 03 — Nút nhấn ngoài: Đặc tả (v1.0)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Mục tiêu

Đọc nút nhấn cơ khí một cách an toàn: đưa tín hiệu bất đồng bộ vào miền clock, lọc hiện tượng dội phím (bounce), và biến mỗi lần nhấn thành đúng một sự kiện dài một chu kỳ. Khái niệm: metastability, synchronizer 2 flip-flop, debounce, phát hiện cạnh, điện trở kéo lên bên trong.

## 2. Phần cứng

| Mục | Cách nối |
|---|---|
| Nút nhấn, một chân | DATA1-5 (chân FPGA A20) |
| Nút nhấn, chân còn lại | DATA1-4 (GND) |
| Điện trở kéo lên | `PULLUP` bên trong FPGA tại A20 |

Thả = 1, nhấn = 0 → tên tín hiệu `btn_n`. **Không chạm vào chân 1–2 của DATA1 (nguồn cấp board).**

## 3. Phân cấp module

```
lab03_top
├── por_gen          (Lab 02)
├── sync_2ff         synchronizer 2 flip-flop
├── debounce         bộ lọc mức ổn định
└── edge_detect      xung một chu kỳ ở cạnh lên / cạnh xuống
```

## 4. `sync_2ff`

| Tín hiệu | Hướng | Độ rộng | Mô tả |
|---|---|---|---|
| `clk` | in | 1 | Clock của miền đích |
| `rst` | in | 1 | Reset đồng bộ, tích cực mức cao |
| `d` | in | 1 | Ngõ vào bất đồng bộ |
| `q` | out | 1 | Ngõ ra đã đồng bộ |

| Tham số | Mặc định | Mô tả |
|---|---|---|
| `RST_VAL` | 1'b0 | Giá trị của cả hai flip-flop khi reset |

Hai flip-flop nối tiếp, không có logic ở giữa; độ trễ 2 chu kỳ. Đánh dấu cả hai thanh ghi bằng `(* ASYNC_REG = "TRUE" *)`.

## 5. `debounce`

| Tín hiệu | Hướng | Độ rộng | Mô tả |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset đồng bộ, tích cực mức cao |
| `din` | in | 1 | Ngõ vào đã đồng bộ, còn nhiễu |
| `dout` | out | 1 | Ngõ ra đã lọc |

| Tham số | Mặc định | Mô tả |
|---|---|---|
| `STABLE_CYCLES` | 1_000_000 | 20 ms ở 50 MHz |
| `RST_VAL` | 1'b0 | Giá trị `dout` khi reset |

Hành vi: `dout` chỉ nhận giá trị của `din` sau khi `din` khác `dout` liên tục trong `STABLE_CYCLES` chu kỳ; `dout` đổi đúng ở chu kỳ bộ đếm đạt `STABLE_CYCLES`. Nếu `din` quay lại bằng `dout` trước lúc đó thì đếm lại từ đầu. Xung ngắn hơn `STABLE_CYCLES` không bao giờ tới được `dout`.

## 6. `edge_detect`

| Tín hiệu | Hướng | Độ rộng | Mô tả |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset đồng bộ, tích cực mức cao |
| `din` | in | 1 | Mức tín hiệu sạch |
| `rise` | out | 1 | Bằng 1 đúng một chu kỳ sau khi `din` đi 0 → 1 |
| `fall` | out | 1 | Bằng 1 đúng một chu kỳ sau khi `din` đi 1 → 0 |

Nhả reset không được sinh ra xung nào.

## 7. `lab03_top`

| Tín hiệu | Hướng | Độ rộng | Chân | Mô tả |
|---|---|---|---|---|
| `clk_50m` | in | 1 | N18 | 50 MHz |
| `btn_n` | in | 1 | A20 | Nút nhấn, active-low, kéo lên bên trong |
| `led_g_n` | out | 1 | W13 | Đảo trạng thái mỗi lần nhấn |
| `led_r_n` | out | 1 | W14 | Sáng trong lúc giữ nút |

Đường dữ liệu: `btn_n` → `sync_2ff` (`RST_VAL = 1`) → đảo → `debounce` → `pressed` → `edge_detect.rise` → thanh ghi đảo trạng thái. LED xanh tắt sau reset.

Thêm vào XDC: `set_property PULLUP true [get_ports btn_n]`; `set_false_path -from [get_ports btn_n]` (ngõ vào bất đồng bộ, timing do synchronizer đảm nhận).

## 8. Kế hoạch kiểm tra

| ID | Mức | Kiểm tra | Tiêu chí đạt |
|---|---|---|---|
| T1 | `sync_2ff` | Độ trễ | `q` theo `d` sau đúng 2 cạnh lên |
| T2 | `debounce` | Chuỗi dội (xung ngẫu nhiên < `STABLE_CYCLES`) | `dout` không đổi |
| T3 | `debounce` | Thay đổi ổn định | `dout` đổi đúng `STABLE_CYCLES` chu kỳ sau cạnh cuối của `din` |
| T4 | `edge_detect` | Độ rộng xung | `rise`/`fall` đúng 1 chu kỳ, không có xung sau reset |
| T5 | `lab03_top` | 5 lần nhấn có dội (`STABLE_CYCLES` nhỏ) | LED xanh đảo đúng 5 lần; LED đỏ theo trạng thái giữ nút |
| S1 | Synthesis | Có `ASYNC_REG` trên flip-flop của synchronizer, không latch | — |
| H1 | Board | 20 lần nhấn | 20 lần đảo, không đảo thừa hay thiếu |

## 9. Sản phẩm cần nộp

- [ ] `sync_2ff.v`, `debounce.v`, `edge_detect.v`, `lab03_top.v`, `lab03_top.xdc` (bạn)
- [ ] Testbench (Claude); log, báo cáo, ảnh cách nối dây; README của lab (Claude)
