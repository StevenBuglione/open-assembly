; Tail jump to a target outside the analyzable body.
bits 64
default rel

section .text
global seed_external_tail_jump:function
extern external_target
seed_external_tail_jump:
    jmp external_target

section .note.GNU-stack noalloc noexec nowrite progbits
