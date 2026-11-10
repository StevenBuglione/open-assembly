; Original POSIX TZ rule. Inputs: NUL-terminated rule, zone record, and
; max transition hour. A zone owns both names. Return zero on success.
bits 64
default rel

global __al_tz_rule_parse:function
extern __al_tz_name:function
extern __al_tz_value:function
extern __al_tz_date_rule:function

section .text.__al_tz_rule_parse alloc exec nowrite progbits
__al_tz_rule_parse:
    push rbx
    push r12
    push r13
    mov rbx, rsi
    mov r12, rdx
    mov qword [rbx + 104], 0
    lea rsi, [rbx + 240]
    mov [rbx + 128], rsi
    call __al_tz_name
    test rax, rax
    jz .invalid
    mov rdi, rax
    mov esi, 24
    call __al_tz_value
    test rax, rax
    jz .invalid
    neg rdx                       ; POSIX notation is seconds west
    mov [rbx + 112], rdx
    cmp byte [rax], 0
    je .fixed
    mov rdi, rax
    lea rsi, [rbx + 304]
    mov [rbx + 136], rsi
    call __al_tz_name
    test rax, rax
    jz .invalid
    movzx ecx, byte [rax]
    test ecx, ecx
    jz .default_dst
    cmp ecx, 44
    je .default_dst
    mov rdi, rax
    mov esi, 24
    call __al_tz_value
    test rax, rax
    jz .invalid
    neg rdx
    jmp .offset_ready
.default_dst:
    mov rdx, [rbx + 112]
    add rdx, 3600
.offset_ready:
    mov [rbx + 120], rdx
    cmp byte [rax], 0
    je .default_dates
    cmp byte [rax], 44
    jne .invalid
    lea rdi, [rax + 1]
    lea rsi, [rbx + 144]
    mov rdx, r12
    call __al_tz_date_rule
    test rax, rax
    jz .invalid
    cmp byte [rax], 44
    jne .invalid
    lea rdi, [rax + 1]
    lea rsi, [rbx + 192]
    mov rdx, r12
    call __al_tz_date_rule
    test rax, rax
    jz .invalid
    cmp byte [rax], 0
    jne .invalid
    jmp .recurring
.default_dates:
    mov qword [rbx + 144], 2       ; M3.2.0/2
    mov qword [rbx + 152], 2
    mov qword [rbx + 160], 2
    mov qword [rbx + 168], 0
    mov qword [rbx + 176], 7200
    mov qword [rbx + 184], 0
    mov qword [rbx + 192], 2       ; M11.1.0/2
    mov qword [rbx + 200], 10
    mov qword [rbx + 208], 1
    mov qword [rbx + 216], 0
    mov qword [rbx + 224], 7200
    mov qword [rbx + 232], 0
.recurring:
    mov qword [rbx + 104], 2
    jmp .success
.fixed:
    mov qword [rbx + 104], 1
.success:
    xor eax, eax
    jmp .done
.invalid:
    mov eax, -1
.done:
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
