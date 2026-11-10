; Original allocator corruption diagnostic. No return.
bits 64
default rel

global __al_heap_bad:function
extern __al_panic:function

section .text.__al_heap_bad alloc exec nowrite progbits
__al_heap_bad:
    push rbp
    mov rbp, rsp
    lea rdi, [rel failure]
    mov esi, 42
    call __al_panic
    ud2

section .rodata.__al_heap_bad alloc noexec nowrite progbits
failure:
    db "open-assembly: allocator metadata damaged", 10

section .note.GNU-stack noalloc noexec nowrite progbits
