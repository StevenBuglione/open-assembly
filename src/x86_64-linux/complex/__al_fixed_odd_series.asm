; Evaluate atan (rcx 0) or atanh (rcx 1) at Q-rdx argument rsi into rdi.
bits 64
default rel

global __al_fixed_odd_series:function
extern __al_lock:function
extern __al_unlock:function
extern __al_fixed_mul_precision:function
extern __al_big_bits:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_big_copy:function
extern __al_big_divsmall:function
extern __al_big_sub:function
extern __al_big_add:function

section .text.__al_fixed_odd_series alloc exec nowrite progbits
__al_fixed_odd_series:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 64
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14d, ecx
    cmp qword [r12], 0
    je .argument
    lea rdi, [rel series_lock]
    call __al_lock
    lea rdi, [rel squared]
    mov rsi, r12
    mov rdx, r12
    mov rcx, r13
    lea r8, [rel scratch]
    call __al_fixed_mul_precision
    cmp qword [rel squared], 0
    je .unlock_argument

    ; Each power decays by at least the leading zero count of r².
    lea rdi, [rel squared]
    call __al_big_bits
    mov rsi, r13
    sub rsi, rax
    mov rax, r13
    xor edx, edx
    div rsi
    add eax, 2
    mov [rsp], eax              ; terms including the constant
    mov r15d, 16
    cmp r13d, 1024
    jbe .power_table
    mov r15d, 64
    cmp r13d, 4096
    jbe .power_table
    mov r15d, 96
.power_table:
    lea rdi, [rel powers]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel powers]
    mov rsi, r13
    call __al_big_left
    mov dword [rsp + 4], 1
.power:
    mov eax, [rsp + 4]
    imul eax, 2304
    lea rdi, [rel powers]
    add rdi, rax
    lea rsi, [rdi - 2304]
    lea rdx, [rel squared]
    mov rcx, r13
    lea r8, [rel scratch]
    call __al_fixed_mul_precision
    inc dword [rsp + 4]
    cmp [rsp + 4], r15d
    jbe .power

    mov eax, [rsp]
    dec eax
    xor edx, edx
    div r15
    imul eax, r15d
    mov [rsp + 8], eax          ; coefficient index of the highest block
    mov qword [rel value], 0
.block:
    cmp qword [rel value], 0
    je .start_block
    mov eax, r15d
    imul eax, 2304
    lea rdx, [rel powers]
    add rdx, rax
    lea rdi, [rel value]
    mov rsi, rdi
    mov rcx, r13
    lea r8, [rel scratch]
    call __al_fixed_mul_precision
.start_block:
    mov qword [rel block], 0
    mov dword [rsp + 12], 0
.term:
    mov eax, [rsp + 12]
    add eax, [rsp + 8]
    cmp eax, [rsp]
    jae .combine
    lea eax, [rax*2 + 1]
    mov [rsp + 16], eax
    mov eax, [rsp + 12]
    imul eax, 2304
    lea rsi, [rel powers]
    add rsi, rax
    lea rdi, [rel term]
    call __al_big_copy
    lea rdi, [rel term]
    mov esi, [rsp + 16]
    call __al_big_divsmall
    lea rdi, [rel block]
    lea rsi, [rel term]
    test r14d, r14d
    jnz .positive
    test dword [rsp + 12], 1
    jz .positive
    call __al_big_sub
    jmp .next_term
.positive:
    call __al_big_add
.next_term:
    inc dword [rsp + 12]
    cmp [rsp + 12], r15d
    jb .term
.combine:
    lea rdi, [rel value]
    lea rsi, [rel block]
    call __al_big_add
    sub [rsp + 8], r15d
    jns .block
    mov rdi, rbx
    mov rsi, r12
    lea rdx, [rel value]
    mov rcx, r13
    lea r8, [rel scratch]
    call __al_fixed_mul_precision
    lea rdi, [rel series_lock]
    call __al_unlock
    jmp .done
.unlock_argument:
    lea rdi, [rel series_lock]
    call __al_unlock
.argument:
    mov rdi, rbx
    mov rsi, r12
    call __al_big_copy
.done:
    add rsp, 64
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .bss alloc noexec write nobits
alignb 16
series_lock: resd 1
alignb 16
powers: resb 223488
squared: resb 2304
term: resb 2304
block: resb 2304
value: resb 2304
scratch: resb 10248

section .note.GNU-stack noalloc noexec nowrite progbits
