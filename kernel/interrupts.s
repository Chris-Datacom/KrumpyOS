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

    mov $6, %rdi
    lea invalid_opcode_stub(%rip), %rsi
    call set_idt_entry

    mov $8, %rdi
    lea double_fault_stub(%rip), %rsi
    call set_idt_entry

    mov $13, %rdi
    lea gpf_stub(%rip), %rsi
    call set_idt_entry

    mov $14, %rdi
    lea page_fault_stub(%rip), %rsi
    call set_idt_entry

    mov $32, %rdi
    lea timer_stub(%rip), %rsi
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

.globl invalid_opcode_stub
invalid_opcode_stub:
    pushq $0
    pushq $6
    jmp exception_common

.globl double_fault_stub
double_fault_stub:
    pushq $8
    jmp exception_common

.globl gpf_stub
gpf_stub:
    pushq $13
    jmp exception_common

.globl page_fault_stub
page_fault_stub:
    pushq $14
    jmp exception_common

.globl timer_stub
timer_stub:
    pushq $0
    pushq $32
    jmp interrupt_common

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
    call k_exception_dispatch

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

.globl interrupt_common
interrupt_common:
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
    call k_interrupt_dispatch

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

.globl switch_context
switch_context:
    pushq %rbx
    pushq %rbp
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15

    movq %rsp, (%rdi)
    movq %rsi, %rsp

    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbp
    popq %rbx
    ret

.globl setup_syscall_msrs
setup_syscall_msrs:
    /* IA32_EFER (0xC0000080): enable SCE (bit 0) */
    movl $0xc0000080, %ecx
    rdmsr
    orl $1, %eax
    wrmsr

    /* IA32_STAR (0xC0000081): kernel CS = 0x18, user CS = 0x20/0x2B */
    movl $0xc0000081, %ecx
    xorl %eax, %eax
    movl $0x00200018, %edx
    wrmsr

    /* IA32_LSTAR (0xC0000082): target RIP for syscall */
    movl $0xc0000082, %ecx
    lea syscall_entry(%rip), %rax
    movq %rax, %rdx
    shrq $32, %rdx
    wrmsr

    /* IA32_FMASK (0xC0000084): mask RFLAGS bits (e.g. IF = 0x200) */
    movl $0xc0000084, %ecx
    movl $0x200, %eax
    xorl %edx, %edx
    wrmsr
    ret

.globl syscall_entry
syscall_entry:
    /* Upon entry:
       RCX = user RIP
       R11 = user RFLAGS
       RAX = syscall number
       RDI = arg1, RSI = arg2, RDX = arg3, R10 = arg4, R8 = arg5, R9 = arg6
    */
    /* Swap to kernel stack */
    movq %rsp, %r12
    movq $0x80000, %rsp

    pushq %r12          /* save user RSP */
    pushq %r11          /* save user RFLAGS */
    pushq %rcx          /* save user RIP */
    pushq %rbx
    pushq %rbp
    pushq %r13
    pushq %r14
    pushq %r15

    cld
    /* Call k_syscall_dispatch(syscall_num: %rdi, a1: %rsi, a2: %rdx, a3: %rcx, a4: %r8, a5: %r9) */
    movq %r9, %r9       /* a5 */
    movq %r8, %r8       /* a4 */
    movq %r10, %rcx     /* a3 */
    movq %rdx, %rdx     /* a2 */
    movq %rsi, %rsi     /* a1 */
    movq %rax, %rdi     /* syscall_num */
    call k_syscall_dispatch

    popq %r15
    popq %r14
    popq %r13
    popq %rbp
    popq %rbx
    popq %rcx          /* restore user RIP into RCX */
    popq %r11          /* restore user RFLAGS into R11 */
    popq %rsp          /* restore user RSP */

    sysretq

.globl user_mode_enter
user_mode_enter:
    /* user_mode_enter(entry_point: %rdi, user_stack_top: %rsi) */
    pushq $0x20         /* user SS */
    pushq %rsi          /* user RSP */
    pushfq
    popq %rax
    orq $0x200, %rax    /* IF = 1 */
    pushq %rax          /* user RFLAGS */
    pushq $0x18         /* user CS */
    pushq %rdi          /* user RIP */
    iretq

idt_descriptor:
    .word 256 * 16 - 1
    .quad 0x81000


