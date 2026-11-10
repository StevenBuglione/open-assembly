; Compute complex tanh or tan (r9=0/1) with a scaled sum of squares.
bits 64
default rel

global __al_complex_tangent:function
extern __al_fork_scratch_locks:data
extern __al_fp_decode:function
extern __al_math_hyperbolic:function
extern __al_math_trig:function
extern __al_math_exp:function
extern __al_fp_special:function
extern __al_math_effects:function
extern __al_fp_pack_exact:function
extern __al_math_tiny_adjust:function
extern __al_lock:function
extern __al_unlock:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_big_sub:function
extern __al_big_copy:function
extern __al_big_cmp:function
extern __al_big_add:function
extern __al_big_multiply:function
extern __al_complex_align:function
extern __al_complex_square_cmp:function
extern __al_round_irrational:function

section .text.__al_complex_tangent alloc exec nowrite progbits
__al_complex_tangent:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 144
    mov [rsp + 48], r9d
    test r9d, r9d
    jz .decode
    mov r10, rsi
    mov rsi, rcx
    mov rcx, r10
    mov r10d, edx
    mov edx, r8d
    mov r8d, r10d
.decode:
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
    cmp dword [rsp + 36], 3
    jae .nonfinite
    cmp dword [rsp + 12], 3
    ja .nonfinite
    cmp dword [rsp + 12], 0
    je .imaginary_axis
    mov rax, [rsp + 24]
    bsr rax, rax
    add eax, [rsp + 32]
    mov [rsp + 44], eax
    mov dword [rsp + 52], 0
    cmp dword [rsp + 12], 3
    je .begin
    mov rax, [rsp]
    bsr rax, rax
    add eax, [rsp + 8]
    mov [rsp + 52], eax
    cmp eax, -80
    jge .begin
    cmp dword [rsp + 44], -80
    jl .tiny_pair
.begin:
    lea rdi, [rel __al_fork_scratch_locks + 112]
    call __al_lock
    cmp dword [rsp + 44], -80
    jl .tiny_trig
    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    mov ecx, 3
    lea r8, [rel sine]
    call __al_math_trig
    mov [rsp + 60], eax
    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    mov ecx, 4
    lea r8, [rel cosine]
    call __al_math_trig
    xor [rsp + 60], eax
    mov qword [rsp + 64], -256
    mov qword [rsp + 72], -256
    jmp .select_path
.tiny_trig:
    lea rdi, [rel sine]
    mov rsi, [rsp + 24]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel cosine]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    mov eax, [rsp + 40]
    mov [rsp + 60], eax
    movsxd rax, dword [rsp + 32]
    mov [rsp + 64], rax
    mov qword [rsp + 72], 0
.select_path:
    cmp dword [rsp + 12], 3
    je .limit
    cmp dword [rsp + 52], 5
    jge .large_hyperbolic
    cmp dword [rsp + 52], -80
    jl .tiny_hyperbolic
    lea rax, [rel hyper_sine]
    mov [rel hyper_export], rax
    lea rax, [rel hyper_denominator]
    mov [rel hyper_export + 8], rax
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    mov ecx, 3
    lea r8, [rel hyper_export]
    call __al_math_hyperbolic
    mov rax, [rel hyper_export + 16]
    mov [rsp + 80], rax
    lea rax, [rel hyper_cosine]
    mov [rel hyper_export], rax
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    mov ecx, 4
    lea r8, [rel hyper_export]
    call __al_math_hyperbolic
    mov rax, [rel hyper_export + 16]
    mov [rsp + 88], rax
    jmp .moderate_denominator
.tiny_hyperbolic:
    lea rdi, [rel hyper_sine]
    mov rsi, [rsp]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel hyper_cosine]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel hyper_denominator]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    movsxd rax, dword [rsp + 8]
    mov [rsp + 80], rax
    mov qword [rsp + 88], 0
.moderate_denominator:
    ; Hs and Hc share a denominator D. Multiply both circular
    ; factors by D before forming the squared norm and numerators.
    lea rdi, [rel scaled_cosine]
    lea rsi, [rel cosine]
    lea rdx, [rel hyper_denominator]
    call __al_big_multiply
    lea rdi, [rel scaled_sine]
    lea rsi, [rel sine]
    lea rdx, [rel hyper_denominator]
    call __al_big_multiply
    lea rdi, [rel denominator]
    lea rsi, [rel hyper_sine]
    mov rdx, rsi
    call __al_big_multiply
    lea rdi, [rel temporary]
    lea rsi, [rel scaled_cosine]
    mov rdx, rsi
    call __al_big_multiply
    lea rdi, [rel denominator]
    lea rsi, [rel temporary]
    mov rdx, [rsp + 80]
    add rdx, rdx
    mov rcx, [rsp + 72]
    add rcx, rcx
    call __al_complex_align
    mov [rsp + 96], rax
    lea rdi, [rel denominator]
    lea rsi, [rel temporary]
    call __al_big_add

    lea rdi, [rel numerator]
    lea rsi, [rel hyper_sine]
    lea rdx, [rel hyper_cosine]
    call __al_big_multiply
    mov rax, [rsp + 80]
    add rax, [rsp + 88]
    sub rax, [rsp + 96]
    mov [rel metadata + 16], rax
    mov eax, [rsp + 16]
    mov [rel metadata + 8], rax
    ; The exact rounder uses both operands as working storage.
    lea rdi, [rel round_denominator]
    lea rsi, [rel denominator]
    call __al_big_copy
    lea rdi, [rel numerator]
    lea rsi, [rel round_denominator]
    lea rdx, [rel comparison]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_round_irrational
    mov r12, rax
    mov r13d, edx
    mov [rsp + 104], ecx
    lea rdi, [rel numerator]
    lea rsi, [rel scaled_sine]
    lea rdx, [rel scaled_cosine]
    call __al_big_multiply
    mov rax, [rsp + 64]
    add rax, [rsp + 72]
    sub rax, [rsp + 96]
    mov [rel metadata + 16], rax
    jmp .round_imaginary

