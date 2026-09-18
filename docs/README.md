# KrumpyOS documentation

Architecture notes, boot assumptions, linker layout, and hardware plans
belong here. Keep OS-specific decisions in this repository; language and
compiler decisions belong in the sibling K repository.

The current implementation has an experimental BIOS boot path for x86-64:
QEMU loads a fixed kernel payload, the boot code enters long mode, and a K
kernel entry returns a string that is written to COM1. The next OS work is to
replace fixed-size assumptions with a documented boot contract and automated
cross-repository build checks.
