; Original annual transition. Inputs: zone, full year, rule record,
; end-of-DST flag. Return the transition timestamp in POSIX seconds.
bits 64
default rel

global __al_tz_rule_instant:function
extern __al_gregorian_day:function

section .text.__al_tz_rule_instant alloc exec nowrite progbits
__al_tz_rule_instant:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r12, rdi
    mov r13, rsi
    mov rbx, rdx
    mov r14, rcx
    cmp qword [rbx], 2
    je .monthly
    mov rdi, r13
    xor esi, esi
    mov rdx, [rbx + 8]
    cmp qword [rbx], 1
    je .julian
    inc rdx                      ; zero-based day of year
    call __al_gregorian_day
    jmp .seconds
.julian:
    call __al_gregorian_day
    cmp qword [rbx + 8], 60
    jb .seconds
    test r13b, 3
    jnz .seconds
    mov r15, rax
    mov rax, r13
    cqo
    mov ecx, 100
    idiv rcx
    test rdx, rdx
    jnz .leap
    test al, 3
    jnz .julian_ready
.leap:
    inc r15
.julian_ready:
    mov rax, r15
    jmp .seconds

.monthly:
    mov rdi, r13
    mov rsi, [rbx + 8]
    mov edx, 1
    call __al_gregorian_day
    mov r15, rax
    add rax, 4
    cqo
    mov ecx, 7
    idiv rcx
    test rdx, rdx
    jns .first_weekday
    add rdx, 7
.first_weekday:
    mov rax, [rbx + 24]
    sub rax, rdx
    jns .first_match
    add rax, 7
.first_match:
    add r15, rax
    mov rax, [rbx + 16]
    dec rax
    imul rax, 7
    add r15, rax
    cmp qword [rbx + 16], 5
    jne .month_ready
    mov rdi, r13
    mov rsi, [rbx + 8]
    inc rsi
    cmp rsi, 12
    jb .next_month
    xor esi, esi
    inc rdi
.next_month:
    mov edx, 1
    call __al_gregorian_day
    cmp r15, rax
    jl .month_ready
    sub r15, 7
.month_ready:
    mov rax, r15
.seconds:
    imul rax, 86400
    add rax, [rbx + 32]
    mov rcx, [rbx + 40]
    cmp rcx, 2
    je .done
    test rcx, rcx
    jnz .standard
    test r14, r14
    jz .standard
    sub rax, [r12 + 120]         ; end transition uses the previous DST offset
    jmp .done
.standard:
    sub rax, [r12 + 112]
.done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
