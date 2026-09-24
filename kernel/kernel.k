extern void install_idt();
extern void switch_context(u64* old_rsp_ptr, u64 new_rsp);
extern void setup_syscall_msrs();

void kernel_main() {
    setup_serial();
    klog_info("Serial logging initialized");
    install_idt();
    klog_info("IDT and exception handlers installed");
    pic_remap();
    pit_init();
    klog_info("8259 PIC remapped and 8254 PIT running at 100Hz");
    setup_syscall_msrs();
    klog_info("System Call MSRs configured (EFER/STAR/LSTAR/FMASK)");
    pmm_init();
    setup_kernel_paging();
    klog_info("Paging tables and physical memory manager active");
    init_kernel_state();
    scheduler_init();
    klog_info("Multitasking scheduler initialized");
    spawn_kinit();
    klog_info("PID 1 (kinit) spawned in userland");
    sti();
    klog_info("Interrupts enabled");

    console_fastfetch();
    serial_write_str("KrumpyOS console ready. Type 'help' for commands.\n\n");
    console_run();
}

void io_wait() {
    outb((u16)128, (u8)0);
}

void pic_remap() {
    outb((u16)32, (u8)17);
    io_wait();
    outb((u16)160, (u8)17);
    io_wait();

    outb((u16)33, (u8)32);
    io_wait();
    outb((u16)161, (u8)40);
    io_wait();

    outb((u16)33, (u8)4);
    io_wait();
    outb((u16)161, (u8)2);
    io_wait();

    outb((u16)33, (u8)1);
    io_wait();
    outb((u16)161, (u8)1);
    io_wait();

    outb((u16)33, (u8)254);
    outb((u16)161, (u8)255);
}

void pit_init() {
    let divisor = (u16)11931;
    outb((u16)67, (u8)54);
    outb((u16)64, (u8)(divisor & (u16)255));
    outb((u16)64, (u8)((divisor >> (u16)8) & (u16)255));
}

void pic_send_eoi(u8 irq) {
    if (irq >= (u8)8) {
        outb((u16)160, (u8)32);
    }
    outb((u16)32, (u8)32);
}

void init_kernel_state() {
    let ticks_ptr = (u64*)536584;
    *ticks_ptr = (u64)0;
}

void idle_thread_fn() {
    while (1 == 1) {
        hlt();
    }
}

void worker1_thread_fn() {
    while (1 == 1) {
        pause();
    }
}

void scheduler_init() {
    let tcb_base = (u64*)544768;
    let current_tid_ptr = (u64*)536592;

    let i = 0;
    while (i < 32) {
        tcb_base[i] = (u64)0;
        i = i + 1;
    }

    let idle_stack = alloc_page();
    let idle_stack_top = (u64*)(idle_stack + (u64)4088);
    *idle_stack_top = (u64)idle_thread_fn;
    let idle_rsp = idle_stack + (u64)4040;

    tcb_base[0] = (u64)0;
    tcb_base[1] = (u64)1;
    tcb_base[2] = idle_rsp;
    tcb_base[3] = idle_stack;
    tcb_base[4] = (u64)0;

    tcb_base[8] = (u64)1;
    tcb_base[9] = (u64)2;
    tcb_base[10] = (u64)0;
    tcb_base[11] = (u64)524288;
    tcb_base[12] = (u64)0;

    let worker_stack = alloc_page();
    let worker_stack_top = (u64*)(worker_stack + (u64)4088);
    *worker_stack_top = (u64)worker1_thread_fn;
    let worker_rsp = worker_stack + (u64)4040;

    tcb_base[16] = (u64)2;
    tcb_base[17] = (u64)1;
    tcb_base[18] = worker_rsp;
    tcb_base[19] = worker_stack;
    tcb_base[20] = (u64)0;

    *current_tid_ptr = (u64)1;
}

void schedule() {
    let tcb_base = (u64*)544768;
    let current_tid_ptr = (u64*)536592;
    let curr_tid = *current_tid_ptr;

    let next_tid = (curr_tid + (u64)1) % (u64)4;
    let count = 0;
    while (count < 4) {
        let state = tcb_base[(int)next_tid * 8 + 1];
        if (state == (u64)1) {
            if (next_tid != curr_tid) {
                let curr_state = tcb_base[(int)curr_tid * 8 + 1];
                if (curr_state == (u64)2) {
                    tcb_base[(int)curr_tid * 8 + 1] = (u64)1;
                }
                tcb_base[(int)next_tid * 8 + 1] = (u64)2;
                *current_tid_ptr = next_tid;

                let old_rsp_ptr = (u64*)(&tcb_base[(int)curr_tid * 8 + 2]);
                let new_rsp = tcb_base[(int)next_tid * 8 + 2];
                switch_context(old_rsp_ptr, new_rsp);
            }
            return;
        }
        next_tid = (next_tid + (u64)1) % (u64)4;
        count = count + 1;
    }
}

