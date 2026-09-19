# KrumpyOS documentation

Architecture notes, boot assumptions, linker layout, and hardware plans
belong here. Keep OS-specific decisions in this repository; language and
compiler decisions belong in the sibling K repository.

The current implementation has an experimental BIOS boot path for x86-64.
QEMU loads a fixed kernel payload, the boot code enters long mode, and the K
kernel initializes paging, the IDT, and an interactive COM1 recovery console.
See [interrupt-abi.md](./interrupt-abi.md) for the current exception contract.

Run `scripts/smoke-qemu.sh` (or `scripts\smoke-qemu.ps1` on Windows) for the
bounded boot smoke test. It sends commands through COM1 and verifies the
console banner, command list, echo response, memory report, and prompt.

## Architecture documents

- [Interrupt and exception ABI](./interrupt-abi.md): current x86-64 exception
  entry and register-frame contract.
- [Memory management and paging](./memory-and-paging.md): current early memory
  map and the planned progression to isolated address spaces.
- [Serial recovery console](./serial-console.md): current COM1 input, line
  editing, commands, and smoke-test contract.
- [System architecture](./system-architecture.md): scheduler, process/thread
  model, syscalls, permissions, IPC, `kinit`, services, and shutdown.
- [Userland and packages](./userland-and-packages.md): bundled K toolchain,
  shell/editor/manual tools, `kpkg`, Git-backed repositories, and trust model.
- [Installer architecture](./installer.md): bootable ISO, TUI installer,
  install profiles, root/user setup, and recovery.

## Dependency order

```text
verified paging and interrupts
-> serial console and timer
-> kernel threads and scheduler
-> user mode, syscalls, permissions, filesystem, executable loading
-> kinit PID 1 and supervised services
-> native K compiler and core K userland
-> networking, Git transport, and kpkg repositories
-> ISO/TUI installer and package-based system profiles
-> graphical desktop stack
```

Later features must use documented interfaces from the preceding layer rather
than bypassing them for a demo.
