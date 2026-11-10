; Compute lgamma (rcx=0) or tgamma (rcx=1) from kind and raw words.
bits 64
default rel

global __al_math_gamma:function
extern __al_fork_scratch_locks:data
extern __al_fp_decode:function
extern __al_fp_quiet:function
extern __al_fp_special:function
extern __al_fp_pack_exact:function
extern __al_fp_pack_biased:function
extern __al_math_effects:function
extern __al_math_scale:function
extern __al_math_exp:function
extern __al_math_log:function
extern __al_round_irrational:function
extern __al_float_round:function
extern __al_log_gamma_positive:function
extern __al_sinpi_q256:function
extern __al_lock:function
extern __al_unlock:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_big_right_sticky:function
extern __al_big_muladd:function
extern __al_big_copy:function
extern __al_big_add:function
extern __al_big_sub:function
extern __al_big_cmp:function
extern __al_big_bits:function
extern __al_fixed_mul256:function

section .text.__al_math_gamma alloc exec nowrite progbits
__al_math_gamma:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 64
    mov ebx, edi
    mov r12, rsi
    mov r13d, edx
    mov r14, rcx
    call __al_fp_decode
    mov r15d, ecx
    cmp r8d, 5
    je .signaling
    cmp r8d, 4
    je .original
    cmp r8d, 3
    je .infinity
    test r8d, r8d
    jz .pole
    mov [rsp], rax
    mov [rsp + 8], rdx
    bsr r9, rax
    add r9d, edx
    mov [rsp + 16], r9d

    ; Decompose |x| into its integral part and fractional significand.
    xor r10d, r10d
    mov r11, rax
    mov ecx, edx
    test ecx, ecx
    js .negative_exponent
    cmp r9d, 11
    jge .large_integer
    mov r10, rax
    shl r10, cl
    xor r11d, r11d
    jmp .decomposed
.large_integer:
    mov r10d, 2048
    xor r11d, r11d
    jmp .decomposed
.negative_exponent:
    neg ecx
    cmp ecx, 64
    jae .decomposed
    mov r10, rax
    shr r10, cl
    mov r11, r10
    shl r11, cl
    xor r11, rax
.decomposed:
    mov [rsp + 24], r11
    mov [rsp + 32], r10
    mov dword [rsp + 20], 0
    test r15d, r15d
    jnz .negative_x
    test r14d, r14d
    jz .positive_log_gamma
    cmp r9d, 11
    jge .positive_overflow
    test r11, r11
    jz .factorial
    jmp .finite
.positive_log_gamma:
    test r11, r11
    jnz .finite
    cmp r10, 2
    ja .finite
    xor eax, eax
    xor edx, edx
    jmp .done
.negative_x:
    test r11, r11
    jnz .negative_noninteger
    test r14d, r14d
    jz .pole
    jmp .domain
.negative_noninteger:
    and r10d, 1
    xor r10d, 1
    mov [rsp + 20], r10d

.finite:
    cmp dword [rsp + 16], -140
    jl .tiny
    lea rdi, [rel __al_fork_scratch_locks + 32]
    call __al_lock
    lea rdi, [rel argument]
    mov rsi, [rsp]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel argument]
    mov rsi, [rsp + 8]
    add rsi, 256
    call __al_big_left
    test r15d, r15d
    jz .positive_gamma
    lea rdi, [rel term]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel term]
    mov esi, 256
    call __al_big_left
    lea rdi, [rel argument]
    lea rsi, [rel term]
    call __al_big_add
    lea rdi, [rel gamma_y]
    lea rsi, [rel argument]
    lea rdx, [rel gamma_scratch]
    call __al_log_gamma_positive
    mov [rsp + 40], eax

    ; Reflection uses the sine of the exact fractional part of |x|.
    lea rdi, [rel fraction]
    mov rsi, [rsp + 24]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel fraction]
    mov rsi, [rsp + 8]
    add rsi, 256
    call __al_big_left
    lea rdi, [rel term]
    mov esi, 1
    call __al_big_right_sticky
    lea rdi, [rel fraction]
    lea rsi, [rel term]
    call __al_big_cmp
    test eax, eax
    jle .sine
    lea rdi, [rel term]
    mov esi, 1
    call __al_big_left
    lea rdi, [rel term]
    lea rsi, [rel fraction]
    call __al_big_sub
    lea rdi, [rel fraction]
    lea rsi, [rel term]
    call __al_big_copy
