; Encode a scalar or its null destination equivalent with default slot ecx.
bits 64
default rel

global __al_wcr_scalar:function
extern __al_mbstate_default:function
extern __al_mb_encode:function

section .text.__al_wcr_scalar alloc exec nowrite progbits
__al_wcr_scalar:
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13d, esi
    mov r14, rdx
    test r14, r14
    jnz .destination
    mov edi, ecx
    call __al_mbstate_default
    mov r14, rax
.destination:
    test r12, r12
    jnz .encode
    xor r13d, r13d
.encode:
    mov rdi, r12
    mov esi, r13d
    mov rdx, r14
    call __al_mb_encode
    pop r14
    pop r13
    pop r12
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
