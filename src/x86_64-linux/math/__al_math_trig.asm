; Compute sin/cos/tan (rcx 0/1/2), or export unrounded sine/cosine (rcx 3/4, bignum 5/6).
bits 64
default rel

global __al_math_trig:function
extern __al_fp_decode:function
extern __al_fp_pack_exact:function
extern __al_fp_pack_biased:function
extern __al_fp_special:function
extern __al_fp_quiet:function
extern __al_math_effects:function
extern __al_lock:function
extern __al_unlock:function
extern __al_reduce_pio2:function
extern __al_fixed_mul256:function
extern __al_big_copy:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_big_divsmall:function
extern __al_big_add:function
extern __al_big_sub:function
extern __al_float_round:function
extern fegetround:function

section .text.__al_math_trig alloc exec nowrite progbits
__al_math_trig:
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
    mov [rsp + 48], r8
    mov dword [rsp + 56], 0
    mov dword [rsp + 60], 0
    cmp r14d, 5
    jae .raw_argument
    cmp r14d, 3
    jb .decode
    ; Export callers supply a finite input with magnitude at least 2^-80.
    sub r14d, 3
    mov dword [rsp + 56], 1
.decode:
    call __al_fp_decode
    cmp r8d, 5
    je .signaling
    cmp r8d, 4
    je .original
    cmp r8d, 3
    je .domain
    test r8d, r8d
    jz .zero
    mov r15d, ecx
    bsr r9, rax
    add r9d, edx
    cmp r9d, -80
    jl .tiny
    mov [rsp], rax
    mov [rsp + 8], rdx
    jmp .reduce
.raw_argument:
    ; The magnitude is a bignum at rsi, power at rdx and sign r9.
    sub r14d, 5
    mov [rsp], rsi
    mov [rsp + 8], rdx
    mov r15d, r9d
    mov dword [rsp + 56], 1
    mov dword [rsp + 60], 1
.reduce:
    lea rdi, [rel trig_lock]
    call __al_lock
    mov rdi, [rsp]
    mov rsi, [rsp + 8]
    lea rdx, [rel remainder]
    lea rcx, [rel product]
    lea r8, [rel product_words]
    mov r9d, [rsp + 60]
    call __al_reduce_pio2
    mov [rsp + 64], rcx
    cmp r14d, 2
    je .tangent_kernel
    test r14d, r14d
    jz .choose_kernel
    inc eax                       ; cos(x) = sin(x + pi/2)
    xor r15d, r15d                ; cosine is even
.choose_kernel:
    and eax, 3
    mov ecx, eax
    shr eax, 1
    xor eax, r15d
    and ecx, 1
    mov [rsp + 16], ecx           ; zero selects sine; one selects cosine
    test ecx, ecx
    jnz .result_sign
    xor eax, edx
    jmp .result_sign
.tangent_kernel:
    and eax, 1
    mov [rsp + 36], eax          ; odd quadrants use the negative reciprocal
    xor eax, edx
    xor eax, r15d
    mov dword [rsp + 16], 0      ; first pass computes sine
    mov dword [rsp + 40], 0
.result_sign:
    mov [rsp + 24], eax
    cmp qword [rsp + 64], -256
    jne .tiny_remainder
    lea rdi, [rel squared]
    lea rsi, [rel remainder]
    mov rdx, rsi
    lea rcx, [rel product_words]
    call __al_fixed_mul256
    cmp dword [rsp + 16], 0
    jne .cosine_first
    lea rdi, [rel term]
    lea rsi, [rel remainder]
    call __al_big_copy
    mov dword [rsp + 20], 2
    jmp .begin_series
.cosine_first:
    lea rdi, [rel term]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel term]
    mov esi, 256
    call __al_big_left
    mov dword [rsp + 20], 1
.begin_series:
    lea rdi, [rel series]
    lea rsi, [rel term]
    call __al_big_copy
    mov dword [rsp + 28], 1
.next_term:
    lea rdi, [rel term]
    mov rsi, rdi
    lea rdx, [rel squared]
    lea rcx, [rel product_words]
    call __al_fixed_mul256
    mov esi, [rsp + 20]
    lea eax, [rsi + 1]
    imul esi, eax
    lea rdi, [rel term]
    call __al_big_divsmall
    cmp qword [rel term], 0
    je .round
    lea rdi, [rel series]
    lea rsi, [rel term]
    cmp dword [rsp + 28], 0
    je .positive_term
    call __al_big_sub
    jmp .next_order
.positive_term:
    call __al_big_add
.next_order:
    xor dword [rsp + 28], 1
    add dword [rsp + 20], 2
    cmp dword [rsp + 20], 96
    jbe .next_term
.round:
    cmp dword [rsp + 56], 0
    jne .export_fixed
    cmp r14d, 2
    je .tangent_ratio
    mov qword [rel metadata + 16], -256
    mov qword [rel metadata + 24], 2
    lea rdi, [rel series]
    lea rsi, [rel denominator]
    jmp .round_result
