; Overwrite the return address through a stack-relative operand.
bits 64
default rel

section .text
global seed_return_address_write:function
seed_return_address_write:
    mov [rsp], rax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
