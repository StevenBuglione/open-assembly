; Read a bracket atom. RAX is the next cursor, zero on error.
; ECX zero denotes a literal scalar in EDX and its original value in R8D.
; ECX one denotes a class result. Zero RAX with EDX one denotes a bad class.
bits 64
default rel

global __al_fnmatch_atom:function
extern __al_fnmatch_unit:function
extern __al_fnmatch_class:function

section .text.__al_fnmatch_atom alloc exec nowrite progbits
__al_fnmatch_atom:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12d, esi               ; input scalar for class tests
    mov r13d, ecx               ; UTF-8 mode
    cmp byte [rbx], 92
    jne .special
    test edx, 2                 ; FNM_NOESCAPE
    jnz .literal
    inc rbx
    cmp byte [rbx], 0
    je .invalid
    jmp .literal
.special:
    cmp byte [rbx], 91
    jne .literal
    movzx eax, byte [rbx + 1]
    cmp eax, 58
    je .class
    cmp eax, 46
    je .collating
    cmp eax, 61
    jne .literal
.collating:
    lea rdi, [rbx + 2]
    cmp byte [rdi], 0
    je .literal
    mov esi, r13d
    call __al_fnmatch_unit
    mov r8d, ecx
    lea rcx, [rbx + rdx + 2]
    mov dl, [rbx + 1]
    cmp [rcx], dl
    jne .literal
    cmp byte [rcx + 1], 93
    jne .literal
    mov edx, eax
    lea rax, [rcx + 2]
    xor ecx, ecx
    jmp .return
.class:
    lea rdi, [rbx + 2]
    xor esi, esi
.class_name:
    movzx eax, byte [rdi + rsi]
    cmp eax, 58
    je .class_end
    test eax, eax
    jz .literal
    cmp eax, 97
    jb .invalid_class
    cmp eax, 122
    ja .invalid_class
    inc esi
    cmp esi, 6
    jbe .class_name
    jmp .invalid_class
.class_end:
    cmp byte [rdi + rsi + 1], 93
    je .lookup_class
    cmp byte [rdi + rsi + 1], 0
    je .literal
    jmp .invalid_class
.lookup_class:
    lea rbx, [rdi + rsi + 2]
    mov edx, r12d
    call __al_fnmatch_class
    test eax, eax
    js .invalid_class
    mov edx, eax
    mov rax, rbx
    mov ecx, 1
    jmp .return
.literal:
    mov rdi, rbx
    mov esi, r13d
    call __al_fnmatch_unit
    mov r8d, ecx
    lea rcx, [rbx + rdx]
    mov edx, eax
    mov rax, rcx
    xor ecx, ecx
    jmp .return
.invalid:
    xor edx, edx
    xor eax, eax
    jmp .return
.invalid_class:
    mov edx, 1
    xor eax, eax
.return:
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
