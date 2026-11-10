; Assemble in 32-bit mode inside an x86-64 object.
bits 32
default rel

section .text
global seed_wrong_bits:function
seed_wrong_bits:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
