; Parse the private pattern copy. Group frames hold concatenation, pending
; atom, alternatives, and group id. Return the AST root or a REG error in EDX.
bits 64
default rel

global __al_regex_parse:function
extern __al_regex_token:function
extern __al_regex_bounds:function
extern __al_regex_node:function
extern __al_regex_branch:function

section .text.__al_regex_parse alloc exec nowrite progbits
__al_regex_parse:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12, [rbx]
    mov r13, [rbx + 72]
    mov r14, r13
    xor r15d, r15d             ; back-reference groups already closed
.next:
    mov [rsp], r12
    mov rdi, r12
    mov esi, [rbx + 40]
    mov edx, [rbx + 44]
    call __al_regex_token
    mov r12, rax
    test edx, edx
    jz .end
    cmp edx, 14
    je .token_error
    cmp edx, 7
    je .open
    cmp edx, 8
    je .close
    cmp edx, 9
    je .alternate
    ja .repeat
    cmp edx, 6
    je .reference
    test dword [rbx + 40], 1   ; extended anchors are always special
    jnz .atom
    cmp edx, 4
    je .basic_bol
    cmp edx, 5
    je .basic_eol
    jmp .atom
.basic_bol:
    mov rax, [r14]
    or rax, [r14 + 8]
    jz .atom
    mov edx, 1
    mov ecx, 94
    jmp .atom
.basic_eol:
    cmp byte [r12], 0
    je .atom
    cmp byte [r12], 92
    jne .literal_dollar
    cmp byte [r12 + 1], 41
    je .atom
    cmp byte [r12 + 1], 124
    je .atom
.literal_dollar:
    mov edx, 1
    mov ecx, 36
    jmp .atom
.reference:
    mov eax, 1
    shl eax, cl
    test eax, r15d
    jz .bad_reference
    mov dword [rbx + 48], 1
.atom:
    mov esi, edx
    xor edx, edx
    cmp esi, 1
    je .scalar
    cmp esi, 6
    je .scalar
    cmp esi, 3
    jne .new_atom
    mov rdx, [rsp]
    jmp .new_atom
.scalar:
    mov edx, ecx
.new_atom:
    mov rdi, rbx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_regex_node
    mov [rsp + 8], rax
    mov rdi, rbx
    mov rsi, r14
    xor edx, edx
    call __al_regex_branch
    mov rax, [rsp + 8]
    mov [r14 + 8], rax
    jmp .next
.open:
    mov rdi, rbx
    mov rsi, r14
    xor edx, edx
    call __al_regex_branch
    add r14, 32
    mov qword [r14], 0
    mov qword [r14 + 8], 0
    mov qword [r14 + 16], 0
    inc qword [rbx + 24]
    mov rax, [rbx + 24]
    mov [r14 + 24], rax
    jmp .next
.close:
    cmp r14, r13
    je .bad_parenthesis
    mov rdi, rbx
    mov rsi, r14
    mov edx, 1
    call __al_regex_branch
    mov rdx, rax
    mov rcx, [r14 + 24]
    cmp rcx, 9
    ja .group_node
    mov eax, 1
    shl eax, cl
    or r15d, eax
.group_node:
    mov rdi, rbx
    mov esi, 9                 ; capture
    mov r8, [rbx + 24]         ; greatest lexically nested group id
    xor r9d, r9d
    call __al_regex_node
    sub r14, 32
    mov [r14 + 8], rax
    jmp .next
.alternate:
    mov rdi, rbx
    mov rsi, r14
    mov edx, 1
    call __al_regex_branch
    mov [r14 + 16], rax
    mov qword [r14], 0
    jmp .next
.repeat:
    mov rax, [r14 + 8]
    test rax, rax
    jz .bare_repeat
    cmp dword [rax], 4
    je .bare_repeat
    cmp dword [rax], 5
    je .bad_repeat
    cmp dword [rax], 10
    je .bad_repeat
    cmp edx, 13
    je .interval
    xor ecx, ecx
    mov r8, -1
    cmp edx, 10
    je .repeat_node
    cmp edx, 12
    je .optional
    mov ecx, 1                 ; plus
    jmp .repeat_node
.optional:
    mov r8d, 1
    jmp .repeat_node
.interval:
    mov rdi, r12
    mov esi, [rbx + 40]
    call __al_regex_bounds
    test rax, rax
    jz .error
    mov r12, rax
    mov r8, rcx
    mov ecx, edx
.repeat_node:
    mov rax, [rbx + 32]
    mov r9d, eax
    cmp r9, rax
    jne .no_space
    inc qword [rbx + 32]
    mov rdi, rbx
    mov esi, 10                ; repetition
    mov rdx, [r14 + 8]
    call __al_regex_node
    mov [r14 + 8], rax
    jmp .next
.bare_repeat:
    cmp edx, 10
    jne .bad_repeat
    test dword [rbx + 40], 1
    jnz .bad_repeat
    mov edx, 1
    mov ecx, 42                ; a leading BRE asterisk is literal
    jmp .atom
.end:
    cmp r14, r13
    jne .bad_parenthesis
    mov rdi, rbx
    mov rsi, r14
    mov edx, 1
    call __al_regex_branch
    xor edx, edx
    jmp .return
.token_error:
    mov edx, ecx
    jmp .error
.bad_reference:
    mov edx, 6                 ; REG_ESUBREG
    jmp .error
.bad_parenthesis:
    mov edx, 8                 ; REG_EPAREN
    jmp .error
.bad_repeat:
    mov edx, 13                ; REG_BADRPT
    jmp .error
.no_space:
    mov edx, 12                ; REG_ESPACE
.error:
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
