; Accept signed and unsigned extension before full-width consumption.
; lint-args: edi:s32, esi:u32
bits 64
default rel

section .text
global test_valid_narrow_arguments:function
test_valid_narrow_arguments:
    movsxd rdi, edi
    mov esi, esi
    mov rax, rdi
    add rax, rsi
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
