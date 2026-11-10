; Classify the argument by encoding without arithmetic or exceptions.
bits 64
default rel

global __al_fpclassify:function
extern __al_fp_decode:function

section .text.__al_fpclassify alloc exec nowrite progbits
__al_fpclassify:
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
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
