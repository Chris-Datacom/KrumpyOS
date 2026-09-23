// KrumpyOS Userland Utility: ls
// Lists files from the ramdisk filesystem via standard library

extern u64 syscall0(u64 num);
extern u64 syscall1(u64 num, u64 a1);
extern u64 syscall2(u64 num, u64 a1, u64 a2);
extern u64 syscall3(u64 num, u64 a1, u64 a2, u64 a3);

struct RamdiskEntry {
    char name[32];
    u64 data;
    u64 size;
};

int k_strlen(char* s) {
    let len = 0;
    while (s[len] != (char)0) {
        len = len + 1;
    }
    return len;
}

void k_print(char* s) {
    let len = k_strlen(s);
    syscall2((u64)2, (u64)s, (u64)len);
}

void k_print_char(char c) {
    let buf = " ";
    buf[0] = c;
    syscall2((u64)2, (u64)buf, (u64)1);
}

void k_print_dec(u64 value) {
    if (value == (u64)0) {
        k_print_char('0');
        return;
    }
    let buf = "01234567890123456789";
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
        k_print_char(buf[i]);
        i = i - 1;
    }
}

void ls_main() {
    let rd_ptr = (struct RamdiskEntry*)538624;
    let i = (u64)0;
    while (i < (u64)4) {
        let entry = &rd_ptr[i];
        if (entry.size > (u64)0) {
            k_print((char*)entry.name);
            k_print("  \t");
            k_print_dec(entry.size);
            k_print(" bytes\n");
        }
        i = i + (u64)1;
    }
}
