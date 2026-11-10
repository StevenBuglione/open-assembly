; Compare two vector entries in the active collation order.
bits 64
default rel

global __al_glob_compare:function
extern strcoll:function

section .text.__al_glob_compare alloc exec nowrite progbits
__al_glob_compare:
    sub rsp, 8
    mov rdi, [rdi]
    mov rsi, [rsi]
    call strcoll
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