.sine:
    lea rdi, [rel sine]
    lea rsi, [rel fraction]
    lea rdx, [rel sine_scratch]
    call __al_sinpi_q256
    mov edi, ebx
    lea rsi, [rel sine]
    mov edx, -256
    mov ecx, 5
    lea r8, [rel sine_log]
    call __al_math_log
    mov [rsp + 56], eax
    lea rdi, [rel series]
    lea rsi, [rel log_pi]
    call __al_big_copy
    lea rdi, [rel series]
    lea rsi, [rel sine_log]
    cmp dword [rsp + 56], 0
    je .subtract_sine_log
    call __al_big_add
    jmp .subtract_gamma_y
.subtract_sine_log:
    call __al_big_sub
.subtract_gamma_y:
    lea rdi, [rel series]
    lea rsi, [rel gamma_y]
    cmp dword [rsp + 40], 0
    je .compare_reflection
    call __al_big_add
    xor eax, eax
    jmp .log_ready
.compare_reflection:
    call __al_big_cmp
    test eax, eax
    js .negative_log
    lea rdi, [rel series]
    lea rsi, [rel gamma_y]
    call __al_big_sub
    xor eax, eax
    jmp .log_ready
.negative_log:
    lea rdi, [rel gamma_y]
    lea rsi, [rel series]
    call __al_big_sub
    lea rdi, [rel series]
    lea rsi, [rel gamma_y]
    call __al_big_copy
    mov eax, 1
    jmp .log_ready
.positive_gamma:
    lea rdi, [rel series]
    lea rsi, [rel argument]
    lea rdx, [rel gamma_scratch]
    call __al_log_gamma_positive

.log_ready:
    mov [rsp + 40], eax
    test r14d, r14d
    jz .round_log
    lea rdi, [rel series]
    call __al_big_bits
    cmp rax, 272
    ja .exp_range
    lea rdi, [rel series]
    mov rsi, rdi
    lea rdx, [rel log2e_lower]
    lea rcx, [rel product_words]
    call __al_fixed_mul256
    mov edi, ebx
    lea rsi, [rel series]
    mov edx, [rsp + 40]
    mov ecx, 3
    mov r8d, [rsp + 20]
    xor r9d, r9d
    call __al_math_exp
    jmp .save_and_unlock
.round_log:
    mov qword [rel metadata + 16], -256
    mov qword [rel metadata + 24], 2
    mov eax, [rsp + 40]
    jmp .round_irrational

.tiny:
    lea rdi, [rel __al_fork_scratch_locks + 32]
    call __al_lock
    test r14d, r14d
    jnz .tiny_gamma
    lea rdi, [rel argument]
    mov rsi, [rsp]
    xor edx, edx
    call __al_big_init128
    mov edi, ebx
    lea rsi, [rel argument]
    mov edx, [rsp + 8]
    mov ecx, 5
    lea r8, [rel series]
    call __al_math_log
    xor eax, eax
    mov [rsp + 40], eax
    jmp .round_log
.tiny_gamma:
    ; A rational reciprocal with a sub-boundary perturbation selects
    ; the side of exact reciprocal ties as x approaches signed zero.
    lea rdi, [rel series]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel series]
    mov esi, 192
    call __al_big_left
    test r15d, r15d
    jz .decrement_reciprocal
    lea rdi, [rel series]
    mov esi, 1
    mov edx, 1
    call __al_big_muladd
    jmp .reciprocal_denominator
.decrement_reciprocal:
    lea rdi, [rel term]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel series]
    lea rsi, [rel term]
    call __al_big_sub
.reciprocal_denominator:
    lea rdi, [rel denominator]
    mov rsi, [rsp]
    xor edx, edx
    call __al_big_init128
    mov rax, [rsp + 8]
    neg rax
    sub rax, 192
    mov [rel metadata + 16], rax
    mov qword [rel metadata + 24], 0
    mov eax, r15d
