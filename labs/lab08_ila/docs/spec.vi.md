# Lab 08 — Debug trên chip bằng ILA: Đặc tả (v1.0)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Mục tiêu

Quan sát thiết kế Lab 07 đang chạy trên board bằng Integrated Logic Analyzer (ILA) của Vivado, và chứng minh hành vi trên phần cứng khớp với mô phỏng. Khái niệm: `mark_debug`, debug hub, điều kiện trigger, độ sâu lấy mẫu, chi phí BRAM của debug, so sánh dữ liệu bắt trên phần cứng với dạng sóng mô phỏng.

## 2. Thiết kế được debug

Giữ nguyên RTL của Lab 07 (`lab07_top` và các module con). Lab này không được sửa chức năng — chỉ thêm phần debug.

## 3. Các probe

| Probe | Độ rộng | Lấy từ |
|---|---|---|
| `rx_data` | 8 | Ngõ ra `uart_rx` |
| `rx_valid` | 1 | Ngõ ra `uart_rx` |
| `frame_err` | 1 | Ngõ ra `uart_rx` |
| `fifo_count` | 10 | `sync_fifo.count` |
| `line_state` | độ rộng FSM | Thanh ghi trạng thái của `line_ctrl` |
| `tx_valid`, `tx_ready` | 1, 1 | Bắt tay của `uart_tx` |
| `uart_txd` | 1 | Ngõ ra nối tiếp |

## 4. Cấu hình ILA

| Mục | Giá trị | Lý do |
|---|---|---|
| Cách chèn | Gắn `(* mark_debug = "true" *)` lên net + dùng *Set Up Debug* sau synthesis | RTL không đổi, chỉ thêm attribute |
| Clock lấy mẫu | `clk_50m` (chạy liên tục) | ILA cần một clock luôn chạy trong lúc debug |
| Độ sâu | 32768 mẫu | 32768 × 20 ns = 655 µs ≈ 7.5 khung UART (một khung = 86.8 µs), đủ cho một dòng ngắn. Tốn khoảng 25 bit × 32768 ≈ 23 trên 60 BRAM36 — ghi lại con số thực tế |
| Trigger | `rx_valid == 1 && rx_data == 8'h0D` | Lúc bắt đầu pha DRAIN |
| Vị trí trigger | 128 | Thấy được các byte trước khi nhấn Enter |

Ghi lại lượng LUT / FF / BRAM mà ILA dùng thêm (so với utilization của Lab 07).

## 5. Thí nghiệm

| ID | Thí nghiệm | Kỳ vọng |
|---|---|---|
| E1 | Gõ `abc` + Enter | Trigger kích hoạt; `fifo_count` đi từ 3 → 0 trong khi `tx_valid`/`tx_ready` bắt tay 5 byte (`a b c \r \n`) |
| E2 | So dữ liệu bắt ở E1 với mô phỏng Lab 07 cùng ngõ vào | Cùng chuỗi trạng thái và thứ tự bắt tay |
| E3 | Trigger theo `frame_err == 1`, đổi terminal sang 9600 baud rồi gõ | Bắt được lỗi khung |
| E4 | Đo một bit TX trên `uart_txd` trong dạng sóng | 434 mẫu cho mỗi bit |
| E5 | Chạy lại E1 với độ sâu 1024 và *capture control* (chỉ lưu những chu kỳ có `rx_valid`, `tx_valid && tx_ready` hoặc đổi trạng thái) | Bắt được cùng các sự kiện mà tốn ít BRAM hơn nhiều |

## 6. Sản phẩm cần nộp

- [ ] XDC debug (`lab08_debug.xdc`) sinh ra từ *Set Up Debug* (bạn)
- [ ] File probe `.ltx` lưu cùng kết quả
- [ ] Ảnh chụp E1–E4, bảng chênh lệch utilization
- [ ] README của lab so sánh phần cứng và mô phỏng (Claude)
