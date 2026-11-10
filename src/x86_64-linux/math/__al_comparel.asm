; Return -1, 0, 1 or 2 for less, equal, greater or unordered.
bits 64
default rel

global __al_comparel:function
extern __al_fp_compare:function

section .text.__al_comparel alloc exec nowrite progbits
__al_comparel:
    mov rcx, [rsp + 24]
    movzx r8d, word [rsp + 32]
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 8
    call __al_fp_compare
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
