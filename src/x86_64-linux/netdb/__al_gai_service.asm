; Select TCP/UDP and resolve the service for those transports.
; Context offsets: transport mask 4, network ports 8/10, flags 16,
; token cursor 40, line buffer 1088.
bits 64
default rel

global __al_gai_service:function
extern __al_gai_port:function
extern __al_gai_line:function
extern __al_gai_word:function
extern fclose:function
extern fopen:function
extern strcmp:function

section .text.__al_gai_service alloc exec nowrite progbits
__al_gai_service:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32
    mov rbx, rdi                ; resolver context
    mov r13, rsi                ; service text
    mov r15d, 3                 ; TCP and UDP unless constrained by hints
    test edx, edx
    jz .protocol
    mov r15d, 1
    cmp edx, 1                  ; SOCK_STREAM
    je .protocol
    mov r15d, 2
    cmp edx, 2                  ; SOCK_DGRAM
    jne .unsupported_type
.protocol:
    test ecx, ecx
    jz .numeric
    cmp ecx, 6                  ; IPPROTO_TCP
    je .only_tcp
    cmp ecx, 17                 ; IPPROTO_UDP
    jne .no_service
    and r15d, 2
    jmp .check_protocol
.only_tcp:
    and r15d, 1
.check_protocol:
    jz .no_service
.numeric:
    xor eax, eax
    test r13, r13
    jz .store_numeric
    mov rdi, r13
    xor esi, esi
    call __al_gai_port
    test eax, eax
    js .named
.store_numeric:
    rol ax, 8
    mov [rbx + 8], ax
    mov [rbx + 10], ax
    mov [rbx + 4], r15d
    xor eax, eax
    jmp .return
.named:
    test dword [rbx + 16], 1024 ; AI_NUMERICSERV
    jnz .numeric_required
    lea rdi, [rel services_path]
    lea rsi, [rel read_mode]
    call fopen
    test rax, rax
    jz .no_service
    mov r14, rax
.read_line:
    mov rdi, r14
    lea rsi, [rbx + 1088]
    call __al_gai_line
    test rax, rax
    jz .done_file
    mov [rbx + 40], rax
    lea rdi, [rbx + 40]
    call __al_gai_word
    test rax, rax
    jz .read_line
    mov [rsp + 8], rax          ; primary service name
    lea rdi, [rbx + 40]
    call __al_gai_word
    test rax, rax
    jz .read_line
    mov rdi, rax
    mov esi, 47                 ; port/protocol
    call __al_gai_port
    test eax, eax
    js .read_line
    rol ax, 8
    mov [rsp], ax
    lea rdi, [rdx + 1]
    mov [rsp + 16], rdi
    lea rsi, [rel tcp]
    call strcmp
    mov r12d, 1
    test eax, eax
    jz .check_transport
    mov rdi, [rsp + 16]
    lea rsi, [rel udp]
    call strcmp
    mov r12d, 2
    test eax, eax
    jnz .read_line
.check_transport:
    test r15d, r12d
    jz .read_line
    test [rbx + 4], r12d
    jnz .read_line              ; the first matching row per transport wins
    mov rax, [rsp + 8]
.match_name:
    mov rdi, r13
    mov rsi, rax
    call strcmp
    test eax, eax
    jz .store_named
    lea rdi, [rbx + 40]
    call __al_gai_word
    test rax, rax
    jnz .match_name
    jmp .read_line
.store_named:
    mov ax, [rsp]
    mov ecx, r12d
    dec ecx
    mov [rbx + rcx * 2 + 8], ax
    or [rbx + 4], r12d
    cmp [rbx + 4], r15d
    jne .read_line
.done_file:
    mov rdi, r14
    call fclose
    cmp dword [rbx + 4], 0
    je .no_service
    xor eax, eax
    jmp .return
.unsupported_type:
    mov eax, -7                 ; EAI_SOCKTYPE
    jmp .return
.no_service:
    mov eax, -8                 ; EAI_SERVICE
    jmp .return
.numeric_required:
    mov eax, -2                 ; EAI_NONAME
.return:
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata.__al_gai_service alloc noexec nowrite progbits
services_path: db "/etc/services", 0
read_mode: db "r", 0
tcp: db "tcp", 0
udp: db "udp", 0

section .note.GNU-stack noalloc noexec nowrite progbits
