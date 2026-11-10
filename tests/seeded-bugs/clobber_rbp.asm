; Replace RBP without saving the caller's frame pointer.
bits 64
default rel

section .text
global seed_clobber_rbp:function
seed_clobber_rbp:
    mov rbp, rsp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
