; Query the first valid configured name server for the requested families.
; Local context layout matches __al_gai_hosts and __al_gai_result.
bits 64
default rel

global __al_dns_lookup:function
extern __al_dns_publish:function
extern __al_dns_query:function
extern __al_gai_line:function
extern __al_gai_word:function
extern calloc:function
extern fclose:function
extern fopen:function
extern free:function
extern inet_pton:function
extern strcmp:function

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
    lea rdi, [rel resolv_path]
    lea rsi, [rel read_mode]
    call fopen
    test rax, rax
    jz .default_server
    mov r12, rax
.read_line:
    mov rdi, r12
    lea rsi, [rbx + 1088]
    call __al_gai_line
    test rax, rax
    jz .no_configured_server
    mov [rbx + 40], rax
    lea rdi, [rbx + 40]
    call __al_gai_word
    test rax, rax
    jz .read_line
    mov rdi, rax
    lea rsi, [rel nameserver]
    call strcmp
    test eax, eax
    jnz .read_line
    lea rdi, [rbx + 40]
    call __al_gai_word
    test rax, rax
    jz .read_line
    mov [rsp + 8], rax
    mov edi, 2                  ; AF_INET
    mov rsi, rax
    lea rdx, [r14 + 1036]
    call inet_pton
    test eax, eax
    jnz .configured_ipv4
    mov edi, 10                 ; AF_INET6
    mov rsi, [rsp + 8]
    lea rdx, [r14 + 1040]
    call inet_pton
    test eax, eax
    jz .read_line
    mov word [r14 + 1032], 10
    mov r15d, 28
    jmp .configured
.configured_ipv4:
    mov word [r14 + 1032], 2
    mov r15d, 16
.configured:
    mov rdi, r12
    call fclose
    jmp .server_ready
.no_configured_server:
    mov rdi, r12
    call fclose
.default_server:
    mov word [r14 + 1032], 2
    mov dword [r14 + 1036], 0x0100007f ; loopback default
    mov r15d, 16
.server_ready:
    mov word [r14 + 1034], 0x3500 ; network-order DNS port 53
    mov dword [rsp], -2        ; first unsuccessful family status
    cmp dword [rbx + 12], 2    ; AF_INET requests only A
    je .ipv4
    mov r12d, 28               ; AAAA
    jmp .query
.ipv4:
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

section .rodata.__al_dns_lookup alloc noexec nowrite progbits
resolv_path: db "/etc/resolv.conf", 0
read_mode: db "r", 0
nameserver: db "nameserver", 0

section .note.GNU-stack noalloc noexec nowrite progbits
