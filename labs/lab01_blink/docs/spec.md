# Lab 01 — LED Blink: Specification (v1.0)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Goal

Blink the on-board dual LED (green and red) in opposite phase at 1 Hz, clocked by the 50 MHz PL oscillator. First complete RTL → simulation → bitstream → board loop.

## 2. Files

```
lab01_blink/
├── docs/spec.md, spec.vi.md
├── rtl/
│   ├── blink_core.v         # clock divider + toggle logic
│   └── lab01_top.v          # board wrapper: power-on reset, LED polarity
├── constraints/
│   └── lab01_top.xdc        # pins + 50 MHz clock (lines from board/ebaz4205_master.xdc)
├── tb/
│   ├── tb_blink_core.v      # self-checking testbench for blink_core
│   └── tb_lab01_top.v       # top-level testbench: POR length, LED polarity
└── scripts/
    └── create_project.tcl   # creates the Vivado project in build/
```

## 3. Module Hierarchy

```
lab01_top            board wrapper: power-on reset, LED polarity, pins
└── blink_core       clock divider + toggle logic
```

## 4. `blink_core`

### Interface

| Signal | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock, rising edge |
| `rst` | in | 1 | Synchronous reset, active high |
| `led_g` | out | 1 | Green LED, logical on = 1 |
| `led_r` | out | 1 | Red LED, logical on = 1, always `~led_g` |

| Parameter | Default | Description |
|---|---|---|
| `HALF_PERIOD` | 25_000_000 | Clock cycles between two toggles (≥ 2). 25 000 000 × 20 ns = 0.5 s → 1 Hz blink |

### Behavior

- While `rst` is sampled high on a rising edge: `led_g = 0`, `led_r = 1`.
- After reset release `led_g` stays 0 for exactly `HALF_PERIOD` cycles, then 1 for `HALF_PERIOD` cycles, and so on.
- A reset at any time, including on the edge where a toggle would happen, wins and restarts the count from 0.
- The counter must hold `HALF_PERIOD − 1`. Its width is derived from the parameter (Verilog-2001: no `$clog2`; use a constant function or a width parameter). For the default value this is 25 bits.
- Registered outputs or outputs derived only from registers; no latches.

## 5. `lab01_top`

### Interface

| Signal | Dir | Width | Pin | Description |
|---|---|---|---|---|
| `clk_50m` | in | 1 | N18 | 50 MHz PL oscillator (X5) |
| `led_g_n` | out | 1 | W13 | Green LED, **active-low** |
| `led_r_n` | out | 1 | W14 | Red LED, **active-low** |

| Parameter | Default | Description |
|---|---|---|
| `HALF_PERIOD` | 25_000_000 | Passed to `blink_core`; overridden with a small value in simulation |
| `POR_CYCLES` | 16 | Length of the power-on reset in clock cycles |

### Behavior

- **Power-on reset:** the board has no PL reset button. `lab01_top` generates an internal active-high `rst` that is asserted from configuration until `POR_CYCLES` rising edges of `clk_50m` have passed, then stays low. Implement it with a register that has an initial value (Vivado loads register initial values at configuration), e.g. a counter or shift register.
- **Polarity:** `led_g_n = ~led_g`, `led_r_n = ~led_r` (LEDs light when the pin is 0).
- Visible result: green and red alternate, each on for 0.5 s.

## 6. Constraints (`lab01_top.xdc`)

| Item | Value |
|---|---|
| `clk_50m` | `PACKAGE_PIN N18`, `IOSTANDARD LVCMOS33`, `create_clock -period 20.000` |
| `led_g_n` | `PACKAGE_PIN W13`, `IOSTANDARD LVCMOS33` |
| `led_r_n` | `PACKAGE_PIN W14`, `IOSTANDARD LVCMOS33` |

## 7. Verification Plan

| ID | Level | What is checked | Pass criterion |
|---|---|---|---|
| T1 | `blink_core` | Values during reset | `led_g = 0`, `led_r = 1` |
| T2 | `blink_core` | Free-running toggling over 6 periods | Cycle-exact match with golden model |
| T3 | `blink_core` | Reset in the middle of a count | Count restarts from 0 |
| T4 | `blink_core` | Reset on a toggle edge | Reset wins, no toggle |
| T5 | `blink_core` | 1-cycle reset pulse | Same as T3 |
| T6 | `lab01_top` | Power-on reset length | Outputs held at reset value for `POR_CYCLES` cycles |
| T7 | `lab01_top` | Polarity | `led_g_n == ~led_g`, LEDs alternate |
| S1 | Synthesis | No latch inferred | 0 latch warnings |
| S2 | Implementation | Timing at 50 MHz | WNS ≥ 0, TNS = 0, no unconstrained clocks |
| H1 | Board | Visual | Green/red alternate; 10 full cycles ≈ 10 s (stopwatch or video) |
| H2 | Board | Configuration state | `REGISTER.IR` shows `DONE = 1` after programming; Done LED state recorded |

`tb_blink_core` runs with `HALF_PERIOD` = 2, 5 and 16.

## 8. Commands

```bat
:: Simulation (Vivado xsim, Windows cmd, from labs\lab01_blink)
xvlog tb\tb_blink_core.v rtl\blink_core.v
xelab tb_blink_core -s tb_sim
xsim tb_sim -R

:: Create the Vivado project (references files in place)
vivado -mode batch -source scripts\create_project.tcl
```

## 9. Deliverables

- [ ] `blink_core.v`, `lab01_top.v`, `lab01_top.xdc` (user)
- [ ] `TEST PASSED` logs for T1–T7
- [ ] Utilization and timing summary in `results/`
- [ ] Board photo or video
- [ ] Lab README (log)
