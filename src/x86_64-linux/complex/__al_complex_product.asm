; Compute complex cosh/sinh/cos/sin for r9 0/1/2/3 with scaled factors.
bits 64
default rel

global __al_complex_product:function
extern __al_fp_decode:function
extern __al_math_hyperbolic:function
extern __al_math_trig:function
extern __al_fp_special:function
extern __al_math_effects:function
extern __al_fp_pack_exact:function
extern __al_lock:function
extern __al_unlock:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_big_sub:function
extern __al_big_copy:function
extern __al_big_cmp:function
extern __al_big_mul_u64:function
extern __al_big_muladd:function
extern __al_big_multiply:function
extern __al_round_irrational:function

section .text.__al_complex_product alloc exec nowrite progbits
__al_complex_product:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 144
    mov [rsp + 48], r9d
    cmp r9d, 2
    jb .decode
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
    cmp dword [rsp + 12], 3
    ja .nonfinite
    cmp dword [rsp + 36], 3
    jae .nonfinite
    mov rax, [rsp + 24]
    bsr rax, rax
    add eax, [rsp + 32]
    mov [rsp + 44], eax
    mov dword [rsp + 120], 2     ; infinite hyperbolic factor
    cmp dword [rsp + 12], 3
    je .begin
    mov dword [rsp + 120], 4     ; zero hyperbolic argument
    cmp dword [rsp + 12], 0
    je .begin
    mov rax, [rsp]
    bsr rax, rax
    add eax, [rsp + 8]
    mov [rsp + 52], eax
    mov dword [rsp + 120], 3     ; guaranteed overflow after multiplication
    cmp eax, 15
    jge .begin
    mov dword [rsp + 120], 0
    ; Both corrections are smaller than the leading product's
    ; rounding-grid spacing at these format-dependent cutoffs.
    mov ecx, -69
    cmp ebx, 2
    je .tiny_bounds
    mov ecx, -58
    cmp ebx, 1
    je .tiny_bounds
    mov ecx, -30
.tiny_bounds:
    cmp eax, ecx
    jge .matching_magnitudes
    cmp [rsp + 44], ecx
    jl .tiny_pair
.matching_magnitudes:
    cmp eax, -35
    jge .begin
    mov rax, [rsp]
    cmp rax, [rsp + 24]
    jne .begin
    mov eax, [rsp + 8]
    cmp eax, [rsp + 32]
    jne .begin
.tiny_pair:
    mov dword [rsp + 120], 1     ; product of two tiny arguments
.begin:
    lea rdi, [rel product_lock]
    call __al_lock
    lea rax, [rel hyperbolic]
    mov [rel hyperbolic_export], rax
    lea rax, [rel denominator]
    mov [rel hyperbolic_export + 8], rax
    mov dword [rsp + 56], 0
    mov dword [rsp + 76], 0
.component:
    mov eax, [rsp + 48]
    xor eax, [rsp + 56]
    and eax, 1
    mov [rsp + 60], eax         ; odd hyperbolic factor
    cmp dword [rsp + 120], 1
    je .tiny_trig
    cmp dword [rsp + 44], -80
    jl .tiny_trig
    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    mov ecx, 4
    sub ecx, [rsp + 56]
    lea r8, [rel circular]
    call __al_math_trig
    mov qword [rsp + 112], -256
    jmp .product_sign
.tiny_trig:
    mov esi, 1
    mov qword [rsp + 112], 0
    cmp dword [rsp + 56], 0
    je .init_trig
    mov rsi, [rsp + 24]
    movsxd rax, dword [rsp + 32]
    mov [rsp + 112], rax
.init_trig:
    lea rdi, [rel circular]
    xor edx, edx
    call __al_big_init128
    mov eax, [rsp + 56]
    and eax, [rsp + 40]
.product_sign:
    mov ecx, [rsp + 60]
    and ecx, [rsp + 16]
    xor eax, ecx
    cmp dword [rsp + 48], 2
    jne .save_sign
    xor eax, [rsp + 56]
