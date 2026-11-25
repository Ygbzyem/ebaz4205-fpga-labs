# Lab 01 — LED Blink

[English](README.md) | [Tiếng Việt](README.vi.md)

**Status: simulation complete — board test pending.**

Green and red LEDs alternate at 1 Hz (0.5 s each), clocked by the 50 MHz PL oscillator. Specification: [docs/spec.md](docs/spec.md).

## Lab Structure

```
lab01_blink/
├── README.md / README.vi.md     # this log
├── docs/spec.md, spec.vi.md     # specification v1.0
├── rtl/
│   ├── blink_core.v             # parameterized counter + LED toggle
│   └── lab01_top.v              # power-on reset, active-low LED outputs
├── constraints/
│   └── lab01_top.xdc            # N18 clock (20 ns), W13 / W14 LEDs
├── tb/
│   ├── tb_blink_core.v          # self-checking, golden model, T1–T5
│   └── tb_lab01_top.v           # self-checking, POR length + polarity, T6–T7
├── scripts/
│   └── create_project.tcl       # Vivado project in build/
└── results/                     # timing / utilization reports, board photo (pending)
```

## Module Index

| Module | File | Role |
|---|---|---|
| `blink_core` | `rtl/blink_core.v` | Counter of width `clog2(HALF_PERIOD)`; toggles `led_g` every `HALF_PERIOD` cycles; `led_r = ~led_g`; synchronous active-high reset |
| `lab01_top` | `rtl/lab01_top.v` | 8-bit power-on reset counter (initial value 0, reset held for `POR_CYCLES` = 16 cycles = 320 ns); inverts outputs for the active-low LEDs |

## Design Summary

```
clk_50m (N18) ──┬──────────────────────────────┐
                │                              ▼
          por_cnt (8 bit) ── rst ──►  blink_core (cnt: 25 bit)
                                       │ led_g        │ led_r = ~led_g
                                       ▼              ▼
                                     [NOT]          [NOT]
                                       ▼              ▼
                                led_g_n (W13)   led_r_n (W14)
```

| Item | Value |
|---|---|
| Toggle period | `HALF_PERIOD` × 20 ns = 25 000 000 × 20 ns = 0.5 s |
| Counter width | `clog2(25 000 000)` = 25 bits (constant function, no `$clog2`) |
| Reset | Synchronous, active high, generated internally (no PL reset button) |
| LED polarity | Active-low (anodes to VCC through 150 Ω) |

## Simulation Results

Vivado xsim 2020.2 (user's run) and Icarus Verilog 12 (`-g2001 -Wall`, cross-check), same RTL.

| Testbench | Parameters | Checks | LED toggles | Errors | Result |
|---|---|---|---|---|---|
| `tb_blink_core` | `HALF_PERIOD` = 2 | 48 | 18 | 0 | ✅ PASS |
| `tb_blink_core` | `HALF_PERIOD` = 5 | 100 | 18 | 0 | ✅ PASS |
| `tb_blink_core` | `HALF_PERIOD` = 16 | 293 | 16 | 0 | ✅ PASS |
| `tb_lab01_top` | `HALF_PERIOD` = 4, `POR_CYCLES` = 16 | 52 (16 in POR) | 9 | 0 | ✅ PASS |
| `tb_lab01_top` | `HALF_PERIOD` = 2, `POR_CYCLES` = 16 | 36 (16 in POR) | 10 | 0 | ✅ PASS |
| `tb_lab01_top` | `HALF_PERIOD` = 5, `POR_CYCLES` = 3 | 47 (3 in POR) | 8 | 0 | ✅ PASS |

The testbenches were also checked against deliberately broken designs (off-by-one count, asynchronous reset, missing counter reset, wrong LED polarity, short or missing power-on reset); each one was reported as `TEST FAILED`.

## Implementation and Board Results

| Item | Result |
|---|---|
| Synthesis warnings (latch / critical) | pending |
| Utilization (LUT / FF) | pending |
| Timing at 50 MHz (WNS / TNS / WHS) | pending |
| `check_timing` unconstrained clocks | pending |
| `REGISTER.IR` `DONE` after programming | pending |
| Done LED state after programming | pending |
| Visual: 10 full cycles (stopwatch / video) | pending (expected ≈ 10 s) |

## Issues Found During Development

| Attempt | Symptom (testbench) | Cause | Fix |
|---|---|---|---|
| 1 | LEDs toggled every clock cycle (90 toggles instead of ~18) | No counter; `HALF_PERIOD` unused | Counter that wraps at `HALF_PERIOD − 1` |
| 1–2 | Compile error at end of file / at line 3 | Missing `endmodule`; missing comma between parameters | Syntax |
| 2 | LEDs never toggled | `led_g <= ~led_r; led_r <= ~led_g;` keeps the state (0,1) forever | `led_r` derived combinationally: `assign led_r = ~led_g` |
| 3 | `reg led_r cannot be driven by continuous assignment` | Port declared `reg` but driven by `assign` | Port type `wire` |
| 3 | `led_g_n = x` from the first cycle | `led_g_n` driven by the core **and** by `assign led_g_n = ~led_g_n` (multiple drivers + combinational loop) | Intermediate wires `led_g`, `led_r`, inverted once at the top |
| 4 | 2 errors: LED cleared before the clock edge when `rst` rose | Asynchronous reset (`or posedge rst`) | Synchronous reset (`always @(posedge clk)` only) |

## Commands

```bat
:: Windows (PowerShell: first run  $env:Path += ";C:\Xilinx\Vivado\2020.2\bin")
cd C:\GitHub\ebaz4205-fpga-labs\labs\lab01_blink
xvlog tb\tb_blink_core.v rtl\blink_core.v
xelab tb_blink_core -s tb_core
xsim tb_core -R
xvlog tb\tb_lab01_top.v rtl\lab01_top.v rtl\blink_core.v
xelab tb_lab01_top -s tb_top
xsim tb_top -R
```
