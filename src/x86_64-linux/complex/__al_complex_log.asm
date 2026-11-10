; Principal complex log. Inputs use kind and raw real/imaginary. Return raw words in rax/rdx/rcx/r8d.
bits 64
default rel

global __al_complex_log:function
extern __al_fp_decode:function
extern __al_math_atan:function
extern __al_complex_norm:function
extern __al_math_log:function
extern __al_math_effects:function
extern __al_fp_special:function
extern __al_round_irrational:function
extern __al_lock:function
extern __al_unlock:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_big_right_sticky:function
extern __al_big_bits:function
extern __al_big_cmp:function
extern __al_big_copy:function
extern __al_big_add:function
extern __al_big_sub:function
extern __al_big_divsmall:function
extern __al_big_multiply:function
extern __al_fixed_mul256:function

section .text.__al_complex_log alloc exec nowrite progbits
__al_complex_log:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 80
    mov ebx, edi
    mov r12, rsi
    mov r13d, edx
    mov r14, rcx
    mov r15d, r8d
    call __al_fp_decode
    mov [rsp], rax
    mov [rsp + 8], edx
    mov [rsp + 12], r8d
    mov [rsp + 16], ecx
    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    call __al_fp_decode
    mov [rsp + 24], rax
    mov [rsp + 32], edx
    mov [rsp + 36], r8d
    mov [rsp + 40], ecx
    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    mov rcx, r12
    mov r8d, r13d
    mov r9d, 1
    call __al_math_atan
    mov [rsp + 48], rax          ; imaginary result
    mov [rsp + 56], edx
    cmp dword [rsp + 12], 3
    je .infinite
    cmp dword [rsp + 36], 3
    je .infinite
    cmp dword [rsp + 12], 4
    jae .nan
    cmp dword [rsp + 36], 4
    jae .nan
    cmp dword [rsp + 12], 0
    jne .finite
    cmp dword [rsp + 36], 0
    je .pole
.finite:
    lea rdi, [rel complex_log_lock]
    call __al_lock
    lea rdi, [rel norm]
    lea rsi, [rel norm_scratch]
    mov rdx, [rsp]
    movsxd rcx, dword [rsp + 8]
    mov r8, [rsp + 24]
    movsxd r9, dword [rsp + 32]
    call __al_complex_norm
    mov [rsp + 64], eax          ; common exponent of |z| squared
    lea rdi, [rel norm]
    call __al_big_bits
    movsxd rdx, dword [rsp + 64]
    add rax, rdx
    dec rax
    cmp rax, -1
    jl .full_log
    test rax, rax
    jg .full_log

    ; Keep the exact difference from one for the near-unit circle.
    lea rdi, [rel unit]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel unit]
    movsxd rsi, dword [rsp + 64]
    neg rsi
    call __al_big_left
    lea rdi, [rel norm]
    lea rsi, [rel unit]
    call __al_big_cmp
    test eax, eax
    jz .exact_zero
    js .below_unit
    mov dword [rsp + 68], 0
    lea rsi, [rel norm]
    lea r14, [rel unit]
    jmp .difference
.below_unit:
    mov dword [rsp + 68], 1
    lea rsi, [rel unit]
    lea r14, [rel norm]
.difference:
    lea rdi, [rel delta]
    call __al_big_copy
    lea rdi, [rel delta]
    mov rsi, r14
    call __al_big_sub
    lea rdi, [rel delta]
    call __al_big_bits
    movsxd rdx, dword [rsp + 64]
    lea rax, [rax + rdx - 1]
    cmp rax, -80
    jge .full_log
    cmp rax, -200
    jl .tiny_delta

    ; log(1+d) = d*(1-d/2+d^2/3+...). Compute the factor on
    ; the fixed grid and multiply by the full exact dyadic d.
    lea rdi, [rel term]
    lea rsi, [rel delta]
    call __al_big_copy
    movsxd rsi, dword [rsp + 64]
    add rsi, 256
    js .fixed_delta_right
    lea rdi, [rel term]
    call __al_big_left
    jmp .fixed_delta
