.code64
.section .text

.globl syscall0
syscall0:
    movq %rdi, %rax
    syscall
    ret

.globl syscall1
syscall1:
    movq %rdi, %rax
    movq %rsi, %rdi
    syscall
    ret

.globl syscall2
syscall2:
    movq %rdi, %rax
    movq %rsi, %rdi
    movq %rdx, %rsi
    syscall
    ret

.globl syscall3
syscall3:
    movq %rdi, %rax
    movq %rsi, %rdi
    movq %rdx, %rsi
    movq %rcx, %rdx
    syscall
    ret
