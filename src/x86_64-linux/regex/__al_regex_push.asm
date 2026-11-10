; Push an alternative instruction, input cursor and machine state.
; RDI run context, RSI alternative instruction, RDX input cursor.
bits 64
default rel

global __al_regex_push:function
extern realloc:function
extern memcpy:function

section .text.__al_regex_push alloc exec nowrite progbits
__al_regex_push:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, [rbx + 104]
    mov r15, r14
    add r15, [rbx + 112]
    jc .no_space
    cmp r15, [rbx + 96]
    jbe .store
    mov rsi, [rbx + 96]
    add rsi, rsi
    jc .exact
    cmp rsi, 128
    jae .check
    mov esi, 128
.check:
    cmp rsi, r15
    jae .allocate
.exact:
    mov rsi, r15
.allocate:
    mov [rsp], rsi
    mov rdi, [rbx + 88]
    call realloc
    test rax, rax
    jz .no_space
    mov [rbx + 88], rax
    mov rax, [rsp]
    mov [rbx + 96], rax
.store:
    mov rdi, [rbx + 88]
    add rdi, r14
    mov [rdi], r12
    mov [rdi + 8], r13
    add rdi, 16
    mov rsi, [rbx + 56]
    mov rdx, [rbx + 64]
    call memcpy
    mov [rbx + 104], r15
    xor eax, eax
    jmp .return
.no_space:
    mov eax, 12                ; REG_ESPACE
.return:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
