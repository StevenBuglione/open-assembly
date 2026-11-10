; Match a captured byte span at the current input cursor. RDI/RSI capture
; begin/end, RDX input, ECX mode. Return next input or null on mismatch.
bits 64
default rel

global __al_regex_backref:function
extern __al_fnmatch_unit:function

section .text.__al_regex_backref alloc exec nowrite progbits
__al_regex_backref:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov r15d, ecx
    cmp r12, -1
    je .mismatch
    cmp r13, -1
    je .mismatch
    test r15d, 2
    jnz .folded
.bytes:
    cmp r12, r13
    je .matched
    mov al, [r14]
    test al, al
    jz .mismatch
    cmp al, [r12]
    jne .mismatch
    inc r12
    inc r14
    jmp .bytes
.folded:
    cmp r12, r13
    je .matched
    cmp byte [r14], 0
    je .mismatch
    mov rdi, r12
    mov esi, r15d
    call __al_fnmatch_unit
    mov ebx, eax
    add r12, rdx
    mov rdi, r14
    mov esi, r15d
    call __al_fnmatch_unit
    cmp eax, ebx
    jne .mismatch
    add r14, rdx
    jmp .folded
.matched:
    mov rax, r14
    jmp .return
.mismatch:
    xor eax, eax
.return:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