.tangent_ratio:
    cmp dword [rsp + 40], 0
    jne .tangent_denominator
    lea rdi, [rel sine_series]
    lea rsi, [rel series]
    call __al_big_copy
    mov dword [rsp + 40], 1
    jmp .cosine_first
.tangent_denominator:
    mov qword [rel metadata + 16], 0
    mov qword [rel metadata + 24], 0
    lea rdi, [rel sine_series]
    lea rsi, [rel series]
    cmp dword [rsp + 36], 0
    je .round_result
    mov rax, rdi
    mov rdi, rsi
    mov rsi, rax
.round_result:
    mov eax, [rsp + 24]
    mov [rel metadata + 8], rax
    mov qword [rel metadata + 32], 0
    lea rdx, [rel comparison]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_float_round
    or ecx, 32
    test edx, edx
    jnz .rounded
    or ecx, 16
.rounded:
    mov [rsp + 32], ecx
    mov edi, ebx
    mov rsi, rax
    mov ecx, [rsp + 24]
    call __al_fp_pack_biased
    mov r12, rax
    mov r13d, edx
    lea rdi, [rel trig_lock]
    call __al_unlock
    mov edi, [rsp + 32]
    jmp .effects

.tiny_remainder:
    cmp dword [rsp + 16], 0
    je .export_remainder
    lea rdi, [rel series]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel series]
    mov esi, 256
    call __al_big_left
    mov qword [rsp + 64], -256
    jmp .export_fixed
.export_remainder:
    lea rsi, [rel remainder]
    jmp .export_copy
.export_fixed:
    lea rsi, [rel series]
.export_copy:
    mov rdi, [rsp + 48]
    call __al_big_copy
    lea rdi, [rel trig_lock]
    call __al_unlock
    mov eax, [rsp + 24]
    mov rdx, [rsp + 64]
    jmp .done

.tiny:
    call fegetround
    cmp r14d, 1
    je .tiny_cos
    cmp r14d, 2
    je .tiny_tan
    cmp eax, 3072
    je .toward_zero
    test r15d, r15d
    jz .tiny_positive
    cmp eax, 2048
    je .toward_zero
    jmp .tiny_sin_flags
.tiny_positive:
    cmp eax, 1024
    jne .tiny_sin_flags
.toward_zero:
    cmp ebx, 2
    jne .decrement_sine
    mov r10, 0x8000000000000000
    cmp r12, r10
    jne .decrement_sine
    dec r13d
    mov r12, -1
    test r13d, 0x7fff
    jnz .tiny_sin_flags
    shr r12, 1
    jmp .tiny_sin_flags
.decrement_sine:
    dec r12
.tiny_sin_flags:
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    call __al_fp_decode
    mov edi, 32
    cmp r8d, 1
    ja .effects
    or edi, 16
    jmp .effects

.tiny_tan:
    test r15d, r15d
    jz .tiny_positive_tan
    cmp eax, 1024
    je .outward_tan
    jmp .tiny_sin_flags
.tiny_positive_tan:
    cmp eax, 2048
    jne .tiny_sin_flags
.outward_tan:
    inc r12
    cmp ebx, 2
    jne .tiny_sin_flags
    test r12, r12
    jz .tangent_carry
    mov r10, 0x8000000000000000
    cmp r12, r10
    jne .tiny_sin_flags
    inc r13d
    jmp .tiny_sin_flags
.tangent_carry:
    mov r12, 0x8000000000000000
    inc r13d
    jmp .tiny_sin_flags

.tiny_cos:
    mov r15d, eax
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    xor ecx, ecx
    call __al_fp_pack_exact
    mov r12, rax
    mov r13d, edx
    cmp r15d, 1024
    je .decrement_cosine
    cmp r15d, 3072
    jne .tiny_cos_flags
.decrement_cosine:
    cmp ebx, 2
    je .decrement_extended
    dec r12
    jmp .tiny_cos_flags
.decrement_extended:
    mov r12, -1
    dec r13d
.tiny_cos_flags:
    mov edi, 32
.effects:
    xor esi, esi
    test edi, 24
    jz .raise
    mov esi, 34
.raise:
    call __al_math_effects
    jmp .original

.zero:
    cmp r14d, 1
    jne .original
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    xor ecx, ecx
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
    add rsp, 80
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .bss.__al_math_trig alloc noexec write nobits align=8
trig_lock:
    resq 1
metadata:
    resq 6
remainder:
    resq 1281
squared:
    resq 1281
term:
    resq 1281
series:
    resq 1281
sine_series:
    resq 1281
product:
    resq 1281
denominator:
    resq 1281
comparison:
    resq 1281
product_words:
    resd 18

section .note.GNU-stack noalloc noexec nowrite progbits
