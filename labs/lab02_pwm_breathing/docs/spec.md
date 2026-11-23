# Lab 02 — PWM Breathing LED: Specification (v1.0)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Goal

Make the green and red LEDs "breathe" (fade in and out) in opposite phase with an 8-bit PWM. Concepts: duty cycle, counter compare, glitch-free duty update, reusing a module.

## 2. Module Hierarchy

```
lab02_top
├── por_gen          power-on reset (refactored from Lab 01)
├── breath_ctrl      triangle ramp of the duty value 0 → 255 → 0
├── pwm_core (u_g)   PWM for green, duty = d
└── pwm_core (u_r)   PWM for red,   duty = 255 - d
```

## 3. `por_gen`

| Signal | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | out | 1 | Active-high reset, high for `POR_CYCLES` cycles after configuration |

Parameter `POR_CYCLES` = 16. Same behavior as the reset logic inside `lab01_top`, moved into its own module so later labs reuse it.

## 4. `pwm_core`

| Signal | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset, active high |
| `duty` | in | `W` | Requested duty (0 … 2^W − 1) |
| `pwm` | out | 1 | PWM output, logical on = 1 |

| Parameter | Default | Description |
|---|---|---|
| `W` | 8 | Counter and duty width; PWM period = 2^W clock cycles |

Behavior:
- A free-running counter `cnt` counts 0 … 2^W − 1 and wraps. One PWM period = 2^W cycles (256 × 20 ns = 5.12 µs → 195.3 kHz, flicker-free).
- `duty` is captured into an internal shadow register when `cnt` wraps to 0. A change of `duty` in the middle of a period takes effect at the start of the next period (no glitch).
- In each period `pwm` is 1 for exactly `duty_shadow` cycles, starting at `cnt = 0`, then 0. `duty = 0` → always 0; `duty = 255` → high 255 of 256 cycles.
- `pwm` is registered.
- Reset: `cnt = 0`, shadow duty = 0, `pwm = 0`.

## 5. `breath_ctrl`

| Signal | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset, active high |
| `duty` | out | `W` | Ramp value |

| Parameter | Default | Description |
|---|---|---|
| `W` | 8 | Duty width |
| `STEP_CYCLES` | 196_000 | Clock cycles between two duty steps |

Behavior:
- After reset `duty = 0`, direction = up.
- Every `STEP_CYCLES` cycles `duty` changes by 1: up until 2^W − 1, then down until 0, then up again (triangle, no repeated end values: …254, 255, 254… and …1, 0, 1…).
- One breath = 2 × (2^W − 1) = 510 steps → 510 × 196 000 × 20 ns = 1.999 s.

## 6. `lab02_top`

| Signal | Dir | Width | Pin | Description |
|---|---|---|---|---|
| `clk_50m` | in | 1 | N18 | 50 MHz |
| `led_g_n` | out | 1 | W13 | Active-low |
| `led_r_n` | out | 1 | W14 | Active-low |

`led_g_n = ~pwm_g`, `led_r_n = ~pwm_r`. Parameters `STEP_CYCLES` and `POR_CYCLES` are passed through for simulation.

## 7. Verification Plan

| ID | Level | Check | Pass criterion |
|---|---|---|---|
| T1 | `pwm_core` | High cycles per period for duty 0, 1, 2, 127, 128, 254, 255 | High count = duty, every period |
| T2 | `pwm_core` | Duty changed mid-period | Current period unchanged, new value from next period |
| T3 | `pwm_core` | Reset | `pwm = 0`, counting restarts |
| T4 | `breath_ctrl` | Ramp with `W = 3`, `STEP_CYCLES = 3` | Sequence 0,1,…,7,6,…,0,1… with steps exactly 3 cycles apart |
| T5 | `lab02_top` | Complementary duty | `duty_r = 255 − duty_g`; outputs inverted |
| S1 | Synthesis | No latch, utilization recorded | — |
| S2 | Timing | 50 MHz | WNS ≥ 0 |
| H1 | Board | Visual | Smooth fade, one breath ≈ 2 s, no visible flicker |

## 8. Deliverables

- [ ] `por_gen.v`, `pwm_core.v`, `breath_ctrl.v`, `lab02_top.v`, `lab02_top.xdc` (user)
- [ ] Testbenches `tb_pwm_core.v`, `tb_breath_ctrl.v`, `tb_lab02_top.v` (Claude)
- [ ] Logs, reports, video; lab README (Claude)
