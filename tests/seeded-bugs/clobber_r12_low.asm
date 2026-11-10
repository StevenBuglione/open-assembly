; Clobber R12 through a zero-extending 32-bit write.
bits 64
default rel

section .text
global seed_clobber_r12_low:function
seed_clobber_r12_low:
    xor r12d, r12d
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
