# Serial Recovery Console

KrumpyOS currently provides an interactive polling console over COM1. It is
the first recovery and diagnostics interface and is intended for QEMU
development before USB keyboard and framebuffer console drivers exist.

## Running

Build and start the image:

```sh
./scripts/build.sh
./scripts/run-qemu.sh
```

The prompt is:

```text
krumpy>
```

Input is echoed. Enter submits a line, Backspace and Delete remove one
character, and lines are limited to 127 bytes. The early line buffer occupies
the reserved page beginning at physical address `0x82000`.

## Commands

- `help`: list commands
- `echo TEXT`: print `TEXT`
- `mem`: display physical memory statistics (total, used, free KB and pages) and frame allocator bitmap state
- `ps`: list active kernel threads, their execution states (READY, RUNNING, BLOCKED, DEAD), and total CPU ticks run
- `yield`: cooperatively yield the current thread's time slice to the scheduler
- `uptime`: display system uptime in seconds and monotonic timer ticks
- `panic`: trigger a test kernel panic with register and stack dump
- `clear`: emit ANSI terminal clear/home sequences
- `reboot`: request reset through the legacy keyboard controller
- `halt`: disable interrupts and halt the CPU

This is a kernel recovery console, not the eventual user-space shell. Command
execution is synchronous and serial input is polled. Interrupt-driven input,
terminal abstraction, login sessions, permissions, and the user-space shell
arrive after the timer, scheduler, process, and syscall milestones.

## Automated smoke test

`scripts/smoke-qemu.sh` and `scripts/smoke-qemu.ps1` feed `help`,
`echo smoke`, and `mem` to QEMU through COM1. The test requires the banner,
command list, echoed text, memory status, and a subsequent prompt.
