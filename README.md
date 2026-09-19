# KrumpyOS

KrumpyOS is an experimental operating system being developed alongside the
K programming language. K is the language and compiler project; KrumpyOS is
the freestanding system that will consume it and eventually host the
self-compiled K toolchain.

The repositories are intentionally separate so compiler and kernel changes can
be versioned independently. The long-term product is a self-hosting K system:
the kernel and system software are written primarily in K, while the K
compiler runs as an isolated user-space program alongside the shell, editor,
manual viewer, core utilities, and `kpkg`.

## Project status

KrumpyOS now has an experimental BIOS boot path. The first kernel payload is
compiled from K, loaded by `kernel/boot.s`, and linked into a raw disk image.
After entering x86-64 long mode the K kernel initializes COM1, installs a
minimal IDT, switches to its early page tables, and starts an interactive
serial recovery console. QEMU is the intended runner.

## Roadmap

The milestones are ordered by dependency. A later milestone should not be
considered complete if it only works through undocumented compiler behavior.

### Phase 0: Define the foundation

- [x] Choose the first supported machine and emulator target (x86-64 and
  QEMU).
- [x] Document the initial BIOS boot path, long-mode transition, stack
  contract, and K kernel entry.
- [ ] Define the first K language version and compatibility policy.
- [ ] Establish a cross-repository test strategy between K and KrumpyOS.

**Done when:** the boot contract and language version are written down and a
small example can be used as an integration fixture.

### Phase 1: Make K suitable for systems work

- [ ] Introduce fixed-width integer, byte, boolean, pointer, and `void` types
  (in progress).
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
The fixed-width type names are currently in the Rust frontend and IR layout;
exact-width backend operations are still open.

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
- [x] Run the image in QEMU in automated tests.
- [x] Document how to build, run, debug, and inspect the image.

**Done when:** QEMU boots the image and the kernel produces a deterministic
boot report from code compiled from K.

## Build and run

The current bootable target is x86-64. The build uses LLVM's native
cross-target tools, so it works from both ARM64 macOS and Windows without
WSL:

```sh
./scripts/build.sh
./scripts/run-qemu.sh
./scripts/smoke-qemu.sh
```

On Windows PowerShell, use:

```powershell
.\scripts\build.ps1
.\scripts\run-qemu.ps1
.\scripts\smoke-qemu.ps1
```

Install LLVM (`clang`, `ld.lld`, and `llvm-objcopy`) and QEMU natively on
each development machine. The same commands can be run from a terminal or
the VS Code integrated terminal. Stop QEMU with `Ctrl+C`.

On macOS with Homebrew:

```sh
brew install llvm lld qemu
export PATH="$(brew --prefix llvm)/bin:$(brew --prefix lld)/bin:$PATH"
```

Persist the `PATH` line in your shell profile. On Windows, install the LLVM
Windows package and QEMU, then ensure the directories containing `clang`,
`ld.lld`, `llvm-objcopy`, and `qemu-system-x86_64` are on `PATH`.

The ARM64 compiler backend and ARM64 boot path are not implemented yet; this
repository does not claim to boot natively on ARM hardware.

The image uses BIOS disk services, loads a fixed 64-sector kernel payload,
enters x86-64 long mode, initializes a minimal IDT and early paging, then
starts the `krumpy> ` console on COM1. The current boot path is
intentionally experimental. It has an early bump page allocator, replacement
identity page tables, and a minimal IDT, but no verified general memory
manager, filesystem, general interrupt handling, scheduler, user space, or
hardware abstraction layer yet.

The bounded smoke test runs QEMU without a display, sends `help`, `echo smoke`,
and `mem` over COM1, and verifies their output. QEMU is allowed to time out
while the console waits for more input; any other exit or missing serial output
is a failure.

Set `KRUMPYOS_TEST_DIVZERO=1` when building to retain the divide-by-zero test
path if the kernel entry unexpectedly returns. Normal builds remain in the
interactive console.

### Phase 4: Establish kernel foundations

- [ ] Add panic and assertion handling.
- [ ] Verify the early page-frame allocator and replacement page tables in
  QEMU.
- [ ] Add physical memory discovery and replace the bump allocator with a
  reclaimable frame allocator.
- [ ] Complete interrupt descriptor-table setup and exception reporting.
- [ ] Add a timer.
- [x] Add polling serial input.
- [x] Add an interactive serial recovery console.
- [ ] Add a minimal kernel logging interface.

