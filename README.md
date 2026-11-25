# EBAZ4205 FPGA Labs

[English](README.md) | [Tiếng Việt](README.vi.md)

![License](https://img.shields.io/badge/license-MIT-blue) ![HDL](https://img.shields.io/badge/HDL-Verilog--2001-orange) ![Board](https://img.shields.io/badge/board-EBAZ4205%20(Zynq--7010)-green)

Hands-on RTL labs on the EBAZ4205 (Xilinx Zynq-7010) board, from LED blink to UART, AXI IP and Linux — each lab with a written spec, a self-checking testbench, a reproducible build and on-board results.

## Board

| Item | Value |
|---|---|
| SoC | Xilinx Zynq-7010, `xc7z010clg400-1` (marking `1C`: speed -1, commercial) |
| PL clock | 50 MHz oscillator X5 on pin N18 |
| LEDs | Dual red/green LED on W14 / W13, **active-low** |
| Debug | JTAG (J8), PS UART (J7) via CH343P USB-UART |
| Power | 12 V via J4 (D24 fitted) |
| XADC | Not available: `VCCADC_0` unpowered on this board (see [Lab 00](labs/lab00_bringup/README.md)) |
| Tools | Vivado 2020.2 (incl. xsim), Icarus Verilog + GTKWave (WSL) |

Full pin and hardware reference: [board/README.md](board/README.md).

## Project Structure

```
ebaz4205-fpga-labs/
├── README.md / README.vi.md
├── LICENSE
├── .gitignore
├── board/
│   ├── README.md / README.vi.md       # pins, LED polarity, header pinout, power
│   ├── ebaz4205_master.xdc            # all usable PL pins (commented)
│   ├── LICENSE-xjtuecho-EBAZ4205.txt  # upstream MIT license
│   └── docs/                          # schematic evidence
└── labs/
    ├── lab00_bringup/                 # bring-up log (README.md / README.vi.md)
    ├── lab01_blink/
    │   ├── docs/spec.md, spec.vi.md   # interface, timing, behavior, verification plan
    │   ├── rtl/                       # synthesizable Verilog-2001 (user)
    │   ├── tb/                        # self-checking testbenches
    │   ├── constraints/               # lab XDC
    │   ├── scripts/                   # create_project.tcl, build scripts
    │   └── results/                   # utilization / timing reports, photos
    ├── lab02_pwm_breathing/ … lab11_petalinux_uio/
    │   └── docs/spec.md, spec.vi.md
    └── …
```

## Lab Index

| Lab | Folder | Topic | Key concepts | Spec | Status |
|---|---|---|---|---|---|
| 00 | [`lab00_bringup`](labs/lab00_bringup/README.md) | Board bring-up | JTAG chain, IDCODE, XADC, environment | — | ✅ done |
| 01 | [`lab01_blink`](labs/lab01_blink/README.md) | LED blink | Clock divider, power-on reset, active-low outputs | v1.0 | ✅ done |
| 02 | [`lab02_pwm_breathing`](labs/lab02_pwm_breathing/docs/spec.md) | Breathing LED | PWM, glitch-free duty update, module reuse | v1.0 | planned |
| 03 | [`lab03_button`](labs/lab03_button/docs/spec.md) | External button | 2-FF synchronizer, debounce, edge detect | v1.0 | planned |
| 04 | [`lab04_fsm_traffic`](labs/lab04_fsm_traffic/docs/spec.md) | Traffic-light FSM | Moore FSM, state encoding, timers | v1.0 | planned |
| 05 | [`lab05_uart_tx`](labs/lab05_uart_tx/docs/spec.md) | UART transmitter | 8N1 framing, baud divider, valid/ready | v1.0 | planned |
| 06 | [`lab06_uart_rx`](labs/lab06_uart_rx/docs/spec.md) | UART receiver + echo | Mid-bit sampling, framing error, overrun | v1.0 | planned |
| 07 | [`lab07_fifo`](labs/lab07_fifo/docs/spec.md) | FIFO line buffer | Pointers, BRAM inference, queue model | v1.0 | planned |
| 08 | [`lab08_ila`](labs/lab08_ila/docs/spec.md) | On-chip debug | ILA, triggers, capture control | v1.0 | planned |
| 09 | [`lab09_zynq_ps`](labs/lab09_zynq_ps/docs/spec.md) | Zynq PS + AXI GPIO | Block Design, `.xsa`, Vitis bare-metal | v0.9 draft | planned |
| 10 | [`lab10_axi_lite_ip`](labs/lab10_axi_lite_ip/docs/spec.md) | Custom AXI4-Lite IP | Register map, AXI handshakes, IP packaging | v1.0 | planned |
| 11 | [`lab11_petalinux_uio`](labs/lab11_petalinux_uio/docs/spec.md) | PetaLinux + UIO | Boot flow, device tree, `mmap` | v0.9 draft | planned |

## Module Index

| Module | File | Lab | Role |
|---|---|---|---|
| `blink_core` | `labs/lab01_blink/rtl/blink_core.v` | 01 | Clock divider and LED toggle |
| `lab01_top` | `labs/lab01_blink/rtl/lab01_top.v` | 01 | Power-on reset, LED polarity, pins |
| `tb_blink_core` | `labs/lab01_blink/tb/tb_blink_core.v` | 01 | Self-checking testbench with golden model |
| `tb_lab01_top` | `labs/lab01_blink/tb/tb_lab01_top.v` | 01 | Top-level testbench: power-on reset length, LED polarity |

Modules of later labs are listed in each lab's spec and added here when implemented.


## Getting Started

```bat
:: Windows cmd, from labs\lab01_blink
:: Simulation with Vivado xsim
xvlog tb\tb_blink_core.v rtl\blink_core.v
xelab tb_blink_core -s tb_sim
xsim tb_sim -R

:: Create the Vivado project (files referenced in place, project in build\)
vivado -mode batch -source scripts\create_project.tcl
```

```sh
# WSL / Linux, from labs/lab01_blink — Icarus (repeat with HALF_PERIOD = 2, 5, 16)
mkdir -p build
iverilog -g2001 -Wall -Ptb_blink_core.HALF_PERIOD=5 -o build/sim tb/tb_blink_core.v rtl/blink_core.v
vvp build/sim            # add +vcd to dump a waveform, open it with gtkwave
```

## Workflow per Lab

```
spec.md ──► testbench (fails) ──► RTL ──► simulation PASS ──► synth / impl
   ──► timing met (WNS >= 0) ──► bitstream ──► on-board test ──► results + commit
```

## Results

Results are only reported from real tool reports and on-board tests.

| Lab | Simulation | LUT / FF | WNS (ns) | On-board |
|---|---|---|---|---|
| 01 | ✅ PASS (xsim + Icarus) | 36 / 31 | 16.378 | ✅ 1 Hz blink |

## Acknowledgements

Board schematic and pin reference: [xjtuecho/EBAZ4205](https://github.com/xjtuecho/EBAZ4205) (MIT License).

## Author

Phạm Minh Tùng — Semiconductor IC Design, FPT University, Ho Chi Minh City

## License

MIT — see [LICENSE](LICENSE).
