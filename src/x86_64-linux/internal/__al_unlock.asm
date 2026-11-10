; Original runtime unlock. The exchange publishes all protected writes.
bits 64
default rel

global __al_unlock:function
extern __al_futex:function
extern __al_panic:function

section .text.__al_unlock alloc exec nowrite progbits
__al_unlock:
    xor eax, eax
    xchg dword [rdi], eax
    cmp eax, 1
    je .done

    sub rsp, 8
    cmp eax, 2
    jne .failure
    mov esi, 129                  ; FUTEX_WAKE_PRIVATE
    mov edx, 1
    call __al_futex
    test rax, rax
    js .failure
    add rsp, 8
.done:
    ret
.failure:
    lea rdi, [rel unlock_error]
    mov esi, 43
    call __al_panic
    ud2

section .rodata.__al_unlock alloc noexec nowrite progbits
unlock_error: db "open-assembly: cannot unlock runtime futex", 10

section .note.GNU-stack noalloc noexec nowrite progbits
