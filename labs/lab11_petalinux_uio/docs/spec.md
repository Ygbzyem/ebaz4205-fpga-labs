# Lab 11 — PetaLinux and a UIO Driver: Specification (v0.9 draft)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Goal

Boot Linux on the EBAZ4205 from an SD card and control the Lab 10 `axi_led_pwm` IP from a user-space program through the UIO framework. Concepts: Linux boot flow on Zynq, device tree, `generic-uio`, `mmap` of device registers, keeping software in step with the hardware design.

## 2. Boot Flow

```
BootROM → FSBL → bitstream (PL) → U-Boot → Linux kernel + device tree → rootfs → /usr/bin/pwm_ctl
```

## 3. Tools and Inputs

| Item | Value | Status |
|---|---|---|
| PetaLinux | 2020.2 (must match Vivado 2020.2) | required |
| Build host | Linux; supported host OS for 2020.2 to be checked (VM or container if Ubuntu 26.04 is not supported) | ⏳ |
| Hardware handoff | `.xsa` from Lab 10 (includes bitstream) | — |
| Boot media | SD card, FAT32 boot partition + ext4 rootfs | — |
| Board boot mode | SD (resistor already moved on this board) | ✅ |
| Console | PS UART J7, 115200 8N1 | — |

## 4. Device Tree

Node added in `project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi`:

| Property | Value |
|---|---|
| Target | the `axi_led_pwm` node generated from the `.xsa` |
| `compatible` | `"generic-uio"` |
| Kernel bootargs | add `uio_pdrv_genirq.of_id=generic-uio` |

Expected result: `/dev/uio0` exists and `/sys/class/uio/uio0/maps/map0/addr` equals the base address from the Lab 10 Address Editor.

## 5. User-space Program `pwm_ctl`

| Command | Action |
|---|---|
| `pwm_ctl breathe` | `CTRL = 0x3` (`EN` + `MODE`) |
| `pwm_ctl set <g> <r>` | Manual mode, `DUTY_G = g`, `DUTY_R = r` (0–255) |
| `pwm_ctl off` | `CTRL = 0` |
| `pwm_ctl status` | Print `CTRL`, `DUTY_G`, `DUTY_R`, `STATUS` |

Implementation: open `/dev/uio0`, `mmap` 4 KB, access registers with `volatile uint32_t *` at the Lab 10 offsets. Input values are range-checked.

## 6. Verification Plan

| ID | Check | Pass criterion |
|---|---|---|
| L1 | Boot log on J7 | Reaches the login prompt; boot log saved |
| L2 | UIO device | `/dev/uio0` present, map address and size correct |
| L3 | `pwm_ctl status` after boot | Register reset values (all 0) |
| L4 | `pwm_ctl set 255 0`, `set 0 255`, `breathe`, `off` | LEDs behave as in Lab 10 |
| L5 | Out-of-range argument | Rejected with an error message, no register write |

## 7. Deliverables

- [ ] PetaLinux project config changes (`system-user.dtsi`, `project-spec` diffs) and `pwm_ctl.c` (user)
- [ ] Boot images kept out of Git (published in a Release)
- [ ] Boot log, boot time, image sizes, photo; lab README with the boot flow