.save_sign:
    mov [rel metadata + 8], rax
    cmp dword [rsp + 120], 4
    je .zero_hyperbolic
    cmp dword [rsp + 120], 2
    je .infinite_factor
    cmp dword [rsp + 120], 1
    je .tiny_product
    cmp dword [rsp + 120], 3
    je .overflow_product
    cmp dword [rsp + 52], -80
    jl .tiny_hyperbolic

    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    mov ecx, 4
    sub ecx, [rsp + 60]
    lea r8, [rel hyperbolic_export]
    call __al_math_hyperbolic
    jmp .multiply
.tiny_hyperbolic:
    mov esi, 1
    mov qword [rel hyperbolic_export + 16], 0
    cmp dword [rsp + 60], 0
    je .init_hyperbolic
    mov rsi, [rsp]
    movsxd rax, dword [rsp + 8]
    mov [rel hyperbolic_export + 16], rax
.init_hyperbolic:
    lea rdi, [rel hyperbolic]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel denominator]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
.multiply:
    mov rax, [rel hyperbolic_export + 16]
    add rax, [rsp + 112]
    mov [rel metadata + 16], rax
    lea rdi, [rel numerator]
    lea rsi, [rel hyperbolic]
    lea rdx, [rel circular]
    call __al_big_multiply
    jmp .round

.tiny_product:
    ; The leading correction is x^2/2 or x^2/6 minus y^2/2
    ; or y^2/6. The equal-weight tie has a negative next term.
    mov rax, [rsp]
    mul rax
    mov rsi, rax
    lea rdi, [rel left_square]
    call __al_big_init128
    mov rax, [rsp + 24]
    mul rax
    mov rsi, rax
    lea rdi, [rel right_square]
    call __al_big_init128
    mov eax, [rsp + 60]
    cmp eax, [rsp + 56]
    je .align_squares
    lea rsi, [rel left_square]
    test eax, eax
    jz .scale_square
    lea rsi, [rel right_square]
.scale_square:
    mov [rsp + 128], rsi
    lea rdi, [rel numerator]
    mov edx, 3
    call __al_big_mul_u64
    mov rdi, [rsp + 128]
    lea rsi, [rel numerator]
    call __al_big_copy
.align_squares:
    movsxd rsi, dword [rsp + 8]
    movsxd rax, dword [rsp + 32]
    sub rsi, rax
    lea rdi, [rel left_square]
    jns .shift_square
    neg rsi
    lea rdi, [rel right_square]
.shift_square:
    add rsi, rsi
    call __al_big_left
    lea rdi, [rel left_square]
    lea rsi, [rel right_square]
    call __al_big_cmp
    mov [rsp + 128], eax
    mov esi, 1
    mov qword [rel hyperbolic_export + 16], 0
    cmp dword [rsp + 60], 0
    je .leading_product
    mov rsi, [rsp]
    movsxd rax, dword [rsp + 8]
    mov [rel hyperbolic_export + 16], rax
.leading_product:
    lea rdi, [rel numerator]
    mov rdx, rsi
    lea rsi, [rel circular]
    call __al_big_mul_u64
    lea rdi, [rel numerator]
    mov esi, 192
    call __al_big_left
    cmp dword [rsp + 128], 0
    jle .perturb_down
    lea rdi, [rel numerator]
    mov esi, 1
    mov edx, 1
    call __al_big_muladd
    jmp .tiny_scale
.perturb_down:
    lea rdi, [rel left_square]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel numerator]
    lea rsi, [rel left_square]
    call __al_big_sub
.tiny_scale:
    mov rax, [rel hyperbolic_export + 16]
    add rax, [rsp + 112]
    sub rax, 192
    mov [rel metadata + 16], rax
    jmp .unit_denominator
.overflow_product:
    lea rdi, [rel numerator]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    mov qword [rel metadata + 16], 65536
.unit_denominator:
    lea rdi, [rel denominator]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
.round:
    lea rdi, [rel numerator]
    lea rsi, [rel denominator]
    lea rdx, [rel comparison]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_round_irrational
    or [rsp + 76], ecx
    jmp .store_component

