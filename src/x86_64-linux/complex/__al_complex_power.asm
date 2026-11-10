; Principal complex power. Exponent input uses XMM1 for kind 0, XMM2-XMM4 otherwise.
bits 64
default rel

global __al_complex_power:function
extern __al_fork_scratch_locks:data
extern __al_fp_decode:function
extern __al_fp_pack_exact:function
extern __al_fp_special:function
extern __al_math_pow:function
extern __al_math_effects:function
extern __al_lock:function
extern __al_unlock:function
extern __al_complex_norm:function
extern __al_complex_align:function
extern __al_complex_sqrt:function
extern __al_complex_power_log:function
extern __al_complex_power_arg:function
extern __al_complex_signed_sum:function
extern __al_complex_power_coefficient:function
extern __al_complex_power_constant:function
extern __al_complex_power_finish:function
extern __al_big_init128:function
extern __al_big_multiply:function
extern __al_big_mul_u64:function

section .text.__al_complex_power alloc exec nowrite progbits
__al_complex_power:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 224
    xor eax, eax
    mov [rsp + 64], rax
    cmp edi, 0
    jne .wide_exponent
    movq rax, xmm1
    mov r10, rax
    shr r10, 32
    mov eax, eax
    jmp .store_exponent
.wide_exponent:
    movq rax, xmm2
    movq r10, xmm3
    cmp edi, 2
    jne .store_exponent
    movq r11, xmm4
    mov r11d, r11d
    movzx r9d, r11w
    shr r11d, 16
    mov [rsp + 64], r9d
    mov [rsp + 68], r11d
.store_exponent:
    mov [rsp + 48], rax
    mov [rsp + 56], r10
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
    mov rsi, [rsp + 48]
    mov edx, [rsp + 64]
    call __al_fp_decode
    mov [rsp + 72], rax
    mov [rsp + 80], edx
    mov [rsp + 84], r8d
    mov [rsp + 88], ecx
    mov edi, ebx
    mov rsi, [rsp + 56]
    mov edx, [rsp + 68]
    call __al_fp_decode
    mov [rsp + 96], rax
    mov [rsp + 104], edx
    mov [rsp + 108], r8d
    mov [rsp + 112], ecx
    cmp dword [rsp + 12], 5
    je .signaling
    cmp dword [rsp + 36], 5
    je .signaling
    cmp dword [rsp + 84], 5
    je .signaling
    cmp dword [rsp + 108], 5
    je .signaling
    mov eax, [rsp + 84]
    or eax, [rsp + 108]
    jz .one
    cmp dword [rsp + 36], 0
    jne .classify
    cmp dword [rsp + 16], 0
    jne .classify
    cmp dword [rsp + 108], 0
    je .positive_real_power
    cmp dword [rsp + 12], 2
    jne .classify
    mov rax, [rsp]
    lea rdx, [rax - 1]
    test rax, rdx
    jnz .classify
    bsr rax, rax
    add eax, [rsp + 8]
    jz .one

.classify:
    cmp dword [rsp + 12], 4
    je .nan_pair
    cmp dword [rsp + 36], 4
    je .nan_pair
    cmp dword [rsp + 84], 4
    je .nan_pair
    cmp dword [rsp + 108], 4
    je .nan_pair
    cmp dword [rsp + 84], 3
    je .domain
    cmp dword [rsp + 108], 3
    je .domain
    mov dword [rsp + 188], 0    ; finite exponential magnitude
    cmp dword [rsp + 12], 3
    je .infinite_base
    cmp dword [rsp + 36], 3
    je .infinite_base
    mov eax, [rsp + 12]
    or eax, [rsp + 36]
    jz .zero_base
    cmp dword [rsp + 108], 0
    jne .precision
    cmp dword [rsp + 88], 0
    jne .precision
    mov rax, [rsp + 72]
    lea rdx, [rax - 1]
    test rax, rdx
    jnz .precision
    bsr rax, rax
    add eax, [rsp + 80]
    jz .result
    cmp eax, -1
    jne .precision
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    mov rcx, r14
    mov r8d, r15d
    call __al_complex_sqrt
    jmp .done
.zero_base:
    cmp dword [rsp + 108], 0
    jne .domain
    mov eax, [rsp + 16]
    shl eax, 2
    mov [rsp + 116], eax
    mov dword [rsp + 188], 1
    cmp dword [rsp + 88], 0
    je .precision
    mov dword [rsp + 188], 3
    jmp .precision
