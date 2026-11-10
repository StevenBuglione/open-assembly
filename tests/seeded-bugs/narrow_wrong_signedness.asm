; Zero-extend a signed argument before consuming its 64-bit value.
; lint-args: edi:s32
bits 64
default rel

section .text
global seed_narrow_wrong_signedness:function
seed_narrow_wrong_signedness:
    mov edi, edi
    mov rax, rdi
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