.large_hyperbolic:
    ; Write t = exp(-2|x|). tanh has imaginary component
    ; 4t sin(y) cos(y) / ((1-t)^2 + 4t cos(y)^2).
    mov qword [rsp + 80], -65536
    cmp dword [rsp + 52], 15
    jge .limit_direction
    mov edi, ebx
    mov rsi, [rsp]
    mov edx, [rsp + 8]
    inc edx
    mov ecx, 1
    call __al_fp_pack_exact
    mov edi, ebx
    mov rsi, rax
    mov ecx, 4
    lea r8, [rel exponential]
    call __al_math_exp
    sub rax, 256
    mov [rsp + 80], rax
.limit_direction:
    ; The signed real result is within half a step of one.
    ; Its magnitude lies below one exactly when cos(2y)+t > 0.
    lea rdi, [rel scaled_cosine]
    lea rsi, [rel cosine]
    mov rdx, rsi
    call __al_big_multiply
    lea rdi, [rel scaled_sine]
    lea rsi, [rel sine]
    mov rdx, rsi
    call __al_big_multiply
    mov rax, [rsp + 72]
    add rax, rax
    mov [rsp + 88], rax
    cmp qword [rsp + 80], -512
    jl .compare_cosine
    lea rdi, [rel temporary]
    lea rsi, [rel exponential]
    call __al_big_copy
    lea rdi, [rel scaled_cosine]
    lea rsi, [rel temporary]
    mov rdx, [rsp + 88]
    mov rcx, [rsp + 80]
    call __al_complex_align
    mov [rsp + 88], rax
    lea rdi, [rel scaled_cosine]
    lea rsi, [rel temporary]
    call __al_big_add
.compare_cosine:
    lea rdi, [rel scaled_cosine]
    lea rsi, [rel scaled_sine]
    mov rdx, [rsp + 88]
    mov rcx, [rsp + 64]
    add rcx, rcx
    call __al_complex_align
    lea rdi, [rel scaled_cosine]
    lea rsi, [rel scaled_sine]
    call __al_big_cmp
    mov dword [rsp + 108], 1
    test eax, eax
    js .large_imaginary
    mov dword [rsp + 108], -1
.large_imaginary:
    mov dword [rsp + 104], 0
    mov qword [rsp + 96], 0
    cmp dword [rsp + 52], 15
    jge .underflow_imaginary
    lea rdi, [rel temporary]
    lea rsi, [rel sine]
    lea rdx, [rel cosine]
    call __al_big_multiply
    lea rdi, [rel numerator]
    lea rsi, [rel temporary]
    lea rdx, [rel exponential]
    call __al_big_multiply
    mov rax, [rsp + 64]
    add rax, [rsp + 72]
    add rax, [rsp + 80]
    add rax, 2
    mov [rsp + 112], rax
    cmp qword [rsp + 80], -512
    jl .unit_denominator

    lea rdi, [rel temporary]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel temporary]
    mov rsi, [rsp + 80]
    neg rsi
    call __al_big_left
    lea rdi, [rel temporary]
    lea rsi, [rel exponential]
    call __al_big_sub
    lea rdi, [rel denominator]
    lea rsi, [rel temporary]
    mov rdx, rsi
    call __al_big_multiply
    lea rdi, [rel scaled_cosine]
    lea rsi, [rel cosine]
    mov rdx, rsi
    call __al_big_multiply
    lea rdi, [rel temporary]
    lea rsi, [rel scaled_cosine]
    lea rdx, [rel exponential]
    call __al_big_multiply
    lea rdi, [rel denominator]
    lea rsi, [rel temporary]
    mov rdx, [rsp + 80]
    add rdx, rdx
    mov rcx, [rsp + 72]
    add rcx, rcx
    add rcx, [rsp + 80]
    add rcx, 2
    call __al_complex_align
    mov [rsp + 96], rax
    lea rdi, [rel denominator]
    lea rsi, [rel temporary]
    call __al_big_add
    jmp .large_round_scale
