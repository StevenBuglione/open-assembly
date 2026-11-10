; Compute log2/log/log10/log1p for rcx=0/1/2/3 from kind and raw words rdi/rsi/rdx.
bits 64
default rel

global __al_math_log:function
extern __al_fp_decode:function
extern __al_fp_pack_exact:function
extern __al_fp_pack_biased:function
extern __al_fp_special:function
extern __al_fp_quiet:function
extern __al_math_effects:function
extern __al_lock:function
extern __al_unlock:function
extern __al_fixed_ratio256:function
extern __al_fixed_mul256:function
extern __al_big_copy:function
extern __al_big_add:function
extern __al_big_sub:function
extern __al_big_muladd:function
extern __al_big_divsmall:function
extern __al_big_left:function
extern __al_big_init128:function
extern __al_big_right_sticky:function
extern __al_fixed_big_ratio256:function
extern __al_big_bits:function
extern __al_math_tiny_adjust:function
extern __al_float_round:function

section .text.__al_math_log alloc exec nowrite progbits
__al_math_log:
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
    mov [rsp + 40], r8          ; Q256 output for private mode 4
    cmp r14d, 5
    je .fixed_input
    call __al_fp_decode
    cmp r8d, 5
    je .signaling
    cmp r8d, 4
    je .original
    cmp r14d, 3
    je .log1p
    test r8d, r8d
    jz .pole
    test ecx, ecx
    jnz .domain
    cmp r8d, 3
    je .original

    cmp r14d, 2
    jne .normalize
    ; A binary-exact power of ten is 5^n * 2^n for 0 <= n <= 27.
    mov r9, rax
    mov r10d, edx
.odd_factor:
    test r9b, 1
    jnz .test_power
    shr r9, 1
    inc r10d
    jmp .odd_factor
.test_power:
    cmp r10d, 27
    ja .normalize
    mov r11d, 1
    mov ecx, r10d
    test ecx, ecx
    jz .test_five
.power_five:
    lea r11, [r11 + r11*4]
    dec ecx
    jnz .power_five
.test_five:
    cmp r11, r9
    jne .normalize
    mov eax, r10d
    jmp .exact_integer

.normalize:
    bsr r9, rax
    add edx, r9d
    mov [rsp + 16], edx
    mov ecx, 63
    sub ecx, r9d
    shl rax, cl
    mov r9, 0x8000000000000000
    mov r15, rax
    cmp rax, r9
    jne .series_start
    test r14d, r14d
    jz .exact_exponent
    cmp r14d, 4
    je .exact_q256
    test edx, edx
    jz .exact_exponent
.series_start:
    lea rdi, [rel log_lock]
    call __al_lock
    mov rsi, r15
    mov r9, 0x8000000000000000
    sub rsi, r9
    mov rdx, r15
    xor ecx, ecx
    add rdx, r9
    adc ecx, 0
    lea rdi, [rel power]
    call __al_fixed_ratio256
.series_from_power:
    lea rdi, [rel series]
    lea rsi, [rel power]
    call __al_big_copy
    cmp qword [rel power], 0
    je .scale_series
    lea rdi, [rel factor]
    lea rsi, [rel power]
    mov rdx, rsi
    lea rcx, [rel product_words]
    call __al_fixed_mul256

    mov dword [rsp + 24], 3
.next_term:
    lea rdi, [rel power]
    mov rsi, rdi
    lea rdx, [rel factor]
    lea rcx, [rel product_words]
    call __al_fixed_mul256
    lea rdi, [rel term]
    lea rsi, [rel power]
    call __al_big_copy
    lea rdi, [rel term]
    mov esi, [rsp + 24]
    call __al_big_divsmall
    cmp qword [rel term], 0
    je .scale_series
    lea rdi, [rel series]
    lea rsi, [rel term]
    call __al_big_add
    add dword [rsp + 24], 2
    cmp dword [rsp + 24], 175
    jbe .next_term
