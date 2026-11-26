# Lab 02 — PWM Breathing LED: Specification (v1.1)

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

Exact timing: `rst` is sampled high on rising edges 1 … `POR_CYCLES` after configuration and low from edge `POR_CYCLES` + 1 on (a counter with initial value 0 that stops at `POR_CYCLES`; `rst = (counter < POR_CYCLES)`).

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

Cycle-accurate model (what happens on every rising edge while `rst` is low; all three updates use the values from before the edge):

| Register | Next value |
|---|---|
| `pwm` | `(cnt < duty_sh)` |
| `duty_sh` | `duty` if `cnt == 2^W − 1` (the wrap edge), otherwise unchanged |
| `cnt` | `cnt + 1`, wrapping 2^W − 1 → 0 |

Consequences, all checked by the testbench:
- `pwm` is one cycle behind `cnt`: the high pulse is output while `cnt = 1 … duty_sh`.
- The value of `duty` on the wrap edge is the one used for the whole next period; earlier changes in the same period are ignored.
- The first period after reset is always low, because `duty_sh = 0` until the first wrap edge.

Example with `W = 2` (period 4), `duty = 2` constant, reset released before edge 1:

| After edge | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|
| `cnt` | 1 | 2 | 3 | 0 | 1 | 2 | 3 | 0 | 1 |
| `duty_sh` | 0 | 0 | 0 | 2 | 2 | 2 | 2 | 2 | 2 |
| `pwm` | 0 | 0 | 0 | 0 | 1 | 1 | 0 | 0 | 1 |

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
- After reset `duty = 0`, direction = up, step timer = 0.
- Every `STEP_CYCLES` cycles `duty` changes by 1: up until 2^W − 1, then down until 0, then up again (triangle, no repeated end values: …254, 255, 254… and …1, 0, 1…).
- One breath = 2 × (2^W − 1) = 510 steps → 510 × 196 000 × 20 ns = 1.999 s.

Exact timing: the step timer counts 0 … `STEP_CYCLES` − 1. `duty` changes on the edge where the timer is at `STEP_CYCLES` − 1, so after reset release the first change happens on edge `STEP_CYCLES` and `duty` holds every value (including the first 0) for exactly `STEP_CYCLES` cycles. `duty` is a register output.

## 6. `lab02_top`

| Signal | Dir | Width | Pin | Description |
|---|---|---|---|---|
| `clk_50m` | in | 1 | N18 | 50 MHz |
| `led_g_n` | out | 1 | W13 | Active-low |
| `led_r_n` | out | 1 | W14 | Active-low |

`led_g_n = ~pwm_g`, `led_r_n = ~pwm_r`. Parameters `STEP_CYCLES` and `POR_CYCLES` are passed through for simulation. Both `pwm_core` instances share the same reset and clock, so their periods are aligned and, from the second period on, green high cycles + red high cycles = 255 in every period. During the power-on reset and the first PWM period both LEDs are off.

## 7. Verification Plan

| ID | Level | Check | Pass criterion |
|---|---|---|---|
| T1 | `pwm_core` | High cycles per period for duty 0, 1, 2, 127, 128, 254, 255 | High count = duty, every period |
| T2 | `pwm_core` | Duty changed mid-period | Current period unchanged, new value from next period |
| T3 | `pwm_core` | Reset in the middle of a period, 1-cycle reset pulse | `pwm = 0`, counting restarts from 0 |
| T4 | `breath_ctrl` | Ramp with `W = 3`, `STEP_CYCLES = 3`; reset on the falling ramp | Sequence 0,1,…,7,6,…,0,1… with steps exactly 3 cycles apart; every value reached; restart from 0 going up |
| T5 | `lab02_top` | Complementary duty, power-on | Pins match the model every cycle; green + red high cycles = 255 per period; LEDs off during reset |
| S1 | Synthesis | No latch, utilization recorded | — |
| S2 | Timing | 50 MHz | WNS ≥ 0 |
| H1 | Board | Visual | Smooth fade, one breath ≈ 2 s, no visible flicker |

## 8. Resolved Ambiguities (v1.0 → v1.1)

| Question in v1.0 | Decision |
|---|---|
| "Registered `pwm`": in which cycle does the pulse start? | One cycle after `cnt = 0` (table in section 4) |
| When exactly is `duty` captured? | On the wrap edge (`cnt` = 2^W − 1 → 0) |
| What does the first period after reset show? | All low (`duty_sh` = 0) |
| When is the first `breath_ctrl` step after reset? | On edge `STEP_CYCLES` after reset release |
| Is `por_gen` output registered or combinational? | Same as Lab 01: `rst = (counter < POR_CYCLES)`, high on edges 1 … `POR_CYCLES` |
| How is the complementary duty checked without internal names? | On the pins: green + red high cycles = 255 per period |

## 9. Deliverables

- [ ] `por_gen.v`, `pwm_core.v`, `breath_ctrl.v`, `lab02_top.v`, `lab02_top.xdc` (user)
- [x] Testbenches `tb_pwm_core.v`, `tb_breath_ctrl.v`, `tb_lab02_top.v` (self-checking, cycle-accurate golden models)
- [ ] Logs, reports, video; lab README
