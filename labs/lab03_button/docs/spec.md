# Lab 03 — External Push Button: Specification (v1.1)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Goal

Read a mechanical push button safely: bring the asynchronous signal into the clock domain, remove contact bounce, and turn each press into a single one-cycle event. Concepts: metastability, 2-FF synchronizer, debounce, edge detection, internal pull-up.

## 2. Hardware

| Item | Connection |
|---|---|
| Push button, one side | DATA1-5 (FPGA pin A20) |
| Push button, other side | DATA1-12 (GND); DATA1-4 is diagonally adjacent to DATA1-5, too close for two connectors. The header has a 2.0 mm pitch: use 2.0 mm female jumper wires |
| Pull-up | FPGA internal `PULLUP` on A20 |

Released = 1, pressed = 0 → signal name `btn_n`. **Do not touch DATA1 pins 1–2 (board supply).**

## 3. Module Hierarchy

```
lab03_top
├── por_gen          (Lab 02)
├── sync_2ff         2-flip-flop synchronizer
├── debounce         stable-level filter
└── edge_detect      rise / fall one-cycle pulses
```

## 4. `sync_2ff`

| Signal | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Destination clock |
| `rst` | in | 1 | Synchronous reset, active high |
| `d` | in | 1 | Asynchronous input |
| `q` | out | 1 | Synchronized output |

| Parameter | Default | Description |
|---|---|---|
| `RST_VAL` | 1'b0 | Value of both flip-flops in reset |

Two flip-flops in series, no logic between them; latency 2 cycles. Mark both registers with `(* ASYNC_REG = "TRUE" *)`.

Cycle model (every rising edge): `rst` = 1 → `ff1 <= RST_VAL`, `q <= RST_VAL`; otherwise `ff1 <= d`, `q <= ff1`. A change of `d` between two edges appears on `q` after exactly 2 rising edges.

## 5. `debounce`

| Signal | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset, active high |
| `din` | in | 1 | Synchronized noisy input |
| `dout` | out | 1 | Debounced output |

| Parameter | Default | Description |
|---|---|---|
| `STABLE_CYCLES` | 1_000_000 | 20 ms at 50 MHz |
| `RST_VAL` | 1'b0 | `dout` value in reset |

Behavior: `dout` takes the value of `din` only after `din` has differed from `dout` for `STABLE_CYCLES` consecutive cycles; `dout` changes on the cycle the count reaches `STABLE_CYCLES`. Any return of `din` to the `dout` value before that restarts the count. Pulses shorter than `STABLE_CYCLES` never reach `dout`.

Cycle model (S = `STABLE_CYCLES`, `cnt` = consecutive samples with `din` ≠ `dout`), every rising edge:

| Condition | Action |
|---|---|
| `rst` = 1 | `dout <= RST_VAL`, `cnt <= 0` |
| `din` == `dout` | `cnt <= 0` |
| `din` ≠ `dout`, `cnt` < S − 1 | `cnt <= cnt + 1` |
| `din` ≠ `dout`, `cnt` == S − 1 | `dout <= din`, `cnt <= 0` |

So `dout` changes on the edge where `din` has been sampled different from `dout` on S consecutive edges, that edge included: a pulse of S − 1 samples is blocked, a pulse of S samples passes.

## 6. `edge_detect`

| Signal | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset, active high |
| `din` | in | 1 | Clean level |
| `rise` | out | 1 | 1 for exactly one cycle after `din` goes 0 → 1 |
| `fall` | out | 1 | 1 for exactly one cycle after `din` goes 1 → 0 |

No pulse is produced by reset release.

Cycle model (outputs are registered), every rising edge: `din_d <= din` (also during reset); `rst` = 1 → `rise <= 0`, `fall <= 0`; otherwise `rise <= din & ~din_d`, `fall <= ~din & din_d`. `rise` is high in the cycle after the first cycle in which `din` is 1. Because `din_d` follows `din` during reset, releasing reset never creates a pulse, whatever the level of `din`.

## 7. `lab03_top`

| Signal | Dir | Width | Pin | Description |
|---|---|---|---|---|
| `clk_50m` | in | 1 | N18 | 50 MHz |
| `btn_n` | in | 1 | A20 | Button, active-low, internal pull-up |
| `led_g_n` | out | 1 | W13 | Toggles on every press |
| `led_r_n` | out | 1 | W14 | On while the button is held |

Data path: `btn_n` → `sync_2ff` (`RST_VAL = 1`) → invert → `debounce` (`RST_VAL = 0`) → `pressed` → `edge_detect.rise` → toggle register. Green starts off after reset. The toggle register is a flip-flop that inverts on every cycle in which `rise` = 1; `led_g_n = ~toggle`, `led_r_n = ~pressed`. All modules use the reset of `por_gen` (Lab 02 timing). Parameters `STABLE_CYCLES` and `POR_CYCLES` are passed through for simulation.

XDC additions: `set_property PULLUP true [get_ports btn_n]`; `set_false_path -from [get_ports btn_n]` (asynchronous input, timing handled by the synchronizer).

## 8. Verification Plan

| ID | Level | Check | Pass criterion |
|---|---|---|---|
| T1 | `sync_2ff` | Latency at several input offsets; reset | `q` follows `d` after exactly 2 rising edges; `q` = `RST_VAL` in reset |
| T2 | `debounce` | Bounce burst (random pulses < `STABLE_CYCLES`) | `dout` unchanged |
| T3 | `debounce` | Stable change; pulses of S − 1 and S samples; reset mid-count | `dout` changes exactly `STABLE_CYCLES` cycles after the last edge of `din`; S − 1 blocked, S passed |
| T4 | `edge_detect` | Pulse width and count | `rise`/`fall` exactly 1 cycle, one pulse per input edge, none at reset release (`din` = 0 or 1) |
| T5 | `lab03_top` | 5 bouncy presses (`STABLE_CYCLES` small) | Green toggles exactly 5 times; red follows the held state |
| S1 | Synthesis | `ASYNC_REG` on synchronizer flops, no latch | — |
| H1 | Board | 20 presses | 20 toggles, no double or missed toggles |

## 9. Resolved Ambiguities (v1.0 → v1.1)

| Question in v1.0 | Decision |
|---|---|
| `debounce`: is the edge that completes S samples the one that updates `dout`? | Yes: S consecutive differing samples, that edge included |
| `debounce` reset value inside `lab03_top` | `RST_VAL = 0` (released), matching the inverted synchronizer reset value 1 |
| `edge_detect`: combinational or registered outputs? | Registered: pulse in the cycle after `din` first becomes 1 |
| How is "no pulse at reset release" guaranteed? | `din_d` follows `din` during reset |
| Toggle register timing | Inverts on the edge after the cycle in which `rise` = 1 |

## 10. Deliverables

- [ ] `sync_2ff.v`, `debounce.v`, `edge_detect.v`, `lab03_top.v`, `lab03_top.xdc` (user)
- [x] Testbenches `tb_sync_2ff.v`, `tb_debounce.v`, `tb_edge_detect.v`, `tb_lab03_top.v` (self-checking, cycle-accurate golden models)
- [ ] Logs, reports, photo of the wiring; lab README