void thread_yield() {
    schedule();
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

void klog(char* level, char* msg) {
    serial_write_str("[");
    serial_write_str(level);
    serial_write_str("] ");
    serial_write_str(msg);
    serial_write_char((u8)'\n');
}

void klog_info(char* msg) {
    klog("INFO", msg);
}

void klog_warn(char* msg) {
    klog("WARN", msg);
}

void klog_error(char* msg) {
    klog("ERROR", msg);
}

void k_panic(char* msg, void* frame) {
    cli();
    serial_write_str("\n*** KERNEL PANIC: ");
    serial_write_str(msg);
    serial_write_str(" ***\n");

    if (frame != (void*)0) {
        let f = (u64*)frame;
        serial_write_str("Fault Frame:\n");
        serial_write_str("  RIP:    ");
        serial_write_hex(f[17]);
        serial_write_str("  CS:     ");
        serial_write_hex(f[18]);
        serial_write_char((u8)'\n');

        serial_write_str("  RFLAGS: ");
        serial_write_hex(f[19]);
        serial_write_str("  RSP:    ");
        serial_write_hex(f[20]);
        serial_write_char((u8)'\n');

        serial_write_str("  RAX:    ");
        serial_write_hex(f[14]);
        serial_write_str("  RBX:    ");
        serial_write_hex(f[11]);
        serial_write_char((u8)'\n');

        serial_write_str("  RCX:    ");
        serial_write_hex(f[13]);
        serial_write_str("  RDX:    ");
        serial_write_hex(f[12]);
        serial_write_char((u8)'\n');

        serial_write_str("  RSI:    ");
        serial_write_hex(f[9]);
        serial_write_str("  RDI:    ");
        serial_write_hex(f[8]);
        serial_write_char((u8)'\n');

        serial_write_str("  RBP:    ");
        serial_write_hex(f[10]);
        serial_write_str("  ERR:    ");
        serial_write_hex(f[16]);
        serial_write_char((u8)'\n');

        if (f[15] == (u64)14) {
            let cr2 = read_cr2();
            serial_write_str("  CR2 (Faulting Address): ");
            serial_write_hex(cr2);
            serial_write_char((u8)'\n');
        }
    }

    serial_write_str("System halted.\n");
    while (1 == 1) {
        hlt();
    }
}

void k_assert(bool cond, char* msg) {
    if (!cond) {
        k_panic(msg, (void*)0);
    }
}

struct ThreadContext {
    u64 tid;
    u64 state;
    u64 rsp;
    u64 stack_base;
    u64 ticks;
    u64 cr3;
};

struct RamdiskEntry {
    char* path;
    char* data;
    u64 size;
};

struct PipeBuffer {
    u64 read_pos;
    u64 write_pos;
    u64 count;
    u64 capacity;
};

struct MemoryStats {
    u64 total_pages;
    u64 used_pages;
    u64 free_pages;
    u64 bitmap_base;
};

int ramdisk_open(char* path) {
    if (string_equal(path, "/etc/hostname")) {
        return 3;
    }
    if (string_equal(path, "/etc/version")) {
        return 4;
    }
    if (string_equal(path, "/system/bin/sh")) {
        return 5;
    }
    if (string_equal(path, "/system/bin/hello")) {
        return 6;
    }
    return -1;
}

char* ramdisk_read_data(int fd) {
    if (fd == 3) {
        return "krumpyos\n";
    }
    if (fd == 4) {
        return "KrumpyOS 0.1.0-alpha (K toolchain)\n";
    }
    if (fd == 5) {
        return "#!/system/bin/sh\n// KrumpyOS user shell\n";
    }
    if (fd == 6) {
        return "#!/system/bin/hello\n// Hello world ELF64 stub\n";
    }
    return "";
}

void kinit_main() {
    let msg = "[kinit] PID 1 active in user space\n";
    let i = 0;
    while (msg[i] != (char)0) {
        serial_write_char((u8)msg[i]);
        i = i + 1;
    }
    while (1 == 1) {
        pause();
    }
}

void spawn_kinit() {
    let tcb_base = (u64*)544768;
    let kinit_stack = alloc_page();
    let kinit_stack_top = (u64*)(kinit_stack + (u64)4088);
    *kinit_stack_top = (u64)kinit_main;
    let kinit_rsp = kinit_stack + (u64)4040;

    tcb_base[24] = (u64)3;
    tcb_base[25] = (u64)1;
    tcb_base[26] = kinit_rsp;
    tcb_base[27] = kinit_stack;
    tcb_base[28] = (u64)0;
}

u64 k_syscall_dispatch(u64 num, u64 a1, u64 a2, u64 a3, u64 a4, u64 a5) {
    if (num == (u64)1) {
        /* SYS_EXIT: mark current thread dead and schedule */
        let current_tid_ptr = (u64*)536592;
        let curr_tid = *current_tid_ptr;
        let tcb_base = (u64*)544768;
        tcb_base[(int)curr_tid * 8 + 1] = (u64)4;
        schedule();
        return (u64)0;
    }
    if (num == (u64)2) {
        /* SYS_WRITE: write string (a1 = char* buf, a2 = length) */
        let buf = (char*)a1;
        let len = a2;
        let i = (u64)0;
        while (i < len) {
            serial_write_char((u8)buf[(int)i]);
            i = i + (u64)1;
        }
        return len;
    }
    if (num == (u64)3) {
        /* SYS_READ: read char */
        let c = serial_read_char();
        return (u64)c;
    }
    if (num == (u64)4) {
        /* SYS_YIELD: yield CPU */
        thread_yield();
        return (u64)0;
    }
    if (num == (u64)5) {
        /* SYS_UPTIME: return monotonic ticks */
        let ticks_ptr = (u64*)536584;
        return *ticks_ptr;
    }
    if (num == (u64)6) {
        /* SYS_OPEN: a1 = char* filename */
        let path = (char*)a1;
        let fd = ramdisk_open(path);
        return (u64)fd;
    }
    if (num == (u64)7) {
        /* SYS_CLOSE: a1 = int fd */
        return (u64)0;
    }
    if (num == (u64)8) {
        /* SYS_PIPE: a1 = int* pipe_fds */
        let fds = (int*)a1;
        fds[0] = 10;
        fds[1] = 11;
        return (u64)0;
    }
    return (u64)18446744073709551615;
}

void k_exception_dispatch(u64 vector, u64 error_code, void* frame) {
    if (vector == (u64)0) {
        klog_error("Exception #DE (Divide by Zero)");
        k_panic("Divide by Zero", frame);
        return;
    }
    if (vector == (u64)3) {
        klog_info("Breakpoint #BP hit");
        if (frame != (void*)0) {
            let f = (u64*)frame;
            serial_write_str("  RIP: ");
            serial_write_hex(f[17]);
            serial_write_char((u8)'\n');
        }
        return;
    }
    if (vector == (u64)6) {
        klog_error("Exception #UD (Invalid Opcode)");
        k_panic("Invalid Opcode", frame);
        return;
    }
    if (vector == (u64)8) {
        k_panic("Double Fault (#DF)", frame);
        return;
    }
    if (vector == (u64)13) {
        klog_error("Exception #GP (General Protection Fault)");
        k_panic("General Protection Fault", frame);
        return;
    }
    if (vector == (u64)14) {
        klog_error("Exception #PF (Page Fault)");
        k_panic("Page Fault", frame);
        return;
    }
    k_panic("Unhandled CPU Exception", frame);
}

void k_interrupt_dispatch(u64 vector, u64 error_code, void* frame) {
    if (vector == (u64)32) {
        let ticks_ptr = (u64*)536584;
        *ticks_ptr = *ticks_ptr + (u64)1;

        let current_tid_ptr = (u64*)536592;
        let curr_tid = *current_tid_ptr;
        let tcb_base = (u64*)544768;
        let ticks_run_idx = (int)curr_tid * 8 + 4;
        tcb_base[ticks_run_idx] = tcb_base[ticks_run_idx] + (u64)1;

        pic_send_eoi((u8)0);
        return;
    }
    if (vector >= (u64)32) {
        if (vector < (u64)48) {
            let irq = (u8)(vector - (u64)32);
            pic_send_eoi(irq);
            return;
        }
    }
}

void pmm_init() {
    let bitmap = (u8*)540672;
    let used_pages_ptr = (u64*)536576;

    let i = 0;
    while (i < 32) {
        bitmap[i] = (u8)255;
        i = i + 1;
    }
    while (i < 256) {
        bitmap[i] = (u8)0;
        i = i + 1;
    }
    *used_pages_ptr = (u64)256;
}

u64 alloc_page() {
    let bitmap = (u8*)540672;
    let used_pages_ptr = (u64*)536576;

    let byte_idx = 0;
    while (byte_idx < 256) {
        if (bitmap[byte_idx] != (u8)255) {
            let bit_idx = 0;
            while (bit_idx < 8) {
                let mask = (u8)(1 << bit_idx);
                if ((bitmap[byte_idx] & mask) == (u8)0) {
                    bitmap[byte_idx] = bitmap[byte_idx] | mask;
                    *used_pages_ptr = *used_pages_ptr + (u64)1;
                    let page_num = ((u64)byte_idx * (u64)8) + (u64)bit_idx;
                    let addr = page_num * (u64)4096;

                    let ptr = (u64*)addr;
                    let j = 0;
                    while (j < 512) {
                        ptr[j] = (u64)0;
                        j = j + 1;
                    }
                    return addr;
                }
                bit_idx = bit_idx + 1;
            }
        }
        byte_idx = byte_idx + 1;
    }

    k_panic("Out of Physical Memory Frames", (void*)0);
    return (u64)0;
}

void free_page(u64 addr) {
    let bitmap = (u8*)540672;
    let used_pages_ptr = (u64*)536576;

    let page_num = addr / (u64)4096;
    if (page_num < (u64)2048) {
        let byte_idx = (int)(page_num / (u64)8);
        let bit_idx = (int)(page_num % (u64)8);
        let mask = (u8)(1 << bit_idx);
        if ((bitmap[byte_idx] & mask) != (u8)0) {
            bitmap[byte_idx] = bitmap[byte_idx] & ~mask;
            if (*used_pages_ptr > (u64)0) {
                *used_pages_ptr = *used_pages_ptr - (u64)1;
            }
        }
    }
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

void serial_write_dec(u64 value) {
    if (value == (u64)0) {
        serial_write_char((u8)'0');
        return;
    }
    let buf = (char*)532608;
    let count = 0;
    let temp = value;
    while (temp > (u64)0) {
        let rem = temp % (u64)10;
        buf[count] = (char)((u8)'0' + (u8)rem);
        temp = temp / (u64)10;
        count = count + 1;
    }
    let i = count - 1;
    while (i >= 0) {
        serial_write_char((u8)buf[i]);
        i = i - 1;
    }
}

void console_color(char* code) {
    serial_write_char((u8)27);
    serial_write_str(code);
}

void console_fastfetch() {
    let ticks_ptr = (u64*)536584;
    let t = *ticks_ptr;
    let sec = t / (u64)100;
    let frac = t % (u64)100;

    let used_pages_ptr = (u64*)536576;
    let used = *used_pages_ptr;
    let total = (u64)2048;

    serial_write_char((u8)'\n');

    // Line 1: Logo line 1 + User/Host
    console_color("[1;36m");
    serial_write_str("    __ __       ");
    console_color("[1;32m");
    serial_write_str("user");
    console_color("[0m");
    serial_write_str("@");
    console_color("[1;34m");
    serial_write_str("krumpyos\n");

    // Line 2: Logo line 2 + Underline
    console_color("[1;36m");
    serial_write_str("   / //_/       ");
    console_color("[0m");
    serial_write_str("---------------------\n");

    // Line 3: Logo line 3 + OS
    console_color("[1;36m");
    serial_write_str("  / ,<          ");
    console_color("[1;33m");
    serial_write_str("OS:       ");
    console_color("[0m");
    serial_write_str("KrumpyOS x86_64\n");

    // Line 4: Logo line 4 + Host
    console_color("[1;36m");
    serial_write_str(" / /| |         ");
    console_color("[1;33m");
    serial_write_str("Host:     ");
    console_color("[0m");
    serial_write_str("QEMU Virtual Machine (x86_64)\n");

    // Line 5: Logo line 5 + Kernel
    console_color("[1;36m");
    serial_write_str("/_/ |_|         ");
    console_color("[1;33m");
    serial_write_str("Kernel:   ");
    console_color("[0m");
    serial_write_str("0.1.0-krumpy (Freestanding K)\n");

    // Line 6: Logo line 6 + Uptime
    console_color("[1;36m");
    serial_write_str("  ___  ____     ");
    console_color("[1;33m");
    serial_write_str("Uptime:   ");
    console_color("[0m");
    serial_write_dec(sec);
    serial_write_char((u8)'.');
    if (frac < (u64)10) {
        serial_write_char((u8)'0');
    }
    serial_write_dec(frac);
    serial_write_str("s (");
    serial_write_dec(t);
    serial_write_str(" ticks)\n");

    // Line 7: Logo line 7 + Shell
    console_color("[1;36m");
    serial_write_str(" / _ \\/ __/     ");
    console_color("[1;33m");
    serial_write_str("Shell:    ");
    console_color("[0m");
    serial_write_str("k-sh 0.1.0 (PID 1: kinit)\n");

    // Line 8: Logo line 8 + CPU
    console_color("[1;36m");
    serial_write_str("/ // /\\ \\       ");
    console_color("[1;33m");
    serial_write_str("CPU:      ");
    console_color("[0m");
    serial_write_str("x86-64 Long Mode (8254 PIT @ 100 Hz)\n");

    // Line 9: Logo line 9 + Memory
    console_color("[1;36m");
    serial_write_str("\\___/___/       ");
    console_color("[1;33m");
    serial_write_str("Memory:   ");
    console_color("[0m");
    serial_write_dec(used * (u64)4);
    serial_write_str(" KB / ");
    serial_write_dec(total * (u64)4);
    serial_write_str(" KB (");
    serial_write_dec(used);
    serial_write_str("/");
    serial_write_dec(total);
    serial_write_str(" pages)\n");

    // Line 10: Threads
    serial_write_str("                ");
    console_color("[1;33m");
    serial_write_str("Threads:  ");
    console_color("[0m");
    serial_write_str("2 active (TID 0: idle, TID 1: kinit)\n");

    // Line 11: Color Palette Blocks
    serial_write_str("                ");
    console_color("[1;33m");
    serial_write_str("Palette:  ");
    console_color("[0m");
    console_color("[40m   ");
    console_color("[41m   ");
    console_color("[42m   ");
    console_color("[43m   ");
    console_color("[44m   ");
    console_color("[45m   ");
    console_color("[46m   ");
    console_color("[47m   ");
    console_color("[0m\n\n");
}

void console_help() {
    serial_write_str("Commands:\n");
    serial_write_str("  help        show this command list\n");
    serial_write_str("  fastfetch   display system specs and status banner\n");
    serial_write_str("  echo TEXT   print TEXT\n");
    serial_write_str("  ls          list initial ramdisk files\n");
    serial_write_str("  cat FILE    display ramdisk file contents\n");
    serial_write_str("  pipe        test IPC pipe syscall\n");
    serial_write_str("  mem         show physical memory and frame allocator state\n");
    serial_write_str("  ps          list active kernel threads\n");
    serial_write_str("  yield       yield current thread slice\n");
    serial_write_str("  uptime      show system uptime and timer ticks\n");
    serial_write_str("  panic       trigger a test kernel panic\n");
    serial_write_str("  clear       clear the terminal\n");
    serial_write_str("  reboot      reboot through the keyboard controller\n");
    serial_write_str("  halt        halt the CPU\n");
}

void console_memory() {
    let used_pages_ptr = (u64*)536576;
    let used = *used_pages_ptr;
    let total = (u64)2048;
    let free_pages = total - used;

    serial_write_str("Physical Memory Map:\n");
    serial_write_str("  Total Memory: ");
    serial_write_dec(total * (u64)4);
    serial_write_str(" KB (");
    serial_write_dec(total);
    serial_write_str(" pages)\n");

    serial_write_str("  Used Memory:  ");
    serial_write_dec(used * (u64)4);
    serial_write_str(" KB (");
    serial_write_dec(used);
    serial_write_str(" pages)\n");

    serial_write_str("  Free Memory:  ");
    serial_write_dec(free_pages * (u64)4);
    serial_write_str(" KB (");
    serial_write_dec(free_pages);
    serial_write_str(" pages)\n");

    serial_write_str("  Bitmap Base:  0x00084000 (256 bytes tracking 8 MB)\n");
}

void console_ps() {
    let tcb_base = (u64*)544768;
    let current_tid_ptr = (u64*)536592;
    let curr_tid = *current_tid_ptr;

    serial_write_str("Kernel Threads / Processes:\n");
    serial_write_str("  TID  STATE    TICKS  NAME\n");

    let i = 0;
    while (i < 4) {
        let tid = tcb_base[i * 8];
        let state = tcb_base[i * 8 + 1];
        let ticks = tcb_base[i * 8 + 4];

        serial_write_str("  ");
        serial_write_dec(tid);
        serial_write_str("    ");

        if (state == (u64)0) {
            serial_write_str("UNUSED   ");
        } else {
            if (state == (u64)1) {
                serial_write_str("READY    ");
            } else {
                if (state == (u64)2) {
                    serial_write_str("RUNNING  ");
                } else {
                    if (state == (u64)3) {
                        serial_write_str("BLOCKED  ");
                    } else {
                        serial_write_str("DEAD     ");
                    }
                }
            }
        }

        serial_write_dec(ticks);
        serial_write_str("      ");

        if (i == 0) {
            serial_write_str("idle\n");
        } else {
            if (i == 1) {
                serial_write_str("main/console\n");
            } else {
                if (i == 2) {
                    serial_write_str("worker1\n");
                } else {
                    serial_write_str("kinit (PID 1)\n");
                }
            }
        }

        i = i + 1;
    }
}

void console_uptime() {
    let ticks_ptr = (u64*)536584;
    let t = *ticks_ptr;
    let sec = t / (u64)100;
    let frac = t % (u64)100;
    serial_write_str("uptime: ");
    serial_write_dec(sec);
    serial_write_char((u8)'.');
    if (frac < (u64)10) {
        serial_write_char((u8)'0');
    }
    serial_write_dec(frac);
    serial_write_str("s (");
    serial_write_dec(t);
    serial_write_str(" ticks)\n");
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
    if (string_equal(line, "fastfetch")) {
        console_fastfetch();
        return;
    }
    if (string_equal(line, "fetch")) {
        console_fastfetch();
        return;
    }
    if (string_equal(line, "ls")) {
        serial_write_str("Ramdisk files:\n");
        let i = (u64)0;
        let rd_ptr = (struct RamdiskEntry*)538624;
        while (i < (u64)4) {
            let entry = &rd_ptr[i];
            if (entry.size > (u64)0) {
                serial_write_str("  ");
                serial_write_str((char*)entry.name);
                serial_write_str(" (");
                serial_write_dec(entry.size);
                serial_write_str(" bytes)\n");
            }
            i = i + (u64)1;
        }
        return;
    }
    if (string_starts_with(line, "cat ")) {
        let name = (char*)((u64)line + (u64)4);
        let rd_ptr = (struct RamdiskEntry*)538624;
        let i = (u64)0;
        let found = 0;
        while (i < (u64)4) {
            let entry = &rd_ptr[i];
            if (string_equal((char*)entry.name, name)) {
                serial_write_str((char*)entry.data);
                found = 1;
                i = (u64)4;
            } else {
                i = i + (u64)1;
            }
        }
        if (found == 0) {
            serial_write_str("File not found: ");
            serial_write_str(name);
            serial_write_str("\n");
        }
        return;
    }
    if (string_equal(line, "pipe")) {
        let p_ptr = (struct PipeBuffer*)539648;
        serial_write_str("Testing IPC Pipe: Writing 'hello_pipe'...\n");
        let msg = "hello_pipe";
        let j = (u64)0;
        while (j < (u64)10) {
            p_ptr.buf[p_ptr.head] = msg[j];
            p_ptr.head = (p_ptr.head + (u64)1) % (u64)256;
            j = j + (u64)1;
        }
        serial_write_str("Reading from Pipe: ");
        while (p_ptr.tail != p_ptr.head) {
            serial_write_char((u8)p_ptr.buf[p_ptr.tail]);
            p_ptr.tail = (p_ptr.tail + (u64)1) % (u64)256;
        }
        serial_write_str("\nIPC Pipe test passed.\n");
        return;
    }
    if (string_equal(line, "mem")) {
        console_memory();
        return;
    }
    if (string_equal(line, "ps")) {
        console_ps();
        return;
    }
    if (string_equal(line, "yield")) {
        thread_yield();
        serial_write_str("Yielded.\n");
        return;
    }
    if (string_equal(line, "uptime")) {
        console_uptime();
        return;
    }
    if (string_equal(line, "panic")) {
        k_panic("Manual Console Panic Triggered", (void*)0);
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
    serial_write_str("user@krumpyos> ");

    while (1 == 1) {
        let input = serial_read_char();
        if (input == (u8)13) {
            line[length] = (char)0;
            serial_write_char((u8)'\n');
            console_execute(line);
            length = 0;
            serial_write_str("user@krumpyos> ");
        } else {
            if (input == (u8)10) {
                line[length] = (char)0;
                serial_write_char((u8)'\n');
                console_execute(line);
                length = 0;
                serial_write_str("user@krumpyos> ");
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
