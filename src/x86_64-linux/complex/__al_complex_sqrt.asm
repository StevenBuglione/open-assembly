; Principal complex square root. Inputs use kind and raw real/imaginary; outputs rax/rdx/rcx/r8d.
bits 64
default rel

global __al_complex_sqrt:function
extern __al_fp_decode:function
extern __al_fp_quiet:function
extern __al_fp_special:function
extern __al_fp_pack_exact:function
extern __al_fp_pack_biased:function
extern __al_math_effects:function
extern __al_complex_norm:function
extern __al_root_round:function
extern __al_big_isqrt:function
extern __al_lock:function
extern __al_unlock:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_big_right_sticky:function
extern __al_big_copy:function
extern __al_big_muladd:function
extern __al_big_add:function
extern __al_float_round:function

section .text.__al_complex_sqrt alloc exec nowrite progbits
__al_complex_sqrt:
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
    cmp dword [rsp + 12], 5
    je .signal
    cmp dword [rsp + 36], 5
    jne .classify
.signal:
    mov edi, 1
    xor esi, esi
    call __al_math_effects
.classify:
    cmp dword [rsp + 36], 3
    je .imaginary_infinity
    cmp dword [rsp + 12], 3
    je .real_infinity
    cmp dword [rsp + 12], 4
    jae .nan_real
    cmp dword [rsp + 36], 4
    jae .nan_imaginary
    cmp dword [rsp + 36], 0
    je .real_axis

    mov rax, [rsp + 24]
    bsr r10, rax
    add r10d, [rsp + 32]
    mov rax, [rsp]
    test rax, rax
    jz .imaginary_leads
    bsr r11, rax
    add r11d, [rsp + 8]
    cmp r10d, r11d
    jge .exponent
    mov r10d, r11d
    jmp .exponent
.imaginary_leads:
    mov dword [rsp + 16], 0      ; treat either real zero as nonnegative
.exponent:
    sar r10d, 1
    mov [rsp + 88], r10d        ; final binary exponent scaling
    mov dword [rsp + 80], 0      ; omitted positive contribution to the large root
    lea rdi, [rel complex_sqrt_lock]
    call __al_lock
    lea rdi, [rel norm]
    lea rsi, [rel norm_scratch]
    mov rdx, [rsp]
    movsxd rcx, dword [rsp + 8]
    mov r8, [rsp + 24]
    movsxd r9, dword [rsp + 32]
    call __al_complex_norm
    movsxd r10, dword [rsp + 88]
    shl r10, 2
    lea rsi, [rax + 512]
    sub rsi, r10
    lea rdi, [rel norm]
    test rsi, rsi
    js .shift_norm_right
    call __al_big_left
    jmp .radius
.shift_norm_right:
    neg rsi
    call __al_big_right_sticky
    mov [rsp + 80], eax
.radius:
    lea rdi, [rel radius]
    lea rsi, [rel norm]
    lea rdx, [rel remainder]
    lea rcx, [rel trial]
    call __al_big_isqrt
    cmp qword [rel remainder], 0
    je .scaled_real
    mov dword [rsp + 80], 1
.scaled_real:
    lea rdi, [rel norm_scratch]
    mov rsi, [rsp]
    xor edx, edx
    call __al_big_init128
    movsxd rsi, dword [rsp + 8]
    movsxd rax, dword [rsp + 88]
    add rax, rax
    sub rsi, rax
    add rsi, 256
    lea rdi, [rel norm_scratch]
    test rsi, rsi
    js .shift_real_right
    call __al_big_left
    jmp .large_root
.shift_real_right:
    neg rsi
    call __al_big_right_sticky
    or [rsp + 80], eax
.large_root:
    lea rdi, [rel radius]
    lea rsi, [rel norm_scratch]
    call __al_big_add
    lea rdi, [rel radius]
    mov esi, 255
    call __al_big_left
    lea rdi, [rel large]
    lea rsi, [rel radius]
    lea rdx, [rel remainder]
    lea rcx, [rel trial]
    call __al_big_isqrt
    cmp qword [rel remainder], 0
    je .round_large
    mov dword [rsp + 80], 1

.round_large:
    lea rdi, [rel numerator]
    lea rsi, [rel large]
    call __al_big_copy
    movsxd rax, dword [rsp + 88]
    sub rax, 256
    mov [rel metadata + 16], rax
    mov qword [rel metadata + 24], 2
    mov eax, [rsp + 80]
    mov [rel metadata + 32], rax
    mov eax, [rsp + 16]
    and eax, [rsp + 40]
    mov [rel metadata + 8], rax
    lea rsi, [rel denominator]
    lea rdi, [rel numerator]
    lea rdx, [rel trial]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_float_round
    mov [rsp + 84], ecx
    mov edi, ebx
    mov rsi, rax
    mov ecx, [rsp + 16]
    and ecx, [rsp + 40]
    call __al_fp_pack_biased
    mov [rsp + 48], rax
    mov [rsp + 56], edx

    ; Divide the original |imaginary| by twice the scaled large
    ; root. Retain the exact scale of the smaller input.
    cmp dword [rsp + 80], 0
    je .small_numerator
    lea rdi, [rel large]
    mov esi, 1
    mov edx, 2
    call __al_big_muladd
