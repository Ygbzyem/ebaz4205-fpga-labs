# Lab 05 — UART Transmitter: Specification (v1.0)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Goal

Send the text `Hello EBAZ4205\r\n` from the PL to a PC terminal once per second over UART (115200 baud, 8N1). Concepts: serial framing, baud timing from a clock divider, valid/ready handshake, ROM-driven sequencer.

## 2. Hardware

| USB-UART (CH343P, 3.3 V) | EBAZ4205 |
|---|---|
| RXD | DATA1-6 (FPGA pin H16) — `uart_txd` |
| GND | DATA1-4 |

Terminal: 115200 baud, 8 data bits, no parity, 1 stop bit, no flow control.

## 3. Timing

`CLKS_PER_BIT = round(50 000 000 / 115 200) = 434` → actual 115 207 baud, error +0.006 % (UART tolerates about ±2 %). One frame = 10 bits = 4 340 cycles = 86.8 µs.

## 4. Module Hierarchy

```
lab05_top
├── por_gen          (Lab 02)
├── tick_gen         1 s tick (Lab 04)
├── msg_sender       walks the message ROM, feeds uart_tx
└── uart_tx          serializer
```

## 5. `uart_tx`

| Signal | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset, active high |
| `tx_data` | in | 8 | Byte to send |
| `tx_valid` | in | 1 | Byte available |
| `tx_ready` | out | 1 | Transmitter can accept a byte |
| `txd` | out | 1 | Serial line, idle high |

Parameter `CLKS_PER_BIT` = 434.

Behavior:
- Handshake: a byte is accepted on a rising edge where `tx_valid && tx_ready`. `tx_ready` is 0 from the cycle after acceptance until the stop bit has been on the line for `CLKS_PER_BIT` cycles.
- Frame: start bit (0), `tx_data[0]` … `tx_data[7]` (LSB first), stop bit (1). Each bit lasts exactly `CLKS_PER_BIT` cycles.
- The start bit begins on the cycle after acceptance. Back-to-back bytes produce frames with no idle gap.
- `txd` is driven from a register (no glitches). Reset: `txd = 1`, `tx_ready = 1`.

## 6. `msg_sender`

| Signal | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst` | in | 1 | Clock, reset |
| `start` | in | 1 | 1-cycle pulse: send the message once |
| `tx_data` | out | 8 | To `uart_tx` |
| `tx_valid` | out | 1 | To `uart_tx` |
| `tx_ready` | in | 1 | From `uart_tx` |
| `busy` | out | 1 | 1 while sending |
| `done` | out | 1 | 1-cycle pulse after the last byte is accepted |

Message ROM, 16 bytes: `H e l l o ␠ E B A Z 4 2 0 5 \r \n` (0x48 0x65 0x6C 0x6C 0x6F 0x20 0x45 0x42 0x41 0x5A 0x34 0x32 0x30 0x35 0x0D 0x0A). A `start` while `busy` is ignored.

## 7. `lab05_top`

| Signal | Dir | Width | Pin | Description |
|---|---|---|---|---|
| `clk_50m` | in | 1 | N18 | 50 MHz |
| `uart_txd` | out | 1 | H16 | To USB-UART RXD |
| `led_g_n` | out | 1 | W13 | Toggles after each message (`done`) |
| `led_r_n` | out | 1 | W14 | Off (`1`) |

`tick` → `msg_sender.start`.

## 8. Verification Plan

| ID | Check | Pass criterion |
|---|---|---|
| T1 | UART receiver model in TB decodes `txd` | Bytes equal to `tx_data`, LSB first |
| T2 | Bit timing | Every bit exactly `CLKS_PER_BIT` cycles (checked with small `CLKS_PER_BIT`, e.g. 8, and with 434) |
| T3 | Handshake | No byte lost or duplicated with random `tx_valid` gaps; `tx_ready` low during a frame |
| T4 | Back-to-back | Consecutive frames without idle bits |
| T5 | `msg_sender` | Exactly the 16 ROM bytes in order, `done` once; `start` during `busy` ignored |
| S2 | Timing | WNS ≥ 0 at 50 MHz |
| H1 | Board | Terminal prints `Hello EBAZ4205` once per second, no garbage characters |

## 9. Deliverables

- [ ] `uart_tx.v`, `msg_sender.v`, `lab05_top.v`, `lab05_top.xdc` (user)
- [ ] Testbenches with UART receiver model (Claude); terminal screenshot; lab README (Claude)
