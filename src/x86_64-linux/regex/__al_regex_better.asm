; Compare subexpression spans for equal full matches. Earlier numbered
; groups take priority, and an empty participating match outranks absence.
; RDI candidate tags, RSI saved tags, RDX tag bytes, ECX character mode.
bits 64
default rel

global __al_regex_better:function
extern __al_regex_span_count:function

section .text.__al_regex_better alloc exec nowrite progbits
__al_regex_better:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r15d, ecx
    mov r14d, 16               ; the full match is already tied
.next:
    cmp r14, r13
    jae .keep
    mov r8, [rbx + r14 + 8]
    mov r9, [r12 + r14 + 8]
    cmp r8, -1
    je .candidate_absent
    cmp r9, -1
    je .replace
    test r15d, 1
    jnz .scalar_length
    sub r8, [rbx + r14]
    sub r9, [r12 + r14]
    jmp .compare
.scalar_length:
    mov rdi, [rbx + r14]
    mov rsi, r8
    call __al_regex_span_count
    mov [rsp], rax
    mov rdi, [r12 + r14]
    mov rsi, [r12 + r14 + 8]
    call __al_regex_span_count
    mov r8, [rsp]
    mov r9, rax
.compare:
    cmp r8, r9
    ja .replace
    jb .keep
    jmp .advance
.candidate_absent:
    cmp r9, -1
    jne .keep
.advance:
    add r14, 16
    jmp .next
.replace:
    mov eax, 1
    jmp .return
.keep:
    xor eax, eax
.return:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
