; Resolve an A, AAAA or PTR question through a caller-supplied name server.
; UDP and a truncation-triggered TCP retry each have a two-second deadline.
; The work block holds a deadline, timespec, pollfd, framed query and reply.
bits 64
default rel

global __al_dns_query:function
extern __al_dns_build:function
extern __al_dns_now:function
extern __al_dns_open:function
extern __al_dns_parse:function
extern __al_dns_transfer:function
extern __al_dns_wait:function
extern __al_syscall:function
extern __errno_location:function
extern close:function
extern free:function
extern malloc:function
extern recv:function

section .text.__al_dns_query alloc exec nowrite progbits
__al_dns_query:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 64
    mov r12, rdi                ; name server sockaddr
    mov r13d, esi               ; sockaddr length
    mov r14, rdx                ; DNS name
    mov r15, r8                 ; answer block
    mov [rsp + 8], ecx          ; RR type
    mov dword [rsp + 12], -1    ; active descriptor
    mov qword [r15], 0
    xor ebx, ebx                ; work block, once allocated
    call __errno_location
    mov [rsp + 32], rax
    mov eax, [rax]
    mov [rsp + 40], eax
    mov edi, 65872
    call malloc
    test rax, rax
    jz .no_memory
    mov rbx, rax
    mov rdi, r14
    mov esi, [rsp + 8]
    xor edx, edx
    lea rcx, [rbx + 34]        ; reserve two preceding bytes for TCP framing
    mov r8d, 271
    call __al_dns_build
    test rax, rax
    jz .bad_name
    mov [rsp + 16], rax
.random_id:
    mov qword [rsp], 0
    mov edi, 318                ; getrandom
    lea rsi, [rbx + 34]
    mov edx, 2
    mov ecx, 1                  ; GRND_NONBLOCK
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4                 ; EINTR
    je .random_id
    cmp rax, 2
    jne .temporary
    mov rdi, rbx
    call __al_dns_now
    test rax, rax
    js .temporary
    add rax, 2000
    mov [rbx], rax
    mov rdi, rbx
    mov rsi, r12
    mov edx, r13d
    mov ecx, 2                  ; SOCK_DGRAM
    call __al_dns_open
    test eax, eax
    js .temporary
    mov [rsp + 12], eax
    mov edi, eax
    lea rsi, [rbx + 34]
    mov rdx, [rsp + 16]
    mov ecx, 1                  ; transmit
    mov r8, rbx
    call __al_dns_transfer
    test eax, eax
    jz .temporary
.udp_receive:
    mov edi, [rsp + 12]
    mov esi, 1                  ; POLLIN
    mov rdx, rbx
    call __al_dns_wait
    test eax, eax
    jz .temporary
    mov edi, [rsp + 12]
    lea rsi, [rbx + 336]
    mov edx, 65535
    xor ecx, ecx
    call recv
    test rax, rax
    js .udp_error
    mov rsi, rax
    lea rdi, [rbx + 336]
    lea rdx, [rbx + 34]
    mov rcx, [rsp + 16]
    mov r8, r15
    call __al_dns_parse
    cmp eax, 2                  ; unrelated transaction or question
    je .udp_receive
    cmp eax, 1                  ; truncated matching response
    jne .finish
    mov edi, [rsp + 12]
    call close
    mov dword [rsp + 12], -1
    jmp .tcp
.udp_error:
    call __errno_location
    mov eax, [rax]
    cmp eax, 4                  ; EINTR
    je .udp_receive
    cmp eax, 11                 ; EAGAIN
    je .udp_receive
    jmp .temporary
.tcp:
    mov rdi, rbx
    call __al_dns_now
    test rax, rax
    js .temporary
    add rax, 2000
    mov [rbx], rax
    mov rdi, rbx
    mov rsi, r12
    mov edx, r13d
    mov ecx, 1                  ; SOCK_STREAM
    call __al_dns_open
    test eax, eax
    js .temporary
    mov [rsp + 12], eax
    mov edi, eax
    mov rdx, [rsp + 16]
    mov eax, edx
    rol ax, 8
    mov [rbx + 32], ax
    lea rsi, [rbx + 32]
    add rdx, 2
    mov ecx, 1
    mov r8, rbx
    call __al_dns_transfer
    test eax, eax
    jz .temporary
    mov edi, [rsp + 12]
    lea rsi, [rbx + 312]
    mov edx, 2
    xor ecx, ecx
    mov r8, rbx
    call __al_dns_transfer
    test eax, eax
    jz .temporary
    movzx edx, word [rbx + 312]
    rol dx, 8
    cmp edx, 12
    jb .malformed
    mov [rsp + 48], rdx
    mov edi, [rsp + 12]
    lea rsi, [rbx + 336]
    xor ecx, ecx
    mov r8, rbx
    call __al_dns_transfer
    test eax, eax
    jz .temporary
    lea rdi, [rbx + 336]
    mov rsi, [rsp + 48]
    lea rdx, [rbx + 34]
    mov rcx, [rsp + 16]
    mov r8, r15
    call __al_dns_parse
    test eax, eax
    jle .finish
.malformed:
    mov eax, -4                 ; EAI_FAIL
    jmp .finish
.temporary:
    mov eax, -3                 ; EAI_AGAIN
    jmp .finish
.bad_name:
    mov eax, -2                 ; EAI_NONAME
    jmp .finish
.no_memory:
    mov eax, -10                ; EAI_MEMORY
.finish:
    mov [rsp + 24], eax
    mov edi, [rsp + 12]
    test edi, edi
    js .release
    call close
.release:
    test rbx, rbx
    jz .restore_errno
    mov rdi, rbx
    call free
.restore_errno:
    mov rcx, [rsp + 32]
    mov edx, [rsp + 40]
    mov [rcx], edx
    mov eax, [rsp + 24]
    add rsp, 64
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
