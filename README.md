# KrumpyOS

KrumpyOS is the operating-system project that will be developed alongside
the K language.

## Repository relationship

- `K` is the language and compiler repository.
- `KrumpyOS` is the OS repository that consumes K.
- K must provide the freestanding target features needed by KrumpyOS.

The repositories are intentionally separate so compiler changes and kernel
changes can be versioned and released independently.

## Initial plan

1. Define the x86-64 boot contract.
2. Add a freestanding K target profile.
3. Build a boot entry point and linker layout.
4. Add serial or framebuffer output.
5. Compile the first kernel subsystem with K.
