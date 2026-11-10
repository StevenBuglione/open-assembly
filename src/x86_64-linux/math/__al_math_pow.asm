; Compute pow for the same-kind encoded operands in edi/rsi/edx and rcx/r8d.
bits 64
default rel

global __al_math_pow:function
extern __al_fork_scratch_locks:data
extern __al_fp_decode:function
extern __al_fp_pack_exact:function
extern __al_fp_special:function
extern __al_fp_quiet:function
extern __al_math_effects:function
extern __al_isqrt64_exact:function
extern __al_lock:function
extern __al_unlock:function
extern __al_big_init128:function
extern __al_big_mul_u64:function
extern __al_float_round:function
extern __al_fp_pack_biased:function
extern __al_math_log:function
extern __al_big_bits:function
extern __al_big_left:function
extern __al_big_right_sticky:function
extern __al_math_exp:function
extern __al_math_tiny_adjust:function
extern __al_math_scale:function

section .text.__al_math_pow alloc exec nowrite progbits
__al_math_pow:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 112
    mov ebx, edi
    mov r12, rsi
    mov r13d, edx
    mov r14, rcx
    mov r15d, r8d
    call __al_fp_decode
    mov [rsp], rax
    mov [rsp + 16], edx
    mov [rsp + 24], r8d
    mov [rsp + 32], ecx
    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    call __al_fp_decode
    mov [rsp + 8], rax
    mov [rsp + 20], edx
    mov [rsp + 28], r8d
    mov [rsp + 36], ecx
    cmp dword [rsp + 24], 5
    je .signaling
    cmp r8d, 5
    je .signaling_y
    test r8d, r8d
    jz .positive_one

    ; Classify |x| relative to one for infinite exponents and identities.
    mov dword [rsp + 56], 1
    cmp dword [rsp + 24], 3
    jae .one_comparison
    mov dword [rsp + 56], -1
    mov rax, [rsp]
    test rax, rax
    jz .one_comparison
    bsr r9, rax
    mov edx, [rsp + 16]
    add edx, r9d
    mov [rsp + 48], edx
    js .one_comparison
    mov dword [rsp + 56], 1
    jnz .one_comparison
    mov ecx, r9d
    mov r10d, 1
    shl r10, cl
    cmp rax, r10
    jne .one_comparison
    mov dword [rsp + 56], 0
.one_comparison:
    cmp dword [rsp + 56], 0
    jne .nan_operands
    cmp dword [rsp + 32], 0
    je .positive_one
    cmp dword [rsp + 28], 3
    je .positive_one
.nan_operands:
    cmp dword [rsp + 24], 4
    je .original
    cmp dword [rsp + 28], 4
    je .return_y
    cmp dword [rsp + 28], 3
    je .infinite_y

    ; Finite nonzero y. Determine integrality and the result sign.
    mov rax, [rsp + 8]
    bsr r9, rax
    mov ecx, [rsp + 20]
    lea edx, [r9 + rcx]
    mov [rsp + 52], edx
    mov dword [rsp + 40], 0
    mov dword [rsp + 44], 0
    test ecx, ecx
    jg .integral_y_even
    jz .integral_y
    neg ecx
    cmp ecx, 64
    jae .class_x
    mov rdx, rax
    shr rax, cl
    mov r9, rax
    shl r9, cl
    cmp r9, rdx
    jne .class_x
.integral_y:
    and eax, 1
    and eax, [rsp + 32]
    mov [rsp + 40], eax
.integral_y_even:
    mov dword [rsp + 44], 1
.class_x:
    cmp dword [rsp + 24], 0
    je .zero_x
    cmp dword [rsp + 24], 3
    je .infinite_x
    cmp dword [rsp + 32], 0
    je .finite_x
    cmp dword [rsp + 44], 0
    je .domain
.finite_x:
    cmp dword [rsp + 56], 0
    je .signed_one

    ; Powers of two use their exact integer logarithm. Otherwise try
    ; dyadic roots and small integral powers before approximation.
    mov dword [rsp + 72], 0
    mov rax, [rsp]
    lea rdx, [rax - 1]
    test rax, rdx
    jnz .odd_base
    mov dword [rsp + 72], 1
    jmp .logarithm
.odd_base:
    mov ecx, [rsp + 16]
.trim_x:
    test al, 1
    jnz .odd_x_ready
    shr rax, 1
    inc ecx
    jmp .trim_x
.odd_x_ready:
    mov [rsp + 80], rax
    mov [rsp + 88], ecx
    mov rax, [rsp + 8]
    mov ecx, [rsp + 20]
.trim_y:
    test al, 1
    jnz .odd_y_ready
    shr rax, 1
    inc ecx
    jmp .trim_y
.odd_y_ready:
    test ecx, ecx
    js .fractional_power
    cmp dword [rsp + 52], 5
    jg .logarithm
    shl rax, cl
    xor ecx, ecx
    jmp .check_numerator
.fractional_power:
    neg ecx
    cmp ecx, 5
    ja .logarithm
.check_numerator:
    cmp rax, 40
    ja .logarithm
    mov [rsp + 96], eax
    mov [rsp + 100], eax
    test ecx, ecx
    jz .exact_rational
    mov r9d, 1
    shl r9d, cl
    dec r9d
    test [rsp + 88], r9d
    jnz .logarithm
    sar dword [rsp + 88], cl
    mov [rsp + 92], ecx
.take_root:
    mov rdi, [rsp + 80]
    call __al_isqrt64_exact
    test rax, rax
    jz .logarithm
    mov [rsp + 80], rax
    dec dword [rsp + 92]
    jnz .take_root

.exact_rational:
    lea rdi, [rel __al_fork_scratch_locks + 48]
    call __al_lock
    lea r12, [rel power_a]
    lea r13, [rel power_b]
    mov rdi, r12
    mov esi, 1
    xor edx, edx
    call __al_big_init128
