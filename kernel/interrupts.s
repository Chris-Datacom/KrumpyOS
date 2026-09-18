.section .text

.globl install_idt
install_idt:
    mov $0x81000, %rdi
    xor %eax, %eax
    mov $512, %ecx
    rep stosq

    lea divide_by_zero_stub(%rip), %rax
    mov $0x81000, %rcx
    movw %ax, (%rcx)
    movw $0x18, 2(%rcx)
    movb $0, 4(%rcx)
    movb $0x8e, 5(%rcx)
    shr $16, %rax
    movw %ax, 6(%rcx)
    shr $16, %rax
    movl %eax, 8(%rcx)
    movl $0, 12(%rcx)

    lea breakpoint_stub(%rip), %rax
    mov $0x81030, %rcx
    movw %ax, (%rcx)
    movw $0x18, 2(%rcx)
    movb $0, 4(%rcx)
    movb $0x8e, 5(%rcx)
    shr $16, %rax
    movw %ax, 6(%rcx)
    shr $16, %rax
    movl %eax, 8(%rcx)
    movl $0, 12(%rcx)

    lidt idt_descriptor(%rip)
    ret

.globl divide_by_zero_stub
divide_by_zero_stub:
    pushq $0
    pushq $0
    jmp exception_common

.globl breakpoint_stub
breakpoint_stub:
    pushq $0
    pushq $3
    jmp exception_common

.globl exception_with_error_code
exception_with_error_code:
    pushq $13
    jmp exception_common

.globl exception_common
exception_common:
    mov (%rsp), %rdi
    mov 8(%rsp), %rsi
    call exception_dispatch
    add $16, %rsp
    iretq

exception_dispatch:
    cmp $0, %rdi
    je .handle_divide_by_zero
    cmp $3, %rdi
    je .handle_breakpoint
    lea unknown_exception_message(%rip), %rdi
    call serial_write
    ret

.handle_divide_by_zero:
    lea divide_by_zero_message(%rip), %rdi
    call serial_write
    ret

.handle_breakpoint:
    lea breakpoint_message(%rip), %rdi
    call serial_write
    ret

.section .rodata
unknown_exception_message:
    .asciz "exception=?\n"
divide_by_zero_message:
    .asciz "exception=0\n"
breakpoint_message:
    .asciz "exception=3\n"

idt_descriptor:
    .word 256 * 16 - 1
    .quad 0x81000
