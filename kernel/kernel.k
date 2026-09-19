extern void install_idt();

void kernel_main() {
    setup_serial();
    install_idt();
    setup_kernel_paging();
    serial_write_str("KrumpyOS console ready\n");
    serial_write_str("Type 'help' for commands.\n\n");
    console_run();
}

void serial_write_char(u8 c) {
    outb((u16)1016, c);
}

void serial_write_str(char* str) {
    let i = 0;
    while (str[i] != (char)0) {
        serial_write_char((u8)str[i]);
        i = i + 1;
    }
}

u8 serial_read_char() {
    while ((inb((u16)1021) & (u8)1) == (u8)0) {
        pause();
    }
    return inb((u16)1016);
}

void setup_serial() {
    outb((u16)1017, (u8)0);
    outb((u16)1019, (u8)128);
    outb((u16)1016, (u8)1);
    outb((u16)1017, (u8)0);
    outb((u16)1019, (u8)3);
    outb((u16)1018, (u8)199);
    outb((u16)1020, (u8)11);
}

void set_idt_gate(u8 vector, u64 handler) {
    let offset = (int)vector * 16;
    let base = (u8*)528384;
    let low = (u16)(handler & (u64)65535);
    let mid = (u16)((handler >> (u64)16) & (u64)65535);
    let high = (u32)((handler >> (u64)32) & (u64)4294967295);

    base[offset] = (u8)(low & (u16)255);
    base[offset + 1] = (u8)((low >> (u16)8) & (u16)255);
    base[offset + 2] = (u8)24;
    base[offset + 3] = (u8)0;
    base[offset + 4] = (u8)0;
    base[offset + 5] = (u8)142;
    base[offset + 6] = (u8)(mid & (u16)255);
    base[offset + 7] = (u8)((mid >> (u16)8) & (u16)255);
    base[offset + 8] = (u8)(high & (u32)255);
    base[offset + 9] = (u8)((high >> (u32)8) & (u32)255);
    base[offset + 10] = (u8)((high >> (u32)16) & (u32)255);
    base[offset + 11] = (u8)((high >> (u32)24) & (u32)255);
    base[offset + 12] = (u8)0;
    base[offset + 13] = (u8)0;
    base[offset + 14] = (u8)0;
    base[offset + 15] = (u8)0;
}

void k_exception_dispatch(u64 vector, u64 error_code, void* frame) {
    if (vector == (u64)0) {
        serial_write_str("exception=0\n");
        return;
    }
    if (vector == (u64)3) {
        serial_write_str("exception=3\n");
        return;
    }
    serial_write_str("exception=?\n");
}

bool string_equal(char* left, char* right) {
    let i = 0;
    while (left[i] == right[i]) {
        if (left[i] == (char)0) {
            return true;
        }
        i = i + 1;
    }
    return false;
}

bool string_starts_with(char* value, char* prefix) {
    let i = 0;
    while (prefix[i] != (char)0) {
        if (value[i] != prefix[i]) {
            return false;
        }
        i = i + 1;
    }
    return true;
}

void serial_write_hex(u64 value) {
    let digits = "0123456789abcdef";
    serial_write_str("0x");
    let shift = 60;
    while (shift >= 0) {
        let digit = (value >> (u64)shift) & (u64)15;
        serial_write_char((u8)digits[(int)digit]);
        shift = shift - 4;
    }
}

void console_help() {
    serial_write_str("Commands:\n");
    serial_write_str("  help        show this command list\n");
    serial_write_str("  echo TEXT   print TEXT\n");
    serial_write_str("  mem         show early memory state\n");
    serial_write_str("  clear       clear the terminal\n");
    serial_write_str("  reboot      reboot through the keyboard controller\n");
    serial_write_str("  halt        halt the CPU\n");
}

