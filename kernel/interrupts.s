.code64
.section .text

.globl install_idt
install_idt:
    mov $0x81000, %rdi
    xor %eax, %eax
    mov $512, %ecx
    rep stosq

    mov $0, %rdi
    lea divide_by_zero_stub(%rip), %rsi
    call set_idt_entry

    mov $3, %rdi
    lea breakpoint_stub(%rip), %rsi
    call set_idt_entry

    mov $13, %rdi
    lea gpf_stub(%rip), %rsi
    call set_idt_entry

    lidt idt_descriptor(%rip)
    ret

/* set_idt_entry(vector: %rdi, handler: %rsi) */
set_idt_entry:
    shl $4, %rdi
    add $0x81000, %rdi
    movw %si, (%rdi)
    movw $0x18, 2(%rdi)
    movb $0, 4(%rdi)
    movb $0x8e, 5(%rdi)
    mov %rsi, %rax
    shr $16, %rax
    movw %ax, 6(%rdi)
    shr $16, %rax
    movl %eax, 8(%rdi)
    movl $0, 12(%rdi)
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

.globl gpf_stub
gpf_stub:
    pushq $13
    jmp exception_common

.globl exception_with_error_code
exception_with_error_code:
    pushq $13
    jmp exception_common

.globl exception_common
exception_common:
    pushq %rax
    pushq %rcx
    pushq %rdx
    pushq %rbx
    pushq %rbp
    pushq %rsi
    pushq %rdi
    pushq %r8
    pushq %r9
    pushq %r10
    pushq %r11
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15

    cld

    mov 120(%rsp), %rdi
    mov 128(%rsp), %rsi
    mov %rsp, %rdx
    call exception_dispatch

    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %r11
    popq %r10
    popq %r9
    popq %r8
    popq %rdi
    popq %rsi
    popq %rbp
    popq %rbx
    popq %rdx
    popq %rcx
    popq %rax

    addq $16, %rsp
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

serial_write:
    mov $0x3f8, %dx
.Lserial_loop:
    movzbq (%rdi), %rax
    test %al, %al
    jz .Lserial_done
    out %al, (%dx)
    inc %rdi
    jmp .Lserial_loop
.Lserial_done:
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

