; Loopback-only HTTP acceptance program, driven by level-triggered epoll.
bits 64
default rel

global main:function
extern __al_http_client:function
extern __errno_location:function
extern accept4:function
extern bind:function
extern clock_gettime:function
extern close:function
extern epoll_create1:function
extern epoll_ctl:function
extern epoll_wait:function
extern fflush:function
extern getsockname:function
extern htons:function
extern listen:function
extern ntohs:function
extern perror:function
extern printf:function
extern setsockopt:function
extern socket:function
extern stdout:data

section .text.main alloc exec nowrite progbits
main:
    push rbx
    push r12
    push r13
    push r14
    push r15
    movsxd rax, edi
    xor edi, edi                ; ephemeral port by default
    cmp rax, 1
    je .port_ready
    cmp rax, 2
    jne .usage_error
    mov rsi, [rsi + 8]
    cmp byte [rsi], 0
    je .usage_error
.port_digit:
    movzx eax, byte [rsi]
    test eax, eax
    jz .port_ready
    sub eax, 48
    cmp eax, 9
    ja .usage_error
    imul edi, 10
    add edi, eax
    cmp edi, 65535
    ja .usage_error
    inc rsi
    jmp .port_digit
.port_ready:
    call htons
    mov word [rel listen_address], 2        ; AF_INET
    mov [rel listen_address + 2], ax
    mov dword [rel listen_address + 4], 0x0100007f ; 127.0.0.1 in network order
    mov edi, 2                  ; AF_INET
    mov esi, 526337             ; SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK
    xor edx, edx
    call socket
    test eax, eax
    js .runtime_error
    mov r12d, eax
    mov edi, eax
    mov esi, 1                  ; SOL_SOCKET
    mov edx, 2                  ; SO_REUSEADDR
    lea rcx, [rel enable_option]
    mov r8d, 4
    call setsockopt
    test eax, eax
    jnz .runtime_error
    mov edi, r12d
    lea rsi, [rel listen_address]
    mov edx, 16
    call bind
    test eax, eax
    jnz .runtime_error
    mov edi, r12d
    mov esi, 64
    call listen
    test eax, eax
    jnz .runtime_error
    mov dword [rel listen_address_length], 16
    mov edi, r12d
    lea rsi, [rel listen_address]
    lea rdx, [rel listen_address_length]
    call getsockname
    test eax, eax
    jnz .runtime_error
    mov edi, 524288             ; EPOLL_CLOEXEC
    call epoll_create1
    test eax, eax
    js .runtime_error
    mov r13d, eax
    mov edi, eax
    mov esi, 1                  ; EPOLL_CTL_ADD
    mov edx, r12d
    lea rcx, [rel listen_event]
    call epoll_ctl
    test eax, eax
    jnz .runtime_error
    movzx edi, word [rel listen_address + 2]
    call ntohs
    movzx esi, ax
    lea rdi, [rel ready_format]
    xor eax, eax
    call printf
    test eax, eax
    js .runtime_error
    mov rdi, [rel stdout]
    call fflush
    test eax, eax
    jnz .runtime_error
    xor ebx, ebx                ; next monotonic sweep deadline
.wait:
    mov edi, r13d
    lea rsi, [rel wait_event]
    mov edx, 1                  ; consume one event before recycling any slot
    mov ecx, 1000
    call epoll_wait
    test eax, eax
    js .wait_error
    mov [rel ready_count], eax
    mov edi, 1                  ; CLOCK_MONOTONIC
    lea rsi, [rel monotonic_time]
    call clock_gettime
    test eax, eax
    jnz .runtime_error
    mov r14, [rel monotonic_time]
    imul r14, 1000000000
    add r14, [rel monotonic_time + 8]
    cmp dword [rel ready_count], 0
    je .maybe_sweep
    mov r15, [rel wait_event + 4]
    test r15, r15
    jz .accept
    mov rdi, r15
    mov esi, r13d
    mov edx, [rel wait_event]
    mov rcx, r14
    call __al_http_client
    test eax, eax
    jnz .maybe_sweep
    mov edi, [r15]
    mov dword [r15], 0
    dec edi
    call close
    jmp .maybe_sweep
.accept:
    mov edi, r12d
    xor esi, esi
    xor edx, edx
    mov ecx, 526336             ; SOCK_CLOEXEC | SOCK_NONBLOCK
    call accept4
    test eax, eax
    js .accept_error
    mov [rel accepted_fd], eax
    lea r15, [rel clients]
    lea rcx, [rel clients_end]
.find_slot:
    cmp dword [r15], 0
    je .prepare_slot
    add r15, 8232
    cmp r15, rcx
    jb .find_slot
    mov edi, eax                ; bounded capacity, decline this connection
    call close
    jmp .maybe_sweep
.prepare_slot:
    mov dword [r15 + 4], 0      ; output interest is not yet armed
    mov qword [r15 + 8], 0      ; input count
    mov qword [r15 + 16], 0     ; output cursor
    mov rdx, 5000000000
    add rdx, r14
    mov [r15 + 32], rdx        ; idle deadline
    mov [rel client_event + 4], r15
    mov edi, r13d
    mov esi, 1                  ; EPOLL_CTL_ADD
    mov edx, eax
    lea rcx, [rel client_event]
    call epoll_ctl
    test eax, eax
    jnz .reject_client
    mov eax, [rel accepted_fd]
    inc eax
    mov [r15], eax
    jmp .maybe_sweep
.reject_client:
    mov edi, [rel accepted_fd]
    call close
    jmp .maybe_sweep
.wait_error:
    call __errno_location
    cmp dword [rax], 4          ; EINTR
    je .wait
    jmp .runtime_error
.accept_error:
    call __errno_location
    mov eax, [rax]
    cmp eax, 4                  ; EINTR
    je .maybe_sweep
    cmp eax, 11                 ; EAGAIN
    je .maybe_sweep
    cmp eax, 103                ; ECONNABORTED
    jne .runtime_error
.maybe_sweep:
    cmp r14, rbx
    jb .wait
    lea rbx, [r14 + 1000000000]
    lea r15, [rel clients]
.sweep:
    mov edi, [r15]
    test edi, edi
    jz .sweep_next
    cmp r14, [r15 + 32]
    jb .sweep_next
    mov dword [r15], 0
    dec edi
    call close
.sweep_next:
    add r15, 8232
    lea rax, [rel clients_end]
    cmp r15, rax
    jb .sweep
    jmp .wait
.runtime_error:
    lea rdi, [rel program_name]
    call perror
    mov eax, 1
    jmp .return
.usage_error:
    mov eax, 2
.return:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata.main alloc noexec nowrite progbits
program_name: db "httpd", 0
ready_format: db "PORT %u", 10, 0
enable_option: dd 1
listen_event: dd 1              ; EPOLLIN
    dq 0                       ; listener sentinel

section .data.main alloc noexec write progbits
client_event: dd 0x2001         ; EPOLLIN | EPOLLRDHUP
    dq 0

section .bss.main alloc noexec write nobits align=8
clients: resb 526848            ; 64 slots of 8232 bytes
clients_end:
monotonic_time: resq 2
listen_address: resb 16
wait_event: resb 12
listen_address_length: resd 1
ready_count: resd 1
accepted_fd: resd 1

section .note.GNU-stack noalloc noexec nowrite progbits
