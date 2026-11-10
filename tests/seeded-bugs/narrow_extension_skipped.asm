; Read a signed narrow argument after one path skips its extension.
; lint-args: edi:s32
bits 64
default rel

section .text
global seed_narrow_extension_skipped:function
seed_narrow_extension_skipped:
    test rsi, rsi
    jz .use
    movsxd rdi, edi
.use:
    mov rax, rdi
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
