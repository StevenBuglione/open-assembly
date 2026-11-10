bits 64
default rel

global main:function

section .text
main:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
