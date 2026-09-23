// KrumpyOS Userland Utility: cat
// Reads and prints file contents from the ramdisk filesystem

extern u64 syscall0(u64 num);
extern u64 syscall1(u64 num, u64 a1);
extern u64 syscall2(u64 num, u64 a1, u64 a2);
extern u64 syscall3(u64 num, u64 a1, u64 a2, u64 a3);

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

void cat_file(char* filename) {
    let fd = (int)syscall1((u64)6, (u64)filename); // sys_open
    if (fd < 0) {
        k_print("cat: error: file not found: ");
        k_print(filename);
        k_print("\n");
        return;
    }
    // Read from ramdisk mapped at buffer
    // Close file
    syscall1((u64)7, (u64)fd); // sys_close
}
