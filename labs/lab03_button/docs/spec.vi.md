# Lab 03 — Nút nhấn ngoài: Đặc tả (v1.1)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Mục tiêu

Đọc nút nhấn cơ khí một cách an toàn: đưa tín hiệu bất đồng bộ vào miền clock, lọc hiện tượng dội phím (bounce), và biến mỗi lần nhấn thành đúng một sự kiện dài một chu kỳ. Khái niệm: metastability, synchronizer 2 flip-flop, debounce, phát hiện cạnh, điện trở kéo lên bên trong.

## 2. Phần cứng

| Mục | Cách nối |
|---|---|
| Nút nhấn, một chân | DATA1-5 (chân FPGA A20) |
| Nút nhấn, chân còn lại | DATA1-12 (GND); DATA1-4 nằm chéo sát DATA1-5, quá gần để cắm hai đầu dây. Header có bước chân 2.0 mm: dùng dây cắm đầu cái bước 2.0 mm |
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

Mô hình theo chu kỳ (mỗi cạnh lên): `rst` = 1 → `ff1 <= RST_VAL`, `q <= RST_VAL`; ngược lại `ff1 <= d`, `q <= ff1`. `d` đổi giữa hai cạnh clock thì `q` đổi theo sau đúng 2 cạnh lên.

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

Mô hình theo chu kỳ (S = `STABLE_CYCLES`, `cnt` = số mẫu liên tiếp có `din` ≠ `dout`), mỗi cạnh lên:

| Điều kiện | Hành động |
|---|---|
| `rst` = 1 | `dout <= RST_VAL`, `cnt <= 0` |
| `din` == `dout` | `cnt <= 0` |
| `din` ≠ `dout`, `cnt` < S − 1 | `cnt <= cnt + 1` |
| `din` ≠ `dout`, `cnt` == S − 1 | `dout <= din`, `cnt <= 0` |

Tức là `dout` đổi ở cạnh mà `din` đã được lấy mẫu khác `dout` trên S cạnh liên tiếp, tính cả cạnh đó: xung dài S − 1 mẫu bị chặn, xung dài S mẫu đi qua.

## 6. `edge_detect`

| Tín hiệu | Hướng | Độ rộng | Mô tả |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset đồng bộ, tích cực mức cao |
| `din` | in | 1 | Mức tín hiệu sạch |
| `rise` | out | 1 | Bằng 1 đúng một chu kỳ sau khi `din` đi 0 → 1 |
| `fall` | out | 1 | Bằng 1 đúng một chu kỳ sau khi `din` đi 1 → 0 |

Nhả reset không được sinh ra xung nào.

Mô hình theo chu kỳ (ngõ ra có thanh ghi), mỗi cạnh lên: `din_d <= din` (kể cả khi reset); `rst` = 1 → `rise <= 0`, `fall <= 0`; ngược lại `rise <= din & ~din_d`, `fall <= ~din & din_d`. `rise` lên 1 ở chu kỳ ngay sau chu kỳ đầu tiên `din` bằng 1. Vì `din_d` theo `din` cả trong lúc reset, nhả reset không bao giờ sinh ra xung, dù `din` đang ở mức nào.

## 7. `lab03_top`

| Tín hiệu | Hướng | Độ rộng | Chân | Mô tả |
|---|---|---|---|---|
| `clk_50m` | in | 1 | N18 | 50 MHz |
| `btn_n` | in | 1 | A20 | Nút nhấn, active-low, kéo lên bên trong |
| `led_g_n` | out | 1 | W13 | Đảo trạng thái mỗi lần nhấn |
| `led_r_n` | out | 1 | W14 | Sáng trong lúc giữ nút |

Đường dữ liệu: `btn_n` → `sync_2ff` (`RST_VAL = 1`) → đảo → `debounce` (`RST_VAL = 0`) → `pressed` → `edge_detect.rise` → thanh ghi đảo trạng thái. LED xanh tắt sau reset. Thanh ghi đảo trạng thái là một flip-flop đảo giá trị ở mỗi chu kỳ có `rise` = 1; `led_g_n = ~toggle`, `led_r_n = ~pressed`. Mọi module dùng reset của `por_gen` (định thời như Lab 02). Tham số `STABLE_CYCLES` và `POR_CYCLES` được truyền xuống để mô phỏng.

Thêm vào XDC: `set_property PULLUP true [get_ports btn_n]`; `set_false_path -from [get_ports btn_n]` (ngõ vào bất đồng bộ, timing do synchronizer đảm nhận).

## 8. Kế hoạch kiểm tra

| ID | Mức | Kiểm tra | Tiêu chí đạt |
|---|---|---|---|
| T1 | `sync_2ff` | Độ trễ ở nhiều thời điểm đổi ngõ vào; reset | `q` theo `d` sau đúng 2 cạnh lên; `q` = `RST_VAL` khi reset |
| T2 | `debounce` | Chuỗi dội (xung ngẫu nhiên < `STABLE_CYCLES`) | `dout` không đổi |
| T3 | `debounce` | Thay đổi ổn định; xung dài S − 1 và S mẫu; reset giữa lúc đếm | `dout` đổi đúng `STABLE_CYCLES` chu kỳ sau cạnh cuối của `din`; S − 1 bị chặn, S đi qua |
| T4 | `edge_detect` | Độ rộng và số xung | `rise`/`fall` đúng 1 chu kỳ, mỗi cạnh ngõ vào một xung, không có xung khi nhả reset (`din` = 0 hoặc 1) |
| T5 | `lab03_top` | 5 lần nhấn có dội (`STABLE_CYCLES` nhỏ) | LED xanh đảo đúng 5 lần; LED đỏ theo trạng thái giữ nút |
| S1 | Synthesis | Có `ASYNC_REG` trên flip-flop của synchronizer, không latch | — |
| H1 | Board | 20 lần nhấn | 20 lần đảo, không đảo thừa hay thiếu |

## 9. Các điểm mơ hồ đã chốt (v1.0 → v1.1)

| Câu hỏi ở v1.0 | Quyết định |
|---|---|
| `debounce`: cạnh hoàn thành S mẫu có phải là cạnh cập nhật `dout`? | Đúng: S mẫu khác nhau liên tiếp, tính cả cạnh đó |
| Giá trị reset của `debounce` trong `lab03_top` | `RST_VAL = 0` (đang thả), khớp với giá trị reset 1 của synchronizer sau khi đảo |
| `edge_detect`: ngõ ra tổ hợp hay có thanh ghi? | Có thanh ghi: xung ở chu kỳ sau khi `din` lần đầu bằng 1 |
| Làm sao đảm bảo "không có xung khi nhả reset"? | `din_d` theo `din` cả trong lúc reset |
| Định thời của thanh ghi đảo trạng thái | Đảo ở cạnh ngay sau chu kỳ có `rise` = 1 |

## 10. Sản phẩm cần nộp

- [ ] `sync_2ff.v`, `debounce.v`, `edge_detect.v`, `lab03_top.v`, `lab03_top.xdc` (bạn)
- [x] Testbench `tb_sync_2ff.v`, `tb_debounce.v`, `tb_edge_detect.v`, `tb_lab03_top.v` (tự kiểm tra, golden model chính xác theo chu kỳ)
- [ ] Log, báo cáo, ảnh cách nối dây; README của lab