.zero_hyperbolic:
    cmp dword [rsp + 60], 0
    jne .zero_factor
    ; The even factor equals one. Use the scalar directed-rounding
    ; path for the complete component, with no lock held.
    lea rdi, [rel product_lock]
    call __al_unlock
    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    mov ecx, 1
    sub ecx, [rsp + 56]
    call __al_math_trig
    mov [rsp + 128], rax
    mov [rsp + 136], edx
    lea rdi, [rel product_lock]
    call __al_lock
    mov rax, [rsp + 128]
    mov edx, [rsp + 136]
    jmp .store_component
.zero_factor:
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    mov ecx, [rel metadata + 8]
    call __al_fp_pack_exact
    jmp .store_component
.infinite_factor:
    mov edi, ebx
    xor esi, esi
    mov edx, [rel metadata + 8]
    call __al_fp_special
.store_component:
    cmp dword [rsp + 56], 0
    jne .second_component
    mov [rsp + 80], rax
    mov [rsp + 88], edx
    mov dword [rsp + 56], 1
    jmp .component
.second_component:
    mov [rsp + 96], rax
    mov [rsp + 104], edx
    lea rdi, [rel product_lock]
    call __al_unlock
    mov edi, [rsp + 76]
    test edi, edi
    jz .results
    xor esi, esi
    test edi, 24
    jz .raise
    mov esi, 34
.raise:
    call __al_math_effects
    jmp .results

.real_axis:
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    mov ecx, [rsp + 48]
    and ecx, 1
    xor ecx, 1
    call __al_math_hyperbolic
    mov [rsp + 80], rax
    mov [rsp + 88], edx
    mov ecx, [rsp + 48]
    and ecx, 1
    xor ecx, 1
    and ecx, [rsp + 16]
    xor ecx, [rsp + 40]
    cmp dword [rsp + 48], 2
    jne .axis_zero
    xor ecx, 1
.axis_zero:
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    call __al_fp_pack_exact
    jmp .special_second

.nonfinite:
    cmp dword [rsp + 12], 5
    je .invalid
    cmp dword [rsp + 36], 5
    je .invalid
    cmp dword [rsp + 36], 3
    jne .classify_special
    cmp dword [rsp + 12], 4
    jae .classify_special
.invalid:
    mov edi, 1
    xor esi, esi
    call __al_math_effects
.classify_special:
    cmp dword [rsp + 12], 3
    je .infinity_nan
    mov edi, ebx
    mov esi, 2
    xor edx, edx
    call __al_fp_special
    mov [rsp + 80], rax
    mov [rsp + 88], edx
    cmp dword [rsp + 12], 0
    jne .special_second
    test dword [rsp + 48], 1
    jz .nan_zero
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    mov ecx, [rsp + 16]
    call __al_fp_pack_exact
    mov [rsp + 80], rax
    mov [rsp + 88], edx
    jmp .nan_second
.nan_zero:
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    mov ecx, [rsp + 16]
    xor ecx, [rsp + 40]
    cmp dword [rsp + 48], 2
    jne .pack_special_zero
    xor ecx, 1
.pack_special_zero:
    call __al_fp_pack_exact
    jmp .special_second
.infinity_nan:
    mov edi, ebx
    xor esi, esi
    mov edx, [rsp + 48]
    and edx, 1
    and edx, [rsp + 16]
    call __al_fp_special
    mov [rsp + 80], rax
    mov [rsp + 88], edx
.nan_second:
    mov edi, ebx
    mov esi, 2
    xor edx, edx
    call __al_fp_special
.special_second:
    mov [rsp + 96], rax
    mov [rsp + 104], edx
.results:
    cmp dword [rsp + 48], 3
    je .swapped
    mov rax, [rsp + 80]
    mov edx, [rsp + 88]
    mov rcx, [rsp + 96]
    mov r8d, [rsp + 104]
    jmp .done
.swapped:
    mov rax, [rsp + 96]
    mov edx, [rsp + 104]
    mov rcx, [rsp + 80]
    mov r8d, [rsp + 88]
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
product_lock: resd 1
alignb 16
hyperbolic_export: resq 3
circular: resb 64
hyperbolic: resb 10248
denominator: resb 10248
numerator: resb 10248
comparison: resb 10248
left_square: resb 10248
right_square: resb 10248

section .note.GNU-stack noalloc noexec nowrite progbits
