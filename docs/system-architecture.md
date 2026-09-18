# KrumpyOS System Architecture

This document defines the intended boundary between kernel scheduling,
processes, permissions, and the user-space init system. It is a roadmap, not a
claim that these components are implemented.

## Boot and ownership boundaries

```text
bootloader
-> K kernel
   -> memory, interrupts, timer, scheduler, processes, syscalls, IPC, drivers
-> PID 1: /system/bin/kinit
   -> mounts, service supervision, login sessions, shutdown
-> ordinary user programs
   -> shell, compiler, editor, man, core tools, kpkg clients
```

The scheduler is kernel mechanism. `kinit` is user-space policy. Neither the K
compiler nor the package manager belongs in the kernel or PID 1.

## Processes and threads

A process owns:

- PID and parent relationship
- isolated virtual address space
- handle table and current working directory
- UID, primary GID, supplementary groups, and capabilities
- environment, arguments, children, and exit status

A thread owns:

- TID and containing process
- saved CPU context
- kernel stack and user stack
- scheduling state, time slice, and initial priority
- blocking reason and wake condition

The scheduler runs threads. A process may initially contain one thread, but
the structures and ABI must not make that permanent.

## Initial scheduler

The first scheduler is single-core, preemptive round-robin:

- one FIFO ready queue
- fixed time slices driven by a timer interrupt
- an idle thread that halts until work or an interrupt arrives
- explicit `yield`, sleep, block, and wake operations
- no real-time classes, CPU affinity, work stealing, or SMP initially

Thread states are `NEW`, `READY`, `RUNNING`, `BLOCKED`, `STOPPED`, and `DEAD`.
Run-queue and wake-up operations require kernel synchronization and narrowly
scoped preemption control. Interrupt disabling is not a general substitute for
preemption control.

## Process and syscall model

KrumpyOS begins with direct process spawning rather than Unix `fork`.

Initial process operations:

- `spawn`: load an executable into a new address space
- `exit`: terminate the calling process or thread
- `wait`: collect a child exit result
- `yield` and `sleep`
- file and directory operations
- terminal I/O
- handles, events, pipes/channels, and shared memory

Every syscall validates user pointers, lengths, handles, permissions, and
object state. Kernel failures are reported explicitly; user input must not
panic the kernel.

## Users, root, and capabilities

- UID 0 is root and begins with administrative authority.
- Regular interactive users receive UIDs at or above 1000.
- Services use dedicated system identities where practical.
- Files carry owner UID/GID and read/write/execute permissions.
- Processes carry credentials inherited and changed only through checked
  kernel operations.

Root should not be the normal interactive login. Administrative operations
should move toward narrow capabilities such as service management, mounting,
user management, package installation, raw-device access, network
administration, and reboot. Services receive only the capabilities and handles
they require.

## `kinit` and services

`kinit` is PID 1. It:

1. mounts required filesystems and prepares runtime directories
2. reads the selected boot target
3. starts services in dependency order
4. supervises long-running services with restart rate limits
5. reaps orphaned children
6. starts console login or a graphical session
7. coordinates shutdown in reverse dependency order

Service definitions are declarative rather than executable shell scripts.
Initial service kinds are `oneshot`, `service`, `mount`, and `target`.
Dependencies use explicit `requires` and ordering relationships.

Planned targets:

- `recovery.target`
- `minimal.target`
- `multi-user.target`
- `server.target`
- `graphical.target`

Installer profiles select a default target and package groups; they do not
create incompatible init implementations.

## Service control and shutdown

A user-space `kctl` client communicates with `kinit` over authenticated IPC to
inspect, start, stop, and restart services. Permission checks apply to every
management request.

Orderly shutdown is:

```text
authorized request
-> stop new sessions
-> stop services in reverse dependency order
-> sync and unmount filesystems
-> terminate remaining user processes
-> ask the kernel to power off or reboot
```

Unexpected PID 1 exit is fatal. During development the kernel enters a
diagnostic recovery path or panics; later policy may permit controlled reboot.

## Implementation order

1. verified paging, IDT, and serial diagnostics
2. timer interrupts and complete saved contexts
3. kernel threads, context switch, run queue, and idle thread
4. blocking, waking, synchronization, and scheduler stress tests
5. process objects, isolated address spaces, and ring 3
6. syscalls, handles, executable loading, `spawn`/`exit`/`wait`
7. filesystem, terminal, UID/GID permissions, and capabilities
8. initial filesystem and `kinit` PID 1
9. declarative services, targets, login, and orderly shutdown

