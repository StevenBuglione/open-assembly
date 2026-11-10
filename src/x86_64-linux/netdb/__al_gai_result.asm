; Materialize address/transport pairs into independently owned list nodes.
; Each allocation starts with addrinfo (48 bytes), an inline sockaddr
; (up to 28 bytes), and an optional name at offset 80.
bits 64
default rel

global __al_gai_result:function
extern calloc:function
extern freeaddrinfo:function
extern strlen:function

section .text.__al_gai_result alloc exec nowrite progbits
__al_gai_result:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov r12, rdi                ; resolver context
    lea r13, [r12 + 64]        ; first address record
    xor r14d, r14d              ; head
    xor r15d, r15d              ; tail
    mov eax, [r12]
    imul eax, 24
    lea rax, [r13 + rax]
    mov [rsp], rax             ; end of address records
.address:
    cmp r13, [rsp]
    jae .success
    mov ebx, 1                 ; try TCP before UDP
.transport:
    test [r12 + 4], ebx
    jz .next_transport
    mov qword [rsp + 8], 0
    mov esi, 80                ; address information with inline sockaddr
    test r14, r14
    jnz .allocate
    test dword [r12 + 16], 2   ; AI_CANONNAME
    jz .allocate
    mov rdi, [r12 + 32]
    test rdi, rdi
    jz .allocate
    mov [rsp + 8], rdi
    call strlen
    add rax, 81                ; also reserve a terminating byte
    jc .allocation_failed
    mov rsi, rax
.allocate:
    mov edi, 1
    call calloc
    test rax, rax
    jz .allocation_failed
    mov ecx, [r12 + 16]
    mov [rax], ecx             ; ai_flags
    mov ecx, [r13]
    mov [rax + 4], ecx         ; ai_family
    mov [rax + 8], ebx         ; ai_socktype (STREAM=1, DGRAM=2)
    mov edx, 6                 ; IPPROTO_TCP
    cmp ebx, 1
    je .protocol
    mov edx, 17                ; IPPROTO_UDP
.protocol:
    mov [rax + 12], edx
    lea rdx, [rax + 48]
    mov [rax + 24], rdx        ; ai_addr
    mov [rdx], cx
    mov esi, ebx
    dec esi
    movzx edi, word [r12 + rsi * 2 + 8]
    mov [rdx + 2], di          ; network-order port
    cmp ecx, 2
    jne .ipv6
    mov dword [rax + 16], 16
    mov ecx, [r13 + 8]
    mov [rdx + 4], ecx
    jmp .canonical_name
.ipv6:
    mov dword [rax + 16], 28
    mov rcx, [r13 + 8]
    mov [rdx + 8], rcx
    mov rcx, [r13 + 16]
    mov [rdx + 16], rcx
    mov ecx, [r13 + 4]
    mov [rdx + 24], ecx
.canonical_name:
    mov rdx, [rsp + 8]
    test rdx, rdx
    jz .link
    lea rcx, [rax + 80]
    mov [rax + 32], rcx
    xor esi, esi
.copy_name:
    mov dil, [rdx + rsi]
    mov [rcx + rsi], dil
    inc rsi
    test dil, dil
    jnz .copy_name
.link:
    test r14, r14
    jnz .append
    mov r14, rax
    jmp .new_tail
.append:
    mov [r15 + 40], rax
.new_tail:
    mov r15, rax
.next_transport:
    inc ebx
    cmp ebx, 2
    jbe .transport
    add r13, 24
    jmp .address
.success:
    mov rax, r14
    jmp .return
.allocation_failed:
    mov rdi, r14
    call freeaddrinfo
    xor eax, eax
.return:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
