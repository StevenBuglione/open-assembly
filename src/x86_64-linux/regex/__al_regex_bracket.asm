; RDI bracket start, ESI raw scalar, EDX folded scalar, ECX regex mode.
; RAX returns the next pattern byte, or zero on syntax failure. EDX is
; the match boolean on success and the REG diagnostic on failure.
bits 64
default rel

global __al_regex_bracket:function
extern __al_regex_bracket_atom:function
extern towupper:function
extern towlower:function

section .text.__al_regex_bracket alloc exec nowrite progbits
__al_regex_bracket:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    lea rbx, [rdi + 1]
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    xor r15d, r15d
    cmp byte [rbx], 94
    jne .atom
    mov r15d, 2                ; negated list
    inc rbx
.atom:
    cmp byte [rbx], 0
    je .unclosed
    mov rdi, rbx
    mov esi, r12d
    mov ecx, r14d
    call __al_regex_bracket_atom
    test rax, rax
    jz .return
    mov rbx, rax
    test ecx, ecx
    jnz .class_record
    cmp byte [rbx], 45
    jne .single
    cmp byte [rbx + 1], 93
    je .single
    cmp byte [rbx + 1], 0
    je .unclosed
    mov [rsp], edx
    mov [rsp + 4], r8d
    lea rdi, [rbx + 1]
    mov esi, r12d
    mov ecx, r14d
    call __al_regex_bracket_atom
    test rax, rax
    jz .return
    test ecx, ecx
    jnz .invalid_range
    cmp r8d, [rsp + 4]
    jb .invalid_range
    mov rbx, rax
    cmp r12d, [rsp + 4]
    jb .case_range
    cmp r12d, r8d
    jbe .matched
.case_range:
    test r14d, 2
    jz .next
    mov [rsp + 8], r8d
    mov [rsp + 12], edx
    mov edi, r12d
    call towupper
    cmp eax, [rsp + 4]
    jb .lower_range
    cmp eax, [rsp + 8]
    jbe .matched
.lower_range:
    mov edi, r12d
    call towlower
    cmp eax, [rsp + 4]
    jb .folded_range
    cmp eax, [rsp + 8]
    jbe .matched
.folded_range:
    cmp r13d, [rsp]
    jb .next
    cmp r13d, [rsp + 12]
    ja .next
    jmp .matched
.single:
    cmp r13d, edx
    jne .next
    jmp .matched
.class_record:
    cmp byte [rbx], 45
    jne .record
    cmp byte [rbx + 1], 93
    jne .invalid_range
    jmp .record
.matched:
    mov edx, 1
.record:
    or r15d, edx
.next:
    cmp byte [rbx], 93
    jne .atom
    lea rax, [rbx + 1]
    xor edx, edx
    cmp r12d, 10
    jne .invert
    test r14d, 4
    jz .invert
    test r15d, 2
    jnz .return                ; REG_NEWLINE excludes LF from negated lists
.invert:
    mov edx, r15d
    shr edx, 1
    xor edx, r15d
    and edx, 1
    jmp .return
.unclosed:
    mov edx, 7                 ; REG_EBRACK
    jmp .error
.invalid_range:
    mov edx, 11                ; REG_ERANGE
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
