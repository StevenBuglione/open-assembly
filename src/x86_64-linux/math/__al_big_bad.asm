; Original internal bound-failure diagnostic.
bits 64
default rel

global __al_big_bad:function
extern __al_panic:function

section .text.__al_big_bad alloc exec nowrite progbits
__al_big_bad:
    push rbp
    mov rbp, rsp
    lea rdi, [rel message]
    mov esi, 40
    call __al_panic
    ud2

section .rodata.__al_big_bad alloc noexec nowrite progbits
message:
    db "open-assembly: bignum capacity exceeded", 10

section .note.GNU-stack noalloc noexec nowrite progbits
