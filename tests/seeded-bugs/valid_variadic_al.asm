; Accept a known vector argument count at an aligned variadic call.
; lint-variadic: external_printf
bits 64
default rel

section .text
global test_valid_variadic_al:function
extern external_printf
test_valid_variadic_al:
    sub rsp, 8
    xor eax, eax
    call external_printf
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
