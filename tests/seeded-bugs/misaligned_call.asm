; Call a direct target at the misaligned entry stack depth.
bits 64
default rel

section .text
global seed_misaligned_call:function
extern external_target
seed_misaligned_call:
    call external_target
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
