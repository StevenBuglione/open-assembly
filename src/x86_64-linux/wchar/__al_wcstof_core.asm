; Convert a wide floating subject and return its raw floating representation.
bits 64
default rel

global __al_wcstof_core:function
extern __al_skip_wide_space:function
extern __al_strtof_core:function

section .text.__al_wcstof_core alloc exec nowrite progbits
__al_wcstof_core:
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 8
    mov rbx, rdi                ; original input
    mov r12, rsi                ; caller's end pointer
    mov r13d, edx               ; floating representation selector
    call __al_skip_wide_space
    mov r14, rax
    mov rdi, rax
    mov rsi, r12
    mov edx, r13d
    or edx, 4                   ; four-byte units
    call __al_strtof_core
    test r12, r12
    jz .return
    cmp [r12], r14
    jne .return
    mov [r12], rbx             ; no conversion includes skipped whitespace
.return:
    add rsp, 8
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
