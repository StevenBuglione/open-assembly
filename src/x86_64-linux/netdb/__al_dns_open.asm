; Open and connect a nonblocking DNS socket within the work block's deadline.
; Return the descriptor or -1. Socket option scratch starts at offset 316.
bits 64
default rel

global __al_dns_open:function
extern __al_dns_wait:function
extern __errno_location:function
extern close:function
extern connect:function
extern getsockopt:function
extern socket:function

section .text.__al_dns_open alloc exec nowrite progbits
__al_dns_open:
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 8
    mov r12, rdi                ; work block
    mov r13, rsi                ; sockaddr
    mov r14d, edx               ; sockaddr length
    movzx edi, word [r13]
    mov esi, ecx
    or esi, 526336              ; SOCK_NONBLOCK | SOCK_CLOEXEC
    xor edx, edx
    call socket
    test eax, eax
    js .failed
    mov ebx, eax
    mov edi, eax
    mov rsi, r13
    mov edx, r14d
    call connect
    test eax, eax
    jz .connected
    call __errno_location
    mov eax, [rax]
    cmp eax, 115                ; EINPROGRESS
    je .pending
    cmp eax, 4                  ; EINTR can leave a connection pending
    jne .close_socket
.pending:
    mov edi, ebx
    mov esi, 4                  ; POLLOUT
    mov rdx, r12
    call __al_dns_wait
    test eax, eax
    jz .close_socket
    mov dword [r12 + 316], 4
    mov edi, ebx
    mov esi, 1                  ; SOL_SOCKET
    mov edx, 4                  ; SO_ERROR
    lea rcx, [r12 + 320]
    lea r8, [r12 + 316]
    call getsockopt
    test eax, eax
    jnz .close_socket
    cmp dword [r12 + 320], 0
    jne .close_socket
.connected:
    mov eax, ebx
    jmp .return
.close_socket:
    mov edi, ebx
    call close
.failed:
    mov eax, -1
.return:
    add rsp, 8
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
