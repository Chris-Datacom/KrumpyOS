extern void install_idt();

char* kernel_message() {
    setup_serial();
    install_idt();
    return "Hello, World!\n";
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
