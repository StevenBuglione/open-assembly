; Jump through a register to an unanalyzable destination.
bits 64
default rel

section .text
global seed_indirect_jump:function
seed_indirect_jump:
    jmp rax

section .note.GNU-stack noalloc noexec nowrite progbits
