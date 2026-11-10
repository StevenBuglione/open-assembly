; Set a variadic vector argument count above eight.
; lint-variadic: external_printf
bits 64
default rel

section .text
global seed_variadic_al_out_of_range:function
extern external_printf
seed_variadic_al_out_of_range:
    sub rsp, 8
    mov al, 9
    call external_printf
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
