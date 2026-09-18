extern void install_idt();

char* kernel_message() {
    setup_serial();
    serial_write_str("step 1: serial init\n");
    install_idt();
    serial_write_str("step 2: idt init\n");
    setup_kernel_paging();
    serial_write_str("step 3: paging init\n");
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

u64 alloc_page() {
    let base_ptr = (u64*)655360;
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

