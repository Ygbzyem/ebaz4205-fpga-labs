# EBAZ4205 FPGA Labs

[English](README.md) | [Tiếng Việt](README.vi.md)

![License](https://img.shields.io/badge/license-MIT-blue) ![HDL](https://img.shields.io/badge/HDL-Verilog--2001-orange) ![Board](https://img.shields.io/badge/board-EBAZ4205%20(Zynq--7010)-green)

Chuỗi bài thực hành RTL trên board EBAZ4205 (Xilinx Zynq-7010), từ nháy LED tới UART, IP AXI và Linux — mỗi lab có đặc tả viết rõ ràng, testbench tự kiểm tra, quy trình build tái tạo được và kết quả chạy thật trên board.

## Board

| Mục | Giá trị |
|---|---|
| SoC | Xilinx Zynq-7010, `xc7z010clg400-1` (chữ in `1C`: speed -1, loại commercial) |
| Clock của PL | Thạch anh 50 MHz X5 vào chân N18 |
| LED | LED kép đỏ/xanh ở W14 / W13, **active-low** |
| Debug | JTAG (J8), UART của PS (J7) qua USB-UART CH343P |
| Nguồn | 12 V vào J4 (đã hàn D24) |
| XADC | Không dùng được: `VCCADC_0` không có nguồn trên board này (xem [Lab 00](labs/lab00_bringup/README.vi.md)) |
| Công cụ | Vivado 2020.2 (có xsim), Icarus Verilog + GTKWave (WSL) |

Tài liệu đầy đủ về chân và phần cứng: [board/README.vi.md](board/README.vi.md).

## Cấu trúc project

```
ebaz4205-fpga-labs/
├── README.md / README.vi.md
├── LICENSE
├── .gitignore
├── board/
│   ├── README.md / README.vi.md       # chân, cực tính LED, sơ đồ header, nguồn
│   ├── ebaz4205_master.xdc            # toàn bộ chân PL dùng được (đang comment)
│   ├── LICENSE-xjtuecho-EBAZ4205.txt  # giấy phép MIT của repo gốc
│   └── docs/                          # ảnh schematic làm bằng chứng
└── labs/
    ├── lab00_bringup/                 # log bring-up (README.md / README.vi.md)
    ├── lab01_blink/
    │   ├── docs/                      # spec.md / spec.vi.md, báo cáo lab (.docx EN + VI)
    │   ├── rtl/                       # Verilog-2001 tổng hợp được (bạn viết)
    │   ├── tb/                        # testbench tự kiểm tra
    │   ├── constraints/               # XDC của lab
    │   ├── scripts/                   # create_project.tcl, script build
    │   └── results/                   # báo cáo utilization / timing, ảnh
    ├── lab02_pwm_breathing/ … lab11_petalinux_uio/
    │   └── docs/spec.md, spec.vi.md
    └── …
```

## Danh sách lab

| Lab | Thư mục | Chủ đề | Khái niệm chính | Spec | Trạng thái |
|---|---|---|---|---|---|
| 00 | [`lab00_bringup`](labs/lab00_bringup/README.vi.md) | Bring-up board | JTAG chain, IDCODE, XADC, môi trường | — | ✅ xong |
| 01 | [`lab01_blink`](labs/lab01_blink/README.vi.md) | Nháy LED | Chia tần, reset khi bật nguồn, ngõ ra active-low | v1.0 | ✅ xong |
| 02 | [`lab02_pwm_breathing`](labs/lab02_pwm_breathing/README.vi.md) | LED "thở" | PWM, cập nhật duty không glitch, tái sử dụng module | v1.1 | ✅ xong |
| 03 | [`lab03_button`](labs/lab03_button/README.vi.md) | Nút nhấn ngoài | Synchronizer 2 FF, debounce, phát hiện cạnh | v1.1 | 🟡 xong mô phỏng + impl, chờ board |
| 04 | [`lab04_fsm_traffic`](labs/lab04_fsm_traffic/docs/spec.vi.md) | FSM đèn giao thông | FSM Moore, mã hoá trạng thái, bộ định thời | v1.0 | dự kiến |
| 05 | [`lab05_uart_tx`](labs/lab05_uart_tx/docs/spec.vi.md) | Bộ phát UART | Khung 8N1, chia baud, valid/ready | v1.0 | dự kiến |
| 06 | [`lab06_uart_rx`](labs/lab06_uart_rx/docs/spec.vi.md) | Bộ thu UART + echo | Lấy mẫu giữa bit, lỗi khung, overrun | v1.0 | dự kiến |
| 07 | [`lab07_fifo`](labs/lab07_fifo/docs/spec.vi.md) | Bộ đệm dòng FIFO | Con trỏ, suy ra BRAM, mô hình hàng đợi | v1.0 | dự kiến |
| 08 | [`lab08_ila`](labs/lab08_ila/docs/spec.vi.md) | Debug trên chip | ILA, trigger, capture control | v1.0 | dự kiến |
| 09 | [`lab09_zynq_ps`](labs/lab09_zynq_ps/docs/spec.vi.md) | Zynq PS + AXI GPIO | Block Design, `.xsa`, Vitis bare-metal | v0.9 nháp | dự kiến |
| 10 | [`lab10_axi_lite_ip`](labs/lab10_axi_lite_ip/docs/spec.vi.md) | IP AXI4-Lite tự thiết kế | Bản đồ thanh ghi, bắt tay AXI, đóng gói IP | v1.0 | dự kiến |
| 11 | [`lab11_petalinux_uio`](labs/lab11_petalinux_uio/docs/spec.vi.md) | PetaLinux + UIO | Quy trình boot, device tree, `mmap` | v0.9 nháp | dự kiến |

## Danh sách module

| Module | File | Lab | Vai trò |
|---|---|---|---|
| `blink_core` | `labs/lab01_blink/rtl/blink_core.v` | 01 | Chia tần và đảo trạng thái LED |
| `lab01_top` | `labs/lab01_blink/rtl/lab01_top.v` | 01 | Reset khi bật nguồn, cực tính LED, gán chân |
| `tb_blink_core` | `labs/lab01_blink/tb/tb_blink_core.v` | 01 | Testbench tự kiểm tra có golden model |
| `tb_lab01_top` | `labs/lab01_blink/tb/tb_lab01_top.v` | 01 | Testbench cấp top: độ dài reset khi bật nguồn, cực tính LED |
| `por_gen` | `labs/lab02_pwm_breathing/rtl/por_gen.v` | 02, 03 | Reset khi bật nguồn từ giá trị khởi tạo của thanh ghi |
| `pwm_core` | `labs/lab02_pwm_breathing/rtl/pwm_core.v` | 02 | PWM W bit, duty chốt vào thanh ghi shadow khi bộ đếm quay vòng |
| `breath_ctrl` | `labs/lab02_pwm_breathing/rtl/breath_ctrl.v` | 02 | Duty tăng giảm hình tam giác 0 → 255 → 0 |
| `lab02_top` | `labs/lab02_pwm_breathing/rtl/lab02_top.v` | 02 | Duty bù cho xanh / đỏ, ngõ ra active-low |
| `sync_2ff` | `labs/lab03_button/rtl/sync_2ff.v` | 03 | Synchronizer hai flip-flop có `ASYNC_REG` |
| `debounce` | `labs/lab03_button/rtl/debounce.v` | 03 | Chống dội bằng bộ đếm, nhận mức sau `STABLE_CYCLES` mẫu bằng nhau |
| `edge_detect` | `labs/lab03_button/rtl/edge_detect.v` | 03 | Xung rise / fall một chu kỳ có thanh ghi |
| `lab03_top` | `labs/lab03_button/rtl/lab03_top.v` | 03 | Nút nhấn → đảo LED xanh, LED đỏ sáng khi giữ nút |

Module của các lab sau được liệt kê trong spec của từng lab và sẽ thêm vào đây khi đã hiện thực.


## Bắt đầu

```bat
:: cmd của Windows, đứng tại labs\lab01_blink
:: Mô phỏng bằng Vivado xsim
xvlog tb\tb_blink_core.v rtl\blink_core.v
xelab tb_blink_core -s tb_sim
xsim tb_sim -R

:: Tạo project Vivado (tham chiếu file tại chỗ, project nằm trong build\)
vivado -mode batch -source scripts\create_project.tcl
```

```sh
# WSL / Linux, đứng tại labs/lab01_blink — Icarus (lặp lại với HALF_PERIOD = 2, 5, 16)
mkdir -p build
iverilog -g2001 -Wall -Ptb_blink_core.HALF_PERIOD=5 -o build/sim tb/tb_blink_core.v rtl/blink_core.v
vvp build/sim            # thêm +vcd để xuất dạng sóng, mở bằng gtkwave
```

## Quy trình mỗi lab

```
spec.md ──► testbench (fail) ──► RTL ──► mô phỏng PASS ──► synth / impl
   ──► đạt timing (WNS >= 0) ──► bitstream ──► chạy trên board ──► kết quả + commit
```

## Kết quả

Chỉ ghi kết quả lấy từ báo cáo thật của công cụ và từ lần chạy thật trên board.

| Lab | Mô phỏng | LUT / FF | WNS (ns) | Trên board |
|---|---|---|---|---|
| 01 | ✅ PASS (xsim + Icarus) | 36 / 31 | 16.378 | ✅ nháy 1 Hz |
| 02 | ✅ PASS (xsim + Icarus) | 67 / 70 | 16.218 | ✅ chu kỳ thở 2.02 s |
| 03 | ✅ PASS (xsim + Icarus) | 27 / 35 | 15.876 | ⏳ chờ (dây 2.0 mm) |

## Ghi nhận

Schematic và thông tin chân của board: [xjtuecho/EBAZ4205](https://github.com/xjtuecho/EBAZ4205) (giấy phép MIT).

## Tác giả

Phạm Minh Tùng — Thiết kế vi mạch bán dẫn, Đại học FPT, TP. Hồ Chí Minh

## Giấy phép

MIT — xem [LICENSE](LICENSE).
