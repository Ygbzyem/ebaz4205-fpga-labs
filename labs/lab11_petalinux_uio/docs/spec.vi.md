# Lab 11 — PetaLinux và driver UIO: Đặc tả (v0.9 bản nháp)

[English](spec.md) | [Tiếng Việt](spec.vi.md)

## 1. Mục tiêu

Boot Linux trên EBAZ4205 từ thẻ SD và điều khiển IP `axi_led_pwm` của Lab 10 từ một chương trình user-space thông qua framework UIO. Khái niệm: quy trình boot Linux trên Zynq, device tree, `generic-uio`, `mmap` thanh ghi thiết bị, giữ phần mềm luôn khớp với thiết kế phần cứng.

## 2. Quy trình boot

```
BootROM → FSBL → bitstream (PL) → U-Boot → Linux kernel + device tree → rootfs → /usr/bin/pwm_ctl
```

## 3. Công cụ và đầu vào

| Mục | Giá trị | Trạng thái |
|---|---|---|
| PetaLinux | 2020.2 (phải trùng với Vivado 2020.2) | bắt buộc |
| Máy build | Linux; cần kiểm tra hệ điều hành được hỗ trợ cho bản 2020.2 (dùng máy ảo hoặc container nếu Ubuntu 26.04 không được hỗ trợ) | ⏳ |
| Chuyển giao phần cứng | File `.xsa` từ Lab 10 (có kèm bitstream) | — |
| Phương tiện boot | Thẻ SD, phân vùng boot FAT32 + rootfs ext4 | — |
| Chế độ boot của board | SD (board này đã chuyển điện trở) | ✅ |
| Console | UART của PS ở J7, 115200 8N1 | — |

## 4. Device tree

Thêm node vào `project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi`:

| Thuộc tính | Giá trị |
|---|---|
| Đối tượng | node `axi_led_pwm` sinh ra từ file `.xsa` |
| `compatible` | `"generic-uio"` |
| Bootargs của kernel | thêm `uio_pdrv_genirq.of_id=generic-uio` |

Kết quả mong đợi: có `/dev/uio0`, và `/sys/class/uio/uio0/maps/map0/addr` bằng địa chỉ gốc trong Address Editor của Lab 10.

## 5. Chương trình user-space `pwm_ctl`

| Lệnh | Tác dụng |
|---|---|
| `pwm_ctl breathe` | `CTRL = 0x3` (`EN` + `MODE`) |
| `pwm_ctl set <g> <r>` | Chế độ chỉnh tay, `DUTY_G = g`, `DUTY_R = r` (0–255) |
| `pwm_ctl off` | `CTRL = 0` |
| `pwm_ctl status` | In `CTRL`, `DUTY_G`, `DUTY_R`, `STATUS` |

Hiện thực: mở `/dev/uio0`, `mmap` 4 KB, truy cập thanh ghi bằng `volatile uint32_t *` theo offset của Lab 10. Giá trị đầu vào được kiểm tra phạm vi.

## 6. Kế hoạch kiểm tra

| ID | Kiểm tra | Tiêu chí đạt |
|---|---|---|
| L1 | Log boot trên J7 | Lên tới dấu nhắc đăng nhập; đã lưu log boot |
| L2 | Thiết bị UIO | Có `/dev/uio0`, địa chỉ và kích thước map đúng |
| L3 | `pwm_ctl status` sau khi boot | Giá trị reset của thanh ghi (tất cả bằng 0) |
| L4 | `pwm_ctl set 255 0`, `set 0 255`, `breathe`, `off` | LED hoạt động như ở Lab 10 |
| L5 | Tham số ngoài phạm vi | Bị từ chối kèm thông báo lỗi, không ghi thanh ghi |

## 7. Sản phẩm cần nộp

- [ ] Các thay đổi cấu hình project PetaLinux (`system-user.dtsi`, diff của `project-spec`) và `pwm_ctl.c` (bạn)
- [ ] Ảnh boot không đưa vào Git (đăng ở Release)
- [ ] Log boot, thời gian boot, kích thước image, ảnh; README của lab kèm quy trình boot (Claude)
