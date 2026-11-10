; Decode kind/raw words (rdi, rsi, rdx) into significand, exponent, sign, class (rax, rdx, rcx, r8).
bits 64
default rel

global __al_fp_decode:function

section .text.__al_fp_decode alloc exec nowrite progbits
__al_fp_decode:
    test edi, edi
    jz .single
    cmp edi, 1
    je .double

    mov rax, rsi
    mov ecx, edx
    shr ecx, 15
    and ecx, 1
    and edx, 0x7fff
    test edx, edx
    jz .extended_small
    cmp edx, 0x7fff
    je .extended_large
    sub edx, 16446
    jmp .normal
.extended_small:
    mov edx, -16445
    jmp .small
.extended_large:
    xor edx, edx
    mov r9, rax
    shl r9, 1
    jz .infinite
    shl r9, 1
    jc .quiet
    jmp .signaling

.double:
    mov rax, rsi
    shl rax, 12
    shr rax, 12
    mov rcx, rsi
    shr rcx, 63
    shr rsi, 52
    and esi, 0x7ff
    test esi, esi
    jz .double_small
    cmp esi, 0x7ff
    je .double_large
    mov r9, 0x10000000000000
    or rax, r9
    lea edx, [rsi - 1075]
    jmp .normal
.double_small:
    mov edx, -1074
    jmp .small
.double_large:
    xor edx, edx
    test rax, rax
    jz .infinite
    shr rax, 52
    jc .quiet
    jmp .signaling

.single:
    mov eax, esi
    and eax, 0x7fffff
    mov ecx, esi
    shr ecx, 31
    shr esi, 23
    and esi, 0xff
    test esi, esi
    jz .single_small
    cmp esi, 0xff
    je .single_large
    or eax, 0x800000
    lea edx, [rsi - 150]
.normal:
    movsxd rdx, edx
    mov r8d, 2
    ret
.single_small:
    mov edx, -149
.small:
    movsxd rdx, edx
    mov r8d, 1
    test rax, rax
    jnz .done
    xor r8d, r8d
.done:
    ret
.single_large:
    xor edx, edx
    test eax, eax
    jz .infinite
    test eax, 0x400000
    jnz .quiet
.signaling:
    mov r8d, 5
    ret
.quiet:
    mov r8d, 4
    ret
.infinite:
    mov r8d, 3
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
