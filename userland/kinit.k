// KrumpyOS Init System (PID 1) - kinit
// Declarative service supervisor and system bootstrap daemon

extern u64 syscall0(u64 num);
extern u64 syscall1(u64 num, u64 a1);
extern u64 syscall2(u64 num, u64 a1, u64 a2);
extern u64 syscall3(u64 num, u64 a1, u64 a2, u64 a3);

struct ServiceUnit {
    char name[32];
    char command[64];
    int enabled;
    int respawn;
    int pid;
    int status; // 0=stopped, 1=running, 2=failed
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

void k_strcpy(char* dst, char* src) {
    let i = 0;
    while (src[i] != (char)0) {
        dst[i] = src[i];
        i = i + 1;
    }
    dst[i] = (char)0;
}

int k_streq(char* a, char* b) {
    let i = 0;
    while (a[i] != (char)0 && b[i] != (char)0) {
        if (a[i] != b[i]) {
            return 0;
        }
        i = i + 1;
    }
    return a[i] == (char)0 && b[i] == (char)0;
}

void init_banner() {
    k_print("[kinit] KrumpyOS Init System (PID 1) starting...\n");
    k_print("[kinit] Target: multi-user.target\n");
}

void init_register_services(struct ServiceUnit* units) {
    // Service 0: klogd (Kernel Logging Daemon)
    k_strcpy((char*)units[0].name, "klogd");
    k_strcpy((char*)units[0].command, "/bin/klogd");
    units[0].enabled = 1;
    units[0].respawn = 1;
    units[0].pid = 2;
    units[0].status = 1;

    // Service 1: sh (Interactive User Shell)
    k_strcpy((char*)units[1].name, "sh");
    k_strcpy((char*)units[1].command, "/bin/sh");
    units[1].enabled = 1;
    units[1].respawn = 1;
    units[1].pid = 3;
    units[1].status = 1;

    // Service 2: netd (Network Daemon - stub)
    k_strcpy((char*)units[2].name, "netd");
    k_strcpy((char*)units[2].command, "/bin/netd");
    units[2].enabled = 0;
    units[2].respawn = 0;
    units[2].pid = 0;
    units[2].status = 0;
}

void init_start_service(struct ServiceUnit* unit) {
    if (unit.enabled == 0) {
        return;
    }
    k_print("[kinit] Starting service '");
    k_print((char*)unit.name);
    k_print("' (command: ");
    k_print((char*)unit.command);
    k_print(") [PID ");
    k_print_dec((u64)unit.pid);
    k_print("]\n");
}

void init_supervisor_loop(struct ServiceUnit* units, int count) {
    k_print("[kinit] Reached multi-user.target. Entering supervisor event loop.\n");
    let loop_count = 0;
    while (loop_count < 3) {
        syscall0((u64)4); // sys_yield()
        loop_count = loop_count + 1;
    }
}

void kinit_main() {
    init_banner();
    let units = (struct ServiceUnit*)540672; // allocate in user space
    init_register_services(units);
    
    let i = 0;
    while (i < 3) {
        init_start_service(&units[i]);
        i = i + 1;
    }

    init_supervisor_loop(units, 3);
}
