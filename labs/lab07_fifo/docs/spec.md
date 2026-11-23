# Lab 07 — Synchronous FIFO in Block RAM: Specification (v1.0)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Goal

Build a synchronous FIFO that Vivado maps to block RAM and use it as a line buffer: characters typed in the terminal are stored and sent back as a whole line when Enter is pressed. Concepts: read/write pointers, full/empty detection, BRAM inference and its 1-cycle read latency, golden-model (queue) checking.

## 2. Module Hierarchy

```
lab07_top
├── por_gen, sync_2ff          (Labs 02, 03)
├── uart_rx                    (Lab 06)
├── sync_fifo                  512 × 8 line buffer
├── line_ctrl                  FSM: collect line, then drain to TX
└── uart_tx                    (Lab 05)
```

## 3. `sync_fifo`

| Signal | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst` | in | 1 | Synchronous reset, active high (empties the FIFO) |
| `wr_en` | in | 1 | Write request |
| `wr_data` | in | `DW` | Write data |
| `full` | out | 1 | No space; writes are ignored |
| `rd_en` | in | 1 | Read request |
| `rd_data` | out | `DW` | Read data, valid the cycle **after** an accepted read |
| `rd_valid` | out | 1 | 1 in the cycle `rd_data` is valid |
| `empty` | out | 1 | No data; reads are ignored |
| `count` | out | `AW+1` | Number of stored words (0 … 2^AW) |
| `overflow` | out | 1 | 1-cycle pulse on a write while full |

| Parameter | Default | Description |
|---|---|---|
| `DW` | 8 | Data width |
| `AW` | 9 | Address width → depth 2^AW = 512 |

Behavior:
- A write is accepted when `wr_en && !full`; a read when `rd_en && !empty`.
- Simultaneous accepted read and write: `count` unchanged, both performed.
- Read latency 1 cycle (registered memory output, required for BRAM inference).
- Memory: `reg [DW-1:0] mem [0:2**AW-1]` written and read in a clocked `always` block without reset on `mem`. Expected implementation: 1 block RAM, no distributed RAM.
- `full`, `empty` and `count` are registered and correct in the cycle after each operation.

## 4. `line_ctrl`

| Signal | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst` | in | 1 | Clock, reset |
| `rx_data`, `rx_valid` | in | 8, 1 | From `uart_rx` |
| FIFO write / read ports | — | — | To `sync_fifo` |
| `tx_data`, `tx_valid` | out | 8, 1 | To `uart_tx` |
| `tx_ready` | in | 1 | From `uart_tx` |

FSM:
- **COLLECT:** every received byte other than `\r` (0x0D) is written into the FIFO. On `\r` → DRAIN.
- **DRAIN:** read the FIFO and send every byte to `uart_tx` in order until empty, then send `\r` and `\n` (0x0A) → COLLECT.
- Bytes received during DRAIN are written into the FIFO and belong to the next line.

## 5. `lab07_top`

| Signal | Dir | Width | Pin | Description |
|---|---|---|---|---|
| `clk_50m` | in | 1 | N18 | 50 MHz |
| `uart_rxd` | in | 1 | B20 | From USB-UART TXD |
| `uart_txd` | out | 1 | H16 | To USB-UART RXD |
| `led_g_n` | out | 1 | W13 | On while the FIFO is not empty |
| `led_r_n` | out | 1 | W14 | On for 100 ms after `overflow` |

## 6. Verification Plan

| ID | Check | Pass criterion |
|---|---|---|
| T1 | 10 000 random read/write cycles vs queue golden model | `rd_data`, `full`, `empty`, `count` match every cycle |
| T2 | Fill to 512, write once more | `full`, `overflow` pulse, data intact |
| T3 | Read when empty | Ignored, no `rd_valid` |
| T4 | Simultaneous read/write at empty+1 and full | Correct count and data |
| T5 | `lab07_top`: send `abc\r` with UART model | Receive `abc\r\n` |
| T6 | Line longer than 512 characters | First 512 echoed, overflow reported |
| S1 | Utilization | 1 RAMB18 or RAMB36, 0 LUTRAM for the FIFO memory |
| H1 | Board | Typed line is echoed on Enter |

## 7. Deliverables

- [ ] `sync_fifo.v`, `line_ctrl.v`, `lab07_top.v`, `lab07_top.xdc` (user)
- [ ] Testbenches with queue model; utilization report showing BRAM; lab README
