; Original integer scan assignment. rdi = pointer, rsi = size, rdx = bits.
bits 64
default rel

global __al_scan_store:function

section .text.__al_scan_store alloc exec nowrite progbits
__al_scan_store:
    cmp rsi, 8
    je .word64
    cmp rsi, 4
    je .word32
    cmp rsi, 2
    je .word16
    mov [rdi], dl
    ret
.word16:
    mov [rdi], dx
    ret
.word32:
    mov [rdi], edx
    ret
.word64:
    mov [rdi], rdx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
