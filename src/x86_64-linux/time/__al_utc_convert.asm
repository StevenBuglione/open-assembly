; Original Gregorian conversion for epoch seconds passed by value.
bits 64
default rel

global __al_utc_convert:function
extern __al_syscall_result:function
extern __al_gregorian_split:function

section .text.__al_utc_convert alloc exec nowrite progbits
__al_utc_convert:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r12, rsi                  ; public result, untouched until year fits
    mov rax, rdi
    cqo
    mov r9d, 86400
    idiv r9
    test rdx, rdx
    jns .split_day
    add rdx, 86400
    dec rax                       ; floor division for pre-epoch timestamps
.split_day:
    mov r13, rax                 ; days since 1970-01-01
    mov r14, rdx                 ; seconds within the day

    mov rdi, r13
    call __al_gregorian_split
    mov r15, rax
    mov rbx, rdx
    mov r8, rcx
    sub r15, 1900
    cmp r15, 2147483647
    jg .overflow
    cmp r15, -2147483648
    jl .overflow

    xor r9d, r9d                 ; leap-day adjustment for February
    test r8b, 3
    jnz .find_month
    cmp r8d, 100
    je .find_month
    cmp r8d, 200
    je .find_month
    cmp r8d, 300
    je .find_month
    mov r9d, 1
.find_month:
    mov rdi, rbx
    xor r10d, r10d
    lea rsi, [rel month_lengths]
.month:
    movzx edx, byte [rsi + r10]
    cmp r10d, 1
    jne .month_length
    add edx, r9d
.month_length:
    cmp rdi, rdx
    jb .date
    sub rdi, rdx
    inc r10d
    jmp .month
.date:
    inc edi                       ; one-based day of month
    mov [r12 + 12], edi
    mov [r12 + 16], r10d
    mov [r12 + 20], r15d
    mov [r12 + 28], ebx

    lea rax, [r13 + 4]           ; 1970-01-01 was Thursday
    cqo
    mov r9d, 7
    idiv r9
    test edx, edx
    jns .weekday
    add edx, 7
.weekday:
    mov [r12 + 24], edx
    mov rax, r14
    xor edx, edx
    mov r9d, 3600
    div r9
    mov [r12 + 8], eax
    mov rax, rdx
    xor edx, edx
    mov r9d, 60
    div r9
    mov [r12 + 4], eax
    mov [r12], edx
    mov qword [r12 + 32], 0      ; DST flag and padding
    mov qword [r12 + 40], 0      ; UTC offset
    lea rax, [rel utc_name]
    mov [r12 + 48], rax
    mov rax, r12
    jmp .done
.overflow:
    mov rdi, -75                  ; EOVERFLOW
    call __al_syscall_result
    xor eax, eax
.done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.__al_utc_convert alloc noexec nowrite progbits
month_lengths:
    db 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
utc_name:
    db 'UTC', 0

section .note.GNU-stack noalloc noexec nowrite progbits
