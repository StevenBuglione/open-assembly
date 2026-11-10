; Original futex publication wake for an initialized or abandoned control.
bits 64
default rel

global __al_once_wake:function
extern __al_futex:function
extern __al_panic:function

section .text.__al_once_wake alloc exec nowrite progbits
__al_once_wake:
    sub rsp, 8
    mov esi, 129                  ; FUTEX_WAKE_PRIVATE
    mov edx, 2147483647           ; all waiters
    call __al_futex
    test rax, rax
    js .failed
    add rsp, 8
    ret

.failed:
    lea rdi, [rel wake_failure]
    mov esi, 32
    call __al_panic
    ud2

section .rodata.__al_once_wake alloc noexec nowrite progbits
wake_failure: db "open-assembly: once wake failed", 10

section .note.GNU-stack noalloc noexec nowrite progbits