.scale_series:
    lea r12, [rel series]
    test r14d, r14d
    jz .binary_series
    cmp r14d, 4
    jne .natural_series
.binary_series:
    mov rdi, r12
    mov rsi, r12
    lea rdx, [rel twice_inverse_ln2]
    lea rcx, [rel product_words]
    call __al_fixed_mul256
    mov rdi, r12
    mov esi, 1
    mov edx, 512
    call __al_big_muladd
    jmp .integer_term
.natural_series:
    mov rdi, r12
    mov esi, 1
    call __al_big_left

.integer_term:
    mov dword [rsp + 20], 0
    mov r15d, [rsp + 16]
    test r15d, r15d
    jz .base_scale
    jns .integer_magnitude
    mov dword [rsp + 20], 1
    neg r15d
.integer_magnitude:
    test r14d, r14d
    jz .binary_integer
    cmp r14d, 4
    jne .natural_integer
.binary_integer:
    lea rdi, [rel term]
    mov esi, r15d
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel term]
    mov esi, 256
    call __al_big_left
    jmp .combine
.natural_integer:
    lea rdi, [rel term]
    lea rsi, [rel ln2_lower]
    call __al_big_copy
    lea rdi, [rel term]
    mov esi, r15d
    xor edx, edx
    call __al_big_muladd
.combine:
    cmp dword [rsp + 20], 0
    jne .negative_sum
    mov rdi, r12
    lea rsi, [rel term]
    call __al_big_add
    jmp .base_scale
.negative_sum:
    mov rsi, r12
    lea r12, [rel term]
    mov rdi, r12
    call __al_big_sub

.base_scale:
    cmp r14d, 2
    jne .round
    mov rdi, r12
    mov rsi, r12
    lea rdx, [rel inverse_ln10]
    lea rcx, [rel product_words]
    call __al_fixed_mul256
.round:
    cmp r14d, 4
    jae .fixed_result
    mov eax, [rsp + 20]
    mov [rel metadata + 8], rax
    mov qword [rel metadata + 16], -256
    mov qword [rel metadata + 24], 2
    mov qword [rel metadata + 32], 0
    mov rdi, r12
    lea rsi, [rel denominator]
    lea rdx, [rel comparison]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_float_round
    mov edi, ebx
    mov rsi, rax
    mov ecx, [rsp + 20]
    call __al_fp_pack_biased
    mov r12, rax
    mov r13d, edx
    lea rdi, [rel log_lock]
    call __al_unlock
    mov edi, 32
    xor esi, esi
    call __al_math_effects
    jmp .original

.fixed_result:
    mov rdi, [rsp + 40]
    mov rsi, r12
    call __al_big_copy
    lea rdi, [rel log_lock]
    call __al_unlock
    mov eax, [rsp + 20]
    jmp .done
.exact_q256:
    mov r15d, edx
    mov esi, edx
    test esi, esi
    jns .fixed_integer
    neg esi
.fixed_integer:
    mov rdi, [rsp + 40]
    xor edx, edx
    call __al_big_init128
    mov rdi, [rsp + 40]
    mov esi, 256
    call __al_big_left
    mov eax, r15d
    shr eax, 31
    jmp .done

.fixed_input:
    ; Mode 5 accepts a positive integer significand at rsi and its
    ; binary exponent in edx. Return the magnitude of its natural log
    ; on the Q256 grid through the pointer saved from r8.
    mov [rsp + 8], edx
    lea rdi, [rel log_lock]
    call __al_lock
    lea rdi, [rel term]
    mov rsi, r12
    call __al_big_copy
    jmp .normalize_sum

.log1p:
    test r8d, r8d
    jz .original
    cmp r8d, 3
    jne .log1p_finite
    test ecx, ecx
    jnz .domain
    jmp .original
.log1p_finite:
    bsr r9, rax
    lea r10d, [rdx + r9]
    test ecx, ecx
    jz .log1p_range
    test r10d, r10d
    jg .domain
    jl .log1p_range
    mov ecx, r9d
    mov r11d, 1
    shl r11, cl
    cmp rax, r11
    jne .domain
    jmp .pole
