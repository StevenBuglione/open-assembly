; Encode already rounded kind, significand, biased exponent and sign in rdi/rsi/rdx/rcx.
bits 64
default rel

global __al_fp_pack_biased:function

section .text.__al_fp_pack_biased alloc exec nowrite progbits
__al_fp_pack_biased:
    mov rax, rsi
    test edi, edi
    jz .single
    cmp edi, 1
    je .double
    shl ecx, 15
    or edx, ecx
    ret
.double:
    shl rax, 12
    shr rax, 12
    shl rdx, 52
    shl rcx, 63
    or rax, rdx
    or rax, rcx
    xor edx, edx
    ret
.single:
    and eax, 0x7fffff
    shl edx, 23
    shl ecx, 31
    or eax, edx
    or eax, ecx
    xor edx, edx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
