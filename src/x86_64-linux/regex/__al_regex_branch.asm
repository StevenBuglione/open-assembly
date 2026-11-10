; Commit a group's pending atom. EDX one also completes its alternatives.
; RDI program, RSI group frame. Return the committed or completed node.
bits 64
default rel

global __al_regex_branch:function
extern __al_regex_node:function

section .text.__al_regex_branch alloc exec nowrite progbits
__al_regex_branch:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13d, edx
    mov rax, [r12]
    mov rcx, [r12 + 8]
    test rcx, rcx
    jz .complete
    mov qword [r12 + 8], 0
    test rax, rax
    jz .first
    mov rdi, rbx
    mov esi, 7                 ; concatenation
    mov rdx, rax
    xor r8d, r8d
    xor r9d, r9d
    call __al_regex_node
    jmp .commit
.first:
    mov rax, rcx
.commit:
    mov [r12], rax
.complete:
    test r13d, r13d
    jz .return
    test rax, rax
    jnz .alternate
    mov rdi, rbx
    xor esi, esi               ; empty expression
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_regex_node
.alternate:
    mov rdx, [r12 + 16]
    test rdx, rdx
    jz .return
    mov rdi, rbx
    mov esi, 8                 ; alternation
    mov rcx, rax
    xor r8d, r8d
    xor r9d, r9d
    call __al_regex_node
.return:
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
