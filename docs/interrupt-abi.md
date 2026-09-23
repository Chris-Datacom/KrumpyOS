# Interrupt and exception ABI

KrumpyOS brings up an x86-64 exception and interrupt path for CPU faults and hardware IRQs.
The ABI stays intentionally small and deterministic while the kernel is bootstrapping.

## Bootstrap contract

- The BIOS boot sector in `kernel/boot.s` loads the raw kernel payload at
  physical address `0x10000`.
- After enabling x86-64 long mode, the bootstrap sets `RSP = 0x80000` and
  calls the K entry at `0x10000`.
- `kernel_main(void)` on the K side programs COM1, installs the IDT, remaps
  the 8259 PIC (master to vector 32, slave to vector 40), initializes the
  8254 PIT timer to 100 Hz, activates the early kernel page tables, enables
  interrupts with `sti()`, and enters the serial recovery console.
- A build with `KRUMPYOS_TEST_DIVZERO=1` retains the deliberate divide-by-zero
  path if the kernel entry unexpectedly returns. Normal interactive builds do
  not deliberately trigger an exception.

## IDT layout

- The boot path builds a 256-entry IDT in RAM at `0x81000`.
- Vector 0 (divide by zero), vector 3 (breakpoint), and vector 13 (general protection fault)
  are installed as 64-bit interrupt gates with selector `0x18`, IST `0`, and the present bit set.
- Vector 32 (IRQ 0 - PIT timer) is installed as a 64-bit interrupt gate pointing to `timer_stub`.
- Other entries remain zero or are installed dynamically via `set_idt_gate`.

## 8259 PIC and 8254 PIT Configuration

- **8259 PIC**: Master (ports `0x20`/`0x21`) is remapped to vectors 32–39; Slave (ports `0xA0`/`0xA1`)
  is remapped to vectors 40–47. IRQ 0 (timer) is unmasked on the master PIC.
- **8254 PIT**: Configured in mode 3 (square wave) on Channel 0 (port `0x40`/`0x43`) with divisor
  11931 for a periodic 100 Hz timer interrupt (10 ms per tick).
- **EOI Protocol**: `pic_send_eoi(irq)` sends `0x20` to master port `0x20` (and slave port `0xA0` if `irq >= 8`).

## Exception and Interrupt Stub ABI

The reusable `exception_common` and `interrupt_common` entries normalize both CPU and synthetic frames:

At dispatch, the stack layout is:

1. vector number (at `120(%rsp)`)
2. error code (at `128(%rsp)`)
3. interrupted RIP
4. interrupted CS
5. interrupted RFLAGS

`exception_common` and `interrupt_common` preserve all general-purpose registers
(`RAX`, `RCX`, `RDX`, `RBX`, `RBP`, `RSI`, `RDI`, `R8`–`R15`) on the stack, clear the direction flag
(`cld`), and ensure 16-byte stack alignment before calling `k_exception_dispatch` or `k_interrupt_dispatch`.

- Exceptions: received by `k_exception_dispatch(vector, error_code, frame)`.
- Interrupts: received by `k_interrupt_dispatch(vector, error_code, frame)`. Vector 32 increments the system
  monotonic tick counter at `0x83008` and acknowledges the PIC with `pic_send_eoi(0)`.

Handlers return with `iretq` after restoring all saved registers so the interrupted execution context resumes seamlessly.

## Scheduler evolution

Timer preemption builds directly on this interrupt path:

1. saves the complete interrupted thread context
2. acknowledges the timer source and increments ticks
3. updates monotonic time and the current time slice
4. checks thread time slice expiration and triggers preemption at safe boundaries
5. restores the next scheduled thread context and returns with `iretq`
