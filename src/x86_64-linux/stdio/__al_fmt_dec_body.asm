; Original exact decimal printf layout. rdi = output description,
; rsi = format fields, rdx = significand, rcx = binary exponent, r8 = sign.
bits 64
default rel

global __al_fmt_dec_body:function
extern __al_float_decimal:function
extern __al_round_decimal:function
extern __al_fmt_exponent:function
extern fegetround:function
extern memcpy:function
extern memset:function

section .text.__al_fmt_dec_body alloc exec nowrite progbits
__al_fmt_dec_body:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 72
    mov rbx, rdi
    mov r12, rsi
    mov [rsp], r8                 ; negative flag
    mov rdi, rdx
    mov rsi, rcx
    call __al_float_decimal
    mov r13, rax
    mov r14, rdx
    mov r15, rcx
    mov rax, [r12 + 32]
    or eax, 32
    mov [rsp + 8], eax            ; f/e/g
    mov rax, [r12 + 16]
    test rax, rax
    jns .precision
    mov eax, 6
.precision:
    cmp dword [rsp + 8], 103
    jne .keep
    test rax, rax
    jnz .keep
    mov eax, 1
.keep:
    mov [rsp + 16], rax
    cmp dword [rsp + 8], 103
    je .round
    inc rax
    cmp dword [rsp + 8], 101
    je .round
    add rax, r15                  ; fixed: order + 1 + fractional precision
.round:
    mov [rsp + 24], rax
    call fegetround
    mov ecx, eax
    mov rdi, r13
    mov rsi, r14
    mov rdx, [rsp + 24]
    mov r8, [rsp]
    mov r9, r15
    call __al_round_decimal
    mov r14, rax
    mov r15, rdx

    mov qword [rsp + 32], 0       ; scientific notation
    mov rcx, [rsp + 16]           ; requested fractional or significant count
    cmp dword [rsp + 8], 102
    je .fixed_index
    cmp dword [rsp + 8], 101
    je .scientific
    cmp r15, -4
    jl .scientific
    cmp r15, rcx
    jl .fixed_index
.scientific:
    mov qword [rsp + 32], 1
    mov eax, 1
    jmp .fraction_size
.fixed_index:
    lea rax, [r15 + 1]
.fraction_size:
    mov [rsp + 48], rax          ; first fractional digit index, may be negative
    cmp dword [rsp + 8], 103
    jne .save_fraction
    test qword [r12], 8          ; # keeps the requested significant zeros
    jnz .general_size
.trim:
    cmp r14, 1
    jbe .trimmed
    cmp byte [r13 + r14 - 1], 48
    jne .trimmed
    dec r14
    jmp .trim
.trimmed:
    mov rcx, r14
.general_size:
    sub rcx, rax
    jns .save_fraction
    xor ecx, ecx
.save_fraction:
    mov [rsp + 40], rcx
    lea rdi, [rel body]
    mov [rbx], rdi
    mov qword [rsp + 56], 0       ; materialized output bytes
    test rax, rax
    jle .leading_zero
    mov rdx, rax
    cmp rdx, r14
    jbe .copy_integer
    mov rdx, r14
.copy_integer:
    mov [rsp + 64], rdx
    mov rsi, r13
    call memcpy
    mov rax, [rsp + 64]
    mov [rsp + 56], rax
    mov rdx, [rsp + 48]
    sub rdx, rax
    jz .point
    lea rdi, [rel body]
    add rdi, rax
    mov esi, 48
    call memset
    mov rax, [rsp + 48]
    mov [rsp + 56], rax
    jmp .point
.leading_zero:
    mov byte [rdi], 48
    mov qword [rsp + 56], 1

.point:
    cmp qword [rsp + 40], 0
    jne .add_point
    test qword [r12], 8
    jz .suffix
.add_point:
    lea rdi, [rel body]
    mov rax, [rsp + 56]
    mov byte [rdi + rax], 46
    inc qword [rsp + 56]
    mov rax, [rsp + 48]
    test rax, rax
    jns .copy_fraction
    neg rax
    mov rdx, [rsp + 40]
    cmp rdx, rax
    jbe .write_leading_zeros
    mov rdx, rax
.write_leading_zeros:
    mov [rsp + 64], rdx
    add rdi, [rsp + 56]
    mov esi, 48
    call memset
    mov rax, [rsp + 64]
    add [rsp + 56], rax
    sub [rsp + 40], rax
    mov qword [rsp + 48], 0
.copy_fraction:
    mov rax, [rsp + 48]
    cmp rax, r14
    jae .suffix
    mov rdx, r14
    sub rdx, rax
    cmp rdx, [rsp + 40]
    jbe .copy_exact
    mov rdx, [rsp + 40]
.copy_exact:
    mov [rsp + 64], rdx
    lea rsi, [r13 + rax]
    lea rdi, [rel body]
    add rdi, [rsp + 56]
    call memcpy
    mov rax, [rsp + 64]
    add [rsp + 56], rax
    sub [rsp + 40], rax
.suffix:
    mov rax, [rsp + 56]
    mov [rbx + 8], rax
    mov rax, [rsp + 40]
    mov [rbx + 16], rax           ; zero run beyond the exact digits
    cmp qword [rsp + 32], 0
    je .done
    lea rdi, [rel exponent]
    mov [rbx + 24], rdi
    mov rsi, r15
    mov edx, 101
    cmp byte [r12 + 32], 97
    jae .exponent
    mov edx, 69
.exponent:
    mov ecx, 2
    call __al_fmt_exponent
    mov [rbx + 32], rax
.done:
    add rsp, 72
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .bss.__al_fmt_dec_body alloc noexec write nobits align=8
body:
    resb 24000
exponent:
    resb 8

section .note.GNU-stack noalloc noexec nowrite progbits
