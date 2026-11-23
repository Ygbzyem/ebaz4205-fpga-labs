# Lab 09 — Zynq PS + AXI GPIO, bare-metal: Đặc tả (v0.9 bản nháp)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Mục tiêu

Khởi động hệ xử lý ARM (PS) của Zynq: cấu hình nó trong Block Design của Vivado, nối một AXI GPIO trong PL ra hai LED, và chạy một chương trình C bare-metal từ Vitis để in ra UART của PS (J7) và nháy LED. Khái niệm: phân chia PS/PL, cấu hình `processing_system7`, AXI interconnect, bản đồ địa chỉ, chuyển giao phần cứng bằng file `.xsa`, driver bare-metal.

## 2. Block Design

```
processing_system7_0 ── M_AXI_GP0 ── AXI Interconnect / SmartConnect ── axi_gpio_0 ── gpio[1:0] → led_g_n, led_r_n
        │ FCLK_CLK0 (clock cho PL) ─────────────────────────────────────┘
        └ FCLK_RESET0_N → proc_sys_reset_0
```

| Khối | Cấu hình |
|---|---|
| `processing_system7_0` | Thông số PS của EBAZ4205 (bảng bên dưới); bật M_AXI_GP0; bật FCLK_CLK0 |
| `axi_gpio_0` | 1 kênh, 2 bit, toàn bộ là ngõ ra, giá trị mặc định `0b11` (LED tắt, active-low) |
| `proc_sys_reset_0` | Reset cho miền clock AXI |
| Wrapper cấp trên | `led_g_n` → W13, `led_r_n` → W14 (`gpio[0]`, `gpio[1]`) |

## 3. Cấu hình PS (phải xác nhận trước khi build)

Các giá trị này phụ thuộc vào board. Chúng phải được lấy từ một thiết kế tham chiếu đã chạy được trên EBAZ4205 và ghi lại ở đây kèm nguồn trước khi hiện thực.

| Mục | Giá trị | Trạng thái |
|---|---|---|
| Clock tham chiếu của PS (PS_CLK) | chưa có | ⏳ tra schematic |
| Chip DDR3 / độ rộng / dung lượng | 256 MB, mã chip và độ rộng chưa có | ⏳ schematic / thiết kế tham chiếu |
| Thông số timing DDR | chưa có | ⏳ thiết kế tham chiếu |
| UART của PS nối ra J7 (UART0/1) và chân MIO | chưa có | ⏳ tra schematic |
| Điện áp MIO bank 0 / bank 1 | chưa có | ⏳ tra schematic |
| Tần số FCLK_CLK0 | 100 MHz (lựa chọn thiết kế) | đề xuất |

## 4. Bản đồ địa chỉ

| Slave | Địa chỉ gốc | Vùng |
|---|---|---|
| `axi_gpio_0` | do Vivado gán (dự kiến 0x4120_0000) | 64 KB |

Ghi lại giá trị thực tế từ Address Editor.

## 5. Phần mềm (Vitis 2020.2, standalone)

| Mục | Hành vi |
|---|---|
| Platform | Tạo từ file `.xsa` đã export (có kèm bitstream) |
| Ứng dụng | `hello_led`: in `Hello from EBAZ4205 PS` ra J7 ở 115200 8N1, rồi bật luân phiên hai LED mỗi 500 ms bằng driver `XGpio` |
| Boot | Qua JTAG từ Vitis (FSBL / `ps7_init` chạy qua JTAG); boot từ thẻ SD để tới Lab 11 |

## 6. Kế hoạch kiểm tra

| ID | Kiểm tra | Tiêu chí đạt |
|---|---|---|
| V1 | Kiểm tra Block Design | `validate_bd_design` không có lỗi |
| V2 | Timing | WNS ≥ 0 cho FCLK_CLK0 |
| V3 | Bản đồ địa chỉ | Đã ghi địa chỉ gốc, khớp với `xparameters.h` |
| H1 | UART của PS | Lời chào hiện trên J7 |
| H2 | LED | Luân phiên mỗi 500 ms do phần mềm điều khiển |
| H3 | Truy cập thanh ghi | Đọc lại thanh ghi dữ liệu GPIO trong debugger ra đúng giá trị đã ghi |

## 7. Sản phẩm cần nộp

- [ ] Block Design (`.bd` xuất ra Tcl bằng `write_bd_tcl`) và XDC (bạn)
- [ ] `hello_led.c` (bạn)
- [ ] `.xsa` không đưa vào Git (đăng ở Release nếu cần)
- [ ] Bảng cấu hình PS đã điền kèm nguồn, log UART, ảnh; README của lab (Claude)
