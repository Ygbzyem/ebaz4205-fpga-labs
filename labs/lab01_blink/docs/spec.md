# Lab 01 — LED Blink: Specification (v0.1 draft)

## 1. Goal
Blink the two on-board PL LEDs (green and red) of the EBAZ4205 in opposite phase,
driven by the 50 MHz PL oscillator (X5).

## 2. Module hierarchy
```
lab01_top            board wrapper: pins, reset source, LED polarity
└── blink_core       clock divider + toggle logic (verified by tb_blink_core.v)
```

## 3. `blink_core` interface

| Signal | Dir | Width | Description |
|---|---|---|---|
| `clk`   | in  | 1 | Clock, rising edge active |
| `rst`   | in  | 1 | Synchronous reset, active high |
| `led_g` | out | 1 | Green LED, logical "on" = 1 |
| `led_r` | out | 1 | Red LED, logical "on" = 1, always `~led_g` |

| Parameter | Default | Description |
|---|---|---|
| `HALF_PERIOD` | 25_000_000 | Clock cycles between two toggles of `led_g` (>= 2). 25_000_000 at 50 MHz = toggle every 0.5 s = 1 Hz blink |

## 4. Behavior
- While `rst` is sampled high on a rising edge: `led_g = 0`, `led_r = 1`.
- After reset release, `led_g` stays 0 for exactly `HALF_PERIOD` cycles, then 1 for
  `HALF_PERIOD` cycles, and so on.
- A reset at any time (including on the edge where a toggle would happen) wins and
  restarts the count from 0.
- Outputs are registered or derived combinationally from registers only (no latch).
- Language: Verilog-2001 (no `$clog2`). Start the RTL file with `` `timescale 1ns / 1ps``.

## 5. Verification
| Test | What is checked | Pass criterion |
|---|---|---|
| T1 | Values during reset | `led_g=0`, `led_r=1` |
| T2 | Free-running toggling over 6 periods | Cycle-exact match with golden model |
| T3 | Reset in the middle of a count | Count restarts from 0 |
| T4 | Reset on a toggle edge | Reset wins, no toggle |
| T5 | 1-cycle reset pulse | Same as T3 |
| All | `led_r == ~led_g` every cycle, no X after reset | 0 errors, `TEST PASSED` |

Run for `HALF_PERIOD` = 2, 5 and 16 (commands in the lab README).

## 6. Open questions (resolve before writing `lab01_top`)
- [ ] Clock pin of X5 and the `create_clock` period for 50 MHz
- [ ] Pins of the green and red LEDs (schematic / master XDC)
- [ ] LED polarity: is an LED lit by driving its pin high or low?
- [ ] Reset source: the board has no PL reset button — power-on reset logic, or tie `rst` low and rely on register initial values?
- [ ] Counter width needed for `HALF_PERIOD = 25_000_000`
