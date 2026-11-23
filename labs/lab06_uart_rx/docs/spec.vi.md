# Lab 06 — Bộ thu UART và loopback: Đặc tả (v1.0)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Mục tiêu

Nhận các byte gõ từ terminal trên PC và gửi ngược lại (echo). Khái niệm: ngõ vào nối tiếp bất đồng bộ, lấy mẫu giữa bit, loại bỏ start bit giả, lỗi khung (framing error), dung sai baud, tràn dữ liệu (overrun).

## 2. Phần cứng

| USB-UART (CH343P, 3.3 V) | EBAZ4205 |
|---|---|
| RXD | DATA1-6 (H16) — `uart_txd` (Lab 05) |
| TXD | DATA1-8 (B20) — `uart_rxd` |
| GND | DATA1-4 |

## 3. Phân cấp module

```
lab06_top
├── por_gen          (Lab 02)
├── sync_2ff         đồng bộ rxd (Lab 03, RST_VAL = 1)
├── uart_rx          bộ chuyển nối tiếp → song song
├── echo_buf         thanh ghi giữ 1 byte giữa RX và TX
└── uart_tx          (Lab 05)
```

## 4. `uart_rx`

| Tín hiệu | Hướng | Độ rộng | Mô tả |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset đồng bộ, tích cực mức cao |
| `rxd` | in | 1 | Ngõ vào nối tiếp **đã đồng bộ**, rảnh ở mức cao |
| `rx_data` | out | 8 | Byte nhận được, hợp lệ khi `rx_valid = 1` |
| `rx_valid` | out | 1 | Xung 1 chu kỳ cho mỗi khung đúng |
| `frame_err` | out | 1 | Xung 1 chu kỳ khi lấy mẫu stop bit được 0 |

Tham số `CLKS_PER_BIT` = 434 (lấy mẫu trực tiếp bằng clock hệ thống; không dùng clock lấy mẫu 16×).

Hành vi:
1. **IDLE:** chờ `rxd = 0`.
2. **START:** chờ `CLKS_PER_BIT / 2` (= 217) chu kỳ tới giữa start bit rồi lấy mẫu. Nếu `rxd = 1` thì đó là glitch → quay lại IDLE (start bit giả).
3. **DATA:** lấy mẫu 8 bit, mỗi mẫu cách mẫu trước `CLKS_PER_BIT` chu kỳ, LSB trước.
4. **STOP:** lấy mẫu thêm một lần sau `CLKS_PER_BIT` chu kỳ. Được `1` → phát xung `rx_valid` kèm `rx_data`; được `0` → phát xung `frame_err`, bỏ dữ liệu. Sau đó quay về IDLE (không chờ hết stop bit, để không lỡ cạnh start của byte kế tiếp).

## 5. `echo_buf`

| Tín hiệu | Hướng | Độ rộng | Mô tả |
|---|---|---|---|
| `clk`, `rst` | in | 1 | Clock, reset |
| `in_data`, `in_valid` | in | 8, 1 | Từ `uart_rx` |
| `out_data`, `out_valid` | out | 8, 1 | Tới `uart_tx` |
| `out_ready` | in | 1 | Từ `uart_tx` |
| `overrun` | out | 1 | Xung 1 chu kỳ khi có byte mới đến lúc thanh ghi đang đầy |

Chứa được 1 byte. Trạng thái đầy được xoá khi byte được nhận đi (`out_valid && out_ready`). Byte đến khi đang đầy thì bị bỏ và `overrun` phát xung. (Lab 07 thay khối này bằng FIFO.)

## 6. `lab06_top`

| Tín hiệu | Hướng | Độ rộng | Chân | Mô tả |
|---|---|---|---|---|
| `clk_50m` | in | 1 | N18 | 50 MHz |
| `uart_rxd` | in | 1 | B20 | Từ TXD của USB-UART |
| `uart_txd` | out | 1 | H16 | Tới RXD của USB-UART |
| `led_g_n` | out | 1 | W13 | Đảo trạng thái mỗi byte nhận được |
| `led_r_n` | out | 1 | W14 | Sáng 100 ms sau mỗi `frame_err` hoặc `overrun` |

XDC: `set_false_path -from [get_ports uart_rxd]`.

## 7. Kế hoạch kiểm tra

| ID | Kiểm tra | Tiêu chí đạt |
|---|---|---|
| T1 | Mô hình bộ phát UART trong TB, baud danh định, 256 giá trị byte | Nhận đúng tất cả |
| T2 | Sai lệch baud ±2 % (mô hình dùng thời gian bit 425 và 443 chu kỳ) | Nhận đúng tất cả |
| T3 | Glitch ngắn hơn nửa bit | Không ra byte nào, quay về IDLE |
| T4 | Ép stop bit bằng 0 | Có xung `frame_err`, không có `rx_valid` |
| T5 | Các khung liền nhau | Không sót byte nào |
| T6 | Loopback ở `lab06_top`, byte ngẫu nhiên | Đường TX mang đúng các byte đó; hành vi `overrun` khớp mô hình |
| S2 | Timing | WNS ≥ 0 |
| H1 | Board | Ký tự gõ vào được echo lại; dán một đoạn văn dài: ghi lại có xảy ra overrun hay không |

## 8. Sản phẩm cần nộp

- [ ] `uart_rx.v`, `echo_buf.v`, `lab06_top.v`, `lab06_top.xdc` (bạn)
- [ ] Testbench có mô hình UART TX/RX (Claude); ảnh terminal; README của lab (Claude)
