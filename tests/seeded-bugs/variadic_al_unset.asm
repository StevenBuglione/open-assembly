; Call a variadic function with AL still unspecified.
; lint-variadic: external_printf
bits 64
default rel

section .text
global seed_variadic_al_unset:function
extern external_printf
seed_variadic_al_unset:
    sub rsp, 8
    call external_printf
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
