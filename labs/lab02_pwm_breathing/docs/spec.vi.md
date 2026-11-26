# Lab 02 — LED "thở" bằng PWM: Đặc tả (v1.1)

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

Định thời chính xác: `rst` được lấy mẫu bằng 1 ở các cạnh lên 1 … `POR_CYCLES` sau khi cấu hình, và bằng 0 từ cạnh `POR_CYCLES` + 1 trở đi (bộ đếm có giá trị khởi tạo 0, dừng ở `POR_CYCLES`; `rst = (counter < POR_CYCLES)`).

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

Mô hình chính xác theo chu kỳ (điều xảy ra ở mỗi cạnh lên khi `rst` = 0; cả ba thanh ghi đều dùng giá trị *trước* cạnh):

| Thanh ghi | Giá trị kế tiếp |
|---|---|
| `pwm` | `(cnt < duty_sh)` |
| `duty_sh` | `duty` nếu `cnt == 2^W − 1` (cạnh quay vòng), ngược lại giữ nguyên |
| `cnt` | `cnt + 1`, quay vòng 2^W − 1 → 0 |

Hệ quả (testbench đều kiểm tra):
- `pwm` chậm hơn `cnt` một chu kỳ: xung mức cao xuất hiện khi `cnt = 1 … duty_sh`.
- Giá trị `duty` tại cạnh quay vòng là giá trị dùng cho cả chu kỳ kế tiếp; các thay đổi trước đó trong cùng chu kỳ bị bỏ qua.
- Chu kỳ đầu tiên sau reset luôn ở mức thấp, vì `duty_sh = 0` cho tới cạnh quay vòng đầu tiên.

Ví dụ với `W = 2` (chu kỳ 4), `duty = 2` không đổi, reset nhả trước cạnh 1:

| Sau cạnh | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|
| `cnt` | 1 | 2 | 3 | 0 | 1 | 2 | 3 | 0 | 1 |
| `duty_sh` | 0 | 0 | 0 | 2 | 2 | 2 | 2 | 2 | 2 |
| `pwm` | 0 | 0 | 0 | 0 | 1 | 1 | 0 | 0 | 1 |

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
- Sau reset `duty = 0`, hướng = tăng, bộ định thời bước = 0.
- Cứ mỗi `STEP_CYCLES` chu kỳ, `duty` thay đổi 1 đơn vị: tăng tới 2^W − 1, rồi giảm tới 0, rồi lại tăng (dạng tam giác, không lặp giá trị ở đỉnh: …254, 255, 254… và …1, 0, 1…).
- Một nhịp thở = 2 × (2^W − 1) = 510 bước → 510 × 196 000 × 20 ns = 1.999 s.

Định thời chính xác: bộ định thời bước đếm 0 … `STEP_CYCLES` − 1. `duty` đổi ở cạnh mà bộ định thời đang ở `STEP_CYCLES` − 1, nên sau khi nhả reset, lần đổi đầu tiên xảy ra ở cạnh thứ `STEP_CYCLES` và `duty` giữ mỗi giá trị (kể cả giá trị 0 đầu tiên) đúng `STEP_CYCLES` chu kỳ. `duty` là ngõ ra thanh ghi.

## 6. `lab02_top`

| Tín hiệu | Hướng | Độ rộng | Chân | Mô tả |
|---|---|---|---|---|
| `clk_50m` | in | 1 | N18 | 50 MHz |
| `led_g_n` | out | 1 | W13 | Active-low |
| `led_r_n` | out | 1 | W14 | Active-low |

`led_g_n = ~pwm_g`, `led_r_n = ~pwm_r`. Tham số `STEP_CYCLES` và `POR_CYCLES` được truyền xuống để ghi đè khi mô phỏng. Hai instance `pwm_core` dùng chung reset và clock nên chu kỳ PWM của chúng trùng nhau, và từ chu kỳ thứ hai trở đi, số chu kỳ mức cao của xanh + đỏ = 255 trong mỗi chu kỳ. Trong lúc power-on reset và chu kỳ PWM đầu tiên, cả hai LED đều tắt.

## 7. Kế hoạch kiểm tra

| ID | Mức | Kiểm tra | Tiêu chí đạt |
|---|---|---|---|
| T1 | `pwm_core` | Số chu kỳ mức cao mỗi chu kỳ PWM với duty 0, 1, 2, 127, 128, 254, 255 | Số chu kỳ mức cao = duty, ở mọi chu kỳ |
| T2 | `pwm_core` | Đổi duty giữa chu kỳ | Chu kỳ hiện tại không đổi, giá trị mới áp dụng từ chu kỳ sau |
| T3 | `pwm_core` | Reset giữa chu kỳ, xung reset 1 chu kỳ | `pwm = 0`, đếm lại từ 0 |
| T4 | `breath_ctrl` | Dốc với `W = 3`, `STEP_CYCLES = 3`; reset khi đang giảm | Chuỗi 0,1,…,7,6,…,0,1…, mỗi bước cách nhau đúng 3 chu kỳ; đạt đủ mọi giá trị; bắt đầu lại từ 0 theo hướng tăng |
| T5 | `lab02_top` | Duty bù nhau, power-on | Chân ra khớp mô hình ở mọi chu kỳ; số chu kỳ mức cao xanh + đỏ = 255 mỗi chu kỳ PWM; LED tắt khi reset |
| S1 | Synthesis | Không latch, ghi lại utilization | — |
| S2 | Timing | 50 MHz | WNS ≥ 0 |
| H1 | Board | Quan sát | Sáng/tối mượt, một nhịp thở ≈ 2 s, không thấy nháy |

## 8. Các điểm mơ hồ đã chốt (v1.0 → v1.1)

| Câu hỏi ở v1.0 | Quyết định |
|---|---|
| "`pwm` là thanh ghi": xung bắt đầu ở chu kỳ nào? | Một chu kỳ sau `cnt = 0` (bảng ở mục 4) |
| `duty` được chốt chính xác lúc nào? | Ở cạnh quay vòng (`cnt` = 2^W − 1 → 0) |
| Chu kỳ đầu tiên sau reset ra gì? | Toàn mức thấp (`duty_sh` = 0) |
| Bước đầu tiên của `breath_ctrl` sau reset ở đâu? | Ở cạnh thứ `STEP_CYCLES` sau khi nhả reset |
| Ngõ ra `por_gen` là thanh ghi hay tổ hợp? | Giống Lab 01: `rst = (counter < POR_CYCLES)`, bằng 1 ở cạnh 1 … `POR_CYCLES` |
| Kiểm tra duty bù nhau thế nào khi không biết tên tín hiệu bên trong? | Trên chân ra: số chu kỳ mức cao xanh + đỏ = 255 mỗi chu kỳ PWM |

## 9. Sản phẩm cần nộp

- [ ] `por_gen.v`, `pwm_core.v`, `breath_ctrl.v`, `lab02_top.v`, `lab02_top.xdc` (bạn)
- [x] Testbench `tb_pwm_core.v`, `tb_breath_ctrl.v`, `tb_lab02_top.v` (tự kiểm tra, có golden model chính xác theo chu kỳ)
- [ ] Log, báo cáo, video; README của lab
