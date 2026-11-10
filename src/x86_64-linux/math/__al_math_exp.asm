; Compute exp2, exp or expm1 (rcx 0/1/2) from kind and raw words rdi/rsi/rdx.
bits 64
default rel

global __al_math_exp:function
extern __al_fork_scratch_locks:data
extern __al_fp_decode:function
extern __al_fp_quiet:function
extern __al_fp_pack_exact:function
extern __al_math_scale:function
extern __al_math_effects:function
extern __al_lock:function
extern __al_unlock:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_big_sub:function
extern __al_big_copy:function
extern __al_fixed_mul256:function
extern __al_big_divsmall:function
extern __al_big_add:function
extern __al_big_muladd:function
extern __al_float_round:function
extern __al_fp_pack_biased:function
extern __al_math_tiny_adjust:function
extern fegetround:function

section .text.__al_math_exp alloc exec nowrite progbits
__al_math_exp:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 48
    mov ebx, edi
    mov r12, rsi
    mov r13d, edx
    mov [rsp + 28], ecx
    mov [rsp + 40], r8          ; Q256 result pointer for private mode 4
    mov dword [rsp + 32], 0
    mov dword [rsp + 36], 0
    cmp ecx, 3
    je .prepared
    cmp ecx, 5
    je .prepared_export
    call __al_fp_decode
    cmp r8d, 5
    je .signaling
    cmp r8d, 4
    je .original
    cmp r8d, 3
    je .infinity
    test r8d, r8d
    jz .one
    mov r15d, ecx
    bsr r9, rax
    add r9d, edx
    cmp r9d, 15
    jg .extreme
    cmp r9d, -80
    jl .near_one
    cmp dword [rsp + 28], 0
    jne .natural_reduction

    mov [rsp + 16], edx
    mov ecx, edx
    test ecx, ecx
    js .fractional
    shl rax, cl
    mov r14, rax
    xor eax, eax
    jmp .apply_sign
.fractional:
    neg ecx
    xor r14d, r14d
    cmp ecx, 64
    jae .apply_sign
    mov r14, rax
    shr r14, cl
    mov r9, r14
    shl r9, cl
    xor rax, r9
.apply_sign:
    test r15d, r15d
    jz .have_floor
    neg r14
    test rax, rax
    jz .integral
    dec r14
.have_floor:
    test rax, rax
    jz .integral
    mov [rsp + 8], rax
    lea rdi, [rel __al_fork_scratch_locks + 24]
    call __al_lock
    lea rdi, [rel parameter]
    mov rsi, [rsp + 8]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel parameter]
    mov esi, [rsp + 16]
    add esi, 256
    call __al_big_left
    test r15d, r15d
    jz .multiply_ln2
    jmp .negative_fraction

.natural_reduction:
    mov [rsp + 8], rax
    mov [rsp + 16], edx
    lea rdi, [rel __al_fork_scratch_locks + 24]
    call __al_lock
    lea rdi, [rel parameter]
    mov rsi, [rsp + 8]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel parameter]
    mov esi, [rsp + 16]
    add esi, 256
    call __al_big_left
    lea rdi, [rel parameter]
    mov rsi, rdi
    lea rdx, [rel log2e_lower]
    lea rcx, [rel product_words]
    call __al_fixed_mul256

    jmp .split_absolute

.prepared:
    ; Mode 3 receives a nonnegative Q256 base-two exponent magnitude
    ; in rsi, exponent sign in edx, result sign in r8d, and exactness
    ; eligibility in r9d. Return flags through ecx to the owner.
    mov r15d, edx
    mov [rsp + 32], r8d
    mov [rsp + 36], r9d
    jmp .copy_parameter
.prepared_export:
    ; Mode 5 accepts a prepared exponent like mode 3 and exports the
    ; unrounded result like mode 4.
    mov r15d, edx
