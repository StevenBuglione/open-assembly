; Accept a private syscall with argument four marshaled through R10.
bits 64
default rel

section .text
global test_valid_private_syscall:function
test_valid_private_syscall:
    mov r10, rcx
    syscall
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
