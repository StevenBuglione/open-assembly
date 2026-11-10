; Emit 32-byte instructions from a parsed AST, using heap traversal frames.
; RDI compiled object, RSI AST root. Return zero or REG_ESPACE.
bits 64
default rel

global __al_regex_emit:function
extern calloc:function

section .text.__al_regex_emit alloc exec nowrite progbits
__al_regex_emit:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12, rsi
    mov rdi, [rbx + 64]
    mov rax, rdi
    shr rax, 62
    jnz .no_space
    lea rdi, [rdi * 4 + 1]       ; at most four instructions per AST node
    mov esi, 32
    call calloc
    test rax, rax
    jz .no_space
    mov [rbx + 8], rax
    mov r15, rax
    mov r13, [rbx + 72]
    mov r14, r13
    mov rax, r12
    jmp .load_frame
.push_child:
    add r14, 32
.load_frame:
    mov [r14], rax
    mov qword [r14 + 8], 0
.next:
    mov rsi, [r14]
    mov eax, [rsi]
    test eax, eax
    jz .pop
    cmp eax, 6
    jbe .atom
    cmp eax, 7
    je .concatenation
    cmp eax, 8
    je .alternation
    cmp eax, 9
    je .capture
    jmp .repeat
.atom:
    movdqu xmm0, [rsi]
    movdqu xmm1, [rsi + 16]
    movdqu [r15], xmm0
    movdqu [r15 + 16], xmm1
    add r15, 32
    jmp .pop
.concatenation:
    cmp qword [r14 + 8], 0
    jne .second
    mov qword [r14 + 8], 1
    mov rax, [rsi + 8]
    jmp .push_child
.second:
    mov rax, [rsi + 16]
    jmp .load_frame
.alternation:
    mov rax, [r14 + 8]
    test rax, rax
    jz .first_branch
    cmp eax, 1
    je .second_branch
    mov rax, [r14 + 16]
    mov [rax + 8], r15
    jmp .pop
.first_branch:
    mov dword [r15], 8          ; SPLIT: try the next instruction first
    mov [r14 + 16], r15
    mov qword [r14 + 8], 1
    add r15, 32
    mov rax, [rsi + 8]
    jmp .push_child
.second_branch:
    mov rax, [r14 + 16]
    lea rcx, [r15 + 32]
    mov [rax + 8], rcx
    mov dword [r15], 7          ; JUMP over the second branch
    mov [r14 + 16], r15
    mov qword [r14 + 8], 2
    mov r15, rcx
    mov rax, [rsi + 16]
    jmp .push_child
.capture:
    mov rax, [rsi + 16]
    mov [r15 + 8], rax
    cmp qword [r14 + 8], 0
    jne .close_capture
    mov dword [r15], 9          ; OPEN capture and reset descendants
    mov rax, [rsi + 24]
    mov [r15 + 16], rax
    mov qword [r14 + 8], 1
    add r15, 32
    mov rax, [rsi + 8]
    jmp .push_child
.close_capture:
    mov dword [r15], 10         ; CLOSE capture
    add r15, 32
    jmp .pop
.repeat:
    mov eax, [rsi + 4]
    mov [r15 + 4], eax
    mov [r15 + 36], eax
    cmp qword [r14 + 8], 0
    jne .repeat_end
    mov dword [r15], 11         ; REPEAT_INIT
    mov dword [r15 + 32], 12    ; REPEAT_SPLIT
    mov rax, [rsi + 16]
    mov [r15 + 48], rax         ; minimum
    mov rax, [rsi + 24]
    mov [r15 + 56], rax         ; maximum
    lea rax, [r15 + 32]
    mov [r14 + 16], rax
    mov qword [r14 + 8], 1
    add r15, 64
    mov rax, [rsi + 8]
    jmp .push_child
.repeat_end:
    mov dword [r15], 13         ; REPEAT_NEXT
    mov dword [r15 + 32], 14    ; REPEAT_END
    mov rax, [r14 + 16]
    mov [r15 + 8], rax
    lea rcx, [r15 + 32]
    mov [rax + 8], rcx
    add r15, 64
.pop:
    cmp r14, r13
    je .finish
    sub r14, 32
    jmp .next
.finish:
    mov dword [r15], 0          ; MATCH
    lea rax, [r15 + 32]
    sub rax, [rbx + 8]
    shr rax, 5
    mov [rbx + 16], rax
    xor eax, eax
    jmp .return
.no_space:
    mov eax, 12                 ; REG_ESPACE
.return:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
