; Original scanner consume. rdi = context with a byte already peeked.
bits 64
default rel

global __al_scan_take:function

section .text.__al_scan_take alloc exec nowrite progbits
__al_scan_take:
    inc qword [rdi + 16]
    cmp qword [rdi + 8], 0
    jne .clear
    inc qword [rdi]
.clear:
    mov qword [rdi + 24], -2
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