.round_irrational:
    mov [rel metadata + 8], rax
    mov qword [rel metadata + 32], 0
    lea rdi, [rel series]
    lea rsi, [rel denominator]
    lea rdx, [rel comparison]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_round_irrational
    jmp .save_and_unlock

.factorial:
    lea rdi, [rel __al_fork_scratch_locks + 32]
    call __al_lock
    lea rdi, [rel series]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    mov dword [rsp + 48], 2
.factorial_factor:
    mov esi, [rsp + 48]
    cmp rsi, [rsp + 32]
    jae .round_factorial
    lea rdi, [rel series]
    xor edx, edx
    call __al_big_muladd
    inc dword [rsp + 48]
    jmp .factorial_factor
.round_factorial:
    mov qword [rel metadata + 8], 0
    mov qword [rel metadata + 16], 0
    mov qword [rel metadata + 24], 2
    mov qword [rel metadata + 32], 0
    lea rdi, [rel series]
    lea rsi, [rel denominator]
    lea rdx, [rel comparison]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_float_round
    mov [rsp + 44], ecx
    mov edi, ebx
    mov rsi, rax
    xor ecx, ecx
    call __al_fp_pack_biased
    mov ecx, [rsp + 44]
.save_and_unlock:
    mov r12, rax
    mov r13d, edx
    mov [rsp + 44], ecx
    lea rdi, [rel __al_fork_scratch_locks + 32]
    call __al_unlock
    mov edi, [rsp + 44]
    xor esi, esi
    test edi, 24
    jz .effects
    mov esi, 34
.effects:
    call __al_math_effects
    jmp .original

.exp_range:
    lea rdi, [rel __al_fork_scratch_locks + 32]
    call __al_unlock
    mov ecx, [rsp + 20]
    mov r14d, 65536
    cmp dword [rsp + 40], 0
    je .scale_one
    neg r14
    jmp .scale_one
.positive_overflow:
    xor ecx, ecx
    mov r14d, 65536
.scale_one:
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    call __al_fp_pack_exact
    mov edi, ebx
    mov rsi, rax
    mov rcx, r14
    call __al_math_scale
    jmp .done

.pole:
    mov edi, 4
    mov esi, 34
    call __al_math_effects
    xor edx, edx
    test r14d, r14d
    jz .infinite_result
    mov edx, r15d
    jmp .infinite_result
.infinity:
    test r14d, r14d
    jz .positive_infinity
    test r15d, r15d
    jnz .domain
.positive_infinity:
    xor edx, edx
.infinite_result:
    mov edi, ebx
    xor esi, esi
    call __al_fp_special
    jmp .done
.domain:
    mov edi, 1
    mov esi, 33
    call __al_math_effects
    mov edi, ebx
    mov esi, 2
    xor edx, edx
    call __al_fp_special
    jmp .done
.signaling:
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    call __al_fp_quiet
    mov r12, rax
    mov r13d, edx
    mov edi, 1
    xor esi, esi
    call __al_math_effects
.original:
    mov rax, r12
    mov edx, r13d
.done:
    add rsp, 64
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata.__al_math_gamma alloc noexec nowrite progbits align=8
log_pi:
    dq 9
    dd 0xefa9308e, 0x33802eca, 0xb3f2606e, 0x5e6ddbf3, 0x843f4998, 0x5f956c6a, 0x7a1bd0bd, 0x250d048e, 0x00000001
log2e_lower:
    dq 9
    dd 0xa342648f, 0x164a2cd9, 0xbad2b4b1, 0xd6aef551
    dd 0xd23a7d11, 0x7d0ffda0, 0xb82fe177, 0x71547652, 0x00000001

section .bss.__al_math_gamma alloc noexec write nobits align=8
    resq 1                    ; preserve scratch record offsets
metadata:
    resq 6
argument:
    resq 1281
term:
    resq 1281
series:
    resq 1281
fraction:
    resq 1281
sine:
    resq 1281
sine_log:
    resq 1281
gamma_y:
    resq 1281
denominator:
    resq 1281
comparison:
    resq 1281
gamma_scratch:
    resb 92304
sine_scratch:
    resb 30816
product_words:
    resd 18

section .note.GNU-stack noalloc noexec nowrite progbits
