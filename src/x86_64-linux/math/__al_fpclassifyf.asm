; Classify the argument by encoding without arithmetic or exceptions.
bits 64
default rel

global __al_fpclassifyf:function
extern __al_fp_decode:function

section .text.__al_fpclassifyf alloc exec nowrite progbits
__al_fpclassifyf:
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_fp_decode
    add rsp, 8
    xor eax, eax
    cmp r8d, 4
    jae .done
    mov eax, 1
    cmp r8d, 3
    je .done
    lea eax, [r8 + 2]
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
