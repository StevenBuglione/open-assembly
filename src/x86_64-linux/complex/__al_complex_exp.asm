; Compute exp of an encoded complex argument, with one final rounding per component.
bits 64
default rel

global __al_complex_exp:function
extern __al_fp_decode:function
extern __al_math_exp:function
extern __al_math_trig:function
extern __al_fp_special:function
extern __al_math_effects:function
extern __al_fp_pack_exact:function
extern __al_math_scale:function
extern __al_math_tiny_adjust:function
extern __al_lock:function
extern __al_unlock:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_big_add:function
extern __al_big_sub:function
extern __al_big_divsmall:function
extern __al_big_copy:function
extern __al_big_cmp:function
extern __al_big_mul_u64:function
extern __al_fixed_mul256:function
extern __al_round_irrational:function

section .text.__al_complex_exp alloc exec nowrite progbits
__al_complex_exp:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 96
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
    cmp dword [rsp + 36], 0
    je .real_axis
    cmp dword [rsp + 12], 3
    ja .nan_pair
    cmp dword [rsp + 36], 3
    jae .imaginary_special
    cmp dword [rsp + 12], 0
    je .imaginary_axis

    mov rax, [rsp + 24]
    bsr rax, rax
    add eax, [rsp + 32]
    mov [rsp + 44], eax
    cmp dword [rsp + 12], 3
    je .infinite_real
    mov rax, [rsp]
    bsr rax, rax
    add eax, [rsp + 8]
    mov [rsp + 48], eax
    cmp eax, -80
    jge .finite_product
    cmp dword [rsp + 44], -80
    jl .tiny_pair

.finite_product:
    lea rdi, [rel exp_lock]
    call __al_lock
    cmp dword [rsp + 48], 15
    jge .extreme_real
    cmp dword [rsp + 48], -80
    jl .near_one
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    mov ecx, 4
    lea r8, [rel exponential]
    call __al_math_exp
    mov [rsp + 56], rax
    jmp .factors
.near_one:
    mov qword [rsp + 56], 0
    lea rdi, [rel exponential]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel exponential]
    mov esi, 256
    call __al_big_left
    cmp dword [rsp + 48], -200
    jl .factors
    lea rdi, [rel term]
    mov rsi, [rsp]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel term]
    mov esi, [rsp + 8]
    add esi, 256
    call __al_big_left
    lea rdi, [rel exponential]
    lea rsi, [rel term]
    cmp dword [rsp + 16], 0
    je .add_first
    call __al_big_sub
    jmp .square
.add_first:
    call __al_big_add
.square:
    lea rdi, [rel term]
    mov rsi, rdi
    mov rdx, rdi
    lea rcx, [rel words]
    call __al_fixed_mul256
    lea rdi, [rel term]
    mov esi, 2
    call __al_big_divsmall
    lea rdi, [rel exponential]
    lea rsi, [rel term]
    call __al_big_add
.factors:
    mov rax, [rsp + 56]
    sub rax, 256
    mov [rel metadata + 16], rax
    cmp dword [rsp + 44], -80
    jl .tiny_cosine
    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    mov ecx, 4
    lea r8, [rel factor]
    call __al_math_trig
    mov [rel metadata + 8], rax
    lea rdi, [rel component]
    lea rsi, [rel exponential]
    lea rdx, [rel factor]
    lea rcx, [rel words]
    call __al_fixed_mul256
    jmp .round_real
.tiny_cosine:
    mov qword [rel metadata + 8], 0
    lea rdi, [rel component]
    lea rsi, [rel exponential]
    call __al_big_copy
.round_real:
    lea rdi, [rel component]
    lea rsi, [rel denominator]
    lea rdx, [rel comparison]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_round_irrational
    mov r12, rax
    mov r13d, edx
    mov [rsp + 64], ecx
    cmp dword [rsp + 44], -80
    jl .tiny_sine
    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    mov ecx, 3
    lea r8, [rel factor]
    call __al_math_trig
    mov [rel metadata + 8], rax
    lea rdi, [rel component]
    lea rsi, [rel exponential]
    lea rdx, [rel factor]
    lea rcx, [rel words]
    call __al_fixed_mul256
    jmp .round_imaginary
.tiny_sine:
    mov eax, [rsp + 40]
    mov [rel metadata + 8], rax
    movsxd rax, dword [rsp + 32]
    add [rel metadata + 16], rax
    lea rdi, [rel component]
    lea rsi, [rel exponential]
    mov rdx, [rsp + 24]
    call __al_big_mul_u64
.round_imaginary:
    lea rdi, [rel component]
    lea rsi, [rel denominator]
    lea rdx, [rel comparison]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_round_irrational
    mov r14, rax
    mov r15d, edx
    or [rsp + 64], ecx
    lea rdi, [rel exp_lock]
    call __al_unlock
    mov edi, [rsp + 64]
    xor esi, esi
    test edi, 24
    jz .effects
    mov esi, 34
.effects:
    call __al_math_effects
    jmp .result

.tiny_pair:
    mov dword [rsp + 64], -1
    mov dword [rsp + 68], -1
    cmp dword [rsp + 16], 0
    jne .round_tiny_pair

    ; Compare 2a and 6a to b squared. At equality, the positive
    ; fourth-order correction to the two logarithms decides below.
    lea rdi, [rel exp_lock]
    call __al_lock
    mov rax, [rsp + 24]
    mul rax
    mov rsi, rax
    lea rdi, [rel factor]
    call __al_big_init128
    lea rdi, [rel term]
    mov rsi, [rsp]
    xor edx, edx
    call __al_big_init128
    movsxd rsi, dword [rsp + 8]
    inc rsi
    movsxd rax, dword [rsp + 32]
    add rax, rax
    sub rsi, rax
    lea rdi, [rel term]
    jns .align_tiny
    neg rsi
    lea rdi, [rel factor]