.infinite_base:
    cmp dword [rsp + 108], 0
    jne .domain
    mov eax, [rsp + 16]
    shl eax, 2
    cmp dword [rsp + 36], 3
    jne .infinite_angle
    mov eax, 2
    cmp dword [rsp + 12], 3
    jne .infinite_angle
    mov eax, [rsp + 16]
    lea eax, [rax*2 + 1]
.infinite_angle:
    mov [rsp + 116], eax
    mov dword [rsp + 188], 2
    cmp dword [rsp + 88], 0
    je .precision
    mov dword [rsp + 188], 1

.precision:
    ; Product with the exponent cannot erase the fixed grid's guard bits.
    xor ecx, ecx
    mov rax, [rsp + 72]
    test rax, rax
    jz .imaginary_precision
    bsr rax, rax
    add eax, [rsp + 80]
    test eax, eax
    js .imaginary_precision
    mov ecx, eax
.imaginary_precision:
    mov rax, [rsp + 96]
    test rax, rax
    jz .guard_bits
    bsr rax, rax
    add eax, [rsp + 104]
    cmp eax, ecx
    jle .guard_bits
    mov ecx, eax
.guard_bits:
    add ecx, 671
    and ecx, -32
    mov [rsp + 120], rcx
    lea rdi, [rel __al_fork_scratch_locks + 88]
    call __al_lock
    lea rax, [rel amplitude]
    mov [rel result_record], rax
    lea rax, [rel phase]
    mov [rel result_record + 8], rax
    mov eax, [rsp + 188]
    mov [rel result_record + 44], eax
    mov dword [rel result_record + 40], 0
    test eax, eax
    jz .polar
    mov qword [rel amplitude], 0
    mov qword [rel logarithm], 0
    mov qword [rel angle_residual], 0
    mov qword [rel result_record + 16], 0
    mov dword [rel result_record + 32], 0
    mov qword [rsp + 128], 0
    mov qword [rsp + 160], 0
    mov dword [rsp + 144], 0
    mov dword [rsp + 148], 0
    jmp .phase_terms

.polar:
    lea rdi, [rel norm]
    lea rsi, [rel work]
    mov rdx, [rsp]
    movsxd rcx, dword [rsp + 8]
    mov r8, [rsp + 24]
    movsxd r9, dword [rsp + 32]
    call __al_complex_norm
    lea rdi, [rel logarithm]
    lea rsi, [rel norm]
    mov rdx, rax
    mov rcx, [rsp + 120]
    call __al_complex_power_log
    mov [rsp + 128], rax
    mov [rsp + 144], edx

    lea rdi, [rel horizontal]
    mov rsi, [rsp]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel vertical]
    mov rsi, [rsp + 24]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel horizontal]
    lea rsi, [rel vertical]
    movsxd rdx, dword [rsp + 8]
    movsxd rcx, dword [rsp + 32]
    call __al_complex_align
    lea rdi, [rel argument]
    lea rsi, [rel horizontal]
    lea rdx, [rel vertical]
    mov ecx, [rsp + 16]
    mov r8, [rsp + 120]
    lea r9, [rel angle_residual]
    call __al_complex_power_arg
    mov [rsp + 136], rax
    mov [rsp + 116], edx
    mov [rsp + 160], rcx
    mov [rsp + 148], r8d

    ; U = a log|z| - b arg(z).
    lea rdi, [rel amplitude]
    lea rsi, [rel logarithm]
    mov rdx, [rsp + 72]
    call __al_big_mul_u64
    lea rdi, [rel work]
    lea rsi, [rel argument]
    mov rdx, [rsp + 96]
    call __al_big_mul_u64
    lea rdi, [rel amplitude]
    lea rsi, [rel work]
    movsxd rdx, dword [rsp + 80]
    add rdx, [rsp + 128]
    movsxd rcx, dword [rsp + 104]
    add rcx, [rsp + 136]
    mov r8d, [rsp + 40]
    xor r8d, [rsp + 112]
    xor r8d, 1
    shl r8d, 1
    mov eax, [rsp + 144]
    xor eax, [rsp + 88]
    or r8d, eax
    mov r9, [rsp + 120]
    add r9, 128
    call __al_complex_signed_sum
    mov [rel result_record + 16], rax
    mov [rel result_record + 32], edx