.underflow_imaginary:
    lea rdi, [rel numerator]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    mov qword [rsp + 112], -65536
.unit_denominator:
    lea rdi, [rel denominator]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
.large_round_scale:
    mov rax, [rsp + 112]
    sub rax, [rsp + 96]
    mov [rel metadata + 16], rax
.round_imaginary:
    mov eax, [rsp + 60]
    mov [rel metadata + 8], rax
    lea rdi, [rel numerator]
    lea rsi, [rel denominator]
    lea rdx, [rel comparison]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_round_irrational
    mov r14, rax
    mov r15d, edx
    or [rsp + 104], ecx
    lea rdi, [rel __al_fork_scratch_locks + 112]
    call __al_unlock
    cmp dword [rsp + 52], 5
    jl .effects
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    mov ecx, [rsp + 16]
    call __al_fp_pack_exact
    mov edi, ebx
    mov rsi, rax
    mov ecx, [rsp + 108]
    cmp dword [rsp + 16], 0
    je .round_limit
    neg ecx
.round_limit:
    call __al_math_tiny_adjust
    mov r12, rax
    mov r13d, edx
.effects:
    mov edi, [rsp + 104]
    xor esi, esi
    test edi, 24
    jz .raise
    mov esi, 34
.raise:
    call __al_math_effects
    jmp .results

.tiny_pair:
    ; Near zero the real correction has the sign of 3y²-x²,
    ; and the imaginary correction has the sign of y²-3x².
    mov rdi, [rsp]
    movsxd rsi, dword [rsp + 8]
    mov rdx, [rsp + 24]
    movsxd rcx, dword [rsp + 32]
    mov r8d, 2
    call __al_complex_square_cmp
    neg eax
    cmp dword [rsp + 16], 0
    je .adjust_real
    neg eax
.adjust_real:
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    mov ecx, eax
    call __al_math_tiny_adjust
    mov r12, rax
    mov r13d, edx
    mov rdi, [rsp]
    movsxd rsi, dword [rsp + 8]
    mov rdx, [rsp + 24]
    movsxd rcx, dword [rsp + 32]
    mov r8d, 1
    call __al_complex_square_cmp
    neg eax
    cmp dword [rsp + 40], 0
    je .adjust_imaginary
    neg eax
.adjust_imaginary:
    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    mov ecx, eax
    call __al_math_tiny_adjust
    jmp .store_imaginary
.real_axis:
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    mov ecx, 2
    call __al_math_hyperbolic
    mov r12, rax
    mov r13d, edx
    jmp .results
.imaginary_axis:
    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    mov ecx, 2
    call __al_math_trig
    jmp .store_imaginary

.nonfinite:
    cmp dword [rsp + 36], 5
    je .invalid
    cmp dword [rsp + 12], 5
    je .invalid
    cmp dword [rsp + 12], 3
    jae .special
    cmp dword [rsp + 36], 3
    jne .special
.invalid:
    mov edi, 1
    xor esi, esi
    call __al_math_effects
.special:
    cmp dword [rsp + 12], 3
    je .infinite_hyperbolic
    cmp dword [rsp + 12], 0
    je .nan_imaginary
    mov edi, ebx
    mov esi, 2
    xor edx, edx
    call __al_fp_special
    mov r12, rax
    mov r13d, edx
.nan_imaginary:
    mov edi, ebx
    mov esi, 2
    xor edx, edx
    call __al_fp_special
    jmp .store_imaginary
.infinite_hyperbolic:
    mov eax, [rsp + 40]
    mov [rsp + 60], eax
    jmp .infinite_limit
.limit:
    lea rdi, [rel __al_fork_scratch_locks + 112]
    call __al_unlock
.infinite_limit:
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    mov ecx, [rsp + 16]
    call __al_fp_pack_exact
    mov r12, rax
    mov r13d, edx
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    mov ecx, [rsp + 60]
    call __al_fp_pack_exact
.store_imaginary:
    mov r14, rax
    mov r15d, edx
.results:
    cmp dword [rsp + 48], 0
    jne .swapped
    mov rax, r12
    mov edx, r13d
    mov rcx, r14
    mov r8d, r15d
    jmp .done
.swapped:
    mov rax, r14
    mov edx, r15d
    mov rcx, r12
    mov r8d, r13d
.done:
    add rsp, 144
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .data alloc noexec write progbits
align 8
metadata:
    dq 0, 0, 0, 0, 0

section .bss alloc noexec write nobits
alignb 16
    resd 1                    ; preserve scratch record offsets
alignb 16
hyper_export: resq 3
sine: resb 64
cosine: resb 64
exponential: resb 64
hyper_sine: resb 10248
hyper_cosine: resb 10248
hyper_denominator: resb 10248
scaled_sine: resb 10248
scaled_cosine: resb 10248
numerator: resb 10248
denominator: resb 10248
temporary: resb 10248
comparison: resb 10248
round_denominator: resb 10248

section .note.GNU-stack noalloc noexec nowrite progbits
