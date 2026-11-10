; Original implementation. See docs/adr/0002-runtime-abi.md.
bits 64
default rel

global __al_syscall:function

section .text.__al_syscall alloc exec nowrite progbits
__al_syscall:
    ; SysV: (number, arg1, arg2, arg3, arg4, arg5, arg6).
    ; Linux: rax, rdi, rsi, rdx, r10, r8, r9.
    mov rax, rdi
    mov rdi, rsi
    mov rsi, rdx
    mov rdx, rcx
    mov r10, r8
    mov r8, r9
    mov r9, [rsp + 8]
    syscall
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
