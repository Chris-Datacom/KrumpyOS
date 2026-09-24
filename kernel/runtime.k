// Staged K runtime extracted from the kernel bootstrap path.
//
// This file intentionally keeps the helper names prefixed with `runtime_` so it
// can be compiled alongside the monolithic kernel during the migration while the
// K compiler and OS runtime continue to mature. The goal is to preserve the
// working boot path while porting the low-level runtime to K in small, testable
// slices.

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

void runtime_vga_scroll() {
    let vga = (u16*)753664;
    let color_ptr = (u64*)532744;
    let color = (u16)(*color_ptr);

    let i = 0;
    while (i < 1920) {
        vga[i] = vga[i + 80];
        i = i + 1;
    }
    while (i < 2000) {
        vga[i] = (u16)32 | (color << (u16)8);
        i = i + 1;
    }
}

void runtime_vga_update_hw_cursor(u64 pos) {
    outb((u16)980, (u8)14);
    outb((u16)981, (u8)((pos >> (u64)8) & (u64)255));
    outb((u16)980, (u8)15);
    outb((u16)981, (u8)(pos & (u64)255));
}

void runtime_vga_write_char(u8 c) {
    let cursor_ptr = (u64*)532736;
    let color_ptr = (u64*)532744;
    let ansi_ptr = (u64*)532760;
    let pos = *cursor_ptr;
    let color = (u16)(*color_ptr);
    let vga = (u16*)753664;

    let ansi = *ansi_ptr;
    if (ansi == (u64)1) {
        if (c == (u8)'[') {
            *ansi_ptr = (u64)2;
            return;
        }
        *ansi_ptr = (u64)0;
    } else {
        if (ansi == (u64)2) {
            if (c == (u8)'m') {
                *ansi_ptr = (u64)0;
                return;
            }
            if (c == (u8)'H') {
                *cursor_ptr = (u64)0;
                runtime_vga_update_hw_cursor((u64)0);
                *ansi_ptr = (u64)0;
                return;
            }
            if (c == (u8)'J') {
                let i = 0;
                while (i < 2000) {
                    vga[i] = (u16)32 | (color << (u16)8);
                    i = i + 1;
                }
                *cursor_ptr = (u64)0;
                runtime_vga_update_hw_cursor((u64)0);
                *ansi_ptr = (u64)0;
                return;
            }
            if (c == (u8)'0') {
                *color_ptr = (u64)7;
            } else {
                if (c == (u8)'6') {
                    *color_ptr = (u64)11;
                } else {
                    if (c == (u8)'2') {
                        *color_ptr = (u64)10;
                    } else {
                        if (c == (u8)'3') {
                            *color_ptr = (u64)14;
                        } else {
                            if (c == (u8)'4') {
                                *color_ptr = (u64)9;
                            } else {
                                if (c == (u8)'1') {
                                    *color_ptr = (u64)12;
                                }
                            }
                        }
                    }
                }
            }
            return;
        }
    }

    if (c == (u8)27) {
        *ansi_ptr = (u64)1;
        return;
    }

    if (c == (u8)8) {
        if (pos > (u64)0) {
            pos = pos - (u64)1;
            vga[pos] = (u16)32 | (color << (u16)8);
            *cursor_ptr = pos;
            runtime_vga_update_hw_cursor(pos);
        }
        return;
    }

    if (c == (u8)'\n') {
        pos = ((pos / (u64)80) + (u64)1) * (u64)80;
    } else {
        if (c == (u8)'\r') {
            pos = (pos / (u64)80) * (u64)80;
        } else {
            if (c >= (u8)32) {
                if (pos < (u64)2000) {
                    vga[pos] = (u16)c | (color << (u16)8);
                    pos = pos + (u64)1;
                }
            }
        }
    }

    if (pos >= (u64)2000) {
        runtime_vga_scroll();
        pos = (u64)1920;
    }

    *cursor_ptr = pos;
    runtime_vga_update_hw_cursor(pos);
}

void runtime_vga_init() {
    let cursor_ptr = (u64*)532736;
    let color_ptr = (u64*)532744;
    let shift_ptr = (u64*)532752;
    let ansi_ptr = (u64*)532760;

    *cursor_ptr = (u64)0;
    *color_ptr = (u64)7;
    *shift_ptr = (u64)0;
    *ansi_ptr = (u64)0;

    runtime_vga_clear();
    outb((u16)980, (u8)10);
    outb((u16)981, (u8)14);
    outb((u16)980, (u8)11);
    outb((u16)981, (u8)15);
}

void runtime_pic_remap() {
    outb((u16)32, (u8)17);
    runtime_io_wait();
    outb((u16)160, (u8)17);
    runtime_io_wait();

    outb((u16)33, (u8)32);
    runtime_io_wait();
    outb((u16)161, (u8)40);
    runtime_io_wait();

    outb((u16)33, (u8)4);
    runtime_io_wait();
    outb((u16)161, (u8)2);
    runtime_io_wait();

    outb((u16)33, (u8)1);
    runtime_io_wait();
    outb((u16)161, (u8)1);
    runtime_io_wait();

    outb((u16)33, (u8)254);
    outb((u16)161, (u8)255);
}

void runtime_pit_init() {
    let divisor = (u16)11931;
    outb((u16)67, (u8)54);
    outb((u16)64, (u8)(divisor & (u16)255));
    outb((u16)64, (u8)((divisor >> (u16)8) & (u16)255));
}
