; Query a PTR record for an effective address, then render its target.
; RDI getnameinfo context, RSI address bytes, EDX family. Return an EAI code.
bits 64
default rel

global __al_dns_reverse:function
extern __al_dns_reverse_name:function
extern __al_dns_server:function
extern __al_dns_query:function
extern __al_dns_text:function

section .text.__al_dns_reverse alloc exec nowrite progbits
__al_dns_reverse:
    push rbx
    mov rbx, rdi
    lea rdi, [rbx + 608]        ; reverse question text
    lea rcx, [rbx + 736]        ; reordered IPv4 octets
    call __al_dns_reverse_name
    mov rdi, rbx
    lea rsi, [rbx + 576]        ; name server sockaddr
    call __al_dns_server
    mov esi, eax
    lea rdi, [rbx + 576]
    lea rdx, [rbx + 608]
    mov ecx, 12                ; PTR
    lea r8, [rbx + 1088]        ; reuse the configuration line after selection
    call __al_dns_query
    test eax, eax
    jnz .return
    cmp byte [rbx + 1352], 0   ; the root name is not a host name
    je .no_name
    lea rdi, [rbx + 1352]       ; answer block + PTR target offset
    lea rsi, [rbx + 64]
    call __al_dns_text
    test eax, eax
    jz .bad_name
    xor eax, eax
    jmp .return
.no_name:
    mov eax, -2                ; EAI_NONAME
    jmp .return
.bad_name:
    mov eax, -4                ; EAI_FAIL
.return:
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
