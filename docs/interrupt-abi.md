# Interrupt and exception ABI

KrumpyOS currently brings up a small x86-64 exception path for vectors 0 and 3.
The ABI stays intentionally small and deterministic while the kernel is still
bootstrapping.

## Bootstrap contract

- The BIOS boot sector in `kernel/boot.s` loads the raw kernel payload at
  physical address `0x10000`.
- After enabling x86-64 long mode, the bootstrap sets `RSP = 0x80000` and
  calls the K entry at `0x10000`.
- `kernel_message(void)` on the K side programs COM1 and returns a pointer to
  the startup message, which the bootstrap prints before entering the interrupt
  ABI.
- The bootstrap installs the IDT and executes either `int3` (default) or a
  deliberate divide-by-zero path when `KRUMPYOS_TEST_DIVZERO=1` is set.

## IDT layout

- The boot path builds a 256-entry IDT in RAM at `0x81000`.
- Vector 0 (divide by zero) and vector 3 (breakpoint) are each installed as a
  64-bit interrupt gate with selector `0x18`, IST `0`, and the present bit set.
- All other entries remain zero for now.

## Exception stub ABI

The reusable `exception_common` entry normalizes both CPU and synthetic frames.
For exceptions without a hardware error code, the stub pushes a synthetic error
code `0` before the vector number so the frame matches the same layout as a
trapped fault with a hardware error code.

At `exception_common`, the stack layout is:

1. vector number
2. error code
3. interrupted RIP
4. interrupted CS
5. interrupted RFLAGS

The handler receives the vector in `RDI` and the normalized error code in `RSI`.
Recoverable handlers return with `iretq` so the interrupted context resumes.
The serial diagnostics printed by the first two handlers are deterministic and
use the literal strings `exception=0` and `exception=3`.
