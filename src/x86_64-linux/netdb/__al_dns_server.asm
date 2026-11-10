; Select the first valid resolv.conf nameserver or IPv4 loopback.
; RDI resolver context, RSI a 32-byte sockaddr buffer. Return its length.
bits 64
default rel

global __al_dns_server:function
extern __al_gai_line:function
extern __al_gai_word:function
extern fopen:function
extern fclose:function
extern inet_pton:function
extern strcmp:function

section .text.__al_dns_server alloc exec nowrite progbits
__al_dns_server:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r13, rsi
    mov qword [r13], 0
    mov qword [r13 + 8], 0
    mov qword [r13 + 16], 0
    mov qword [r13 + 24], 0
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
    mov r15, rax
    mov edi, 2                  ; AF_INET
    mov rsi, rax
    lea rdx, [r13 + 4]
    call inet_pton
    test eax, eax
    jnz .ipv4
    mov edi, 10                 ; AF_INET6
    mov rsi, r15
    lea rdx, [r13 + 8]
    call inet_pton
    test eax, eax
    jz .read_line
    mov word [r13], 10
    mov r14d, 28
    jmp .configured
.ipv4:
    mov word [r13], 2
    mov r14d, 16
.configured:
    mov rdi, r12
    call fclose
    jmp .ready
.no_configured_server:
    mov rdi, r12
    call fclose
.default_server:
    mov word [r13], 2
    mov dword [r13 + 4], 0x0100007f
    mov r14d, 16
.ready:
    mov word [r13 + 2], 0x3500  ; network-order port 53
    mov eax, r14d
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata.__al_dns_server alloc noexec nowrite progbits
resolv_path: db "/etc/resolv.conf", 0
read_mode: db "r", 0
nameserver: db "nameserver", 0

section .note.GNU-stack noalloc noexec nowrite progbits
