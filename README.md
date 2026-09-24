# KrumpyOS

KrumpyOS is a freestanding operating system being developed alongside the K
programming language. The two repositories are intentionally separate: K is the
language/compiler project, while KrumpyOS is the target system that consumes it
and eventually hosts its own self-compiled toolchain.

The current project goal is deliberately narrow and practical:

- keep the x86-64 QEMU boot path stable
- keep the low-level kernel ABI in K
- use Rust only as the trusted bootstrap compiler while the K subset matures
- move more runtime code into K before attempting deeper self-hosting work

## Current status

KrumpyOS is in a verified bootable state for the x86-64 BIOS/QEMU path:

- the kernel builds from K
- the boot image is generated from the raw disk layout
- the system reaches the serial console and accepts interactive commands
- the smoke test passes in QEMU

The current active target is x86-64 QEMU. The project is not claiming a full
ARM or Mac hardware boot path yet.

## What we are doing now

The next milestone is not a broad rewrite of the whole OS. The next milestone is
focusing the remaining work on the K-first runtime path:

- port the remaining early kernel runtime pieces to K
- keep the firmware/boot boundary in K without reintroducing a temporary C shim
- validate each low-level ABI feature against the actual K compiler subset
- push userland bootstrap and runtime helpers toward K
- only then move to self-hosting milestones

This keeps the project honest: no speculative full-OS rewrite, only the next
necessary layer of the system.

## Active milestones

### Completed

- [x] x86-64 QEMU target defined and validated
- [x] BIOS boot path and long-mode transition working
- [x] serial console and early kernel logging working
- [x] IDT + timer + paging initialization working
- [x] interactive console booted under QEMU
- [x] temporary C EFI shim removed in favor of K stub code

### In progress

- [ ] port remaining early kernel runtime to K
- [ ] move userland bootstrap and runtime helpers to K
- [ ] simplify the kernel/runtime docs to match the active target only
- [ ] validate the next K runtime layer with the real compiler and boot tests

### Future

- [ ] self-hosting K toolchain
- [ ] richer userland and service model
- [ ] broader KrumpyOS runtime features after the boot path is stable

## Build and run

```sh
./scripts/build.sh
./scripts/run-qemu.sh
./scripts/smoke-qemu.sh
```

On macOS with Homebrew:

```sh
brew install llvm lld qemu
export PATH="$(brew --prefix llvm)/bin:$(brew --prefix lld)/bin:$PATH"
```

The smoke test is the project’s current validation target. It boots the image in
QEMU, sends a few commands over the serial console, and verifies that the kernel
produces the expected banner and prompt.

## Current engineering rule

Keep all low-level boot and ABI work in K when the compiler supports it.
Keep Rust only where the language is still too limited for the current target.
Do not reintroduce host-side C shims unless they are explicitly temporary and
clearly labeled as such.

## Documentation policy

This repository is intentionally trimmed to the active reality of the project:

- active boot target: x86-64 QEMU
- active language direction: K-first low-level runtime
- active compiler path: Rust bootstrap + K runtime compilation
- stale hardware-specific or historical notes are removed unless they still map
  to a real target being actively developed

See [docs/README.md](docs/README.md) for the current technical reference set.
