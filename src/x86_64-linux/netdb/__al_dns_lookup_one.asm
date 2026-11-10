; Resolve one absolute DNS candidate for the eligible source families.
; RDI context, RSI candidate, RDX answer/server block, ECX server length.
; R8 retains the caller's original node for canonical fallback.
bits 64
default rel

global __al_dns_lookup_one:function
extern __al_dns_publish:function
extern __al_dns_try_servers:function

section .text.__al_dns_lookup_one alloc exec nowrite progbits
__al_dns_lookup_one:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi                ; resolver context
    mov r13, rsi                ; DNS candidate
    mov r14, rdx                ; answer and sockaddr at +1032
    mov r15d, ecx
    mov [rsp + 8], r8
    mov dword [rsp], -2        ; first unsuccessful family status
    mov dword [rsp + 4], -2
    cmp dword [rbx + 12], 2    ; AF_INET requests only A
    je .ipv4
    test dword [rbx + 48], 2   ; configured IPv6 source
    jz .maybe_ipv4
    mov r12d, 28               ; AAAA
    jmp .query
.ipv4:
    test dword [rbx + 48], 1   ; configured IPv4 source
    jz .select_result
    mov r12d, 1                ; A
.query:
    lea rdi, [r14 + 1032]
    mov esi, r15d
    lea rdx, [r14 + 2608]       ; alternate bank at search record +1544
    mov rcx, r13
    mov r8d, r12d
    mov r9, r14
    call __al_dns_try_servers
    mov [rsp + 4], eax
    test eax, eax
    jnz .next_family
    mov rdi, rbx
    mov rsi, [rsp + 8]
    mov rdx, r14
    call __al_dns_publish
.next_family:
    cmp r12d, 1
    je .select_result
    mov eax, [rsp + 4]
    mov [rsp], eax
    cmp eax, -10               ; allocation failure need not try another family
    je .select_result
.maybe_ipv4:
    cmp dword [rbx + 12], 0    ; AF_UNSPEC tries both families
    je .ipv4
    test dword [rbx + 16], 8   ; AI_V4MAPPED
    jz .select_result
    cmp dword [rbx], 0
    je .ipv4
    test dword [rbx + 16], 16  ; AI_ALL
    jnz .ipv4
.select_result:
    xor r12d, r12d
    cmp dword [rbx], 0
    jne .return_status
    mov r12d, [rsp + 4]
    cmp r12d, -10
    je .return_status
    mov eax, [rsp]
    cmp eax, -10
    je .first_status
    cmp eax, -3                ; retryable failure wins over a negative answer
    je .first_status
    cmp r12d, -3
    je .return_status
    cmp eax, -4
    jne .return_status
.first_status:
    mov r12d, eax
.return_status:
    mov eax, r12d
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
