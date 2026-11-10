; Keep Linux syscall argument four in the System V register RCX.
bits 64
default rel

section .text
global seed_syscall_arg4_in_rcx:function
seed_syscall_arg4_in_rcx:
    syscall
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