.copy_parameter:
    lea rdi, [rel __al_fork_scratch_locks + 24]
    call __al_lock
    lea rdi, [rel parameter]
    mov rsi, r12
    call __al_big_copy
.split_absolute:
    lea rdi, [rel parameter]
    mov r10, [rdi]
    xor r14d, r14d
    cmp r10, 8
    jbe .natural_sign
    mov r14d, [rdi + 40]
    mov r10d, 8
.trim_fraction:
    test r10, r10
    jz .natural_sign
    cmp dword [rdi + r10*4 + 4], 0
    jne .natural_sign
    dec r10
    jmp .trim_fraction
.natural_sign:
    mov [rdi], r10
    test r10, r10
    jz .natural_sign_ready
    mov dword [rsp + 36], 0
.natural_sign_ready:
    test r15d, r15d
    jz .multiply_ln2
    neg r14
    test r10, r10
    jz .multiply_ln2
    dec r14
.negative_fraction:
    lea rdi, [rel term]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel term]
    mov esi, 256
    call __al_big_left
    lea rdi, [rel term]
    lea rsi, [rel parameter]
    call __al_big_sub
    lea rdi, [rel parameter]
    lea rsi, [rel term]
    call __al_big_copy
.multiply_ln2:
    lea rdi, [rel parameter]
    mov rsi, rdi
    lea rdx, [rel ln2_lower]
    lea rcx, [rel product_words]
    call __al_fixed_mul256
    lea rdi, [rel term]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel term]
    mov esi, 256
    call __al_big_left
    lea rdi, [rel series]
    lea rsi, [rel term]
    call __al_big_copy
    mov dword [rsp + 20], 1
.next_term:
    lea rdi, [rel term]
    mov rsi, rdi
    lea rdx, [rel parameter]
    lea rcx, [rel product_words]
    call __al_fixed_mul256
    lea rdi, [rel term]
    mov esi, [rsp + 20]
    call __al_big_divsmall
    cmp qword [rel term], 0
    je .midpoint
    lea rdi, [rel series]
    lea rsi, [rel term]
    call __al_big_add
    inc dword [rsp + 20]
    cmp dword [rsp + 20], 56
    jbe .next_term
.midpoint:
    cmp dword [rsp + 36], 0
    jne .result_sign
    lea rdi, [rel series]
    mov esi, 1
    mov edx, 256
    call __al_big_muladd
.result_sign:
    cmp dword [rsp + 28], 4
    jae .export_fixed
    mov eax, [rsp + 32]
    mov [rel metadata + 8], rax
    cmp dword [rsp + 28], 2
    jne .scale_result
    mov [rel metadata + 8], r15
    cmp r14, -80
    jl .unlock_minus_one
    cmp r14, 16385
    jg .unlock_extreme
    test r14, r14
    js .minus_one_negative
    lea rdi, [rel series]
    mov rsi, r14
    call __al_big_left
    lea rdi, [rel term]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel term]
    mov esi, 256
    call __al_big_left
    lea rdi, [rel series]
    lea rsi, [rel term]
    call __al_big_sub
    xor r14d, r14d
    jmp .scale_result
.minus_one_negative:
    lea rdi, [rel term]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel term]
    mov esi, 256
    call __al_big_left
    lea rdi, [rel term]
    mov rsi, r14
    neg rsi
    call __al_big_left
    lea rdi, [rel term]
    lea rsi, [rel series]
    call __al_big_sub
    lea rdi, [rel series]
    lea rsi, [rel term]
    call __al_big_copy
.scale_result:
    sub r14, 256
    mov [rel metadata + 16], r14
    mov qword [rel metadata + 24], 2
    mov qword [rel metadata + 32], 0
    lea rdi, [rel series]
    lea rsi, [rel denominator]
    lea rdx, [rel comparison]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_float_round
    cmp dword [rsp + 36], 0
    jne .rounded
    or ecx, 32
    test edx, edx
    jnz .rounded
    or ecx, 16
