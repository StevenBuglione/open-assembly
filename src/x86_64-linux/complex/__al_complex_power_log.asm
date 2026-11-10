; Half natural log of norm rsi*2^rdx at precision rcx into rdi. Return scale and sign.
bits 64
default rel

global __al_complex_power_log:function
extern __al_lock:function
extern __al_unlock:function
extern __al_big_copy:function
extern __al_big_bits:function
extern __al_big_cmp:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_big_add:function
extern __al_big_sub:function
extern __al_big_muladd:function
extern __al_complex_align:function
extern __al_fixed_ratio_precision:function
extern __al_complex_scaled_ratio_precision:function
extern __al_fixed_odd_series:function
extern __al_complex_power_constant:function

section .text.__al_complex_power_log alloc exec nowrite progbits
__al_complex_power_log:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 48
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    lea rdi, [rel log_lock]
    call __al_lock
    lea rdi, [rel term]
    mov rsi, r12
    call __al_big_copy
    mov rdi, r12
    call __al_big_bits
    dec rax
    lea r15, [rax + r13]
    mov [rsp], rax
    mov dword [rsp + 8], 0
    mov dword [rsp + 12], 0
    cmp r15, -1
    jl .normalized
    cmp r15, 0
    jg .normalized

    ; Close to one, evaluate the logarithm directly from its exact
    ; distance to one, so the two terms cannot cancel on the grid.
    mov dword [rsp + 8], 1
    lea rdi, [rel unit]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel term]
    lea rsi, [rel unit]
    mov rdx, r13
    xor ecx, ecx
    call __al_complex_align
    lea rdi, [rel term]
    lea rsi, [rel unit]
    call __al_big_cmp
    test eax, eax
    jz .zero
    jns .ratio
    mov dword [rsp + 12], 1
    jmp .ratio
.normalized:
    lea rdi, [rel unit]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel unit]
    mov rsi, [rsp]
    call __al_big_left
.ratio:
    lea rdi, [rel denominator]
    lea rsi, [rel term]
    call __al_big_copy
    lea rdi, [rel denominator]
    lea rsi, [rel unit]
    call __al_big_add
    lea rdi, [rel term]
    lea rsi, [rel unit]
    cmp dword [rsp + 12], 0
    je .difference
    mov rax, rdi
    mov rdi, rsi
    mov rsi, rax
.difference:
    mov r12, rdi
    call __al_big_sub

    cmp dword [rsp + 8], 0
    je .fixed_argument
    mov rdi, r12
    call __al_big_bits
    mov r13, rax
    lea rdi, [rel denominator]
    call __al_big_bits
    sub rax, r13
    add rax, rax
    cmp rax, r14
    jbe .fixed_argument
    ; The relative correction in atanh(r)/r is below this precision.
    mov rdi, rbx
    mov rsi, r12
    lea rdx, [rel denominator]
    xor ecx, ecx
    mov r8, r14
    call __al_complex_scaled_ratio_precision
    mov [rsp + 16], rax
    jmp .unlock
.fixed_argument:
    lea rdi, [rel ratio]
    mov rsi, r12
    lea rdx, [rel denominator]
    mov rcx, r14
    call __al_fixed_ratio_precision
    mov rdi, rbx
    lea rsi, [rel ratio]
    mov rdx, r14
    mov ecx, 1
    call __al_fixed_odd_series
    mov rax, r14
    neg rax
    mov [rsp + 16], rax
    cmp dword [rsp + 8], 0
    jne .unlock
    lea rdi, [rel term]
    mov rsi, r14
    xor edx, edx
    call __al_complex_power_constant
    mov rsi, r15
    test rsi, rsi
    jns .scale_ln2
    neg rsi
    mov dword [rsp + 12], 1
.scale_ln2:
    lea rdi, [rel term]
    xor edx, edx
    call __al_big_muladd
    cmp dword [rsp + 12], 0
    jne .negative
    mov rdi, rbx
    lea rsi, [rel term]
    call __al_big_add
    jmp .unlock
.negative:
    lea rdi, [rel term]
    mov rsi, rbx
    call __al_big_sub
    mov rdi, rbx
    lea rsi, [rel term]
    call __al_big_copy
    jmp .unlock
.zero:
    mov qword [rbx], 0
    mov qword [rsp + 16], 0
.unlock:
    lea rdi, [rel log_lock]
    call __al_unlock
    mov rax, [rsp + 16]
    mov edx, [rsp + 12]
    add rsp, 48
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .bss alloc noexec write nobits
alignb 16
log_lock: resd 1
alignb 16
term: resb 10248
unit: resb 10248
denominator: resb 10248
ratio: resb 2304

section .note.GNU-stack noalloc noexec nowrite progbits
