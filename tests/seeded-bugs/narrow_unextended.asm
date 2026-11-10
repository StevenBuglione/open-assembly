; Read all 64 bits of an incoming unsigned int argument.
; lint-args: edi:u32
bits 64
default rel

section .text
global seed_narrow_unextended:function
seed_narrow_unextended:
    mov rax, rdi
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
