; Read configured address families in the caller's Linux network namespace.
; Return a two-bit family mask or a negative EAI status.
bits 64
default rel

global __al_gai_addrconfig:function
extern __al_dns_now:function
extern __al_dns_wait:function
extern __al_gai_addrconfig_parse:function
extern __errno_location:function
extern calloc:function
extern close:function
extern free:function
extern recvfrom:function
extern sendto:function
extern socket:function

section .text.__al_gai_addrconfig alloc exec nowrite progbits
__al_gai_addrconfig:
    push rbx
    push r12
    push r13
    mov edi, 1
    mov esi, 32832             ; work record plus 32 KiB receive space
    call calloc
    test rax, rax
    jz .no_memory
    mov rbx, rax
    mov rdi, rbx
    call __al_dns_now
    test rax, rax
    js .retry_free
    add rax, 2000
    mov [rbx], rax
    mov edi, 16                ; AF_NETLINK
    mov esi, 526339            ; SOCK_RAW | SOCK_CLOEXEC | SOCK_NONBLOCK
    xor edx, edx               ; NETLINK_ROUTE
    call socket
    test eax, eax
    js .retry_free
    mov r12d, eax
.send_wait:
    mov edi, r12d
    mov esi, 4                 ; POLLOUT
    mov rdx, rbx
    call __al_dns_wait
    test eax, eax
    jle .retry
    mov edi, r12d
    lea rsi, [rel request]
    mov edx, 24
    xor ecx, ecx
    lea r8, [rel kernel]
    mov r9d, 12
    call sendto
    cmp rax, 24
    je .receive_wait
    test rax, rax
    jns .retry
    call __errno_location
    mov eax, [rax]
    cmp eax, 4                 ; EINTR
    je .send_wait
    cmp eax, 11                ; EAGAIN
    je .send_wait
    jmp .retry
.receive_wait:
    mov edi, r12d
    mov esi, 1                 ; POLLIN
    mov rdx, rbx
    call __al_dns_wait
    test eax, eax
    jle .retry
    mov edi, r12d
    lea rsi, [rbx + 64]
    mov edx, 32768
    mov ecx, 32                ; MSG_TRUNC reports the original datagram length
    lea r8, [rbx + 40]
    lea r9, [rbx + 36]
    mov dword [r9], 12         ; socklen_t for sockaddr_nl
    call recvfrom
    test rax, rax
    js .receive_error
    cmp rax, 32768
    ja .retry
    cmp dword [rbx + 36], 12
    jne .retry
    cmp word [rbx + 40], 16    ; AF_NETLINK
    jne .retry
    cmp qword [rbx + 44], 0    ; kernel port ID, unicast
    jne .receive_wait
    lea rdi, [rbx + 64]
    mov rsi, rax
    lea rdx, [rbx + 32]
    call __al_gai_addrconfig_parse
    test eax, eax
    js .retry
    jz .receive_wait
    mov r13d, [rbx + 32]
    jmp .close
.receive_error:
    call __errno_location
    mov eax, [rax]
    cmp eax, 4
    je .receive_wait
    cmp eax, 11
    je .receive_wait
.retry:
    mov r13d, -3               ; EAI_AGAIN
.close:
    mov edi, r12d
    call close
    jmp .release
.retry_free:
    mov r13d, -3
.release:
    mov rdi, rbx
    call free
    mov eax, r13d
    jmp .return
.no_memory:
    mov eax, -10               ; EAI_MEMORY
.return:
    pop r13
    pop r12
    pop rbx
    ret

section .rodata.__al_gai_addrconfig alloc noexec nowrite progbits
request:
    dd 24                     ; nlmsg_len
    dw 22, 0x301              ; RTM_GETADDR, NLM_F_REQUEST | NLM_F_DUMP
    dd 1, 0                   ; sequence, unassigned sender port
    dq 0                      ; AF_UNSPEC and remaining ifaddrmsg fields
kernel:
    dw 16, 0                  ; AF_NETLINK, padding
    dd 0, 0                   ; kernel destination, unicast

section .note.GNU-stack noalloc noexec nowrite progbits
