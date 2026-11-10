; Return the raw sign bit of the floating argument.
bits 64
default rel

global __al_signbitl:function

section .text.__al_signbitl alloc exec nowrite progbits
__al_signbitl:
    movzx eax, word [rsp + 16]
    shr eax, 15
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
