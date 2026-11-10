; Copy validated answers into the local resolver's address records.
bits 64
default rel

global __al_dns_publish:function
extern __al_dns_text:function

section .text.__al_dns_publish alloc exec nowrite progbits
__al_dns_publish:
    push r12
    push r13
    push r14
    mov r12, rdi                ; resolver context
    mov r13, rsi                ; original node for canonical fallback
    mov r14, rdx                ; validated answer block
    mov ecx, [r12]
    imul ecx, 24
    lea rdi, [r12 + rcx + 64]
    lea rsi, [r14 + 264]
    mov ecx, [r14]
    mov r8d, 2                  ; AF_INET for A
    cmp dword [r14 + 4], 1
    je .copy
    mov r8d, 10                 ; AF_INET6 for AAAA
.copy:
    test ecx, ecx
    jz .canonical
    cmp dword [r12], 32
    jae .canonical
    mov [rdi], r8d
    mov dword [rdi + 4], 0
    mov rax, [rsi]
    mov [rdi + 8], rax
    mov rax, [rsi + 8]
    mov [rdi + 16], rax
    inc dword [r12]
    add rsi, 16
    add rdi, 24
    dec ecx
    jmp .copy
.canonical:
    test dword [r12 + 16], 2   ; AI_CANONNAME
    jz .return
    cmp qword [r12 + 32], 0
    jne .return
    lea rdi, [r14 + 8]
    lea rsi, [r12 + 832]
    call __al_dns_text
    test eax, eax
    jz .save_name
    lea r13, [r12 + 832]
.save_name:
    mov [r12 + 32], r13
.return:
    pop r14
    pop r13
    pop r12
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
