; Compute catanh/catan for r9 0/1 on the principal branch.
bits 64
default rel

global __al_complex_inverse_tangent:function
extern __al_fork_scratch_locks:data
extern __al_fp_decode:function
extern __al_fp_pack_exact:function
extern __al_fp_special:function
extern __al_math_atan:function
extern __al_math_log:function
extern __al_math_inverse_hyperbolic:function
extern __al_math_tiny_adjust:function
extern __al_math_effects:function
extern __al_lock:function
extern __al_unlock:function
extern __al_complex_norm:function
extern __al_complex_align:function
extern __al_complex_square_cmp:function
extern __al_big_bits:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_big_add:function
extern __al_big_sub:function
extern __al_big_cmp:function
extern __al_big_copy:function
extern __al_round_irrational:function

section .text.__al_complex_inverse_tangent alloc exec nowrite progbits
__al_complex_inverse_tangent:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 112
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
    cmp dword [rsp + 12], 3
    jae .nonfinite
    cmp dword [rsp + 36], 3
    jae .nonfinite
    cmp dword [rsp + 12], 0
    je .imaginary_axis
    mov rax, [rsp]
    bsr r9, rax
    mov r10d, r9d
    add r10d, [rsp + 8]
    mov [rsp + 52], r10d
    cmp dword [rsp + 36], 0
    je .real_axis
    cmp r10d, -80
    jge .evaluate
    mov rax, [rsp + 24]
    bsr rax, rax
    add eax, [rsp + 32]
    cmp eax, -80
    jl .tiny_pair
    jmp .evaluate
.real_axis:
    test r10d, r10d
    js .scalar_atanh
    jnz .evaluate
    mov ecx, r9d
    mov r10d, 1
    shl r10, cl
    cmp [rsp], r10
    jne .evaluate
.scalar_atanh:
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    mov ecx, 2
    call __al_math_inverse_hyperbolic
    mov r12, rax
    mov r13d, edx
    jmp .results

.evaluate:
    lea rdi, [rel __al_fork_scratch_locks + 80]
    call __al_lock
    lea rdi, [rel norm]
    lea rsi, [rel temporary]
    mov rdx, [rsp]
    movsxd rcx, dword [rsp + 8]
    mov r8, [rsp + 24]
    movsxd r9, dword [rsp + 32]
    call __al_complex_norm
    mov [rsp + 56], rax
    lea rdi, [rel unit]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel norm]
    lea rsi, [rel unit]
    mov rdx, [rsp + 56]
    xor ecx, ecx
    call __al_complex_align
    mov [rsp + 56], rax

    ; Keep 1+|z|² and 2|x| on the same exact scale.
    lea rdi, [rel denominator]
    lea rsi, [rel norm]
    call __al_big_copy
    lea rdi, [rel denominator]
    lea rsi, [rel unit]
    call __al_big_add
    lea rdi, [rel horizontal]
    mov rsi, [rsp]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel horizontal]
    movsxd rsi, dword [rsp + 8]
    inc rsi
    sub rsi, [rsp + 56]
    call __al_big_left
    lea rdi, [rel denominator]
    call __al_big_bits
    mov [rsp + 64], rax
    lea rdi, [rel horizontal]
    call __al_big_bits
    sub rax, [rsp + 64]
    cmp rax, -80
    jl .small_log_ratio

    ; The scale cancels in log(A)-log(B), so both integer inputs
    ; have nonnegative logarithms and the subtraction is ordered.
    lea rdi, [rel temporary]
    lea rsi, [rel denominator]
    call __al_big_copy
    lea rdi, [rel temporary]
    lea rsi, [rel horizontal]
    call __al_big_add
    mov edi, ebx
    lea rsi, [rel temporary]
    xor edx, edx
    mov ecx, 5
    lea r8, [rel real_numerator]
    call __al_math_log
    lea rdi, [rel temporary]
    lea rsi, [rel denominator]
    call __al_big_copy
    lea rdi, [rel temporary]
    lea rsi, [rel horizontal]
    call __al_big_sub
    mov edi, ebx
    lea rsi, [rel temporary]
    xor edx, edx
    mov ecx, 5
    lea r8, [rel logarithm]
    call __al_math_log
    lea rdi, [rel real_numerator]
    lea rsi, [rel logarithm]
    call __al_big_sub
    mov qword [rel metadata + 16], -258
    mov qword [rel metadata + 24], 2
    jmp .round_real

.small_log_ratio:
    ; For small 2x/(1+|z|²), the odd atanh series starts above
    ; x/(1+|z|²). Far from the origin, expand instead in 1/z.
    mov dword [rsp + 72], 1
    mov qword [rsp + 96], 0
    cmp dword [rsp + 52], 81
    jl .norm_order
    cmp dword [rsp + 36], 0
    je .reciprocal_axis
    mov rax, [rsp + 24]
    bsr rax, rax
    add eax, [rsp + 32]
    mov edx, [rsp + 52]
    sub edx, eax
    cmp edx, 80
    jg .reciprocal_axis
.norm_order:
    lea rdi, [rel norm]
    call __al_big_bits
    add rax, [rsp + 56]
    cmp rax, 163
    jl .small_horizontal
    lea rdi, [rel denominator]
    lea rsi, [rel norm]
    call __al_big_copy
    cmp dword [rsp + 36], 0
    je .perturb_ratio
    mov rdi, [rsp]
    movsxd rsi, dword [rsp + 8]
    mov rdx, [rsp + 24]
    movsxd rcx, dword [rsp + 32]
    mov r8d, 2
    call __al_complex_square_cmp
    mov [rsp + 72], eax
    jmp .perturb_ratio
