# Lab 05 — Bộ phát UART: Đặc tả (v1.0)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Mục tiêu

Gửi chuỗi `Hello EBAZ4205\r\n` từ PL lên terminal trên PC mỗi giây một lần qua UART (115200 baud, 8N1). Khái niệm: khung truyền nối tiếp, định thời baud bằng bộ chia clock, bắt tay valid/ready, bộ tuần tự đọc từ ROM.

## 2. Phần cứng

| USB-UART (CH343P, 3.3 V) | EBAZ4205 |
|---|---|
| RXD | DATA1-6 (chân FPGA H16) — `uart_txd` |
| GND | DATA1-4 |

Terminal: 115200 baud, 8 bit dữ liệu, không parity, 1 stop bit, không flow control.

## 3. Định thời

`CLKS_PER_BIT = round(50 000 000 / 115 200) = 434` → baud thực tế 115 207, sai số +0.006 % (UART chịu được khoảng ±2 %). Một khung = 10 bit = 4 340 chu kỳ = 86.8 µs.

## 4. Phân cấp module

```
lab05_top
├── por_gen          (Lab 02)
├── tick_gen         tick 1 s (Lab 04)
├── msg_sender       duyệt ROM thông điệp, đưa dữ liệu cho uart_tx
└── uart_tx          bộ chuyển song song → nối tiếp
```

## 5. `uart_tx`

| Tín hiệu | Hướng | Độ rộng | Mô tả |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset đồng bộ, tích cực mức cao |
| `tx_data` | in | 8 | Byte cần gửi |
| `tx_valid` | in | 1 | Có byte sẵn sàng |
| `tx_ready` | out | 1 | Bộ phát nhận được byte mới |
| `txd` | out | 1 | Đường truyền nối tiếp, rảnh ở mức cao |

Tham số `CLKS_PER_BIT` = 434.

Hành vi:
- Bắt tay: một byte được nhận tại cạnh lên có `tx_valid && tx_ready`. `tx_ready` bằng 0 từ chu kỳ sau khi nhận cho tới khi stop bit đã nằm trên đường truyền đủ `CLKS_PER_BIT` chu kỳ.
- Khung: start bit (0), `tx_data[0]` … `tx_data[7]` (LSB trước), stop bit (1). Mỗi bit kéo dài đúng `CLKS_PER_BIT` chu kỳ.
- Start bit bắt đầu ở chu kỳ ngay sau khi nhận byte. Các byte liên tiếp tạo thành các khung liền nhau, không có khoảng rảnh.
- `txd` được lái từ thanh ghi (không glitch). Reset: `txd = 1`, `tx_ready = 1`.

## 6. `msg_sender`

| Tín hiệu | Hướng | Độ rộng | Mô tả |
|---|---|---|---|
| `clk`, `rst` | in | 1 | Clock, reset |
| `start` | in | 1 | Xung 1 chu kỳ: gửi thông điệp một lần |
| `tx_data` | out | 8 | Tới `uart_tx` |
| `tx_valid` | out | 1 | Tới `uart_tx` |
| `tx_ready` | in | 1 | Từ `uart_tx` |
| `busy` | out | 1 | Bằng 1 trong lúc đang gửi |
| `done` | out | 1 | Xung 1 chu kỳ sau khi byte cuối được nhận |

ROM thông điệp, 16 byte: `H e l l o ␠ E B A Z 4 2 0 5 \r \n` (0x48 0x65 0x6C 0x6C 0x6F 0x20 0x45 0x42 0x41 0x5A 0x34 0x32 0x30 0x35 0x0D 0x0A). Xung `start` đến trong lúc `busy` thì bị bỏ qua.

## 7. `lab05_top`

| Tín hiệu | Hướng | Độ rộng | Chân | Mô tả |
|---|---|---|---|---|
| `clk_50m` | in | 1 | N18 | 50 MHz |
| `uart_txd` | out | 1 | H16 | Tới RXD của USB-UART |
| `led_g_n` | out | 1 | W13 | Đảo trạng thái sau mỗi thông điệp (`done`) |
| `led_r_n` | out | 1 | W14 | Tắt (`1`) |

`tick` → `msg_sender.start`.

## 8. Kế hoạch kiểm tra

| ID | Kiểm tra | Tiêu chí đạt |
|---|---|---|
| T1 | Mô hình bộ thu UART trong TB giải mã `txd` | Byte nhận được bằng `tx_data`, LSB trước |
| T2 | Định thời bit | Mỗi bit đúng `CLKS_PER_BIT` chu kỳ (kiểm tra với `CLKS_PER_BIT` nhỏ, ví dụ 8, và với 434) |
| T3 | Bắt tay | Không mất hay lặp byte khi `tx_valid` có khoảng nghỉ ngẫu nhiên; `tx_ready` bằng 0 trong khung |
| T4 | Truyền liên tiếp | Các khung nối tiếp nhau không có bit rảnh |
| T5 | `msg_sender` | Đúng 16 byte ROM theo thứ tự, `done` một lần; `start` trong lúc `busy` bị bỏ qua |
| S2 | Timing | WNS ≥ 0 ở 50 MHz |
| H1 | Board | Terminal in `Hello EBAZ4205` mỗi giây một lần, không có ký tự rác |

## 9. Sản phẩm cần nộp

- [ ] `uart_tx.v`, `msg_sender.v`, `lab05_top.v`, `lab05_top.xdc` (bạn)
- [ ] Testbench có mô hình bộ thu UART (Claude); ảnh chụp terminal; README của lab (Claude)
