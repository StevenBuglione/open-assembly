; Return with an allocated stack slot still below the return address.
bits 64
default rel

section .text
global seed_unbalanced_stack:function
seed_unbalanced_stack:
    sub rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
