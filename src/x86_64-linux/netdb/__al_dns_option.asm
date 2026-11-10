; Apply one resolver option token to the search record and server bank.
; RDI token, RSI optional search record, RDX bank.
bits 64
default rel

global __al_dns_option:function
extern strcmp:function
extern strncmp:function

section .text.__al_dns_option alloc exec nowrite progbits
__al_dns_option:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    lea rsi, [rel rotate]
    call strcmp
    test eax, eax
    jz .set_rotate
    mov rdi, rbx
    lea rsi, [rel timeout]
    mov edx, 8
    call strncmp
    test eax, eax
    jz .timeout
    mov rdi, rbx
    lea rsi, [rel attempts]
    mov edx, 9
    call strncmp
    test eax, eax
    jz .attempts
    test r12, r12
    jz .return
    mov rdi, rbx
    lea rsi, [rel ndots]
    mov edx, 6
    call strncmp
    test eax, eax
    jnz .return
    lea rsi, [rbx + 6]
    lea rdi, [r12 + 4]
    xor r8d, r8d
    mov r9d, 15
    jmp .digits
.timeout:
    lea rsi, [rbx + 8]
    lea rdi, [r13 + 112]
    mov r8d, 1
    mov r9d, 30
    jmp .digits
.attempts:
    lea rsi, [rbx + 9]
    lea rdi, [r13 + 116]
    mov r8d, 1
    mov r9d, 5
.digits:
    cmp byte [rsi], 0
    je .return
    xor ecx, ecx
.digit:
    movzx eax, byte [rsi]
    test eax, eax
    jz .finish
    sub eax, 48
    cmp eax, 9
    ja .return
    imul ecx, 10
    add ecx, eax
    cmp ecx, r9d
    jbe .next
    mov ecx, r9d
.next:
    inc rsi
    jmp .digit
.finish:
    cmp ecx, r8d
    jae .store
    mov ecx, r8d
.store:
    mov [rdi], ecx
    jmp .return
.set_rotate:
    mov dword [r13 + 120], 1
.return:
    pop r13
    pop r12
    pop rbx
    ret

section .rodata.__al_dns_option alloc noexec nowrite progbits
rotate: db "rotate", 0
timeout: db "timeout:", 0
attempts: db "attempts:", 0
ndots: db "ndots:", 0

section .note.GNU-stack noalloc noexec nowrite progbits
