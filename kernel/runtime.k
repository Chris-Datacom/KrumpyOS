// Low-level K runtime extracted from the kernel bootstrap path.
//
// This is intentionally small and conservative. The goal is to keep the
// freestanding boot ABI in K while the compiler and kernel runtime mature. The
// full runtime can be ported in later stages without destabilizing the current
// working boot path.

extern void outb(u16 port, u8 value);
extern u8 inb(u16 port);
extern void pause();

void runtime_io_wait() {
    outb((u16)128, (u8)0);
}

void runtime_setup_serial() {
    outb((u16)1017, (u8)0);
    outb((u16)1019, (u8)128);
    outb((u16)1016, (u8)1);
    outb((u16)1017, (u8)0);
    outb((u16)1019, (u8)3);
    outb((u16)1018, (u8)199);
    outb((u16)1020, (u8)11);
}

void runtime_serial_write_char(u8 c) {
    while ((inb((u16)1021) & (u8)32) == (u8)0) {
    }
    outb((u16)1016, c);
}

void runtime_serial_write_str(char* str) {
    let i = 0;
    while (str[i] != (char)0) {
        runtime_serial_write_char((u8)str[i]);
        i = i + 1;
    }
}

void runtime_vga_clear() {
    let vga = (u16*)753664;
    let i = 0;
    while (i < 2000) {
        vga[i] = (u16)32 | ((u16)7 << (u16)8);
        i = i + 1;
    }
}

void runtime_vga_write_char(u8 c) {
    let vga = (u16*)753664;
    let pos = (u64)0;
    let i = 0;
    while (i < 2000) {
        if (vga[i] == (u16)32) {
            pos = (u64)i;
            i = 2000;
        }
        i = i + 1;
    }
    if (pos < (u64)2000) {
        vga[pos] = (u16)c | ((u16)7 << (u16)8);
    }
}

void runtime_vga_init() {
    runtime_vga_clear();
    outb((u16)980, (u8)10);
    outb((u16)981, (u8)14);
    outb((u16)980, (u8)11);
    outb((u16)981, (u8)15);
}
