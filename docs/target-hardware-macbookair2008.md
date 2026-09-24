# Target Hardware: 2008 MacBook Air (MacBookAir1,1 / MacBookAir2,1)

This document details the hardware profile, boot path, and driver requirements
for booting KrumpyOS on the 2008 base model MacBook Air off a USB flash drive.

## Hardware Specifications

- **CPU**: Intel Core 2 Duo (Merom P7500 @ 1.6 GHz or Penryn SL9400 @ 1.86 GHz), x86-64
- **RAM**: 2 GB DDR2 SDRAM (soldered)
- **GPU / Display**:
  - MacBookAir1,1: Intel GMA X3100
  - MacBookAir2,1: NVIDIA GeForce 9400M
  - Built-in 13.3-inch TFT LCD (1280x800 native resolution)
- **Storage**: 80 GB PATA/ZIF hard drive or 64 GB PATA SSD (booting primarily from USB 2.0)
- **Input**: Built-in Apple keyboard and trackpad (i8042 PS/2 controller emulation in CSM mode)
- **Firmware**: Apple EFI with CSM (Compatibility Support Module / Legacy BIOS emulation)

## Boot Path (< 3 Seconds Target)

KrumpyOS is engineered as a lean freestanding binary (< 64 KB total disk payload).
The entire boot pipeline executes in **under 200 milliseconds** on the 1.6 GHz Core 2 Duo:

1. **Option Key Selection**:
   - Power on the MacBook Air while holding the `Option` (Alt) key.
   - Select the external USB drive (displayed with the yellow external disk icon labeled "Windows" or "EFI Boot").
2. **Apple CSM Initialization**:
   - Firmware starts in 16-bit real mode, points `%dl` to the boot drive ID, and activates the VGA text buffer (`0xB8000`).
3. **Stage 1 Bootloader (`boot.s`)**:
   - Enables the Fast A20 gate via port `0x92`.
   - Reads 64 sectors (32 KB kernel payload) using BIOS INT 13h Extensions (AH=42h LBA packet).
   - Switches to 32-bit protected mode and sets up early identity page tables.
   - Enables Long Mode (IA-32e) and jumps to 64-bit `kernel_main`.
4. **Kernel Initialization (`kernel.k`)**:
   - Initializes COM1 serial UART (`0x3F8`) and VGA text buffer (`0xB8000`).
   - Remaps 8259 PIC and configures 8254 PIT channel 0 timer to 100 Hz.
   - Activates bitmapped Physical Memory Manager (PMM) and two-level page tables.
   - Spawns PID 1 (`kinit`), enables CPU interrupts (`sti`), and renders the `fastfetch` system banner.
   - Reaches the `user@krumpyos>` interactive prompt.

## Dual-Console Subsystem

Because the MacBook Air has no physical RS-232 serial port, KrumpyOS provides simultaneous dual-console output:
- **Display Output**: Dual-writes characters to both COM1 UART (`outb 0x3F8`) and the VGA text buffer at physical address `0xB8000` (80x25 character grid with hardware cursor and ANSI escape color decoding).
- **Keyboard Input**: Dual-polls both COM1 status (`inb 0x3FD`) and the i8042 PS/2 keyboard controller (`inb 0x64` / `inb 0x60`), translating Set 1 scan codes (with Shift state tracking) into ASCII characters.

## Flashing the USB Drive

To create the bootable USB on macOS or Linux:

```sh
# 1. Build the raw disk image
./scripts/build.sh

# 2. Write raw image to USB drive (replace /dev/sdX or /dev/rdiskN with your USB drive)
sudo dd if=target/krumpyos.img of=/dev/rdiskN bs=1m status=progress
```
