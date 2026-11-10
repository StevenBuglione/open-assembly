; RDI pattern cursor, ESI compile flags, EDX character mode.
; Return RAX next cursor, EDX token, and ECX associated value or REG error.
; Tokens 0-6 are end and atoms. 7-9 are groups/alternation, 10-13
; repetition operators, and 14 an invalid pattern.
bits 64
default rel

global __al_regex_token:function
extern __al_fnmatch_unit:function
extern __al_regex_bracket:function

section .text.__al_regex_token alloc exec nowrite progbits
__al_regex_token:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    movzx eax, byte [rbx]
    xor edx, edx
    test eax, eax
    jz .end
    cmp eax, 92
    je .escape
    cmp eax, 46
    je .any
    cmp eax, 91
    je .bracket
    cmp eax, 94
    je .bol
    cmp eax, 36
    je .eol
    cmp eax, 42
    je .star
    test r12d, 1               ; REG_EXTENDED
    jz .literal
    jmp .operator
.escape:
    inc rbx
    movzx eax, byte [rbx]
    test eax, eax
    jz .bad_escape
    test r12d, 1
    jnz .literal               ; escaped ERE digit is literal
    lea ecx, [rax - 49]
    cmp ecx, 8
    ja .operator
    inc ecx
    mov edx, 6                 ; basic back-reference
    jmp .advance
.operator:
    cmp eax, 40
    je .open
    cmp eax, 41
    je .close
    cmp eax, 124
    je .alternate
    cmp eax, 43
    je .plus
    cmp eax, 63
    je .question
    cmp eax, 123
    je .bounds
.literal:
    mov rdi, rbx
    mov esi, r13d
    call __al_fnmatch_unit
    cmp ecx, 0x10ffff
    ja .bad_pattern
    mov ecx, eax
    lea rax, [rbx + rdx]
    mov edx, 1
    jmp .return
.bracket:
    mov rdi, rbx
    xor esi, esi
    xor edx, edx
    mov ecx, r13d
    call __al_regex_bracket
    test rax, rax
    jz .bracket_error
    mov edx, 3
    jmp .return
.bracket_error:
    mov ecx, edx
    jmp .error
.any:
    mov edx, 2
    jmp .advance
.bol:
    mov edx, 4
    jmp .advance
.eol:
    mov edx, 5
    jmp .advance
.open:
    mov edx, 7
    jmp .advance
.close:
    mov edx, 8
    jmp .advance
.alternate:
    mov edx, 9
    jmp .advance
.star:
    mov edx, 10
    jmp .advance
.plus:
    mov edx, 11
    jmp .advance
.question:
    mov edx, 12
    jmp .advance
.bounds:
    mov edx, 13
.advance:
    lea rax, [rbx + 1]
    jmp .return
.end:
    mov rax, rbx
    jmp .return
.bad_escape:
    mov ecx, 5                 ; REG_EESCAPE
    jmp .error
.bad_pattern:
    mov ecx, 2                 ; REG_BADPAT
.error:
    mov edx, 14
    xor eax, eax
.return:
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