.align_tiny:
    call __al_big_left
    lea rdi, [rel term]
    lea rsi, [rel factor]
    call __al_big_cmp
    test eax, eax
    jle .compare_imaginary
    mov dword [rsp + 64], 1
.compare_imaginary:
    lea rdi, [rel component]
    lea rsi, [rel term]
    mov edx, 3
    call __al_big_mul_u64
    lea rdi, [rel component]
    lea rsi, [rel factor]
    call __al_big_cmp
    test eax, eax
    jle .tiny_unlock
    mov dword [rsp + 68], 1
.tiny_unlock:
    lea rdi, [rel exp_lock]
    call __al_unlock
.round_tiny_pair:
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    xor ecx, ecx
    call __al_fp_pack_exact
    mov edi, ebx
    mov rsi, rax
    mov ecx, [rsp + 64]
    call __al_math_tiny_adjust
    mov r12, rax
    mov r13d, edx
    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    mov ecx, [rsp + 68]
    cmp dword [rsp + 40], 0
    je .adjust_imaginary
    neg ecx
.adjust_imaginary:
    call __al_math_tiny_adjust
    jmp .store_imaginary

.real_axis:
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    mov ecx, 1
    call __al_math_exp
    mov r12, rax
    mov r13d, edx
    jmp .result
.imaginary_axis:
    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    mov ecx, 1
    call __al_math_trig
    mov r12, rax
    mov r13d, edx
    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    xor ecx, ecx
    call __al_math_trig
    jmp .store_imaginary

.extreme_real:
    mov dword [rsp + 72], 1
    jmp .factor_signs
.infinite_real:
    mov dword [rsp + 72], 0
    lea rdi, [rel exp_lock]
    call __al_lock
.factor_signs:
    mov dword [rsp + 64], 0
    mov eax, [rsp + 40]
    mov [rsp + 68], eax
    cmp dword [rsp + 44], -80
    jl .unlock_signs
    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    mov ecx, 4
    lea r8, [rel factor]
    call __al_math_trig
    mov [rsp + 64], eax
    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    mov ecx, 3
    lea r8, [rel factor]
    call __al_math_trig
    mov [rsp + 68], eax
.unlock_signs:
    lea rdi, [rel exp_lock]
    call __al_unlock
    cmp dword [rsp + 72], 0
    jne .scale_extreme
    mov edi, ebx
    mov edx, [rsp + 64]
    cmp dword [rsp + 16], 0
    jne .signed_zeros
    xor esi, esi
    call __al_fp_special
    mov r12, rax
    mov r13d, edx
    mov edi, ebx
    xor esi, esi
    mov edx, [rsp + 68]
    call __al_fp_special
    jmp .store_imaginary
.signed_zeros:
    mov ecx, edx
    xor esi, esi
    xor edx, edx
    call __al_fp_pack_exact
    mov r12, rax
    mov r13d, edx
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    mov ecx, [rsp + 68]
    call __al_fp_pack_exact
    jmp .store_imaginary
.scale_extreme:
    mov qword [rsp + 56], 65536
    cmp dword [rsp + 16], 0
    je .scale_real
    neg qword [rsp + 56]
.scale_real:
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    mov ecx, [rsp + 64]
    call __al_fp_pack_exact
    mov edi, ebx
    mov rsi, rax
    mov rcx, [rsp + 56]
    call __al_math_scale
    mov r12, rax
    mov r13d, edx
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    mov ecx, [rsp + 68]
    call __al_fp_pack_exact
    mov edi, ebx
    mov rsi, rax
    mov rcx, [rsp + 56]
    call __al_math_scale
    jmp .store_imaginary

.imaginary_special:
    cmp dword [rsp + 12], 3
    jne .nan_pair
    mov dword [rsp + 64], 0
    mov eax, [rsp + 40]
    mov [rsp + 68], eax
    cmp dword [rsp + 16], 0
    je .positive_infinity_nan
    cmp dword [rsp + 36], 5
    jne .negative_infinity_zero
    mov edi, 1
    xor esi, esi
    call __al_math_effects
.negative_infinity_zero:
    mov edi, ebx
    xor edx, edx
    jmp .signed_zeros
.positive_infinity_nan:
    cmp dword [rsp + 36], 4
    je .imaginary_nan
    mov edi, 1
    xor esi, esi
    call __al_math_effects
.imaginary_nan:
    mov edi, ebx
    mov esi, 2
    xor edx, edx
    call __al_fp_special
    jmp .store_imaginary
.nan_pair:
    cmp dword [rsp + 12], 5
    je .invalid_pair
    cmp dword [rsp + 36], 5
    je .invalid_pair
    cmp dword [rsp + 36], 3
    jne .quiet_pair
    cmp dword [rsp + 12], 3
    ja .quiet_pair
.invalid_pair:
    mov edi, 1
    xor esi, esi
    call __al_math_effects
.quiet_pair:
    mov edi, ebx
    mov esi, 2
    xor edx, edx
    call __al_fp_special
    mov r12, rax
    mov r13d, edx
.store_imaginary:
    mov r14, rax
    mov r15d, edx
.result:
    mov rax, r12
    mov edx, r13d
    mov rcx, r14
    mov r8d, r15d
    add rsp, 96
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .data alloc noexec write progbits
align 8
metadata:
    dq 0, 0, 0, 2, 0

section .bss alloc noexec write nobits
alignb 16
exp_lock: resd 1
alignb 16
exponential: resb 64
term: resb 10248
factor: resb 10248
component: resb 10248
comparison: resb 10248
denominator: resb 10248
words: resd 18

section .note.GNU-stack noalloc noexec nowrite progbits
