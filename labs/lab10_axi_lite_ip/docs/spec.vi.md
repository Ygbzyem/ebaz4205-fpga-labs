# Lab 10 — IP AXI4-Lite tự thiết kế (`axi_led_pwm`): Đặc tả (v1.0)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Mục tiêu

Biến logic PWM của Lab 02 thành một ngoại vi ánh xạ bộ nhớ mà lõi ARM điều khiển qua thanh ghi. Khái niệm: các kênh và cơ chế bắt tay của AXI4-Lite, thiết kế bản đồ thanh ghi, write strobe, mã phản hồi, đóng gói IP, truy cập thanh ghi từ bare-metal.

## 2. Phân cấp module

```
axi_led_pwm                 IP đã đóng gói
├── axi_lite_regs           slave AXI4-Lite + tập thanh ghi
├── breath_ctrl             (Lab 02)
├── pwm_core (xanh)         (Lab 02)
└── pwm_core (đỏ)           (Lab 02)
```

## 3. Giao tiếp

| Tín hiệu | Hướng | Độ rộng | Mô tả |
|---|---|---|---|
| `s_axi_aclk` | in | 1 | Clock AXI (FCLK_CLK0, 100 MHz) |
| `s_axi_aresetn` | in | 1 | Reset AXI, **tích cực mức thấp**, đồng bộ |
| `s_axi_awaddr`, `s_axi_awvalid`, `s_axi_awready` | — | 4, 1, 1 | Kênh địa chỉ ghi |
| `s_axi_wdata`, `s_axi_wstrb`, `s_axi_wvalid`, `s_axi_wready` | — | 32, 4, 1, 1 | Kênh dữ liệu ghi |
| `s_axi_bresp`, `s_axi_bvalid`, `s_axi_bready` | — | 2, 1, 1 | Kênh phản hồi ghi |
| `s_axi_araddr`, `s_axi_arvalid`, `s_axi_arready` | — | 4, 1, 1 | Kênh địa chỉ đọc |
| `s_axi_rdata`, `s_axi_rresp`, `s_axi_rvalid`, `s_axi_rready` | — | 32, 2, 1, 1 | Kênh dữ liệu đọc |
| `led_g_n`, `led_r_n` | out | 1, 1 | Ngõ ra LED, active-low |

Tham số: `STEP_CYCLES` cho `breath_ctrl` (mặc định 392_000 ở 100 MHz → vẫn ≈ 2 s mỗi nhịp thở).

## 4. Bản đồ thanh ghi

| Offset | Tên | Truy cập | Bit | Reset | Mô tả |
|---|---|---|---|---|---|
| 0x0 | `CTRL` | RW | [0] `EN` | 0 | 1 = bật ngõ ra; 0 = tắt cả hai LED |
| | | | [1] `MODE` | 0 | 0 = duty chỉnh tay, 1 = chế độ thở |
| | | | [31:2] | 0 | Dự trữ, đọc ra 0 |
| 0x4 | `DUTY_G` | RW | [7:0] | 0 | Duty LED xanh ở chế độ chỉnh tay |
| 0x8 | `DUTY_R` | RW | [7:0] | 0 | Duty LED đỏ ở chế độ chỉnh tay |
| 0xC | `STATUS` | RO | [0] `EN`, [15:8] duty của chế độ thở | 0 | Ghi vào bị bỏ qua |

Ở chế độ thở, LED xanh dùng `d` và LED đỏ dùng `255 − d` (giống Lab 02).

## 5. Hành vi AXI4-Lite

- Một lệnh ghi chỉ hoàn tất sau khi cả bắt tay địa chỉ và bắt tay dữ liệu đã xảy ra; hai bắt tay này có thể đến theo thứ tự bất kỳ hoặc cùng một chu kỳ.
- `wstrb` chọn byte; byte có strobe bằng 0 giữ nguyên giá trị cũ.
- Mỗi kênh chỉ có một giao dịch đang chờ; `bvalid` / `rvalid` giữ mức cao cho tới khi có `bready` / `rready`.
- Phản hồi luôn là `OKAY` (`2'b00`). Đọc các bit không ánh xạ trả về 0.
- Bỏ qua bit địa chỉ [1:0] (căn theo word).

## 6. Tích hợp

Thay `axi_gpio_0` của Lab 09 bằng IP `axi_led_pwm` đã đóng gói. Ứng dụng bare-metal `pwm_demo`: chế độ chỉnh tay quét duty, sau đó chuyển sang chế độ thở, in giá trị đọc thanh ghi ra J7.

## 7. Kế hoạch kiểm tra

| ID | Kiểm tra | Tiêu chí đạt |
|---|---|---|
| T1 | BFM master AXI4-Lite trong TB: ghi/đọc mọi thanh ghi | Đọc lại khớp; `STATUS` chỉ đọc |
| T2 | Địa chỉ và dữ liệu đến theo thứ tự và độ trễ khác nhau | Mọi lệnh ghi hoàn tất đúng một lần |
| T3 | `wstrb` một phần | Chỉ các byte được chọn thay đổi |
| T4 | Giữ `bready` / `rready` ở mức thấp vài chu kỳ | `bvalid` / `rvalid` được giữ, dữ liệu ổn định |
| T5 | Ngõ ra PWM theo duty đã ghi | Số chu kỳ mức cao mỗi chu kỳ PWM bằng `DUTY_x` |
| T6 | Tuỳ chọn: bộ kiểm tra giao thức AXI VIP | Không vi phạm giao thức |
| H1 | Board | Phần mềm điều khiển được độ sáng; giá trị đọc thanh ghi in ra J7 |

## 8. Sản phẩm cần nộp

- [ ] `axi_lite_regs.v`, `axi_led_pwm.v`, IP đã đóng gói (`component.xml`) (bạn)
- [ ] `pwm_demo.c` (bạn)
- [ ] Testbench có BFM AXI4-Lite (Claude); log UART, video; README của lab kèm bản đồ thanh ghi (Claude)
