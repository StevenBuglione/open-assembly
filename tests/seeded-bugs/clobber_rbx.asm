; Modify the caller's RBX through integer arithmetic.
bits 64
default rel

section .text
global seed_clobber_rbx:function
seed_clobber_rbx:
    add rbx, 1
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
