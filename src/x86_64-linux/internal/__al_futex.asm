; Original Linux futex boundary for a 32-bit word, operation, and value.
; Initial lock and clear-TID operations use no timeout or secondary word.
bits 64
default rel

global __al_futex:function
extern __al_syscall:function

section .text.__al_futex alloc exec nowrite progbits
__al_futex:
    sub rsp, 8
    mov qword [rsp], 0
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    mov edi, 202                  ; __NR_futex
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
