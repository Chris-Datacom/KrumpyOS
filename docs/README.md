# KrumpyOS documentation

Architecture notes, boot assumptions, linker layout, and hardware plans
belong here. Keep OS-specific decisions in this repository; language and
compiler decisions belong in the sibling K repository.

The current implementation has an experimental BIOS boot path for x86-64:
QEMU loads a fixed kernel payload, the boot code enters long mode, prints the
startup banner, installs a minimal IDT, triggers `int3`, and writes the
kernel-provided exception report to COM1. See [interrupt-abi.md](./interrupt-abi.md)
for the current interrupt contract.

Run `scripts/smoke-qemu.sh` (or `scripts\smoke-qemu.ps1` on Windows) for the
bounded boot smoke test. It verifies the ABI by requiring the `Hello, World!`
startup banner followed by the deterministic `exception=3` COM1 report.