.multiply:
    mov rdi, r13
    mov rsi, r12
    mov rdx, [rsp + 80]
    call __al_big_mul_u64
    mov rax, r12
    mov r12, r13
    mov r13, rax
    dec dword [rsp + 100]
    jnz .multiply

    movsxd rax, dword [rsp + 88]
    mov edx, [rsp + 96]
    imul rax, rdx
    cmp dword [rsp + 36], 0
    jne .inverse_power
    mov [rel metadata + 16], rax
    mov qword [rel metadata + 24], 2
    mov rdi, r12
    mov rsi, r13
    jmp .round_exact
.inverse_power:
    neg rax
    mov [rel metadata + 16], rax
    mov qword [rel metadata + 24], 0
    mov rdi, r13
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    mov rdi, r13
    mov rsi, r12
.round_exact:
    mov eax, [rsp + 40]
    mov [rel metadata + 8], rax
    mov qword [rel metadata + 32], 0
    lea rdx, [rel comparison]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_float_round
    mov [rsp + 76], ecx
    mov edi, ebx
    mov rsi, rax
    mov ecx, [rsp + 40]
    call __al_fp_pack_biased
    jmp .save_and_unlock

.logarithm:
    lea rdi, [rel __al_fork_scratch_locks + 48]
    call __al_lock
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    test ebx, ebx
    jz .absolute_single
    cmp ebx, 1
    je .absolute_double
    and edx, 0x7fff
    jmp .log_q256
.absolute_single:
    and esi, 0x7fffffff
    jmp .log_q256
.absolute_double:
    shl rsi, 1
    shr rsi, 1
.log_q256:
    mov ecx, 4
    lea r8, [rel power_a]
    call __al_math_log
    xor eax, [rsp + 36]
    mov [rsp + 68], eax

    lea rdi, [rel power_a]
    call __al_big_bits
    sub eax, 257
    add eax, [rsp + 52]
    cmp eax, -82
    jl .tiny_exponent
    cmp eax, 16
    jg .extreme_exponent
    lea rdi, [rel power_b]
    lea rsi, [rel power_a]
    mov rdx, [rsp + 8]
    call __al_big_mul_u64
    movsxd rsi, dword [rsp + 20]
    test rsi, rsi
    js .product_right
    lea rdi, [rel power_b]
    call __al_big_left
    jmp .evaluate_power
.product_right:
    neg rsi
    lea rdi, [rel power_b]
    call __al_big_right_sticky
    test eax, eax
    jz .evaluate_power
    mov dword [rsp + 72], 0
.evaluate_power:
    mov edi, ebx
    lea rsi, [rel power_b]
    mov edx, [rsp + 68]
    mov ecx, 3
    mov r8d, [rsp + 40]
    mov r9d, [rsp + 72]
    call __al_math_exp
    mov [rsp + 76], ecx
.save_and_unlock:
    mov r12, rax
    mov r13d, edx
    lea rdi, [rel __al_fork_scratch_locks + 48]
    call __al_unlock
    mov edi, [rsp + 76]
    xor esi, esi
    test edi, 24
    jz .effects
    mov esi, 34
.effects:
    call __al_math_effects
    jmp .original

.tiny_exponent:
    lea rdi, [rel __al_fork_scratch_locks + 48]
    call __al_unlock
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    mov ecx, [rsp + 40]
    call __al_fp_pack_exact
    mov edi, ebx
    mov rsi, rax
    mov ecx, [rsp + 68]
    xor ecx, [rsp + 40]
    add ecx, ecx
    neg ecx
    inc ecx
    call __al_math_tiny_adjust
    jmp .done
.extreme_exponent:
    lea rdi, [rel __al_fork_scratch_locks + 48]
    call __al_unlock
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    mov ecx, [rsp + 40]
    call __al_fp_pack_exact
    mov edi, ebx
    mov rsi, rax
    mov ecx, 65536
    cmp dword [rsp + 68], 0
    je .range_result
    mov rcx, -65536
.range_result:
    call __al_math_scale
    jmp .done

.infinite_y:
    mov dword [rsp + 40], 0
    cmp dword [rsp + 56], 0
    jl .less_than_one
    cmp dword [rsp + 36], 0
    je .signed_infinity
    jmp .signed_zero
.less_than_one:
    cmp dword [rsp + 36], 0
    jne .signed_infinity
    jmp .signed_zero
.infinite_x:
    cmp dword [rsp + 36], 0
    je .signed_infinity
    jmp .signed_zero
.zero_x:
    cmp dword [rsp + 36], 0
    je .signed_zero
    mov edi, 4
    mov esi, 34
    call __al_math_effects
.signed_infinity:
    mov edi, ebx
    xor esi, esi
    mov edx, [rsp + 40]
    call __al_fp_special
    jmp .done
.signed_zero:
    xor esi, esi
    jmp .pack_exact
.positive_one:
    mov dword [rsp + 40], 0
.signed_one:
    mov esi, 1
.pack_exact:
    mov edi, ebx
    xor edx, edx
    mov ecx, [rsp + 40]
    call __al_fp_pack_exact
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
.signaling_y:
    mov r12, r14
    mov r13d, r15d
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
    jmp .original
.return_y:
    mov r12, r14
    mov r13d, r15d
.original:
    mov rax, r12
    mov edx, r13d
.done:
    add rsp, 112
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .bss.__al_math_pow alloc noexec write nobits align=8
    resq 1                    ; preserve scratch record offsets
metadata:
    resq 6
power_a:
    resq 1281
power_b:
    resq 1281
comparison:
    resq 1281

section .note.GNU-stack noalloc noexec nowrite progbits
