; Issue a Linux syscall without access to the private boundary.
bits 64
default rel

section .text
global seed_syscall_public:function
seed_syscall_public:
    mov r10, rcx
    syscall
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
