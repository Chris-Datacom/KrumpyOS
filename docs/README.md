# KrumpyOS documentation

This directory keeps the active technical reference set for the current project
state. The documentation intentionally reflects the verified x86-64 QEMU path and
not a broader collection of historical or speculative hardware targets.

## Current truth

The working project baseline is:

- x86-64 BIOS boot path
- K-compiled kernel payload
- early paging and IDT setup
- serial console and simple interrupt/timer flow
- QEMU smoke validation as the acceptance test

Everything else remains a later milestone until the K runtime can support it
without hidden compiler assumptions.

## Active documentation

- [interrupt-abi.md](./interrupt-abi.md): interrupt and exception flow for the
  current x86-64 target.
- [memory-and-paging.md](./memory-and-paging.md): early memory map, paging, and
  allocator assumptions.
- [serial-console.md](./serial-console.md): COM1 console behavior and the current
  smoke-test contract.
- [system-architecture.md](./system-architecture.md): process/thread model,
  scheduler, system-call shape, and runtime architecture.
- [userland-and-packages.md](./userland-and-packages.md): userland bootstrap,
  package model, and runtime expectations.
- [installer.md](./installer.md): installer-related design notes for later
  system image work.

## Working order

The project should proceed in this order:

1. stable boot and early kernel ABI
2. K runtime parity and boot-layer portability
3. userland bootstrap and service startup
4. self-hosting K toolchain work
5. broader OS features after the baseline is stable

Later features must depend on earlier verified interfaces instead of bypassing
core layers for a demo.

## Validation

Use the project scripts as the canonical validation route:

```sh
./scripts/build.sh
./scripts/run-qemu.sh
./scripts/smoke-qemu.sh
```

The smoke test is the active acceptance check for the current boot path.