.log1p_range:
    cmp r10d, -80
    jl .tiny_log1p
    mov [rsp], rax
    mov [rsp + 8], edx
    mov [rsp + 12], ecx
    lea rdi, [rel log_lock]
    call __al_lock
    lea rdi, [rel power]
    mov rsi, [rsp]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel term]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    movsxd rsi, dword [rsp + 8]
    test rsi, rsi
    js .align_one
    lea rdi, [rel power]
    call __al_big_left
    mov dword [rsp + 8], 0
    jmp .form_sum
.align_one:
    neg rsi
    lea rdi, [rel term]
    call __al_big_left
.form_sum:
    lea rdi, [rel term]
    lea rsi, [rel power]
    cmp dword [rsp + 12], 0
    jne .subtract_x
    call __al_big_add
    jmp .normalize_sum
.subtract_x:
    call __al_big_sub
.normalize_sum:
    lea rdi, [rel term]
    call __al_big_bits
    dec eax
    mov edx, [rsp + 8]
    add edx, eax
    mov [rsp + 16], edx
    mov esi, 256
    sub esi, eax
    js .shift_sum_right
    lea rdi, [rel term]
    call __al_big_left
    jmp .sum_ratio
.shift_sum_right:
    neg esi
    lea rdi, [rel term]
    call __al_big_right_sticky

.sum_ratio:
    lea rdi, [rel series]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel series]
    mov esi, 256
    call __al_big_left
    lea rdi, [rel factor]
    lea rsi, [rel term]
    call __al_big_copy
    lea rdi, [rel factor]
    lea rsi, [rel series]
    call __al_big_add
    lea rdi, [rel term]
    lea rsi, [rel series]
    call __al_big_sub
    lea rdi, [rel power]
    lea rsi, [rel term]
    lea rdx, [rel factor]
    call __al_fixed_big_ratio256
    jmp .series_from_power
.tiny_log1p:
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    mov ecx, -1
    call __al_math_tiny_adjust
    jmp .done

.exact_exponent:
    mov eax, edx
.exact_integer:
    xor ecx, ecx
    test eax, eax
    jns .pack_integer
    neg eax
    mov ecx, 1
.pack_integer:
    mov edi, ebx
    mov esi, eax
    xor edx, edx
    call __al_fp_pack_exact
    jmp .done
.pole:
    mov edi, 4
    mov esi, 34
    call __al_math_effects
    mov edi, ebx
    xor esi, esi
    mov edx, 1
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
    add rsp, 48
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata.__al_math_log alloc noexec nowrite progbits align=8
; Each constant is the Q256 floor, checked against both directed MPFR bounds.
ln2_lower:
    dq 8
    dd 0x8baafa2b, 0x8a0d175b, 0x7298b62d, 0x40f34326
    dd 0x03f2f6af, 0xc9e3b398, 0xd1cf79ab, 0xb17217f7
twice_inverse_ln2:
    dq 9
    dd 0x4684c91f, 0x2c9459b3, 0x75a56962, 0xad5deaa3
    dd 0xa474fa23, 0xfa1ffb41, 0x705fc2ee, 0xe2a8eca5, 0x00000002
inverse_ln10:
    dq 8
    dd 0x7bc7529e, 0x1d1f96a2, 0x22e4d101, 0x1f71a301
    dd 0xd699ee19, 0x9aadd557, 0x9b9438ca, 0x6f2dec54

section .bss.__al_math_log alloc noexec write nobits align=8
log_lock:
    resq 1
metadata:
    resq 6
power:
    resq 1281
factor:
    resq 1281
series:
    resq 1281
term:
    resq 1281
denominator:
    resq 1281
comparison:
    resq 1281
product_words:
    resd 18

section .note.GNU-stack noalloc noexec nowrite progbits
