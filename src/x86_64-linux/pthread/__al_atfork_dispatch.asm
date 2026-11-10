; Invoke one phase of an immutable, published at-fork callback prefix.
; EDI phase (zero prepare, one parent, two child), ESI snapshot count.
bits 64
default rel

global __al_atfork_dispatch:function
extern __al_atfork_state:data

section .text.__al_atfork_dispatch alloc exec nowrite progbits
__al_atfork_dispatch:
    test esi, esi
    jz .empty
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 8
    lea rbx, [rel __al_atfork_state]
    mov r13d, esi
    mov r12d, edi
    mov r14d, 3
    test edi, edi
    jnz .entry
    lea eax, [r13 - 1]
    lea r12d, [rax + rax * 2]
    mov r14, -3
.entry:
    mov rax, r12
    mov rax, [rbx + rax * 8 + 8]
    test rax, rax
    jz .next
    call rax
.next:
    add r12, r14
    dec r13d
    jnz .entry
    add rsp, 8
    pop r14
    pop r13
    pop r12
    pop rbx
.empty:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
