; Expand one DNS name to a lowercase 256-byte wire-name buffer.
; RAX returns the next encoded offset, zero for malformed input.
; EDX returns the expanded count including the terminal zero on success.
bits 64
default rel

global __al_dns_name:function

section .text.__al_dns_name alloc exec nowrite progbits
__al_dns_name:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdx                ; packet cursor
    xor r12d, r12d              ; expanded length
    xor r13d, r13d              ; offset following the first pointer
    xor r14d, r14d              ; compression hop count
    cmp rbx, 12
    jb .invalid
.component:
    cmp rbx, rsi
    jae .invalid
    movzx eax, byte [rdi + rbx]
    test eax, eax
    jz .root
    cmp eax, 63
    ja .pointer
    mov r15d, eax
    lea r8, [rbx + rax + 1]
    cmp r8, rsi
    ja .invalid
    lea r8, [r12 + rax + 1]
    cmp r8, 254                ; leave room for the terminal root byte
    ja .invalid
    mov [rcx + r12], al
    inc rbx
    inc r12
.label_byte:
    movzx eax, byte [rdi + rbx]
    lea r8d, [rax - 65]
    cmp r8d, 25
    ja .copy
    add eax, 32
.copy:
    mov [rcx + r12], al
    inc rbx
    inc r12
    dec r15d
    jnz .label_byte
    jmp .component
.pointer:
    cmp eax, 192               ; the other extended label kinds are invalid
    jb .invalid
    lea rax, [rbx + 1]
    cmp rax, rsi
    jae .invalid
    movzx eax, word [rdi + rbx]
    rol ax, 8
    and eax, 0x3fff
    cmp eax, 12
    jb .invalid
    cmp rax, rbx               ; compression points to an earlier encoding
    jae .invalid
    inc r14d
    cmp r14d, 128
    ja .invalid
    test r13, r13
    jnz .follow
    lea r13, [rbx + 2]
.follow:
    mov rbx, rax
    jmp .component
.root:
    mov byte [rcx + r12], 0
    lea edx, [r12 + 1]
    mov rax, r13
    test rax, rax
    jnz .return
    lea rax, [rbx + 1]
    jmp .return
.invalid:
    xor eax, eax
    xor edx, edx
.return:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
