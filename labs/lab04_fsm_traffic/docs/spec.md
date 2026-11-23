# Lab 04 — FSM: Traffic Light on the Dual LED: Specification (v1.0)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Goal

Design a Moore finite-state machine: a traffic light shown on the red/green LED (both on = yellow), timed by a 1-second tick, with a pedestrian button that shortens the green phase. Concepts: state diagram and state table, Moore outputs, state encoding (binary vs one-hot), timers inside an FSM.

## 2. Module Hierarchy

```
lab04_top
├── por_gen                       (Lab 02)
├── sync_2ff → debounce → edge_detect   button chain (Lab 03)
├── tick_gen                      1-cycle pulse every TICK_CYCLES
└── traffic_fsm                   Moore FSM + phase timer
```

## 3. `tick_gen`

| Signal | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset, active high |
| `tick` | out | 1 | 1 for one cycle every `TICK_CYCLES` cycles |

Parameter `TICK_CYCLES` = 50_000_000 (1 s). First `tick` comes `TICK_CYCLES` cycles after reset release. (Same counter idea as `blink_core`.)

## 4. `traffic_fsm`

### Interface

| Signal | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset, active high |
| `tick` | in | 1 | 1-second pulse |
| `ped_req` | in | 1 | 1-cycle pulse per button press |
| `light_g` | out | 1 | Green lamp, logical on = 1 |
| `light_r` | out | 1 | Red lamp, logical on = 1 |
| `state_o` | out | 2 | Current state code for debug (00 RED, 01 GREEN, 10 YELLOW) |

| Parameter | Default | Unit | Description |
|---|---|---|---|
| `T_GREEN` | 5 | ticks | Normal green time |
| `T_GREEN_MIN` | 2 | ticks | Minimum green time before a request can end it |
| `T_YELLOW` | 2 | ticks | Yellow time |
| `T_RED` | 5 | ticks | Red time |

### States and outputs (Moore)

| State | `light_g` | `light_r` | Seen as |
|---|---|---|---|
| `S_RED` | 0 | 1 | Red |
| `S_GREEN` | 1 | 0 | Green |
| `S_YELLOW` | 1 | 1 | Yellow/orange |

### Transitions

A phase timer `t` counts ticks spent in the current state; it is cleared on every state change.

| From | Condition (evaluated on a `tick`) | To |
|---|---|---|
| `S_RED` | `t + 1 == T_RED` | `S_GREEN` |
| `S_GREEN` | `t + 1 == T_GREEN` | `S_YELLOW` |
| `S_GREEN` | `req_latched && t + 1 >= T_GREEN_MIN` | `S_YELLOW` |
| `S_YELLOW` | `t + 1 == T_YELLOW` | `S_RED` |

- State changes happen only on cycles where `tick = 1`.
- `req_latched` is set by `ped_req` **only while in `S_GREEN`**, and cleared when the FSM leaves `S_GREEN`. Presses in yellow or red are ignored.
- Reset state: `S_RED`, `t = 0`, `req_latched = 0`.
- Encoding is the designer's choice; record which one was used and compare utilization of binary vs one-hot in the lab log.

## 5. `lab04_top`

| Signal | Dir | Width | Pin | Description |
|---|---|---|---|---|
| `clk_50m` | in | 1 | N18 | 50 MHz |
| `btn_n` | in | 1 | A20 | Pedestrian button (Lab 03 wiring) |
| `led_g_n` | out | 1 | W13 | `~light_g` |
| `led_r_n` | out | 1 | W14 | `~light_r` |

## 6. Verification Plan

| ID | Check | Pass criterion |
|---|---|---|
| T1 | Normal cycle (`TICK_CYCLES` small) | RED 5 → GREEN 5 → YELLOW 2 → RED…, durations exact in ticks |
| T2 | Request at green tick 0 | Leaves green after `T_GREEN_MIN` ticks |
| T3 | Request at green tick 3 | Leaves green on the next tick |
| T4 | Requests during yellow and red | Ignored, next green lasts `T_GREEN` |
| T5 | Request pulse not aligned with `tick` | Latched and honoured |
| T6 | Outputs vs state table | Match in every cycle |
| S1 | Synthesis | Vivado FSM extraction report shows the encoding; no latch |
| H1 | Board | Timing by stopwatch; button shortens green |

## 7. Deliverables

- [ ] `tick_gen.v`, `traffic_fsm.v`, `lab04_top.v`, `lab04_top.xdc` (user); state diagram drawn by the user
- [ ] Testbenches with a reference model; logs, reports, video; lab README
