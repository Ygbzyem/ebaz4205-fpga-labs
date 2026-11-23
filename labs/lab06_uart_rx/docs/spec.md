# Lab 06 — UART Receiver and Loopback: Specification (v1.0)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Goal

Receive bytes typed in the PC terminal and echo them back. Concepts: asynchronous serial input, mid-bit sampling, false-start rejection, framing error, baud-rate tolerance, overrun.

## 2. Hardware

| USB-UART (CH343P, 3.3 V) | EBAZ4205 |
|---|---|
| RXD | DATA1-6 (H16) — `uart_txd` (Lab 05) |
| TXD | DATA1-8 (B20) — `uart_rxd` |
| GND | DATA1-4 |

## 3. Module Hierarchy

```
lab06_top
├── por_gen          (Lab 02)
├── sync_2ff         rxd synchronizer (Lab 03, RST_VAL = 1)
├── uart_rx          deserializer
├── echo_buf         1-byte holding register between RX and TX
└── uart_tx          (Lab 05)
```

## 4. `uart_rx`

| Signal | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset, active high |
| `rxd` | in | 1 | **Synchronized** serial input, idle high |
| `rx_data` | out | 8 | Received byte, valid when `rx_valid = 1` |
| `rx_valid` | out | 1 | 1-cycle pulse per good frame |
| `frame_err` | out | 1 | 1-cycle pulse when the stop bit is sampled as 0 |

Parameter `CLKS_PER_BIT` = 434 (sampling directly with the system clock; no 16× oversampling clock).

Behavior:
1. **IDLE:** wait for `rxd = 0`.
2. **START:** wait `CLKS_PER_BIT / 2` (= 217) cycles to the middle of the start bit and sample. If `rxd = 1` it was a glitch → back to IDLE (false start).
3. **DATA:** sample 8 bits, each `CLKS_PER_BIT` cycles after the previous sample, LSB first.
4. **STOP:** sample once more after `CLKS_PER_BIT` cycles. `1` → `rx_valid` pulse with `rx_data`; `0` → `frame_err` pulse, data discarded. Then back to IDLE (no wait for the end of the stop bit, so the next start edge is not missed).

## 5. `echo_buf`

| Signal | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst` | in | 1 | Clock, reset |
| `in_data`, `in_valid` | in | 8, 1 | From `uart_rx` |
| `out_data`, `out_valid` | out | 8, 1 | To `uart_tx` |
| `out_ready` | in | 1 | From `uart_tx` |
| `overrun` | out | 1 | 1-cycle pulse when a byte arrives while the register is full |

One byte of storage. Full is cleared when the byte is accepted (`out_valid && out_ready`). A byte arriving while full is dropped and `overrun` pulses. (Lab 07 replaces this with a FIFO.)

## 6. `lab06_top`

| Signal | Dir | Width | Pin | Description |
|---|---|---|---|---|
| `clk_50m` | in | 1 | N18 | 50 MHz |
| `uart_rxd` | in | 1 | B20 | From USB-UART TXD |
| `uart_txd` | out | 1 | H16 | To USB-UART RXD |
| `led_g_n` | out | 1 | W13 | Toggles on every received byte |
| `led_r_n` | out | 1 | W14 | On for 100 ms after a `frame_err` or `overrun` |

XDC: `set_false_path -from [get_ports uart_rxd]`.

## 7. Verification Plan

| ID | Check | Pass criterion |
|---|---|---|
| T1 | TB UART transmitter model, nominal baud, 256 byte values | All received correctly |
| T2 | Baud error ±2 % (model bit time 425 and 443 cycles) | All received correctly |
| T3 | Glitch shorter than half a bit | No byte, back to IDLE |
| T4 | Stop bit forced to 0 | `frame_err` pulse, no `rx_valid` |
| T5 | Back-to-back frames | No byte missed |
| T6 | `lab06_top` loopback, random bytes | TX line carries the same bytes; `overrun` behaviour matches the model |
| S2 | Timing | WNS ≥ 0 |
| H1 | Board | Typed characters echo; pasting a long text: record whether overrun appears |

## 8. Deliverables

- [ ] `uart_rx.v`, `echo_buf.v`, `lab06_top.v`, `lab06_top.xdc` (user)
- [ ] Testbenches with UART TX/RX models; terminal screenshot; lab README
