; Original environment name validator. rdi = string, rsi != 0 allows equals.
; rax = positive name length or 0, rdx = address of allowed equals or 0.
bits 64
default rel

global __al_env_name:function

section .text.__al_env_name alloc exec nowrite progbits
__al_env_name:
    xor eax, eax
    xor edx, edx
    test rdi, rdi
    jz .done
.next:
    mov cl, [rdi + rax]
    test cl, cl
    jz .done
    cmp cl, 61                    ; '='
    je .equals
    inc rax
    jmp .next
.equals:
    test rsi, rsi
    jz .invalid
    lea rdx, [rdi + rax]
.done:
    ret
.invalid:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
