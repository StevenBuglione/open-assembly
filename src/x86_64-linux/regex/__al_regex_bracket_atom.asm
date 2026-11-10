; Read one bracket atom. RDI cursor, ESI input scalar, ECX mode.
; RAX is next cursor. EDX is folded scalar or class result, ECX selects
; the class result, and R8D is the original scalar. Zero RAX reports an error.
bits 64
default rel

global __al_regex_bracket_atom:function
extern __al_fnmatch_unit:function
extern __al_fnmatch_class:function
extern towupper:function
extern towlower:function

section .text.__al_regex_bracket_atom alloc exec nowrite progbits
__al_regex_bracket_atom:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12d, esi
    mov r13d, ecx
    cmp byte [rbx], 91
    jne .literal
    movzx eax, byte [rbx + 1]
    cmp eax, 58
    je .class
    cmp eax, 46
    je .collation
    cmp eax, 61
    jne .literal
.collation:
    lea rdi, [rbx + 2]
    cmp byte [rdi], 0
    je .bad_collation
    mov esi, r13d
    call __al_fnmatch_unit
    mov r8d, ecx
    cmp r8d, 0x10ffff
    ja .bad_pattern
    lea rcx, [rbx + rdx + 2]
    mov dl, [rbx + 1]
    cmp [rcx], dl
    jne .bad_collation
    cmp byte [rcx + 1], 93
    jne .bad_collation
    mov edx, eax
    lea rax, [rcx + 2]
    xor ecx, ecx
    jmp .return
.class:
    lea r14, [rbx + 2]
    xor r15d, r15d
.class_name:
    movzx eax, byte [r14 + r15]
    cmp eax, 58
    je .class_end
    cmp eax, 97
    jb .bad_class
    cmp eax, 122
    ja .bad_class
    inc r15d
    cmp r15d, 6
    jbe .class_name
    jmp .bad_class
.class_end:
    cmp byte [r14 + r15 + 1], 93
    jne .bad_class
    lea rbx, [r14 + r15 + 2]
    mov rdi, r14
    mov rsi, r15
    mov edx, r12d
    call __al_fnmatch_class
    test eax, eax
    js .bad_class
    jnz .class_result
    test r13d, 2               ; test both case variants for REG_ICASE
    jz .class_result
    mov edi, r12d
    call towupper
    mov edx, eax
    mov rdi, r14
    mov rsi, r15
    call __al_fnmatch_class
    test eax, eax
    jnz .class_result
    mov edi, r12d
    call towlower
    mov edx, eax
    mov rdi, r14
    mov rsi, r15
    call __al_fnmatch_class
.class_result:
    mov edx, eax
    mov rax, rbx
    mov ecx, 1
    jmp .return
.literal:
    mov rdi, rbx
    mov esi, r13d
    call __al_fnmatch_unit
    mov r8d, ecx
    cmp r8d, 0x10ffff
    ja .bad_pattern
    lea rcx, [rbx + rdx]
    mov edx, eax
    mov rax, rcx
    xor ecx, ecx
    jmp .return
.bad_collation:
    mov edx, 3                 ; REG_ECOLLATE
    jmp .error
.bad_class:
    mov edx, 4                 ; REG_ECTYPE
    jmp .error
.bad_pattern:
    mov edx, 2                 ; REG_BADPAT
.error:
    xor eax, eax
.return:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
