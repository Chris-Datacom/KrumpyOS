# KrumpyOS

KrumpyOS is an experimental operating system being developed alongside the
K programming language. K is the language and compiler project; KrumpyOS is
the freestanding system that will consume it.

The repositories are intentionally separate so compiler and kernel changes can
be versioned independently. K must provide the language, compiler, and target
support required by the kernel before KrumpyOS can become bootable.

## Project status

KrumpyOS now has an experimental BIOS boot path. The first kernel payload is
compiled from K, loaded by `kernel/boot.s`, and linked into a raw disk image.
After entering x86-64 long mode it returns a K string to the boot entry, which
writes the message to COM1. QEMU is the intended runner.

## Roadmap

The milestones are ordered by dependency. A later milestone should not be
considered complete if it only works through undocumented compiler behavior.

### Phase 0: Define the foundation

- [ ] Choose the first supported machine and emulator target (x86-64 and
  QEMU are the initial candidates).
- [ ] Document the boot protocol, execution mode, stack contract, memory map,
  and kernel entry signature.
- [ ] Define the first K language version and compatibility policy.
- [ ] Establish a cross-repository test strategy between K and KrumpyOS.

**Done when:** the boot contract and language version are written down and a
small example can be used as an integration fixture.

### Phase 1: Make K suitable for systems work

- [ ] Specify fixed-width integer, byte, boolean, pointer, and `void` types.
- [ ] Specify integer overflow, alignment, layout, pointer, and undefined
  behavior rules.
- [ ] Complete aggregate types and predictable struct layout.
- [ ] Add explicit casts and conversions where the machine representation
  requires them.
- [ ] Add modules or a reproducible multi-file compilation model.
- [ ] Define the unsafe boundary for raw memory and hardware access.
- [ ] Keep lexer, parser, semantic-analysis, IR, and code-generation tests
  beside each language feature.

**Done when:** a versioned K program can express data structures and helper
functions without relying on prototype-only syntax or host-runtime behavior.

### Phase 2: Add a freestanding K target

- [ ] Add a freestanding target profile separate from the Linux/System V
  bootstrap target.
- [ ] Define the target calling convention, object format, relocation rules,
  and symbol visibility.
- [ ] Add volatile reads and writes for memory-mapped devices.
- [ ] Add compiler support for `no_std`-style builds with no libc, allocator,
  garbage collector, or hidden runtime.
- [ ] Produce object files or a well-defined assembly artifact suitable for
  linking.
- [ ] Add reproducible cross-compilation and binary inspection checks.

**Done when:** K can compile a freestanding program that links without libc
or a host operating-system syscall interface.

### Phase 3: Boot the first KrumpyOS kernel

- [x] Add a boot entry point and linker script.
- [x] Initialize a known stack and transfer control to a K kernel entry point.
- [x] Build a bootable image from a clean checkout.
- [x] Add serial output before adding a graphical console.
- [ ] Run the image in QEMU in automated tests.
- [x] Document how to build, run, debug, and inspect the image.

**Done when:** QEMU boots the image and the kernel prints a deterministic
startup message produced by code compiled from K.

## Build and run

From PowerShell:

```powershell
.\scripts\build.ps1
.\scripts\run-qemu.ps1
```

The image uses BIOS disk services, loads a fixed 64-sector kernel payload,
enters x86-64 long mode, and emits `Hello, World!` on COM1. The current boot
path is intentionally experimental and has no filesystem, interrupts, memory
management, or hardware abstraction layer yet.

### Phase 4: Establish kernel foundations

- [ ] Add panic and assertion handling.
- [ ] Add physical memory discovery and a page-frame allocator.
- [ ] Add page tables and a kernel virtual-memory layout.
- [ ] Add interrupt descriptor-table setup and exception reporting.
- [ ] Add a timer and a basic serial or keyboard driver.
- [ ] Add a minimal kernel logging interface.

**Done when:** the kernel can report faults, allocate memory, and continue
running without depending on firmware services or a host OS.

### Phase 5: Grow into an operating system

- [ ] Add a scheduler and process or task model.
- [ ] Define a system-call ABI.
- [ ] Add user-mode execution and executable loading.
- [ ] Add a filesystem and persistent storage driver.
- [ ] Add a command shell and core user programs.
- [ ] Add networking only after the memory, interrupt, and process contracts
  are stable.

**Done when:** a user program can boot, run, perform basic I/O, and exit
through documented KrumpyOS interfaces.

## Development principles

- Keep the K language small, explicit, and easy to bootstrap.
- Prefer specified behavior over accidental behavior inherited from the host.
- Keep unsafe operations visible and testable.
- Make every boot milestone reproducible in QEMU before targeting hardware.
- Treat compiler, ABI, linker, and kernel changes as one integration surface.
- Do not call a feature stable until it is documented and covered by tests.

## Related project

The K language and compiler are maintained in a separate repository. Keep
compiler and kernel changes coordinated through the target contract and
cross-repository integration tests described above.