.small_numerator:
    lea rdi, [rel numerator]
    mov rsi, [rsp + 24]
    xor edx, edx
    call __al_big_init128
    movsxd rax, dword [rsp + 32]
    movsxd rdx, dword [rsp + 88]
    sub rax, rdx
    add rax, 255
    mov [rel metadata + 16], rax
    mov qword [rel metadata + 24], 0
    mov eax, [rsp + 16]
    xor eax, 1
    and eax, [rsp + 40]
    mov [rel metadata + 8], rax
    lea rdi, [rel numerator]
    lea rsi, [rel large]
    lea rdx, [rel trial]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_float_round
    or [rsp + 84], ecx
    mov edi, ebx
    mov rsi, rax
    mov ecx, [rsp + 16]
    xor ecx, 1
    and ecx, [rsp + 40]
    call __al_fp_pack_biased
    mov [rsp + 64], rax
    mov [rsp + 72], edx
    cmp dword [rsp + 16], 0
    je .unlock
    mov rax, [rsp + 48]
    mov edx, [rsp + 56]
    mov rcx, [rsp + 64]
    mov r8d, [rsp + 72]
    mov [rsp + 48], rcx
    mov [rsp + 56], r8d
    mov [rsp + 64], rax
    mov [rsp + 72], edx
    jmp .unlock

.real_axis:
    cmp dword [rsp + 12], 0
    je .zero_pair
    lea rdi, [rel complex_sqrt_lock]
    call __al_lock
    lea rdi, [rel norm]
    mov rsi, [rsp]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel norm]
    movsxd rsi, dword [rsp + 8]
    mov edx, ebx
    mov ecx, [rsp + 16]
    and ecx, [rsp + 40]
    mov r8d, 2
    lea r9, [rel power_scratch]
    call __al_root_round
    mov [rsp + 84], ecx
    cmp dword [rsp + 16], 0
    jne .negative_axis
    mov [rsp + 48], rax
    mov [rsp + 56], edx
    mov [rsp + 64], r14
    mov [rsp + 72], r15d
    jmp .unlock
.negative_axis:
    mov qword [rsp + 48], 0
    mov dword [rsp + 56], 0
    mov [rsp + 64], rax
    mov [rsp + 72], edx
.unlock:
    lea rdi, [rel complex_sqrt_lock]
    call __al_unlock
    mov edi, [rsp + 84]
    xor esi, esi
    test edi, 16
    jz .effects
    mov esi, 34
.effects:
    call __al_math_effects
    mov rax, [rsp + 48]
    mov edx, [rsp + 56]
    mov rcx, [rsp + 64]
    mov r8d, [rsp + 72]
    jmp .done

.zero_pair:
    xor eax, eax
    xor edx, edx
    mov rcx, r14
    mov r8d, r15d
    jmp .done
.imaginary_infinity:
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    call __al_fp_special
    mov rcx, r14
    mov r8d, r15d
    jmp .done
.real_infinity:
    cmp dword [rsp + 16], 0
    jne .negative_infinity
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    call __al_fp_special
    mov r12, rax
    mov r13d, edx
    cmp dword [rsp + 36], 4
    jae .quiet_imaginary
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    mov ecx, [rsp + 40]
    call __al_fp_pack_exact
    jmp .pack_infinite_pair
.quiet_imaginary:
    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    call __al_fp_quiet
.pack_infinite_pair:
    mov rcx, rax
    mov r8d, edx
    mov rax, r12
    mov edx, r13d
    jmp .done
.negative_infinity:
    mov edi, ebx
    xor esi, esi
    mov edx, [rsp + 40]
    call __al_fp_special
    mov r12, rax
    mov r13d, edx
    cmp dword [rsp + 36], 4
    jae .quiet_real
    xor eax, eax
    xor edx, edx
    jmp .pack_negative_infinity
.quiet_real:
    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    call __al_fp_quiet
.pack_negative_infinity:
    mov rcx, r12
    mov r8d, r13d
    jmp .done
.nan_imaginary:
    mov r12, r14
    mov r13d, r15d
.nan_real:
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    call __al_fp_quiet
    mov rcx, rax
    mov r8d, edx
.done:
    add rsp, 96
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .bss.__al_complex_sqrt alloc noexec write nobits align=8
complex_sqrt_lock:
    resq 1
metadata:
    resq 6
norm:
    resq 1281
norm_scratch:
    resq 1281
radius:
    resq 1281
large:
    resq 1281
remainder:
    resq 1281
trial:
    resq 1281
numerator:
    resq 1281
denominator:
    resq 1281
power_scratch:
    resq 8

section .note.GNU-stack noalloc noexec nowrite progbits