.rounded:
    mov [rsp + 24], ecx
    mov edi, ebx
    mov rsi, rax
    mov ecx, [rel metadata + 8]
    call __al_fp_pack_biased
    mov r12, rax
    mov r13d, edx
    lea rdi, [rel __al_fork_scratch_locks + 24]
    call __al_unlock
    mov ecx, [rsp + 24]
    cmp dword [rsp + 28], 3
    je .original
    mov edi, ecx
    xor esi, esi
    test edi, 24
    jz .effects
    mov esi, 34
.effects:
    call __al_math_effects
    jmp .original

.export_fixed:
    ; The caller has already checked the finite positive input range.
    mov rdi, [rsp + 40]
    lea rsi, [rel series]
    call __al_big_copy
    lea rdi, [rel __al_fork_scratch_locks + 24]
    call __al_unlock
    mov rax, r14
    jmp .done

.unlock_extreme:
    lea rdi, [rel __al_fork_scratch_locks + 24]
    call __al_unlock
.extreme:
    mov r14d, 65536
    test r15d, r15d
    jz .integral
    cmp dword [rsp + 28], 2
    je .near_minus_one
    neg r14
.integral:
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    xor ecx, ecx
    call __al_fp_pack_exact
    mov edi, ebx
    mov rsi, rax
    mov rcx, r14
    call __al_math_scale
    jmp .done
.near_one:
    cmp dword [rsp + 28], 2
    je .tiny_expm1
    call fegetround
    mov r14d, eax
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    xor ecx, ecx
    call __al_fp_pack_exact
    test r15d, r15d
    jnz .negative_tiny
    cmp r14d, 2048
    jne .save_tiny
    inc rax
    jmp .save_tiny
.negative_tiny:
    cmp r14d, 1024
    je .below_one
    cmp r14d, 3072
    jne .save_tiny
.below_one:
    cmp ebx, 2
    je .below_extended
    dec rax
    jmp .save_tiny
.below_extended:
    mov rax, -1
    dec edx
.save_tiny:
    mov r12, rax
    mov r13d, edx
    mov edi, 32
    xor esi, esi
    call __al_math_effects
    jmp .original

.unlock_minus_one:
    lea rdi, [rel __al_fork_scratch_locks + 24]
    call __al_unlock
.near_minus_one:
    call fegetround
    mov r14d, eax
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    mov ecx, 1
    call __al_fp_pack_exact
    cmp r14d, 2048
    je .below_one
    cmp r14d, 3072
    je .below_one
    jmp .save_tiny

.tiny_expm1:
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    mov ecx, 1
    call __al_math_tiny_adjust
    jmp .done

.infinity:
    test ecx, ecx
    jz .original
    cmp dword [rsp + 28], 2
    je .minus_one
    xor eax, eax
    xor edx, edx
    jmp .done
.minus_one:
    mov ecx, 1
    jmp .pack_one
.one:
    cmp dword [rsp + 28], 2
    je .original
    xor ecx, ecx
.pack_one:
    mov edi, ebx
    mov esi, 1
    xor edx, edx
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

section .rodata.__al_math_exp alloc noexec nowrite progbits align=8
; Floor of ln(2) times 2^256, checked against both directed MPFR bounds.
ln2_lower:
    dq 8
    dd 0x8baafa2b, 0x8a0d175b, 0x7298b62d, 0x40f34326
    dd 0x03f2f6af, 0xc9e3b398, 0xd1cf79ab, 0xb17217f7

log2e_lower:
    dq 9
    dd 0xa342648f, 0x164a2cd9, 0xbad2b4b1, 0xd6aef551
    dd 0xd23a7d11, 0x7d0ffda0, 0xb82fe177, 0x71547652, 0x00000001

section .bss.__al_math_exp alloc noexec write nobits align=8
    resq 1                    ; preserve scratch record offsets
metadata:
    resq 6
parameter:
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
