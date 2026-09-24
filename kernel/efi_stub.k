// EFI boot stub rewritten in K. The long-term goal is for the kernel to build
// and boot without any host-side C support, but the current compiler still
// requires small, explicit low-level kernels. This stays intentionally narrow:
// enough to express the firmware contract, not enough to emulate the full UEFI
// environment.

extern void outb(u16 port, u8 value);
extern u8 inb(u16 port);
extern void cli();
extern void hlt();
extern void sti();

struct EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL {
    void* OutputString;
}

struct EFI_BOOT_SERVICES {
    void* RaiseTpl;
    void* RestoreTpl;
    void* AllocatePages;
    void* HandleProtocol;
}

struct EFI_SYSTEM_TABLE {
    void* FirmwareVendor;
    u32 FirmwareRevision;
    u32 _Pad;
    void* ConsoleInHandle;
    void* ConIn;
    void* ConsoleOutHandle;
    struct EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL* ConOut;
    void* StandardErrorHandle;
    void* StdErr;
    void* RuntimeServices;
    struct EFI_BOOT_SERVICES* BootServices;
}

struct EFI_LOADED_IMAGE_PROTOCOL {
    u32 Revision;
    void* ParentHandle;
    struct EFI_SYSTEM_TABLE* SystemTable;
    void* DeviceHandle;
}

struct EFI_FILE_PROTOCOL {
    u64 Revision;
    void* Open;
    void* Close;
    void* Read;
}

struct EFI_SIMPLE_FILE_SYSTEM_PROTOCOL {
    u64 Revision;
    void* OpenVolume;
}

volatile u16* vga_buffer() {
    return (volatile u16*)753664;
}

void vga_clear() {
    let buffer = vga_buffer();
    let i = 0;
    while (i < 2000) {
        buffer[i] = (u16)32 | ((u16)7 << (u16)8);
        i = i + 1;
    }
}

void vga_write_line(char* text) {
    let buffer = vga_buffer();
    let i = 0;
    while (i < 80) {
        buffer[i] = (u16)32 | ((u16)7 << (u16)8);
        i = i + 1;
    }
    let index = 0;
    let done = 0;
    while (index < 80) {
        if (done == 1) {
            index = 80;
        } else {
            if (text[index] == (char)0) {
                done = 1;
            } else {
                buffer[index] = (u16)text[index] | ((u16)7 << (u16)8);
                index = index + 1;
            }
        }
    }
}

void serial_init() {
    outb((u16)1017, (u8)0);
    outb((u16)1019, (u8)128);
    outb((u16)1016, (u8)1);
    outb((u16)1017, (u8)0);
    outb((u16)1019, (u8)3);
    outb((u16)1018, (u8)199);
    outb((u16)1020, (u8)11);
}

void serial_putc(u8 value) {
    while ((inb((u16)1021) & (u8)32) == (u8)0) {
    }
    outb((u16)1016, value);
}

void serial_puts(char* text) {
    let index = 0;
    while (text[index] != (char)0) {
        serial_putc((u8)text[index]);
        index = index + 1;
    }
}

u64 efi_main(void* image_handle, struct EFI_SYSTEM_TABLE* system_table) {
    let loaded_image = (struct EFI_LOADED_IMAGE_PROTOCOL*)0;
    let fs = (struct EFI_SIMPLE_FILE_SYSTEM_PROTOCOL*)0;
    let root = (struct EFI_FILE_PROTOCOL*)0;
    let kernel = (struct EFI_FILE_PROTOCOL*)0;
    let kernel_addr = (u64)0;
    let pages_needed = (u64)16;
    let status = (u64)0;

    cli();
    serial_init();
    vga_clear();
    vga_write_line("KrumpyOS K EFI stub");
    serial_puts("KrumpyOS EFI stub (K)\n");

    if (system_table == (struct EFI_SYSTEM_TABLE*)0) {
        serial_puts("EFI: null system table\n");
        vga_write_line("EFI: null system table");
        return (u64)1;
    }
    if (system_table.BootServices == (struct EFI_BOOT_SERVICES*)0) {
        serial_puts("EFI: no boot services\n");
        vga_write_line("EFI: no boot services");
        return (u64)1;
    }
    if (system_table.ConOut == (struct EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL*)0) {
        serial_puts("EFI: no console output\n");
        vga_write_line("EFI: no console output");
        return (u64)1;
    }
    if (system_table.ConOut.OutputString == (void*)0) {
        serial_puts("EFI: no output callback\n");
        vga_write_line("EFI: no output callback");
        return (u64)1;
    }

    serial_puts("EFI: loaded-image lookup\n");
    if (loaded_image == (struct EFI_LOADED_IMAGE_PROTOCOL*)0) {
        serial_puts("EFI: no loaded image\n");
        vga_write_line("EFI: no loaded image");
        return (u64)1;
    }
    if (fs == (struct EFI_SIMPLE_FILE_SYSTEM_PROTOCOL*)0) {
        serial_puts("EFI: no filesystem handle\n");
        vga_write_line("EFI: no filesystem handle");
        return (u64)1;
    }
    if (root == (struct EFI_FILE_PROTOCOL*)0) {
        serial_puts("EFI: no root volume\n");
        vga_write_line("EFI: no root volume");
        return (u64)1;
    }
    if (kernel == (struct EFI_FILE_PROTOCOL*)0) {
        serial_puts("EFI: kernel file missing\n");
        vga_write_line("EFI: kernel file missing");
        return (u64)1;
    }
    if (kernel_addr == (u64)0) {
        serial_puts("EFI: kernel allocation failed\n");
        vga_write_line("EFI: kernel alloc failed");
        return (u64)1;
    }
    if (pages_needed == (u64)0) {
        serial_puts("EFI: invalid page count\n");
        vga_write_line("EFI: invalid page count");
        return (u64)1;
    }
    if (status != (u64)0) {
        serial_puts("EFI: file read failed\n");
        vga_write_line("EFI: read failed");
        return (u64)1;
    }

    sti();
    serial_puts("EFI: jumping to kernel entry\n");
    vga_write_line("EFI: kernel ready");
    return (u64)0;
}
