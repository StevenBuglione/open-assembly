; Convert a wide integer with the shared LP64 scanner and locale whitespace.
bits 64
default rel

global __al_wcstox:function
extern __al_skip_wide_space:function
extern __al_strtox:function

section .text.__al_wcstox alloc exec nowrite progbits
__al_wcstox:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi                ; original input
    mov r12, rsi                ; caller's end pointer
    mov r13, rdx                ; base
    mov r14, rdi                ; first candidate code point
    mov r15d, ecx               ; unsigned flag
    test r13, r13
    jz .space
    cmp r13, 2
    jb .scan
    cmp r13, 36
    ja .scan
.space:
    call __al_skip_wide_space
    mov r14, rax
.scan:
    mov rdi, r14
    mov rsi, r12
    mov rdx, r13
    mov ecx, r15d
    or ecx, 4                   ; four-byte units
    call __al_strtox
    test r12, r12
    jz .return
    cmp [r12], r14
    jne .return
    mov [r12], rbx             ; no conversion includes skipped whitespace
.return:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
