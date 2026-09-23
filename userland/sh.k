// KrumpyOS Userland Shell (sh.k)

void sh_help() {
    k_print("KrumpyOS Userland Shell Commands:\n");
    k_print("  help        show this help list\n");
    k_print("  echo TEXT   display text\n");
    k_print("  ls          list ramdisk files\n");
    k_print("  cat FILE    display ramdisk file contents\n");
    k_print("  pipe        test IPC ring-buffer pipe syscall\n");
    k_print("  uptime      show system uptime via SYS_UPTIME syscall\n");
    k_print("  yield       yield time slice via SYS_YIELD syscall\n");
    k_print("  clear       clear terminal screen\n");
    k_print("  exit        exit user shell via SYS_EXIT syscall\n");
}

void sh_uptime() {
    let ticks = sys_uptime();
    let sec = ticks / (u64)100;
    let frac = ticks % (u64)100;
    k_print("uptime: ");
    k_print_dec(sec);
    k_print_char('.');
    if (frac < (u64)10) {
        k_print_char('0');
    }
    k_print_dec(frac);
    k_print("s (");
    k_print_dec(ticks);
    k_print(" ticks)\n");
}

void sh_ls() {
    k_print("Ramdisk Files:\n");
    k_print("  /system/bin/sh\n");
    k_print("  /system/bin/hello\n");
    k_print("  /etc/hostname\n");
    k_print("  /etc/version\n");
}

void sh_cat(char* filename) {
    let fd = sys_open(filename);
    if (fd < 0) {
        k_print("cat: file not found: ");
        k_print(filename);
        k_print_char('\n');
        return;
    }
    let buf = "                                                                                                                                ";
    let len = sys_write((char*)0, 0); // test read
    sys_close(fd);
}

void sh_test_pipe() {
    let fds = "01234567";
    let res = sys_pipe((int*)fds);
    if (res == 0) {
        k_print("IPC pipe created successfully [read_fd, write_fd]\n");
    } else {
        k_print("IPC pipe creation failed\n");
    }
}

void sh_execute(char* line) {
    if (line[0] == (char)0) {
        return;
    }
    if (k_streq(line, "help")) {
        sh_help();
        return;
    }
    if (k_streq(line, "ls")) {
        sh_ls();
        return;
    }
    if (k_streq(line, "pipe")) {
        sh_test_pipe();
        return;
    }
    if (k_streq(line, "uptime")) {
        sh_uptime();
        return;
    }
    if (k_streq(line, "yield")) {
        sys_yield();
        k_print("Yielded.\n");
        return;
    }
    if (k_streq(line, "clear")) {
        k_print_char((char)27);
        k_print("[2J");
        k_print_char((char)27);
        k_print("[H");
        return;
    }
    if (k_streq(line, "exit")) {
        k_print("User shell exiting...\n");
        sys_exit(0);
        return;
    }
    if (k_strstarts(line, "echo ")) {
        let text = (char*)((u64)line + (u64)5);
        k_print(text);
        k_print_char('\n');
        return;
    }
    if (k_strstarts(line, "cat ")) {
        let filename = (char*)((u64)line + (u64)4);
        sh_cat(filename);
        return;
    }
    k_print("sh: unknown command: ");
    k_print(line);
    k_print_char('\n');
}

void sh_main() {
    k_print("\nKrumpyOS Userland Shell (PID 1 / kinit)\n");
    k_print("Type 'help' for available userland commands.\n\n");

    let line_buf = "                                                                                                                                ";
    while (1 == 1) {
        k_print("user@krumpyos:$ ");
        let len = k_readline(line_buf, 128);
        if (len > 0) {
            sh_execute(line_buf);
        }
    }
}
