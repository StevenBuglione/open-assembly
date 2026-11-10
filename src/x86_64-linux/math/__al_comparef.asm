; Return -1, 0, 1 or 2 for less, equal, greater or unordered.
bits 64
default rel

global __al_comparef:function
extern __al_fp_compare:function

section .text.__al_comparef alloc exec nowrite progbits
__al_comparef:
    movd ecx, xmm1
    xor r8d, r8d
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_fp_compare
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
