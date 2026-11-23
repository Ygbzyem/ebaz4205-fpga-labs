# Lab 07 — FIFO đồng bộ dùng Block RAM: Đặc tả (v1.0)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Mục tiêu

Xây dựng một FIFO đồng bộ mà Vivado ánh xạ vào block RAM, rồi dùng nó làm bộ đệm dòng: các ký tự gõ trên terminal được lưu lại và gửi trả nguyên dòng khi nhấn Enter. Khái niệm: con trỏ đọc/ghi, phát hiện đầy/rỗng, suy ra BRAM và độ trễ đọc 1 chu kỳ của nó, kiểm tra bằng golden model (hàng đợi).

## 2. Phân cấp module

```
lab07_top
├── por_gen, sync_2ff          (Lab 02, 03)
├── uart_rx                    (Lab 06)
├── sync_fifo                  bộ đệm dòng 512 × 8
├── line_ctrl                  FSM: gom dòng rồi xả ra TX
└── uart_tx                    (Lab 05)
```

## 3. `sync_fifo`

| Tín hiệu | Hướng | Độ rộng | Mô tả |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset đồng bộ, tích cực mức cao (làm rỗng FIFO) |
| `wr_en` | in | 1 | Yêu cầu ghi |
| `wr_data` | in | `DW` | Dữ liệu ghi |
| `full` | out | 1 | Hết chỗ; lệnh ghi bị bỏ qua |
| `rd_en` | in | 1 | Yêu cầu đọc |
| `rd_data` | out | `DW` | Dữ liệu đọc, hợp lệ ở chu kỳ **sau** lần đọc được chấp nhận |
| `rd_valid` | out | 1 | Bằng 1 ở chu kỳ `rd_data` hợp lệ |
| `empty` | out | 1 | Không có dữ liệu; lệnh đọc bị bỏ qua |
| `count` | out | `AW+1` | Số từ đang lưu (0 … 2^AW) |
| `overflow` | out | 1 | Xung 1 chu kỳ khi ghi lúc đang đầy |

| Tham số | Mặc định | Mô tả |
|---|---|---|
| `DW` | 8 | Độ rộng dữ liệu |
| `AW` | 9 | Độ rộng địa chỉ → độ sâu 2^AW = 512 |

Hành vi:
- Lệnh ghi được chấp nhận khi `wr_en && !full`; lệnh đọc khi `rd_en && !empty`.
- Đọc và ghi cùng được chấp nhận trong một chu kỳ: `count` giữ nguyên, cả hai đều thực hiện.
- Độ trễ đọc 1 chu kỳ (ngõ ra bộ nhớ có thanh ghi, điều kiện để suy ra BRAM).
- Bộ nhớ: `reg [DW-1:0] mem [0:2**AW-1]`, ghi và đọc trong khối `always` có clock, không reset `mem`. Kỳ vọng khi hiện thực: 1 block RAM, không dùng distributed RAM.
- `full`, `empty` và `count` là thanh ghi, đúng giá trị ở chu kỳ ngay sau mỗi thao tác.

## 4. `line_ctrl`

| Tín hiệu | Hướng | Độ rộng | Mô tả |
|---|---|---|---|
| `clk`, `rst` | in | 1 | Clock, reset |
| `rx_data`, `rx_valid` | in | 8, 1 | Từ `uart_rx` |
| Cổng ghi / đọc FIFO | — | — | Tới `sync_fifo` |
| `tx_data`, `tx_valid` | out | 8, 1 | Tới `uart_tx` |
| `tx_ready` | in | 1 | Từ `uart_tx` |

FSM:
- **COLLECT:** mọi byte nhận được, trừ `\r` (0x0D), được ghi vào FIFO. Gặp `\r` → DRAIN.
- **DRAIN:** đọc FIFO và gửi từng byte cho `uart_tx` theo đúng thứ tự cho tới khi rỗng, sau đó gửi `\r` và `\n` (0x0A) → COLLECT.
- Byte nhận được trong lúc DRAIN vẫn được ghi vào FIFO và thuộc về dòng kế tiếp.

## 5. `lab07_top`

| Tín hiệu | Hướng | Độ rộng | Chân | Mô tả |
|---|---|---|---|---|
| `clk_50m` | in | 1 | N18 | 50 MHz |
| `uart_rxd` | in | 1 | B20 | Từ TXD của USB-UART |
| `uart_txd` | out | 1 | H16 | Tới RXD của USB-UART |
| `led_g_n` | out | 1 | W13 | Sáng khi FIFO không rỗng |
| `led_r_n` | out | 1 | W14 | Sáng 100 ms sau `overflow` |

## 6. Kế hoạch kiểm tra

| ID | Kiểm tra | Tiêu chí đạt |
|---|---|---|
| T1 | 10 000 chu kỳ đọc/ghi ngẫu nhiên so với golden model hàng đợi | `rd_data`, `full`, `empty`, `count` khớp ở mọi chu kỳ |
| T2 | Ghi đầy 512, ghi thêm một lần | `full`, có xung `overflow`, dữ liệu còn nguyên |
| T3 | Đọc khi rỗng | Bị bỏ qua, không có `rd_valid` |
| T4 | Đọc/ghi đồng thời khi còn 1 phần tử và khi đầy | Count và dữ liệu đúng |
| T5 | `lab07_top`: gửi `abc\r` bằng mô hình UART | Nhận lại `abc\r\n` |
| T6 | Dòng dài hơn 512 ký tự | 512 ký tự đầu được echo, có báo overflow |
| S1 | Utilization | 1 RAMB18 hoặc RAMB36, 0 LUTRAM cho bộ nhớ FIFO |
| H1 | Board | Dòng gõ vào được echo khi nhấn Enter |

## 7. Sản phẩm cần nộp

- [ ] `sync_fifo.v`, `line_ctrl.v`, `lab07_top.v`, `lab07_top.xdc` (bạn)
- [ ] Testbench có mô hình hàng đợi (Claude); báo cáo utilization cho thấy BRAM; README của lab (Claude)
