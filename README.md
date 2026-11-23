# EBAZ4205 FPGA Labs

![License](https://img.shields.io/badge/license-MIT-blue) ![HDL](https://img.shields.io/badge/HDL-Verilog--2001-orange) ![Board](https://img.shields.io/badge/board-EBAZ4205%20(Zynq--7010)-green)

Hands-on RTL labs on the EBAZ4205 (Xilinx Zynq-7010) board, from LED blink to UART, AXI IP and Linux — each lab with a written spec, a self-checking testbench, a reproducible build and on-board results.

## Board

| Item | Value |
|---|---|
| SoC | Xilinx Zynq-7010, `xc7z010clg400-1` (marking `1C`: speed -1, commercial) |
| PL clock | 50 MHz oscillator (X5) |
| Debug | JTAG (J8), PS UART (J7) via CH343P USB-UART |
| Power | 12 V via J4 (D24 fitted) |
| XADC | Not available: `VCCADC_0` unpowered on this board (see [Lab 00](labs/lab00_bringup/README.md)) |
| Tools | Vivado 2020.2 (incl. xsim), Icarus Verilog + GTKWave (WSL) |

## Project Structure

```
ebaz4205-fpga-labs/
├── README.md
├── LICENSE
├── .gitignore
├── board/
│   ├── ebaz4205_master.xdc     # board pin constraints (all lines commented)
│   └── docs/                   # board photos, power / JTAG notes
└── labs/
    ├── lab00_bringup/          # bring-up log: JTAG chain, IDCODE, XADC finding
    │   ├── README.md
    │   └── docs/               # schematic evidence
    └── lab01_blink/
        ├── docs/spec.md        # interface, timing, behavior, open questions
        ├── rtl/                # synthesizable Verilog-2001
        ├── tb/                 # self-checking testbenches
        ├── constraints/        # lab XDC
        ├── scripts/            # non-project Vivado build (build.tcl)
        └── results/            # utilization / timing reports, photos
```

## Lab Index

| Lab | Topic | Key concepts | Status |
|---|---|---|---|
| 00 | Board bring-up | JTAG chain, IDCODE, XADC, environment | ✅ done (XADC unavailable on this board) |
| 01 | LED blink | Clock divider, synchronous reset, bit width | in progress |
| 02 | PWM breathing LED | Duty cycle, compare | planned |
| 03 | External button | 2-FF synchronizer, debounce, edge detect | planned |
| 04 | FSM | Moore / Mealy, state encoding | planned |
| 05–06 | UART TX / RX | Baud generator, oversampling, loopback | planned |
| 07–08 | FIFO / BRAM, ILA | Pointers, BRAM inference, on-chip debug | planned |
| 09–10 | Zynq PS + AXI | AXI GPIO, Vitis bare-metal, custom AXI4-Lite IP | planned |
| 11+ | PetaLinux | Device tree, UIO driver | planned |

## Module Index

| Module | File | Lab | Role |
|---|---|---|---|
| `blink_core` | `labs/lab01_blink/rtl/blink_core.v` | 01 | Clock divider and LED toggle |
| `tb_blink_core` | `labs/lab01_blink/tb/tb_blink_core.v` | 01 | Self-checking testbench with golden model |

## Getting Started

```sh
git clone git@github.com:<your-username>/ebaz4205-fpga-labs.git
cd ebaz4205-fpga-labs/labs/lab01_blink
mkdir -p build

# Simulation with Icarus (repeat with HALF_PERIOD = 2, 5, 16)
iverilog -g2001 -Wall -Ptb_blink_core.HALF_PERIOD=5 -o build/sim tb/tb_blink_core.v rtl/blink_core.v
vvp build/sim            # add +vcd to dump a waveform, open it with gtkwave

# Simulation with Vivado xsim (Windows cmd)
xvlog tb/tb_blink_core.v rtl/blink_core.v
xelab tb_blink_core -s tb_sim
xsim tb_sim -R

# Synthesis, implementation, bitstream
vivado -mode batch -source scripts/build.tcl
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
| 01 | pending | pending | pending | pending |

## Acknowledgements

Board schematic and pin reference: [xjtuecho/EBAZ4205](https://github.com/xjtuecho/EBAZ4205) (MIT License).

## Author

Phạm Minh Tùng — Semiconductor IC Design, FPT University, Ho Chi Minh City

## License

MIT — see [LICENSE](LICENSE).