**Done when:** the kernel can report faults, allocate memory, and continue
running without depending on firmware services or a host OS.

### Phase 5: Scheduling and kernel concurrency

- [ ] Introduce separate process and thread abstractions.
- [ ] Add a single-core preemptive round-robin scheduler.
- [ ] Add kernel stacks, context switching, an idle thread, and timer-driven
  time slices.
- [ ] Add blocking, waking, sleeping, yielding, and synchronization
  primitives.
- [ ] Validate scheduling with multiple kernel threads before adding user
  mode.

**Done when:** multiple kernel threads run, block, wake, and survive sustained
timer preemption without corrupting state.

### Phase 6: User space, permissions, and PID 1

- [ ] Define a system-call ABI.
- [ ] Add isolated address spaces, ring-3 execution, and an executable loader.
- [ ] Implement `spawn`, `exit`, `wait`, thread, handle, IPC, and terminal
  primitives without requiring Unix `fork`.
- [ ] Add UID/GID credentials, groups, file ownership and permissions, plus
  narrowly scoped capabilities for privileged operations.
- [ ] Add a filesystem and persistent storage driver.
- [ ] Start `kinit` as PID 1 to mount filesystems, supervise services, reap
  orphaned children, start login sessions, and coordinate shutdown.
- [ ] Add declarative service units and boot targets such as `minimal`,
  `multi-user`, `server`, and `graphical`.
- [ ] Add a normal user login path; reserve UID 0 for root and avoid requiring
  root for ordinary applications.

**Done when:** a user program can boot, run, perform basic I/O, and exit
through documented KrumpyOS interfaces, and PID 1 can supervise it.

See [system architecture](docs/system-architecture.md) for the scheduler,
process, permissions, and init contracts.

### Phase 7: Self-hosted K userland

- [ ] Add the KrumpyOS K runtime and standard library.
- [ ] Cross-compile and run the K compiler as an ordinary user-space program.
- [ ] Add a shell, terminal interface, Vim-inspired editor, `man`-style
  documentation viewer, and small GNU-inspired core utilities.
- [ ] Compile a K program inside KrumpyOS and execute the result.
- [ ] Rebuild the K compiler inside KrumpyOS and pass reproducibility gates.

The compiler belongs in developer and full installations. It is not part of
the kernel or `kinit`.

### Phase 8: Packages and network distribution

- [ ] Define the `kpkg` manifest, lockfile, artifact, repository-index, and
  installation database formats.
- [ ] Install signed/checksummed precompiled artifacts by default.
- [ ] Support explicit source installation from an exact Git tag or commit.
- [ ] Isolate package builds and install transactionally with rollback.
- [ ] Distinguish trusted core repositories from user-added repositories.
- [ ] Add networking, TLS, and Git/HTTP transport only after process,
  filesystem, and permission contracts are stable.

Your Git server will host optional source repositories, package indexes, and
release artifacts. Git transport does not imply trust; `kpkg` verifies the
configured repository identity and selected artifact or source revision.

See [userland and packages](docs/userland-and-packages.md).

### Phase 9: Installable releases

- [ ] Produce a bootable ISO containing a live/recovery environment.
- [ ] Add a TUI installer with guided and manual storage configuration.
- [ ] Install the bootloader, base system, users, default boot target, and
  selected package profile transactionally.
- [ ] Provide `minimal`, `server`, `developer`, and `full`/`desktop` profiles
  as package groups rather than separate operating-system forks.
- [ ] Default to a normal administrative user and require an explicit policy
  choice for direct root login.
- [ ] Add recovery, installation verification, and interrupted-install
  handling.

See [installer architecture](docs/installer.md).

## Development principles

- Keep the K language small, explicit, and easy to bootstrap.
- Prefer specified behavior over accidental behavior inherited from the host.
- Keep unsafe operations visible and testable.
- Make every boot milestone reproducible in QEMU before targeting hardware.
- Treat compiler, ABI, linker, and kernel changes as one integration surface.
- Keep scheduling in the kernel and service policy in the user-space `kinit`
  process.
- Treat downloaded packages and build scripts as untrusted.
- Build installation profiles from versioned package groups instead of
  maintaining divergent editions.
- Do not call a feature stable until it is documented and covered by tests.

## Related project

The K language and compiler are maintained in a separate repository. Keep
compiler and kernel changes coordinated through the target contract and
cross-repository integration tests described above.
