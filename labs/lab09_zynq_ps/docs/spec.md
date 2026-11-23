# Lab 09 — Zynq PS + AXI GPIO, Bare-metal: Specification (v0.9 draft)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Goal

Bring up the ARM processing system (PS) of the Zynq: configure it in a Vivado Block Design, connect an AXI GPIO in the PL to the LEDs, and run a bare-metal C program from Vitis that prints to the PS UART (J7) and blinks the LEDs. Concepts: PS/PL split, `processing_system7` configuration, AXI interconnect, address map, `.xsa` hardware handoff, bare-metal drivers.

## 2. Block Design

```
processing_system7_0 ── M_AXI_GP0 ── AXI Interconnect / SmartConnect ── axi_gpio_0 ── gpio[1:0] → led_g_n, led_r_n
        │ FCLK_CLK0 (PL clock) ─────────────────────────────────────────┘
        └ FCLK_RESET0_N → proc_sys_reset_0
```

| Block | Configuration |
|---|---|
| `processing_system7_0` | EBAZ4205 PS settings (table below); M_AXI_GP0 enabled; FCLK_CLK0 enabled |
| `axi_gpio_0` | 1 channel, 2 bits, all outputs, default output value `0b11` (LEDs off, active-low) |
| `proc_sys_reset_0` | Reset for the AXI clock domain |
| Top wrapper | `led_g_n` → W13, `led_r_n` → W14 (`gpio[0]`, `gpio[1]`) |

## 3. PS Configuration (to be confirmed before building)

These values are board-specific. They must be taken from a working EBAZ4205 reference design and recorded here with the source before implementation.

| Item | Value | Status |
|---|---|---|
| PS reference clock (PS_CLK) | pending | ⏳ from schematic |
| DDR3 device / width / size | 256 MB, part and width pending | ⏳ from schematic / reference design |
| DDR timing parameters | pending | ⏳ reference design |
| PS UART used on J7 (UART0/1) and MIO pins | pending | ⏳ from schematic |
| Bank 0 / bank 1 MIO voltage | pending | ⏳ from schematic |
| FCLK_CLK0 frequency | 100 MHz (design choice) | proposed |

## 4. Address Map

| Slave | Base address | Range |
|---|---|---|
| `axi_gpio_0` | assigned by Vivado (expected 0x4120_0000) | 64 KB |

Record the actual value from the Address Editor.

## 5. Software (Vitis 2020.2, standalone)

| Item | Behavior |
|---|---|
| Platform | From the exported `.xsa` (including bitstream) |
| App | `hello_led`: print `Hello from EBAZ4205 PS` on J7 at 115200 8N1, then toggle the two LEDs alternately every 500 ms using the `XGpio` driver |
| Boot | JTAG from Vitis (FSBL / `ps7_init` over JTAG); SD boot is deferred to Lab 11 |

## 6. Verification Plan

| ID | Check | Pass criterion |
|---|---|---|
| V1 | Block Design validation | `validate_bd_design` with no errors |
| V2 | Timing | WNS ≥ 0 for FCLK_CLK0 |
| V3 | Address map | Base address recorded, matches `xparameters.h` |
| H1 | PS UART | Greeting printed on J7 |
| H2 | LEDs | Alternate every 500 ms under software control |
| H3 | Register access | Reading back the GPIO data register in the debugger returns the written value |

## 7. Deliverables

- [ ] Block Design (`.bd` exported as Tcl with `write_bd_tcl`) and XDC (user)
- [ ] `hello_led.c` (user)
- [ ] `.xsa` kept out of Git (published in a Release if needed)
- [ ] Filled-in PS configuration table with sources, UART log, photo; lab README