.phase_terms:
    ; V uses b log|z| + a times the argument's residual. Its
    ; exact multiple of pi/4 is reduced before entering the sum.
    lea rdi, [rel phase]
    lea rsi, [rel logarithm]
    mov rdx, [rsp + 96]
    call __al_big_mul_u64
    lea rdi, [rel work]
    lea rsi, [rel angle_residual]
    mov rdx, [rsp + 72]
    call __al_big_mul_u64
    lea rdi, [rel phase]
    lea rsi, [rel work]
    movsxd rdx, dword [rsp + 104]
    add rdx, [rsp + 128]
    movsxd rcx, dword [rsp + 80]
    add rcx, [rsp + 160]
    mov r8d, [rsp + 40]
    xor r8d, [rsp + 88]
    mov [rsp + 192], r8d        ; sign of a times the base's argument
    xor r8d, [rsp + 148]
    shl r8d, 1
    mov eax, [rsp + 144]
    xor eax, [rsp + 112]
    or r8d, eax
    mov r9, [rsp + 120]
    add r9, 128
    call __al_complex_signed_sum
    mov [rel result_record + 24], rax
    mov [rel result_record + 36], edx
    cmp qword [rel phase], 0
    jne .angular_coefficient
    mov eax, [rsp + 192]
    mov [rel result_record + 36], eax
.angular_coefficient:
    lea rdi, [rel coefficient]
    mov rsi, [rsp + 72]
    movsxd rdx, dword [rsp + 80]
    mov ecx, [rsp + 116]
    lea r8, [rel work]
    call __al_complex_power_coefficient
    test edx, edx
    js .fractional_coefficient
    cmp dword [rsp + 192], 0
    je .quadrant
    neg edx
.quadrant:
    and edx, 3
    mov [rel result_record + 40], edx
    test edx, 1
    jnz .finish
    cmp dword [rsp + 16], 0
    je .finish
    cmp dword [rsp + 36], 0
    jne .finish
    cmp dword [rsp + 108], 0
    jne .finish
    ; Integer powers on the negative real cut approach the
    ; exact sine zero from the side selected by the base.
    xor dword [rel result_record + 36], 1
    jmp .finish
.fractional_coefficient:
    mov [rsp + 168], rax
    lea rdi, [rel argument]
    mov rsi, [rsp + 120]
    mov edx, 1
    call __al_complex_power_constant
    lea rdi, [rel work]
    lea rsi, [rel argument]
    lea rdx, [rel coefficient]
    call __al_big_multiply
    lea rdi, [rel phase]
    lea rsi, [rel work]
    mov rdx, [rel result_record + 24]
    mov rcx, [rsp + 168]
    sub rcx, [rsp + 120]
    mov r8d, [rsp + 192]
    shl r8d, 1
    or r8d, [rel result_record + 36]
    mov r9, [rsp + 120]
    add r9, 128
    call __al_complex_signed_sum
    mov [rel result_record + 24], rax
    mov [rel result_record + 36], edx

.finish:
    mov edi, ebx
    lea rsi, [rel result_record]
    call __al_complex_power_finish
    mov r12, rax
    mov r13d, edx
    mov r14, rcx
    mov r15d, r8d
    mov [rsp + 176], r9d
    mov [rsp + 180], r10d
    lea rdi, [rel __al_fork_scratch_locks + 88]
    call __al_unlock
    mov edi, [rsp + 176]
    mov esi, [rsp + 180]
    call __al_math_effects
    jmp .result

.positive_real_power:
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    mov rcx, [rsp + 48]
    mov r8d, [rsp + 64]
    call __al_math_pow
    mov r12, rax
    mov r13d, edx
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    mov ecx, [rsp + 40]
    xor ecx, [rsp + 88]
    call __al_fp_pack_exact
    jmp .store_imaginary
.one:
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    xor ecx, ecx
    call __al_fp_pack_exact
    mov r12, rax
    mov r13d, edx
    xor r14d, r14d
    xor r15d, r15d
    jmp .result
.domain:
    mov edi, 1
    mov esi, 33
    call __al_math_effects
    jmp .nan_pair
.signaling:
    mov edi, 1
    xor esi, esi
    call __al_math_effects
.nan_pair:
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
.done:
    add rsp, 224
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .bss alloc noexec write nobits
alignb 16
    resd 1                    ; preserve scratch record offsets
alignb 16
result_record: resb 48
norm: resb 10248
horizontal: resb 10248
vertical: resb 10248
logarithm: resb 2304
argument: resb 2304
angle_residual: resb 2304
amplitude: resb 10248
phase: resb 10248
coefficient: resb 64
work: resb 10248

section .note.GNU-stack noalloc noexec nowrite progbits
