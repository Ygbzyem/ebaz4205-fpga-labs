# Lab 04 — FSM: Đèn giao thông trên LED kép: Đặc tả (v1.0)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Mục tiêu

Thiết kế máy trạng thái hữu hạn kiểu Moore: đèn giao thông hiển thị trên LED đỏ/xanh (bật cả hai = vàng), định thời bằng xung tick 1 giây, có nút cho người đi bộ để rút ngắn pha xanh. Khái niệm: sơ đồ trạng thái và bảng trạng thái, ngõ ra Moore, mã hoá trạng thái (binary và one-hot), bộ định thời bên trong FSM.

## 2. Phân cấp module

```
lab04_top
├── por_gen                       (Lab 02)
├── sync_2ff → debounce → edge_detect   chuỗi xử lý nút nhấn (Lab 03)
├── tick_gen                      xung 1 chu kỳ sau mỗi TICK_CYCLES
└── traffic_fsm                   FSM Moore + bộ định thời pha
```

## 3. `tick_gen`

| Tín hiệu | Hướng | Độ rộng | Mô tả |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset đồng bộ, tích cực mức cao |
| `tick` | out | 1 | Bằng 1 trong một chu kỳ, cứ mỗi `TICK_CYCLES` chu kỳ |

Tham số `TICK_CYCLES` = 50_000_000 (1 s). Xung `tick` đầu tiên xuất hiện `TICK_CYCLES` chu kỳ sau khi nhả reset. (Cùng ý tưởng bộ đếm với `blink_core`.)

## 4. `traffic_fsm`

### Giao tiếp

| Tín hiệu | Hướng | Độ rộng | Mô tả |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Reset đồng bộ, tích cực mức cao |
| `tick` | in | 1 | Xung 1 giây |
| `ped_req` | in | 1 | Xung 1 chu kỳ cho mỗi lần nhấn nút |
| `light_g` | out | 1 | Đèn xanh, logic bật = 1 |
| `light_r` | out | 1 | Đèn đỏ, logic bật = 1 |
| `state_o` | out | 2 | Mã trạng thái hiện tại để debug (00 RED, 01 GREEN, 10 YELLOW) |

| Tham số | Mặc định | Đơn vị | Mô tả |
|---|---|---|---|
| `T_GREEN` | 5 | tick | Thời gian xanh bình thường |
| `T_GREEN_MIN` | 2 | tick | Thời gian xanh tối thiểu trước khi yêu cầu được phép cắt pha |
| `T_YELLOW` | 2 | tick | Thời gian vàng |
| `T_RED` | 5 | tick | Thời gian đỏ |

### Trạng thái và ngõ ra (Moore)

| Trạng thái | `light_g` | `light_r` | Nhìn thấy |
|---|---|---|---|
| `S_RED` | 0 | 1 | Đỏ |
| `S_GREEN` | 1 | 0 | Xanh |
| `S_YELLOW` | 1 | 1 | Vàng/cam |

### Chuyển trạng thái

Bộ định thời pha `t` đếm số tick đã ở trong trạng thái hiện tại; bị xoá về 0 mỗi khi đổi trạng thái.

| Từ | Điều kiện (xét tại chu kỳ có `tick`) | Sang |
|---|---|---|
| `S_RED` | `t + 1 == T_RED` | `S_GREEN` |
| `S_GREEN` | `t + 1 == T_GREEN` | `S_YELLOW` |
| `S_GREEN` | `req_latched && t + 1 >= T_GREEN_MIN` | `S_YELLOW` |
| `S_YELLOW` | `t + 1 == T_YELLOW` | `S_RED` |

- Chỉ đổi trạng thái ở những chu kỳ có `tick = 1`.
- `req_latched` được `ped_req` bật lên **chỉ khi đang ở `S_GREEN`**, và bị xoá khi FSM rời `S_GREEN`. Nhấn nút trong lúc vàng hoặc đỏ thì bị bỏ qua.
- Trạng thái sau reset: `S_RED`, `t = 0`, `req_latched = 0`.
- Cách mã hoá trạng thái do người thiết kế chọn; ghi lại cách đã chọn và so sánh utilization giữa binary và one-hot trong log của lab.

## 5. `lab04_top`

| Tín hiệu | Hướng | Độ rộng | Chân | Mô tả |
|---|---|---|---|---|
| `clk_50m` | in | 1 | N18 | 50 MHz |
| `btn_n` | in | 1 | A20 | Nút người đi bộ (nối như Lab 03) |
| `led_g_n` | out | 1 | W13 | `~light_g` |
| `led_r_n` | out | 1 | W14 | `~light_r` |

## 6. Kế hoạch kiểm tra

| ID | Kiểm tra | Tiêu chí đạt |
|---|---|---|
| T1 | Chu trình bình thường (`TICK_CYCLES` nhỏ) | ĐỎ 5 → XANH 5 → VÀNG 2 → ĐỎ…, thời gian đúng theo số tick |
| T2 | Nhấn nút ở tick 0 của pha xanh | Rời pha xanh sau `T_GREEN_MIN` tick |
| T3 | Nhấn nút ở tick 3 của pha xanh | Rời pha xanh ở tick kế tiếp |
| T4 | Nhấn nút trong pha vàng và đỏ | Bị bỏ qua, pha xanh tiếp theo kéo dài `T_GREEN` |
| T5 | Xung yêu cầu không trùng với `tick` | Vẫn được chốt và xử lý |
| T6 | Ngõ ra so với bảng trạng thái | Khớp ở mọi chu kỳ |
| S1 | Synthesis | Báo cáo FSM extraction của Vivado cho thấy cách mã hoá; không latch |
| H1 | Board | Bấm giờ đúng; nút nhấn rút ngắn pha xanh |

## 7. Sản phẩm cần nộp

- [ ] `tick_gen.v`, `traffic_fsm.v`, `lab04_top.v`, `lab04_top.xdc` (bạn); sơ đồ trạng thái do bạn vẽ
- [ ] Testbench có mô hình tham chiếu; log, báo cáo, video; README của lab
