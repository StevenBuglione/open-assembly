; Quiet an encoded NaN (rdi kind, rsi raw low, rdx raw high).
bits 64
default rel

global __al_fp_quiet:function

section .text.__al_fp_quiet alloc exec nowrite progbits
__al_fp_quiet:
    mov rax, rsi
    test edi, edi
    jz .single
    cmp edi, 1
    je .double
    mov r8, 0x4000000000000000
    or rax, r8
    ret
.double:
    mov r8, 0x8000000000000
    or rax, r8
    ret
.single:
    or eax, 0x400000
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
