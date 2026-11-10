; Record an exact visited VM state in a chained hash table. Return zero for
; a new state, one for a duplicate, or REG_ESPACE. RDI run, RSI PC, RDX input.
bits 64
default rel

global __al_regex_seen:function
extern memcmp:function
extern memcpy:function
extern realloc:function

section .text.__al_regex_seen alloc exec nowrite progbits
__al_regex_seen:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov rax, rsi
    rol rax, 23
    xor rax, rdx
    mov r11, 0x9e3779b185ebca87
    mov r8, [rbx + 56]
    mov r9, [rbx + 64]
    xor ecx, ecx
.hash:
    cmp rcx, r9
    je .bucket
    xor rax, [r8 + rcx]
    rol rax, 11
    imul rax, r11
    add rcx, 8
    jmp .hash
.bucket:
    imul rax, r11
    mov rcx, rax
    shr rcx, 32
    xor rax, rcx
    and rax, [rbx + 136]
    mov rcx, [rbx + 128]
    lea r14, [rcx + rax * 8]
    mov r15, [r14]
.chain:
    test r15, r15
    jz .insert
    mov rax, [rbx + 144]
    lea rax, [rax + r15 - 1]
    cmp r12, [rax + 8]
    jne .link
    cmp r13, [rax + 16]
    jne .link
    mov rdi, [rbx + 56]
    lea rsi, [rax + 24]
    mov rdx, [rbx + 64]
    call memcmp
    test eax, eax
    jz .duplicate
    mov rax, [rbx + 144]
    lea rax, [rax + r15 - 1]
.link:
    mov r15, [rax]
    jmp .chain
.insert:
    mov r15, [rbx + 160]
    mov rax, r15
    add rax, [rbx + 120]
    jc .no_space
    mov [rsp], rax
    cmp rax, [rbx + 152]
    jbe .record
    mov rsi, [rbx + 152]
    add rsi, rsi
    jc .exact
    cmp rsi, 256
    jae .check
    mov esi, 256
.check:
    cmp rsi, rax
    jae .allocate
.exact:
    mov rsi, rax
.allocate:
    mov [rsp + 8], rsi
    mov rdi, [rbx + 144]
    call realloc
    test rax, rax
    jz .no_space
    mov [rbx + 144], rax
    mov rax, [rsp + 8]
    mov [rbx + 152], rax
.record:
    mov rdi, [rbx + 144]
    add rdi, r15
    mov rax, [r14]
    mov [rdi], rax
    mov [rdi + 8], r12
    mov [rdi + 16], r13
    add rdi, 24
    mov rsi, [rbx + 56]
    mov rdx, [rbx + 64]
    call memcpy
    lea rax, [r15 + 1]
    mov [r14], rax
    mov rax, [rsp]
    mov [rbx + 160], rax
    xor eax, eax
    jmp .return
.duplicate:
    mov eax, 1
    jmp .return
.no_space:
    mov eax, 12                ; REG_ESPACE
.return:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
