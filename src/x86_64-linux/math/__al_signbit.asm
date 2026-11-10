; Return the raw sign bit of the floating argument.
bits 64
default rel

global __al_signbit:function

section .text.__al_signbit alloc exec nowrite progbits
__al_signbit:
    movq rax, xmm0
    shr rax, 63
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
