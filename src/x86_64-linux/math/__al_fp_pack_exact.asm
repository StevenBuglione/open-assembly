; Encode finite kind/significand/exponent/sign (rdi, rsi, rdx, rcx), returning raw words in rax and rdx.
bits 64
default rel

global __al_fp_pack_exact:function

section .text.__al_fp_pack_exact alloc exec nowrite progbits
__al_fp_pack_exact:
    mov r8, rcx
    mov rax, rsi
    xor r9d, r9d
    test rax, rax
    jz .apply_sign

    bsr r10, rax
    add edx, r10d
    test edi, edi
    jz .single
    cmp edi, 1
    je .double
    cmp edx, -16382
    jl .extended_small
    lea r9d, [rdx + 16383]
    mov ecx, 63
    sub ecx, r10d
    shl rax, cl
    jmp .apply_sign
.extended_small:
    lea ecx, [rdx + 16445]
    jmp .small

.double:
    cmp edx, -1022
    jl .double_small
    lea r9d, [rdx + 1023]
    mov ecx, 52
    sub ecx, r10d
    shl rax, cl
    shl rax, 12
    shr rax, 12
    shl r9, 52
    or rax, r9
    jmp .apply_sign
.double_small:
    lea ecx, [rdx + 1074]
    jmp .small

.single:
    cmp edx, -126
    jl .single_small
    lea r9d, [rdx + 127]
    mov ecx, 23
    sub ecx, r10d
    shl eax, cl
    and eax, 0x7fffff
    shl r9d, 23
    or eax, r9d
    jmp .apply_sign
.single_small:
    lea ecx, [rdx + 149]
.small:
    sub ecx, r10d
    js .small_right
    shl rax, cl
    jmp .apply_sign
.small_right:
    neg ecx
    shr rax, cl

.apply_sign:
    xor edx, edx
    test edi, edi
    jz .single_sign
    cmp edi, 1
    je .double_sign
    mov edx, r8d
    shl edx, 15
    or edx, r9d
    ret
.double_sign:
    shl r8, 63
    or rax, r8
    ret
.single_sign:
    shl r8d, 31
    or eax, r8d
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