void console_memory() {
    let next_page_ptr = (u64*)536576;
    serial_write_str("identity map: 0x00000000 - 0x007fffff\n");
    serial_write_str("next early page: ");
    serial_write_hex(*next_page_ptr);
    serial_write_char((u8)'\n');
}

void console_halt() {
    serial_write_str("System halted.\n");
    cli();
    while (1 == 1) {
        hlt();
    }
}

void console_reboot() {
    serial_write_str("Rebooting...\n");
    cli();
    while ((inb((u16)100) & (u8)2) != (u8)0) {
        pause();
    }
    outb((u16)100, (u8)254);
    while (1 == 1) {
        hlt();
    }
}

void console_execute(char* line) {
    if (line[0] == (char)0) {
        return;
    }
    if (string_equal(line, "help")) {
        console_help();
        return;
    }
    if (string_equal(line, "mem")) {
        console_memory();
        return;
    }
    if (string_equal(line, "clear")) {
        serial_write_char((u8)27);
        serial_write_str("[2J");
        serial_write_char((u8)27);
        serial_write_str("[H");
        return;
    }
    if (string_equal(line, "halt")) {
        console_halt();
        return;
    }
    if (string_equal(line, "reboot")) {
        console_reboot();
        return;
    }
    if (string_starts_with(line, "echo ")) {
        serial_write_str((char*)((u64)line + (u64)5));
        serial_write_char((u8)'\n');
        return;
    }
    serial_write_str("Unknown command: ");
    serial_write_str(line);
    serial_write_char((u8)'\n');
}

void console_erase_char() {
    serial_write_char((u8)8);
    serial_write_char((u8)' ');
    serial_write_char((u8)8);
}

void console_run() {
    let line = (char*)532480;
    let length = 0;
    serial_write_str("krumpy> ");

    while (1 == 1) {
        let input = serial_read_char();
        if (input == (u8)13) {
            line[length] = (char)0;
            serial_write_char((u8)'\n');
            console_execute(line);
            length = 0;
            serial_write_str("krumpy> ");
        } else {
            if (input == (u8)10) {
                line[length] = (char)0;
                serial_write_char((u8)'\n');
                console_execute(line);
                length = 0;
                serial_write_str("krumpy> ");
            } else {
                if (input == (u8)8) {
                    if (length > 0) {
                        length = length - 1;
                        console_erase_char();
                    }
                } else {
                    if (input == (u8)127) {
                        if (length > 0) {
                            length = length - 1;
                            console_erase_char();
                        }
                    } else {
                        if (length < 127) {
                            line[length] = (char)input;
                            length = length + 1;
                            serial_write_char(input);
                        } else {
                            serial_write_char((u8)7);
                        }
                    }
                }
            }
        }
    }
}

u64 alloc_page() {
    let base_ptr = (u64*)536576;
    let next = *base_ptr;
    if (next == (u64)0) {
        next = (u64)1048576;
    }
    *base_ptr = next + (u64)4096;
    let page = (u64*)next;
    let i = 0;
    while (i < 512) {
        page[i] = (u64)0;
        i = i + 1;
    }
    return next;
}

void setup_kernel_paging() {
    let pml4 = alloc_page();
    let pdpt = alloc_page();
    let pd = alloc_page();

    let pml4_ptr = (u64*)pml4;
    pml4_ptr[0] = pdpt | (u64)3;

    let pdpt_ptr = (u64*)pdpt;
    pdpt_ptr[0] = pd | (u64)3;

    let pd_ptr = (u64*)pd;
    let d = 0;
    while (d < 4) {
        let pt = alloc_page();
        pd_ptr[d] = pt | (u64)3;
        let pt_ptr = (u64*)pt;
        let p = 0;
        while (p < 512) {
            let phys_addr = ((u64)d * (u64)2097152) + ((u64)p * (u64)4096);
            pt_ptr[p] = phys_addr | (u64)3;
            p = p + 1;
        }
        d = d + 1;
    }

    write_cr3(pml4);
}
