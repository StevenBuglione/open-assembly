; Read a format code unit using the one- or four-byte input stride.
bits 64
default rel

global __al_fmt_unit:function

section .text.__al_fmt_unit alloc exec nowrite progbits
__al_fmt_unit:
    cmp esi, 4
    je .wide
    movzx eax, byte [rdi]
    ret
.wide:
    mov eax, [rdi]
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
