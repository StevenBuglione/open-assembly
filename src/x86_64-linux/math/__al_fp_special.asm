; Construct kind edi, selector esi (0 infinity, 1 max finite, 2 quiet NaN), sign edx.
bits 64
default rel

global __al_fp_special:function

section .text.__al_fp_special alloc exec nowrite progbits
__al_fp_special:
    mov r8d, edx
    xor edx, edx
    test edi, edi
    jz .single
    cmp edi, 1
    je .double

    mov rax, 0x8000000000000000
    mov edx, 0x7fff
    test esi, esi
    jz .extended_sign
    cmp esi, 1
    jne .extended_nan
    dec edx
    mov rax, -1
    jmp .extended_sign
.extended_nan:
    mov rax, 0xc000000000000000
.extended_sign:
    shl r8d, 15
    or edx, r8d
    ret

.double:
    mov rax, 0x7ff0000000000000
    test esi, esi
    jz .double_sign
    cmp esi, 1
    jne .double_nan
    dec rax
    jmp .double_sign
.double_nan:
    mov rax, 0x7ff8000000000000
.double_sign:
    shl r8, 63
    or rax, r8
    ret

.single:
    mov eax, 0x7f800000
    test esi, esi
    jz .single_sign
    cmp esi, 1
    jne .single_nan
    dec eax
    jmp .single_sign
.single_nan:
    or eax, 0x400000
.single_sign:
    shl r8d, 31
    or eax, r8d
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
