.code16
.section .text
.globl _start
_start:
    cli
    xor %ax, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %ss
    mov $0x7c00, %sp

    /* Save boot drive ID passed by BIOS / Apple CSM in %dl */
    mov %dl, boot_drive

    /* Enable Fast A20 gate via System Control Port A (0x92) */
    inb $0x92, %al
    orb $2, %al
    andb $0xfe, %al
    outb %al, $0x92

    /* Read kernel sectors from USB boot drive into 0x10000 */
    mov $0x1000, %ax
    mov %ax, %es
    mov $0, %bx
    mov $dap, %si
    mov $0x42, %ah
    mov boot_drive, %dl
    int $0x13
    jc disk_error

    lgdt gdt_descriptor
    mov %cr0, %eax
    or $1, %eax
    mov %eax, %cr0
    ljmp $0x08, $protected_mode

disk_error:
    hlt
    jmp disk_error

.code32
protected_mode:
    mov $0x10, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %ss
    mov $0x80000, %esp

    mov $0x9000, %edi
    xor %eax, %eax
    mov $4096, %ecx
    rep stosl
    mov $0xa000, %eax
    or $3, %eax
    mov %eax, 0x9000
    mov $0xb000, %eax
    or $3, %eax
    mov %eax, 0xa000
    mov $0x83, %eax
    mov %eax, 0xb000

    mov $0x9000, %eax
    mov %eax, %cr3
    mov %cr4, %eax
    or $0x20, %eax
    mov %eax, %cr4
    mov $0xc0000080, %ecx
    rdmsr
    or $0x100, %eax
    wrmsr
    mov %cr0, %eax
    or $0x80000000, %eax
    mov %eax, %cr0
    lgdt gdt64_descriptor
    ljmp $0x18, $long_mode

.code64
long_mode:
    mov $0x20, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %ss
    mov $0x80000, %rsp
    mov $0x10000, %rax
    call *%rax
#ifdef TEST_DIVZERO
    xor %rax, %rax
    xor %rdx, %rdx
    div %rax
#endif
halt:
    hlt
    jmp halt

.align 8
boot_drive:
    .byte 0x80

.align 8
dap:
    .byte 0x10, 0
    .word 64
    .word 0
    .word 0x1000
    .quad 1

.align 8
gdt:
    .quad 0
    .quad 0x00cf9a000000ffff
    .quad 0x00cf92000000ffff
    .quad 0x00af9a000000ffff
    .quad 0x00af92000000ffff
gdt_descriptor:
    .word gdt_descriptor - gdt - 1
    .long gdt
gdt64_descriptor:
    .word gdt64_descriptor - gdt - 1
    .long gdt

.org 510
.word 0xaa55
