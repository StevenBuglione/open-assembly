; Consume the clobbered R11 value after a correctly marshaled syscall.
bits 64
default rel

section .text
global seed_syscall_uses_r11:function
seed_syscall_uses_r11:
    mov r10, rcx
    syscall
    mov rax, r11
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