.fixed_delta_right:
    neg rsi
    lea rdi, [rel term]
    call __al_big_right_sticky
.fixed_delta:
    lea rdi, [rel product]
    lea rsi, [rel term]
    mov rdx, rsi
    lea rcx, [rel product_words]
    call __al_fixed_mul256
    lea rdi, [rel product]
    mov esi, 3
    call __al_big_divsmall
    lea rdi, [rel factor]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel factor]
    mov esi, 256
    call __al_big_left
    lea rdi, [rel factor]
    lea rsi, [rel product]
    call __al_big_add
    lea rdi, [rel term]
    mov esi, 1
    call __al_big_right_sticky
    lea rdi, [rel factor]
    lea rsi, [rel term]
    cmp dword [rsp + 68], 0
    jne .add_linear
    call __al_big_sub
    jmp .multiply_delta
.add_linear:
    call __al_big_add
.multiply_delta:
    lea rdi, [rel result]
    lea rsi, [rel delta]
    lea rdx, [rel factor]
    call __al_big_multiply
    movsxd rax, dword [rsp + 64]
    sub rax, 257
    jmp .round_scale

.tiny_delta:
    ; Below 2^-200 one component has unit magnitude and the other
    ; supplies a square with at most 128 significant bits.
    lea rdi, [rel result]
    lea rsi, [rel delta]
    call __al_big_copy
    lea rdi, [rel result]
    mov esi, 224
    call __al_big_left
    lea rdi, [rel term]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel result]
    lea rsi, [rel term]
    call __al_big_sub
    movsxd rax, dword [rsp + 64]
    sub rax, 225
    jmp .round_scale

.full_log:
    mov edi, ebx
    lea rsi, [rel norm]
    mov edx, [rsp + 64]
    mov ecx, 5
    lea r8, [rel result]
    call __al_math_log
    mov [rsp + 68], eax
    mov rax, -257
.round_scale:
    mov [rel metadata + 16], rax
    mov eax, [rsp + 68]
    mov [rel metadata + 8], rax
    mov qword [rel metadata + 24], 2
    mov qword [rel metadata + 32], 0
    lea rdi, [rel result]
    lea rsi, [rel denominator]
    lea rdx, [rel comparison]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_round_irrational
    mov r12, rax
    mov r13d, edx
    mov [rsp + 72], ecx
    lea rdi, [rel complex_log_lock]
    call __al_unlock
    mov edi, [rsp + 72]
    xor esi, esi
    test edi, 16
    jz .effects
    mov esi, 34
.effects:
    call __al_math_effects
    mov rax, r12
    mov edx, r13d
    jmp .return
.exact_zero:
    lea rdi, [rel complex_log_lock]
    call __al_unlock
    xor eax, eax
    xor edx, edx
    jmp .return
.nan:
    mov rax, [rsp + 48]
    mov edx, [rsp + 56]
    jmp .return
.pole:
    mov edi, 4
    mov esi, 34
    call __al_math_effects
    mov edx, 1
    jmp .pack_infinity
.infinite:
    xor edx, edx
.pack_infinity:
    mov edi, ebx
    xor esi, esi
    call __al_fp_special
.return:
    mov rcx, [rsp + 48]
    mov r8d, [rsp + 56]
    add rsp, 80
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .bss.__al_complex_log alloc noexec write nobits align=8
complex_log_lock:
    resq 1
metadata:
    resq 6
norm:
    resq 1281
norm_scratch:
    resq 1281
unit:
    resq 1281
delta:
    resq 1281
factor:
    resq 1281
term:
    resq 1281
product:
    resq 1281
result:
    resq 1281
denominator:
    resq 1281
comparison:
    resq 1281
product_words:
    resd 18

section .note.GNU-stack noalloc noexec nowrite progbits
