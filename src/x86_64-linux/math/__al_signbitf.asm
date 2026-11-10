; Return the raw sign bit of the floating argument.
bits 64
default rel

global __al_signbitf:function

section .text.__al_signbitf alloc exec nowrite progbits
__al_signbitf:
    movd eax, xmm0
    shr eax, 31
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
