; Query the first valid configured name server for the requested families.
; Local context layout matches __al_gai_hosts and __al_gai_result.
bits 64
default rel

global __al_dns_lookup:function
extern __al_dns_publish:function
extern __al_dns_query:function
extern __al_dns_server:function
extern calloc:function
extern free:function

section .text.__al_dns_lookup alloc exec nowrite progbits
__al_dns_lookup:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi                ; resolver context
    mov r13, rsi                ; original node
    mov edi, 1
    mov esi, 1064               ; answer block and name server sockaddr
    call calloc
    test rax, rax
    jz .no_memory
    mov r14, rax
    mov rdi, rbx
    lea rsi, [r14 + 1032]
    call __al_dns_server
    mov r15d, eax
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
    mov rdx, r13
    mov ecx, r12d
    mov r8, r14
    call __al_dns_query
    mov [rsp + 4], eax
    test eax, eax
    jnz .next_family
    mov rdi, rbx
    mov rsi, r13
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
    jne .release
    mov r12d, [rsp + 4]
    cmp r12d, -10
    je .release
    mov eax, [rsp]
    cmp eax, -10
    je .first_status
    cmp eax, -3                ; retryable failure wins over a negative answer
    je .first_status
    cmp r12d, -3
    je .release
    cmp eax, -4
    jne .release
.first_status:
    mov r12d, eax
.release:
    mov rdi, r14
    call free
    mov eax, r12d
    jmp .return
.no_memory:
    mov eax, -10               ; EAI_MEMORY
.return:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
