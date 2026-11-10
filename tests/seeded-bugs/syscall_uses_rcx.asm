; Consume the clobbered RCX value after a correctly marshaled syscall.
bits 64
default rel

section .text
global seed_syscall_uses_rcx:function
seed_syscall_uses_rcx:
    mov r10, rcx
    syscall
    mov rax, rcx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