.reciprocal_axis:
    ; At large x and small y/x the leading real term is 1/x.
    ; The correction relative to that term has sign 1-3y².
    lea rdi, [rel horizontal]
    mov esi, 2
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel denominator]
    mov rsi, [rsp]
    xor edx, edx
    call __al_big_init128
    movsxd rax, dword [rsp + 8]
    neg rax
    mov [rsp + 96], rax
    cmp dword [rsp + 36], 0
    je .perturb_ratio
    mov edi, 1
    xor esi, esi
    mov rdx, [rsp + 24]
    movsxd rcx, dword [rsp + 32]
    mov r8d, 2
    call __al_complex_square_cmp
    mov [rsp + 72], eax
    jmp .perturb_ratio
.small_horizontal:
    cmp dword [rsp + 52], -80
    jge .perturb_ratio
    ; Holding y fixed and expanding in x gives x/(1+y²);
    ; the first correction has the sign of 1-3y².
    mov rax, [rsp]
    mul rax
    mov rsi, rax
    lea rdi, [rel temporary]
    call __al_big_init128
    movsxd rsi, dword [rsp + 8]
    add rsi, rsi
    sub rsi, [rsp + 56]
    lea rdi, [rel temporary]
    call __al_big_left
    lea rdi, [rel denominator]
    lea rsi, [rel temporary]
    call __al_big_sub
    mov edi, 1
    xor esi, esi
    mov rdx, [rsp + 24]
    movsxd rcx, dword [rsp + 32]
    mov r8d, 2
    call __al_complex_square_cmp
    mov [rsp + 72], eax
.perturb_ratio:
    lea rdi, [rel real_numerator]
    lea rsi, [rel horizontal]
    call __al_big_copy
    lea rdi, [rel real_numerator]
    mov esi, 192
    call __al_big_left
    lea rdi, [rel real_numerator]
    lea rsi, [rel horizontal]
    cmp dword [rsp + 72], 0
    jl .ratio_down
    call __al_big_add
    jmp .ratio_scale
.ratio_down:
    call __al_big_sub
.ratio_scale:
    mov rax, [rsp + 96]
    sub rax, 193
    mov [rel metadata + 16], rax
    mov qword [rel metadata + 24], 0
.round_real:
    mov eax, [rsp + 16]
    mov [rel metadata + 8], rax
    lea rdi, [rel real_numerator]
    lea rsi, [rel denominator]
    lea rdx, [rel comparison]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_round_irrational
    mov r12, rax
    mov r13d, edx
    mov [rsp + 76], ecx

    lea rdi, [rel unit]
    lea rsi, [rel norm]
    call __al_big_cmp
    mov [rsp + 80], eax
    lea rdi, [rel unit]
    lea rsi, [rel norm]
    test eax, eax
    jns .subtract_norm
    mov rax, rdi
    mov rdi, rsi
    mov rsi, rax
.subtract_norm:
    mov [rsp + 88], rdi
    call __al_big_sub
    lea rdi, [rel vertical]
    mov rsi, [rsp + 24]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel vertical]
    movsxd rsi, dword [rsp + 32]
    inc rsi
    sub rsi, [rsp + 56]
    call __al_big_left
    mov edi, ebx
    lea rsi, [rel vertical]
    mov rdx, [rsp + 88]
    mov ecx, [rsp + 80]
    shr ecx, 31
    shl ecx, 1
    or ecx, [rsp + 40]
    mov r8, -1
    mov r9d, 2
    call __al_math_atan
    mov r14, rax
    mov r15d, edx
    or [rsp + 76], ecx
    lea rdi, [rel __al_fork_scratch_locks + 80]
    call __al_unlock
    mov edi, [rsp + 76]
    xor esi, esi
    test edi, 16
    jz .publish
    mov esi, 34
.publish:
    call __al_math_effects
    jmp .results

.tiny_pair:
    ; atanh(z)=z+z³/3+..., so the component corrections have
    ; the opposite directions from those of the direct tangent.
    mov rdi, [rsp]
    movsxd rsi, dword [rsp + 8]
    mov rdx, [rsp + 24]
    movsxd rcx, dword [rsp + 32]
    mov r8d, 2
    call __al_complex_square_cmp
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
.imaginary_axis:
    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    xor r9d, r9d
    call __al_math_atan
    jmp .store_imaginary

.nonfinite:
    cmp dword [rsp + 12], 5
    je .signal_invalid
    cmp dword [rsp + 36], 5
    jne .classify_special
.signal_invalid:
    mov edi, 1
    xor esi, esi
    call __al_math_effects
.classify_special:
    cmp dword [rsp + 12], 3
    je .infinite_real
    cmp dword [rsp + 36], 3
    je .infinite_angle
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
.infinite_real:
    cmp dword [rsp + 36], 4
    jb .infinite_angle
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    mov ecx, [rsp + 16]
    call __al_fp_pack_exact
    mov r12, rax
    mov r13d, edx
    jmp .nan_imaginary
.infinite_angle:
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    mov ecx, [rsp + 16]
    call __al_fp_pack_exact
    mov r12, rax
    mov r13d, edx
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    mov ecx, [rsp + 40]
    call __al_fp_pack_exact
    mov edi, ebx
    mov rsi, rax
    xor ecx, ecx
    xor r8d, r8d
    mov r9d, 1
    call __al_math_atan
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
    add rsp, 112
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
norm: resb 10248
unit: resb 10248
horizontal: resb 10248
vertical: resb 10248
temporary: resb 10248
logarithm: resb 64
real_numerator: resb 10248
denominator: resb 10248
comparison: resb 10248

section .note.GNU-stack noalloc noexec nowrite progbits
