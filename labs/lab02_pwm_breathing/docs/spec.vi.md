# Lab 02 — LED "thở" bằng PWM: Đặc tả (v1.0)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Mục tiêu

Làm hai LED xanh và đỏ "thở" (sáng dần rồi tối dần) ngược pha nhau bằng PWM 8 bit. Khái niệm: duty cycle, so sánh với bộ đếm, cập nhật duty không gây glitch, tái sử dụng module.

## 2. Phân cấp module

```
lab02_top
├── por_gen          reset khi bật nguồn (tách ra từ Lab 01)
├── breath_ctrl      sinh giá trị duty dạng tam giác 0 → 255 → 0
├── pwm_core (u_g)   PWM cho LED xanh, duty = d
└── pwm_core (u_r)   PWM cho LED đỏ,   duty = 255 - d
```

## 3. `por_gen`

| Tín hiệu | Hướng | Độ rộng | Mô tả |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | out | 1 | Reset tích cực mức cao, giữ mức 1 trong `POR_CYCLES` chu kỳ sau khi cấu hình |

Tham số `POR_CYCLES` = 16. Hành vi giống logic reset trong `lab01_top`, được tách thành module riêng để các lab sau dùng lại.

## 4. `pwm_core`

| Tín hiệu | Hướng | Độ rộng | Mô tả |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset đồng bộ, tích cực mức cao |
| `duty` | in | `W` | Duty yêu cầu (0 … 2^W − 1) |
| `pwm` | out | 1 | Ngõ ra PWM, logic bật = 1 |

| Tham số | Mặc định | Mô tả |
|---|---|---|
| `W` | 8 | Độ rộng bộ đếm và duty; chu kỳ PWM = 2^W chu kỳ clock |

Hành vi:
- Bộ đếm `cnt` chạy tự do từ 0 … 2^W − 1 rồi quay về 0. Một chu kỳ PWM = 2^W chu kỳ clock (256 × 20 ns = 5.12 µs → 195.3 kHz, mắt không thấy nháy).
- `duty` được chốt vào một thanh ghi "bóng" (shadow) khi `cnt` quay về 0. Đổi `duty` giữa chu kỳ thì giá trị mới chỉ có hiệu lực từ đầu chu kỳ sau (không glitch).
- Trong mỗi chu kỳ, `pwm` bằng 1 đúng `duty_shadow` chu kỳ clock tính từ `cnt = 0`, phần còn lại bằng 0. `duty = 0` → luôn 0; `duty = 255` → mức cao 255 trên 256 chu kỳ.
- `pwm` là ngõ ra thanh ghi.
- Reset: `cnt = 0`, duty bóng = 0, `pwm = 0`.

## 5. `breath_ctrl`

| Tín hiệu | Hướng | Độ rộng | Mô tả |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset đồng bộ, tích cực mức cao |
| `duty` | out | `W` | Giá trị dốc |

| Tham số | Mặc định | Mô tả |
|---|---|---|
| `W` | 8 | Độ rộng duty |
| `STEP_CYCLES` | 196_000 | Số chu kỳ clock giữa hai bước duty |

Hành vi:
- Sau reset `duty = 0`, hướng = tăng.
- Cứ mỗi `STEP_CYCLES` chu kỳ, `duty` thay đổi 1 đơn vị: tăng tới 2^W − 1, rồi giảm tới 0, rồi lại tăng (dạng tam giác, không lặp giá trị ở đỉnh: …254, 255, 254… và …1, 0, 1…).
- Một nhịp thở = 2 × (2^W − 1) = 510 bước → 510 × 196 000 × 20 ns = 1.999 s.

## 6. `lab02_top`

| Tín hiệu | Hướng | Độ rộng | Chân | Mô tả |
|---|---|---|---|---|
| `clk_50m` | in | 1 | N18 | 50 MHz |
| `led_g_n` | out | 1 | W13 | Active-low |
| `led_r_n` | out | 1 | W14 | Active-low |

`led_g_n = ~pwm_g`, `led_r_n = ~pwm_r`. Tham số `STEP_CYCLES` và `POR_CYCLES` được truyền xuống để ghi đè khi mô phỏng.

## 7. Kế hoạch kiểm tra

| ID | Mức | Kiểm tra | Tiêu chí đạt |
|---|---|---|---|
| T1 | `pwm_core` | Số chu kỳ mức cao mỗi chu kỳ PWM với duty 0, 1, 2, 127, 128, 254, 255 | Số chu kỳ mức cao = duty, ở mọi chu kỳ |
| T2 | `pwm_core` | Đổi duty giữa chu kỳ | Chu kỳ hiện tại không đổi, giá trị mới áp dụng từ chu kỳ sau |
| T3 | `pwm_core` | Reset | `pwm = 0`, đếm lại từ đầu |
| T4 | `breath_ctrl` | Dốc với `W = 3`, `STEP_CYCLES = 3` | Chuỗi 0,1,…,7,6,…,0,1… và mỗi bước cách nhau đúng 3 chu kỳ |
| T5 | `lab02_top` | Duty bù nhau | `duty_r = 255 − duty_g`; ngõ ra bị đảo |
| S1 | Synthesis | Không latch, ghi lại utilization | — |
| S2 | Timing | 50 MHz | WNS ≥ 0 |
| H1 | Board | Quan sát | Sáng/tối mượt, một nhịp thở ≈ 2 s, không thấy nháy |

## 8. Sản phẩm cần nộp

- [ ] `por_gen.v`, `pwm_core.v`, `breath_ctrl.v`, `lab02_top.v`, `lab02_top.xdc` (bạn)
- [ ] Testbench `tb_pwm_core.v`, `tb_breath_ctrl.v`, `tb_lab02_top.v`
- [ ] Log, báo cáo, video; README của lab
