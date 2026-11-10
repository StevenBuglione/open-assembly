; Attempt a privileged halt in a user-space function.
bits 64
default rel

section .text
global seed_privileged_instruction:function
seed_privileged_instruction:
    hlt
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
