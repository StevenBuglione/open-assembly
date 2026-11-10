; Original scanner consume. rdi = context with a code unit already peeked.
bits 64
default rel

global __al_scan_take:function

section .text.__al_scan_take alloc exec nowrite progbits
__al_scan_take:
    inc qword [rdi + 16]
    cmp qword [rdi + 8], 0
    je .byte_string
    cmp qword [rdi + 8], 2
    jne .clear
    add qword [rdi], 4
    jmp .clear
.byte_string:
    inc qword [rdi]
.clear:
    mov qword [rdi + 24], -2
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
