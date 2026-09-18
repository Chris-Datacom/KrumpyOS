# Memory Management and Paging in KrumpyOS

## Memory Map

During early boot, the physical address space is laid out as follows:

| Physical Address | Size | Usage |
|---|---|---|
| `0x00000 - 0x07BFF` | ~31 KB | Real mode IVT, BIOS data area, stack |
| `0x07C00 - 0x07DFF` | 512 B | BIOS boot sector |
| `0x09000 - 0x0BFFF` | 12 KB | Initial boot page tables (PML4, PDPT, PD) |
| `0x10000 - 0x17FFF` | 32 KB | Kernel code/data image (loaded by bootloader) |
| `0x80000` | - | Initial boot stack pointer (`RSP`) |
| `0x81000 - 0x81FFF` | 4 KB | Interrupt Descriptor Table (IDT, 256 gates) |
| `0x100000` (1 MB) | - | Start of dynamic physical memory heap / frames |

## Physical Page Frame Allocator

The frame allocator provides 4096-byte aligned physical pages.
Dynamic physical allocations start at 1 MB (`0x100000`), leaving lower memory reserved for the kernel binary, IDT, and boot structures.

The current allocator is an early bump allocator. It does not discover the
machine memory map, reclaim frames, detect exhaustion, or enforce ownership.
It must be verified under QEMU before later subsystems depend on it, then
replaced by a frame allocator driven by boot-time physical-memory discovery.

## 4-Level Paging Architecture

x86-64 uses 4 levels of translation tables:
1. **PML4** (Page Map Level 4) - points to PDPT
2. **PDPT** (Page Directory Pointer Table) - points to PD
3. **PD** (Page Directory) - points to PT (or 2MB pages)
4. **PT** (Page Table) - maps 4KB physical frames

Flags:
- `Present (bit 0)`: Entry is valid
- `Read/Write (bit 1)`: Page is writable
- `User/Supervisor (bit 2)`: User privilege allowed if set

## Planned virtual-memory model

- Kernel mappings are supervisor-only and shared according to a documented
  kernel layout.
- Each user process owns an isolated address space.
- User code, data, stack, shared memory, and mapped files receive explicit
  read/write/execute permissions.
- The kernel validates every user pointer crossing the syscall boundary.
- Context switching changes the active address space when processes differ.
- Package builds and the native K compiler run in user address spaces; they do
  not receive direct access to page tables or physical memory.

Page-frame ownership, mapping ownership, copy/unmap behavior, and out-of-memory
handling must be explicit before user processes or the package manager are
considered reliable.
