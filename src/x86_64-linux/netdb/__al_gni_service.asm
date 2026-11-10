; Render the service into the context's 256-byte buffer at offset 320.
bits 64
default rel

global __al_gni_service:function
extern __al_gai_line:function
extern __al_gai_port:function
extern __al_gai_word:function
extern fclose:function
extern fopen:function
extern snprintf:function
extern strcmp:function

section .text.__al_gni_service alloc exec nowrite progbits
__al_gni_service:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi                ; context
    movzx r13d, si              ; host-order port
    mov r14d, edx               ; flags
    test r14d, 2                ; NI_NUMERICSERV
    jnz .numeric
    lea rdi, [rel services_path]
    lea rsi, [rel read_mode]
    call fopen
    test rax, rax
    jz .numeric
    mov r15, rax
.read_line:
    mov rdi, r15
    lea rsi, [r12 + 1088]
    call __al_gai_line
    test rax, rax
    jz .close_missing
    mov [r12 + 40], rax
    lea rdi, [r12 + 40]
    call __al_gai_word
    test rax, rax
    jz .read_line
    mov rbx, rax                ; service name
    lea rdi, [r12 + 40]
    call __al_gai_word
    test rax, rax
    jz .read_line
    mov rdi, rax
    mov esi, 47                 ; port/protocol
    call __al_gai_port
    cmp eax, r13d
    jne .read_line
    lea rdi, [rdx + 1]
    lea rsi, [rel tcp]
    test r14d, 16               ; NI_DGRAM selects UDP
    jz .protocol
    lea rsi, [rel udp]
.protocol:
    call strcmp
    test eax, eax
    jnz .read_line
    xor ecx, ecx
.copy_name:
    cmp ecx, 256
    jae .read_line
    mov al, [rbx + rcx]
    mov [r12 + rcx + 320], al
    inc ecx
    test al, al
    jnz .copy_name
    mov rdi, r15
    call fclose
    jmp .success
.close_missing:
    mov rdi, r15
    call fclose
.numeric:
    lea rdi, [r12 + 320]
    mov esi, 256
    lea rdx, [rel decimal]
    mov ecx, r13d
    xor eax, eax
    call snprintf
    test eax, eax
    js .failed
.success:
    xor eax, eax
    jmp .return
.failed:
    mov eax, -4                 ; EAI_FAIL
.return:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata.__al_gni_service alloc noexec nowrite progbits
services_path: db "/etc/services", 0
read_mode: db "r", 0
tcp: db "tcp", 0
udp: db "udp", 0
decimal: db "%u", 0

section .note.GNU-stack noalloc noexec nowrite progbits
