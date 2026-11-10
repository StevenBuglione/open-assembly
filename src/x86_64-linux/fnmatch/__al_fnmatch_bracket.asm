; Match an entire bracket expression. RAX is its end cursor or zero if invalid.
; EDX is the match boolean, or one with zero RAX for a malformed class.
; ESI is the folded input, EDX the flags, ECX the mode, and R8D the raw input.
bits 64
default rel

global __al_fnmatch_bracket:function
extern __al_fnmatch_atom:function

section .text.__al_fnmatch_bracket alloc exec nowrite progbits
__al_fnmatch_bracket:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    mov [rsp + 4], r8d         ; input before folding
    mov [rsp + 16], rdi        ; opening bracket
    mov dword [rsp + 24], 0    ; saw a quoted closing bracket
.begin:
    mov rbx, [rsp + 16]
    inc rbx
    xor r15d, r15d             ; bit zero matched, bit one negated
    cmp byte [rbx], 33
    je .negated
    cmp byte [rbx], 94
    jne .atom
.negated:
    mov r15d, 2
    inc rbx
.atom:
    cmp byte [rbx], 0
    je .invalid
    cmp byte [rbx], 92
    jne .read_atom
    cmp byte [rbx + 1], 93
    jne .read_atom
    mov dword [rsp + 24], 1
.read_atom:
    mov rdi, rbx
    mov esi, [rsp + 4]
    mov edx, r13d
    mov ecx, r14d
    call __al_fnmatch_atom
    test rax, rax
    jz .bad_atom
    mov rbx, rax
    test ecx, ecx
    jnz .record
    cmp byte [rbx], 45
    jne .single
    cmp byte [rbx + 1], 93
    je .single
    cmp byte [rbx + 1], 0
    je .invalid
    mov [rsp], edx            ; folded lower endpoint
    mov [rsp + 8], r8d        ; original lower endpoint
    cmp byte [rbx + 1], 92
    jne .read_endpoint
    cmp byte [rbx + 2], 93
    jne .read_endpoint
    mov dword [rsp + 24], 1
.read_endpoint:
    lea rdi, [rbx + 1]
    mov esi, [rsp + 4]
    mov edx, r13d
    mov ecx, r14d
    call __al_fnmatch_atom
    test rax, rax
    jz .bad_atom
    test ecx, ecx
    jnz .malformed
    mov rbx, rax
    mov ecx, [rsp + 4]
    cmp ecx, [rsp + 8]
    jb .folded_range
    cmp ecx, r8d
    jbe .matched
.folded_range:
    cmp r12d, [rsp]
    jb .next
    cmp r12d, edx
    ja .next
    jmp .matched
.single:
    cmp r12d, edx
    jne .next
.matched:
    mov edx, 1
.record:
    or r15d, edx
.next:
    cmp byte [rbx], 93
    jne .atom
    lea rax, [rbx + 1]
    mov edx, r15d
    shr edx, 1
    xor edx, r15d
    and edx, 1
    jmp .return
.bad_atom:
    test edx, edx
    jnz .malformed
.invalid:
    test r13d, 2
    jnz .unclosed
    cmp dword [rsp + 24], 0
    je .unclosed
    or r13d, 2                 ; retry a bracket with a literal terminal backslash
    jmp .begin
.unclosed:
    xor edx, edx
    xor eax, eax
    jmp .return
.malformed:
    mov edx, 1
    xor eax, eax
.return:
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
