// KrumpyOS Userland C-Style Standard Library (libk)

extern u64 syscall0(u64 num);
extern u64 syscall1(u64 num, u64 a1);
extern u64 syscall2(u64 num, u64 a1, u64 a2);
extern u64 syscall3(u64 num, u64 a1, u64 a2, u64 a3);

// Syscall Numbers
// SYS_EXIT   = 1
// SYS_WRITE  = 2
// SYS_READ   = 3
// SYS_YIELD  = 4
// SYS_UPTIME = 5
// SYS_OPEN   = 6
// SYS_CLOSE  = 7
// SYS_PIPE   = 8

void sys_exit(int code) {
    syscall1((u64)1, (u64)code);
}

int sys_write(char* buf, int len) {
    return (int)syscall2((u64)2, (u64)buf, (u64)len);
}

char sys_read_char() {
    return (char)syscall0((u64)3);
}

void sys_yield() {
    syscall0((u64)4);
}

u64 sys_uptime() {
    return syscall0((u64)5);
}

int sys_open(char* name) {
    return (int)syscall1((u64)6, (u64)name);
}

int sys_close(int fd) {
    return (int)syscall1((u64)7, (u64)fd);
}

int sys_pipe(int* pipe_fds) {
    return (int)syscall1((u64)8, (u64)pipe_fds);
}

int k_strlen(char* s) {
    let len = 0;
    while (s[len] != (char)0) {
        len = len + 1;
    }
    return len;
}

void k_print(char* s) {
    let len = k_strlen(s);
    sys_write(s, len);
}

void k_print_char(char c) {
    let buf = " ";
    buf[0] = c;
    sys_write(buf, 1);
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

void k_print_hex(u64 value) {
    let digits = "0123456789abcdef";
    k_print("0x");
    let shift = 60;
    while (shift >= 0) {
        let digit = (value >> (u64)shift) & (u64)15;
        k_print_char(digits[(int)digit]);
        shift = shift - 4;
    }
}

bool k_streq(char* a, char* b) {
    let i = 0;
    while (a[i] == b[i]) {
        if (a[i] == (char)0) {
            return true;
        }
        i = i + 1;
    }
    return false;
}

bool k_strstarts(char* s, char* prefix) {
    let i = 0;
    while (prefix[i] != (char)0) {
        if (s[i] != prefix[i]) {
            return false;
        }
        i = i + 1;
    }
    return true;
}

int k_readline(char* buf, int max_len) {
    let len = 0;
    while (1 == 1) {
        let c = sys_read_char();
        if (c == (char)13 || c == (char)10) {
            buf[len] = (char)0;
            k_print_char('\n');
            return len;
        }
        if (c == (char)8 || c == (char)127) {
            if (len > 0) {
                len = len - 1;
                k_print_char((char)8);
                k_print_char(' ');
                k_print_char((char)8);
            }
        } else {
            if (len < max_len - 1) {
                buf[len] = c;
                len = len + 1;
                k_print_char(c);
            } else {
                k_print_char((char)7);
            }
        }
    }
    return len;
}
