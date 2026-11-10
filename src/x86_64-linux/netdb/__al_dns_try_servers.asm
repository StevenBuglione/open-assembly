; Query the configured servers in a bounded cyclic order.
; RDI primary, ESI length, RDX bank, RCX node, R8D type, R9 answer.
bits 64
default rel

global __al_dns_try_servers:function
extern __al_dns_query:function
extern __al_dns_query_timeout:function
extern __al_dns_rotate:function

section .text.__al_dns_try_servers alloc exec nowrite progbits
__al_dns_try_servers:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32
    mov rbx, rdx
    mov r12, rcx
    mov r13d, r8d
    mov r14, r9
    mov [rsp], rdi             ; primary sockaddr and length
    mov [rsp + 8], esi
    mov eax, [rbx]
    inc eax
    mov [rsp + 12], eax         ; configured server count
    mov ecx, [rbx + 116]
    test ecx, ecx
    jnz .rounds
    mov ecx, 1                 ; also accept a zeroed bank from callers
.rounds:
    imul eax, ecx
    mov [rsp + 16], eax         ; remaining attempts over all rounds
    mov dword [rsp + 20], -4   ; EAI_FAIL unless any attempt was retryable
    mov eax, [rbx + 112]
    test eax, eax
    jnz .timeout
    mov eax, 2
.timeout:
    imul eax, 1000
    mov [rsp + 24], eax
    xor r15d, r15d
    cmp dword [rbx + 120], 0
    je .prepare
    mov edi, [rsp + 12]
    cmp edi, 1
    jbe .prepare
    call __al_dns_rotate
    mov r15d, eax

.prepare:
    test r15d, r15d
    jnz .alternate
    mov rdi, [rsp]
    mov esi, [rsp + 8]
    jmp .query
.alternate:
    mov esi, [rbx + r15 * 4]
    mov rdi, r15
    shl rdi, 5
    lea rdi, [rbx + rdi - 16]
.query:
    mov rdx, r12
    mov ecx, r13d
    mov r8, r14
    mov r9d, [rsp + 24]
    cmp r9d, 2000
    jne .timed
    call __al_dns_query
    jmp .result
.timed:
    call __al_dns_query_timeout
.result:
    cmp eax, -3               ; EAI_AGAIN
    je .retryable
    cmp eax, -4               ; EAI_FAIL
    jne .return
    jmp .next_server
.retryable:
    mov [rsp + 20], eax
.next_server:
    dec dword [rsp + 16]
    jz .exhausted
    inc r15d
    cmp r15d, [rsp + 12]
    jb .prepare
    xor r15d, r15d
    jmp .prepare
.exhausted:
    mov eax, [rsp + 20]
.return:
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
