; Compute sinh/cosh/tanh or export their unrounded factors for rcx 3/4.
bits 64
default rel

global __al_math_hyperbolic:function
extern __al_fork_scratch_locks:data
extern __al_fp_decode:function
extern __al_fp_pack_exact:function
extern __al_fp_special:function
extern __al_fp_quiet:function
extern __al_math_effects:function
extern __al_math_tiny_adjust:function
extern __al_math_scale:function
extern __al_math_exp:function
extern __al_round_irrational:function
extern __al_lock:function
extern __al_unlock:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_big_copy:function
extern __al_big_sub:function
extern __al_big_add:function
extern __al_fixed_mul256:function

section .text.__al_math_hyperbolic alloc exec nowrite progbits
__al_math_hyperbolic:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 48
    mov ebx, edi
    mov r12, rsi
    mov r13d, edx
    mov r14, rcx
    mov qword [rsp + 32], 0
    cmp r14d, 3
    jb .decode
    ; The caller bounds finite magnitude to [2^-80, 32768).
    sub r14d, 3
    mov [rsp + 32], r8
.decode:
    call __al_fp_decode
    mov r15d, ecx
    cmp r8d, 5
    je .signaling
    cmp r8d, 4
    je .original
    cmp r8d, 3
    je .infinity
    test r8d, r8d
    jz .zero
    bsr r9, rax
    lea r10d, [rdx + r9]
    cmp r10d, -80
    jl .tiny
    cmp r14d, 2
    jne .range
    cmp r10d, 6
    jge .tanh_limit
.range:
    cmp r10d, 14
    jg .overflow
    mov [rsp + 16], r10d
    mov [rsp + 20], r15d
    cmp r14d, 1
    jne .evaluate
    mov dword [rsp + 20], 0
.evaluate:
    lea rdi, [rel __al_fork_scratch_locks + 36]
    call __al_lock
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    test ebx, ebx
    jz .absolute_single
    cmp ebx, 1
    je .absolute_double
    and edx, 0x7fff
    jmp .exp_magnitude
.absolute_single:
    and esi, 0x7fffffff
    jmp .exp_magnitude
.absolute_double:
    shl rsi, 1
    shr rsi, 1
.exp_magnitude:
    mov ecx, 4
    lea r8, [rel exponential]
    call __al_math_exp
    mov [rsp + 8], rax           ; exp(|x|) = exponential * 2^(rax-256)
    cmp dword [rsp + 16], 7
    jge .large

    ; Use (e^(2|x|) +/- 1)/(2e^|x|) or their ratio. Subtract in
    ; limbs before final rounding to avoid cancellation near zero.
    lea rdi, [rel series]
    lea rsi, [rel exponential]
    mov rdx, rsi
    lea rcx, [rel product_words]
    call __al_fixed_mul256
    lea rdi, [rel series]
    mov rsi, [rsp + 8]
    add rsi, rsi
    call __al_big_left
    lea rdi, [rel term]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel term]
    mov esi, 256
    call __al_big_left
    mov qword [rel metadata + 24], 0
    cmp r14d, 2
    je .tangent_ratio
    mov rax, [rsp + 8]
    neg rax
    dec rax
    mov [rel metadata + 16], rax
    lea rdi, [rel series]
    lea rsi, [rel term]
    cmp r14d, 1
    je .cosine_sum
    call __al_big_sub
    jmp .sine_ratio
.cosine_sum:
    call __al_big_add
.sine_ratio:
    lea rdi, [rel series]
    lea rsi, [rel exponential]
    jmp .round

.tangent_ratio:
    lea rdi, [rel denominator]
    lea rsi, [rel series]
    call __al_big_copy
    lea rdi, [rel denominator]
    lea rsi, [rel term]
    call __al_big_add
    lea rdi, [rel series]
    lea rsi, [rel term]
    call __al_big_sub
    lea rdi, [rel series]
    lea rsi, [rel denominator]
    mov qword [rel metadata + 16], 0
    jmp .round

.large:
    mov rax, [rsp + 8]
    sub rax, 257
    mov [rel metadata + 16], rax
    mov qword [rel metadata + 24], 2
    lea rdi, [rel exponential]
    lea rsi, [rel denominator]
.round:
    cmp qword [rsp + 32], 0
    jne .export_fixed
    mov eax, [rsp + 20]
    mov [rel metadata + 8], rax
    mov qword [rel metadata + 32], 0
    lea rdx, [rel comparison]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_round_irrational
    mov r12, rax
    mov r13d, edx
    mov [rsp + 24], ecx
    lea rdi, [rel __al_fork_scratch_locks + 36]
    call __al_unlock
    mov edi, [rsp + 24]
    xor esi, esi
    test edi, 24
    jz .effects
    mov esi, 34
.effects:
    call __al_math_effects
    jmp .original

.export_fixed:
    mov rax, [rsp + 32]
    mov [rsp + 40], rsi
    mov rsi, rdi
    mov rdi, [rax]
    call __al_big_copy
    mov rax, [rsp + 32]
    mov rdi, [rax + 8]
    cmp qword [rel metadata + 24], 2
    jne .export_ratio
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    jmp .export_scale
.export_ratio:
    mov rsi, [rsp + 40]
    call __al_big_copy
.export_scale:
    mov rax, [rsp + 32]
    mov rdx, [rel metadata + 16]
    mov [rax + 16], rdx
    lea rdi, [rel __al_fork_scratch_locks + 36]
    call __al_unlock
    jmp .done

.tiny:
    cmp r14d, 1
    jne .tiny_odd
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    xor ecx, ecx
    call __al_fp_pack_exact
    mov rsi, rax
    mov ecx, 1
    jmp .tiny_adjust
.tiny_odd:
    mov rsi, r12
    mov edx, r13d
    mov ecx, r15d
    add ecx, ecx
    neg ecx
    inc ecx
    cmp r14d, 2
    jne .tiny_adjust
    neg ecx
.tiny_adjust:
    mov edi, ebx
    call __al_math_tiny_adjust
    jmp .done

.tanh_limit:
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    mov ecx, r15d
    call __al_fp_pack_exact
    mov rsi, rax
    lea ecx, [r15*2 - 1]
    jmp .tiny_adjust
.overflow:
    cmp r14d, 1
    jne .signed_overflow
    xor r15d, r15d
.signed_overflow:
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    mov ecx, r15d
    call __al_fp_pack_exact
    mov edi, ebx
    mov rsi, rax
    mov ecx, 65536
    call __al_math_scale
    jmp .done

.infinity:
    test r14d, r14d
    jz .original
    cmp r14d, 2
    je .signed_one
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    call __al_fp_special
    jmp .done
.zero:
    cmp r14d, 1
    jne .original
    xor r15d, r15d
.signed_one:
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    mov ecx, r15d
    call __al_fp_pack_exact
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
    add rsp, 48
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .bss.__al_math_hyperbolic alloc noexec write nobits align=8
    resq 1                    ; preserve scratch record offsets
metadata:
    resq 6
exponential:
    resq 1281
term:
    resq 1281
series:
    resq 1281
denominator:
    resq 1281
comparison:
    resq 1281
product_words:
    resd 18

section .note.GNU-stack noalloc noexec nowrite progbits
