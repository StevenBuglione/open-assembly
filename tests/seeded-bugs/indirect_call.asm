; Call an unanalyzable function pointer with an aligned stack.
bits 64
default rel

section .text
global seed_indirect_call:function
seed_indirect_call:
    sub rsp, 8
    call rdi
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
