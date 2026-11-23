# Lab 10 — Custom AXI4-Lite IP (`axi_led_pwm`): Specification (v1.0)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Goal

Turn the Lab 02 PWM logic into a memory-mapped peripheral that the ARM core controls through registers. Concepts: AXI4-Lite channels and handshakes, register map design, write strobes, response codes, IP packaging, bare-metal register access.

## 2. Module Hierarchy

```
axi_led_pwm                 packaged IP
├── axi_lite_regs           AXI4-Lite slave + register file
├── breath_ctrl             (Lab 02)
├── pwm_core (green)        (Lab 02)
└── pwm_core (red)          (Lab 02)
```

## 3. Interface

| Signal | Dir | Width | Description |
|---|---|---|---|
| `s_axi_aclk` | in | 1 | AXI clock (FCLK_CLK0, 100 MHz) |
| `s_axi_aresetn` | in | 1 | AXI reset, **active low**, synchronous |
| `s_axi_awaddr`, `s_axi_awvalid`, `s_axi_awready` | — | 4, 1, 1 | Write address channel |
| `s_axi_wdata`, `s_axi_wstrb`, `s_axi_wvalid`, `s_axi_wready` | — | 32, 4, 1, 1 | Write data channel |
| `s_axi_bresp`, `s_axi_bvalid`, `s_axi_bready` | — | 2, 1, 1 | Write response channel |
| `s_axi_araddr`, `s_axi_arvalid`, `s_axi_arready` | — | 4, 1, 1 | Read address channel |
| `s_axi_rdata`, `s_axi_rresp`, `s_axi_rvalid`, `s_axi_rready` | — | 32, 2, 1, 1 | Read data channel |
| `led_g_n`, `led_r_n` | out | 1, 1 | Active-low LED outputs |

Parameters: `STEP_CYCLES` for `breath_ctrl` (default 392_000 at 100 MHz → same ≈ 2 s breath).

## 4. Register Map

| Offset | Name | Access | Bits | Reset | Description |
|---|---|---|---|---|---|
| 0x0 | `CTRL` | RW | [0] `EN` | 0 | 1 = outputs active; 0 = both LEDs off |
| | | | [1] `MODE` | 0 | 0 = manual duty, 1 = breathing |
| | | | [31:2] | 0 | Reserved, read as 0 |
| 0x4 | `DUTY_G` | RW | [7:0] | 0 | Green duty in manual mode |
| 0x8 | `DUTY_R` | RW | [7:0] | 0 | Red duty in manual mode |
| 0xC | `STATUS` | RO | [0] `EN`, [15:8] breathing duty | 0 | Writes ignored |

In breathing mode green uses `d` and red uses `255 − d` (as in Lab 02).

## 5. AXI4-Lite Behavior

- A write completes only after both the address and the data handshakes; they may arrive in any order or in the same cycle.
- `wstrb` selects bytes; bytes with strobe 0 keep their old value.
- One outstanding transaction per channel; `bvalid` / `rvalid` stay high until `bready` / `rready`.
- Response is always `OKAY` (`2'b00`). Reads of unmapped bits return 0.
- Address bits [1:0] are ignored (word aligned).

## 6. Integration

Replace `axi_gpio_0` of Lab 09 with the packaged `axi_led_pwm`. Bare-metal app `pwm_demo`: manual mode sweeping duty, then breathing mode, printing register reads on J7.

## 7. Verification Plan

| ID | Check | Pass criterion |
|---|---|---|
| T1 | AXI4-Lite master BFM in TB: write/read every register | Read-back matches; `STATUS` read-only |
| T2 | Address and data in different orders and delays | All writes complete exactly once |
| T3 | Partial `wstrb` | Only selected bytes change |
| T4 | `bready` / `rready` held low for several cycles | `bvalid` / `rvalid` held, data stable |
| T5 | PWM output for written duty | High count per period matches `DUTY_x` |
| T6 | Optional: AXI VIP protocol checker | No protocol violations |
| H1 | Board | Software controls brightness; register reads printed on J7 |

## 8. Deliverables

- [ ] `axi_lite_regs.v`, `axi_led_pwm.v`, packaged IP (`component.xml`) (user)
- [ ] `pwm_demo.c` (user)
- [ ] Testbench with AXI4-Lite BFM; UART log, video; lab README with register map
