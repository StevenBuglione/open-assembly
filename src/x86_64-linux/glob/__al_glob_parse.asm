; Split a private pattern copy into 48-byte component frames.
; Each starts with the component pointer, slash count and wildcard flag.
bits 64
default rel

global __al_glob_parse:function
extern strdup:function
extern strlen:function
extern calloc:function
extern __al_locale_flags:data
extern __al_fnmatch_bracket:function

section .text.__al_glob_parse alloc exec nowrite progbits
__al_glob_parse:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov rdi, rsi
    call strdup
    test rax, rax
    jz .no_space
    mov [rbx + 56], rax
    mov r12, rax                ; unprocessed source
    mov r13, rax                ; compacted component strings
    mov rdi, rax
    call strlen
    shr rax, 1
    lea rdi, [rax + 1]          ; maximum number of components
    mov esi, 48
    call calloc
    test rax, rax
    jz .no_space
    mov [rbx + 64], rax
    mov r14, rax
    mov r15d, [rbx + 8]
    and r15d, 64                ; GLOB_NOESCAPE
    shr r15d, 5                 ; FNM_NOESCAPE
.leading:
    cmp byte [r12], 47
    jne .component
    inc qword [rbx + 104]
    inc r12
    jmp .leading
.component:
    cmp byte [r12], 0
    je .done
    mov [r14], r13
    xor r9d, r9d               ; possible bracket or definite wildcard
.copy:
    movzx eax, byte [r12]
    test eax, eax
    jz .component_end
    cmp eax, 47
    je .component_end
    cmp eax, 92
    jne .special
    test r15d, r15d
    jnz .byte
    cmp byte [r12 + 1], 47
    je .escaped_separator
    cmp byte [r12 + 1], 0
    je .byte
    mov ax, [r12]
    mov [r13], ax
    add r12, 2
    add r13, 2
    jmp .copy
.escaped_separator:
    inc r12
    jmp .component_end
.special:
    cmp eax, 42
    je .wildcard
    cmp eax, 63
    je .wildcard
    cmp eax, 91
    jne .byte
    or r9d, 1
    jmp .byte
.wildcard:
    or r9d, 2
.byte:
    mov [r13], al
    inc r12
    inc r13
    jmp .copy
.component_end:
    xor ecx, ecx
.separator:
    cmp byte [r12], 47
    jne .component_saved
    inc rcx
    inc r12
    jmp .separator
.component_saved:
    mov [r14 + 8], rcx
    mov byte [r13], 0
    inc r13
    cmp r9d, 1
    jb .literal
    ja .mark_wild
    mov rax, [r14]
.bracket_scan:
    movzx ecx, byte [rax]
    test ecx, ecx
    jz .literal
    cmp ecx, 92
    jne .bracket_start
    test r15d, r15d
    jnz .bracket_next
    cmp byte [rax + 1], 0
    je .literal
    inc rax
    jmp .bracket_next
.bracket_start:
    cmp ecx, 91
    jne .bracket_next
    mov [rsp], rax
    mov rdi, rax
    xor esi, esi
    mov edx, r15d
    mov ecx, [rel __al_locale_flags]
    and ecx, 1
    xor r8d, r8d
    call __al_fnmatch_bracket
    test rax, rax
    jnz .mark_wild
    test edx, edx
    jnz .mark_wild
    mov rax, [rsp]
.bracket_next:
    inc rax
    jmp .bracket_scan
.mark_wild:
    mov qword [r14 + 16], 1
    jmp .frame_saved
.literal:
    test r15d, r15d
    jnz .frame_saved
    mov r10, [r14]
    mov r13, r10
.unescape:
    mov al, [r10]
    cmp al, 92
    jne .literal_byte
    cmp byte [r10 + 1], 0
    je .literal_byte
    inc r10
    mov al, [r10]
.literal_byte:
    mov [r13], al
    inc r13
    inc r10
    test al, al
    jnz .unescape
.frame_saved:
    inc qword [rbx + 72]
    add r14, 48
    jmp .component
.done:
    xor eax, eax
    jmp .return
.no_space:
    mov eax, 1                 ; GLOB_NOSPACE
.return:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
