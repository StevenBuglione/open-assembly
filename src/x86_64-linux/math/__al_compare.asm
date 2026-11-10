; Return -1, 0, 1 or 2 for less, equal, greater or unordered.
bits 64
default rel

global __al_compare:function
extern __al_fp_compare:function

section .text.__al_compare alloc exec nowrite progbits
__al_compare:
    movq rcx, xmm1
    xor r8d, r8d
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_fp_compare
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
