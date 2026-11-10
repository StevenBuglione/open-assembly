; Balance the stack while restoring R14 from a caller-saved register.
bits 64
default rel

section .text
global seed_clobber_r14_pop:function
seed_clobber_r14_pop:
    push rax
    pop r14
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
