; Return while popping a caller-owned argument slot.
bits 64
default rel

section .text
global seed_callee_pops_argument:function
seed_callee_pops_argument:
    ret 8

section .note.GNU-stack noalloc noexec nowrite progbits
