; Compute complex asin/acos/asinh/acosh for r9 0/1/2/3.
bits 64
default rel

global __al_complex_inverse_circle:function
extern __al_fork_scratch_locks:data
extern __al_fp_decode:function
extern __al_fp_pack_exact:function
extern __al_fp_special:function
extern __al_math_atan:function
extern __al_math_asin:function
extern __al_math_log:function
extern __al_math_inverse_hyperbolic:function
extern __al_math_tiny_adjust:function
extern __al_math_effects:function
extern __al_lock:function
extern __al_unlock:function
extern __al_complex_align:function
extern __al_complex_square_cmp:function
extern __al_complex_scaled_add:function
extern __al_complex_distance_delta:function
extern __al_complex_geometric_root:function
extern __al_complex_constant_angle:function
extern __al_big_bits:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_big_add:function
extern __al_big_sub:function
extern __al_big_cmp:function
extern __al_big_copy:function
extern __al_big_multiply:function
extern __al_big_right_sticky:function
extern __al_big_divsmall:function
extern __al_round_irrational:function

section .text.__al_complex_inverse_circle alloc exec nowrite progbits
__al_complex_inverse_circle:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 160
    mov [rsp + 44], r9d
    cmp r9d, 2
    jne .decode
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
    mov eax, [rsp + 40]
    mov ecx, [rsp + 44]
    cmp ecx, 1
    jne .magnitude_sign
    xor eax, 1
.magnitude_sign:
    cmp ecx, 3
    jne .store_magnitude_sign
    xor eax, eax
.store_magnitude_sign:
    mov [rsp + 48], eax
    mov eax, [rsp + 16]
    test ecx, 1
    jz .angle_sign
    xor eax, eax
    cmp ecx, 3
    jne .angle_sign
    mov eax, [rsp + 40]
.angle_sign:
    mov [rsp + 52], eax
    mov dword [rsp + 60], 0
    cmp dword [rsp + 12], 3
    jae .nonfinite
    cmp dword [rsp + 36], 3
    jae .nonfinite
    cmp dword [rsp + 12], 0
    je .zero_real
    mov rax, [rsp]
    bsr r9, rax
    mov r10d, r9d
    add r10d, [rsp + 8]
    mov [rsp + 108], r10d
    cmp dword [rsp + 36], 0
    je .real_axis
    mov rax, [rsp + 24]
    bsr rax, rax
    add eax, [rsp + 32]
    mov [rsp + 112], eax
    cmp r10d, -80
    jge .geometry
    cmp eax, -80
    jl .tiny_pair
    jmp .geometry

.real_axis:
    cmp dword [rsp + 44], 3
    je .geometry
    test r10d, r10d
    js .scalar_angle
    jnz .geometry
    mov ecx, r9d
    mov r10d, 1
    shl r10, cl
    cmp [rsp], r10
    jne .geometry
.scalar_angle:
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    mov ecx, [rsp + 44]
    and ecx, 1
    call __al_math_asin
    mov r12, rax
    mov r13d, edx
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    mov ecx, [rsp + 48]
    call __al_fp_pack_exact
    mov r14, rax
    mov r15d, edx
    jmp .results

.zero_real:
    mov edi, ebx
    mov rsi, [rsp + 24]
    mov edx, [rsp + 32]
    mov ecx, [rsp + 48]
    call __al_fp_pack_exact
    mov edi, ebx
    mov rsi, rax
    xor ecx, ecx
    call __al_math_inverse_hyperbolic
    mov r14, rax
    mov r15d, edx
    jmp .center_angle

.tiny_pair:
    mov rdi, [rsp]
    movsxd rsi, dword [rsp + 8]
    mov rdx, [rsp + 24]
    movsxd rcx, dword [rsp + 32]
    mov r8d, 1
    call __al_complex_square_cmp
    cmp dword [rsp + 48], 0
    je .tiny_magnitude_direction
    neg eax
.tiny_magnitude_direction:
    mov [rsp + 120], eax
    mov edi, ebx
    mov rsi, [rsp + 24]
    mov edx, [rsp + 32]
    mov ecx, [rsp + 48]
    call __al_fp_pack_exact
    mov edi, ebx
    mov rsi, rax
    mov ecx, [rsp + 120]
    call __al_math_tiny_adjust
    mov r14, rax
    mov r15d, edx
    test dword [rsp + 44], 1
    jnz .center_angle
    mov rdi, [rsp]
    movsxd rsi, dword [rsp + 8]
    mov rdx, [rsp + 24]
    movsxd rcx, dword [rsp + 32]
    mov r8d, 2
    call __al_complex_square_cmp
    cmp dword [rsp + 16], 0
    je .tiny_angle_direction
    neg eax
.tiny_angle_direction:
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    mov ecx, eax
    call __al_math_tiny_adjust
    jmp .store_angle

.geometry:
    lea rdi, [rel __al_fork_scratch_locks + 76]
    call __al_lock
    lea rdi, [rel horizontal]
    mov rsi, [rsp]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel unit]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel horizontal]
    lea rsi, [rel unit]
    movsxd rdx, dword [rsp + 8]
    xor ecx, ecx
    call __al_complex_align
    mov [rsp + 64], rax
    lea rdi, [rel plus]
    lea rsi, [rel horizontal]
    call __al_big_copy
    lea rdi, [rel plus]
    lea rsi, [rel unit]
    call __al_big_add
    lea rdi, [rel horizontal]
    lea rsi, [rel unit]
    call __al_big_cmp
    mov [rsp + 104], eax
    lea rsi, [rel horizontal]
    test eax, eax
    jns .copy_gap
    lea rsi, [rel unit]
.copy_gap:
    lea rdi, [rel gap]
    call __al_big_copy
    lea rsi, [rel unit]
    cmp dword [rsp + 104], 0
    jge .subtract_gap
    lea rsi, [rel horizontal]
.subtract_gap:
    lea rdi, [rel gap]
    call __al_big_sub
    mov rax, [rsp + 24]
    mul rax
    mov rsi, rax
    lea rdi, [rel vertical_squared]
    call __al_big_init128
    movsxd rax, dword [rsp + 32]
    add rax, rax
    mov [rsp + 72], rax

    lea rdi, [rel delta]
    lea rsi, [rel plus]
    mov rdx, [rsp + 64]
    lea rcx, [rel vertical_squared]
    mov r8, [rsp + 72]
    call __al_complex_distance_delta
    mov [rsp + 80], rax
    lea rdi, [rel temporary]
    lea rsi, [rel gap]
    mov rdx, [rsp + 64]
    lea rcx, [rel vertical_squared]
    mov r8, [rsp + 72]
    call __al_complex_distance_delta
    lea rdi, [rel delta]
    lea rsi, [rel temporary]
    mov rdx, [rsp + 80]
    mov rcx, rax
    call __al_complex_scaled_add
    dec rax
    mov [rsp + 80], rax

    ; D²=(A-|x|)(A+|x|), with A=max(1,|x|)+delta.
    cmp dword [rsp + 104], 0
    jl .angle_small_real
    lea rdi, [rel temporary]
    lea rsi, [rel horizontal]
    call __al_big_copy
    lea rdi, [rel temporary]
    mov esi, 1
    call __al_big_left
    lea rsi, [rel zero]
    lea rdx, [rel temporary]
    jmp .angle_root
.angle_small_real:
    lea rsi, [rel gap]
    lea rdx, [rel plus]
.angle_root:
    lea rdi, [rel angle_root]
    mov rcx, [rsp + 64]
    lea r8, [rel delta]
    mov r9, [rsp + 80]
    call __al_complex_geometric_root
    mov [rsp + 88], rax

    ; W²=(A-1)(A+1), so acosh(A)=asinh(W).
    cmp dword [rsp + 104], 0
    jge .height_large_real
    lea rdi, [rel temporary]
    lea rsi, [rel unit]
    call __al_big_copy
    lea rdi, [rel temporary]
    mov esi, 1
    call __al_big_left
    lea rsi, [rel zero]
    lea rdx, [rel temporary]
    jmp .height_root
.height_large_real:
    lea rsi, [rel gap]
    lea rdx, [rel plus]
.height_root:
    lea rdi, [rel height_root]
    mov rcx, [rsp + 64]
    lea r8, [rel delta]
    mov r9, [rsp + 80]
    call __al_complex_geometric_root
    mov [rsp + 96], rax
    cmp qword [rel height_root], 0
    je .zero_height
    lea rdi, [rel height_root]
    call __al_big_bits
    add rax, [rsp + 96]
    cmp rax, -79
    jle .small_height

    ; A+W stays positive. Form it without subtracting nearly equal
    ; distances, then evaluate the natural logarithm.
    lea rdi, [rel height]
    lea rsi, [rel unit]
    cmp dword [rsp + 104], 0
    jl .copy_base
    lea rsi, [rel horizontal]
.copy_base:
    call __al_big_copy
    lea rdi, [rel height]
    lea rsi, [rel delta]
    mov rdx, [rsp + 64]
    mov rcx, [rsp + 80]
    call __al_complex_scaled_add
    lea rdi, [rel height]
    lea rsi, [rel height_root]
    mov rdx, rax
    mov rcx, [rsp + 96]
    call __al_complex_scaled_add
    mov edi, ebx
    lea rsi, [rel height]
    mov edx, eax
    mov ecx, 5
    lea r8, [rel numerator]
    call __al_math_log
    mov qword [rel metadata + 16], -256
    jmp .round_height

.small_height:
    cmp rax, -124
    jl .tiny_height
    ; asinh(W)/W = 1-W²/6+O(W⁴). Keep the quadratic correction
    ; when it fits Q256, so nearby directed ties retain their side.
    lea rdi, [rel temporary]
    lea rsi, [rel height_root]
    mov rdx, rsi
    call __al_big_multiply
    mov rsi, [rsp + 96]
    add rsi, rsi
    add rsi, 256
    neg rsi
    lea rdi, [rel temporary]
    call __al_big_right_sticky
    lea rdi, [rel temporary]
    mov esi, 6
    call __al_big_divsmall
    lea rdi, [rel height]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel height]
    mov esi, 256
    call __al_big_left
    lea rdi, [rel height]
    lea rsi, [rel temporary]
    call __al_big_sub
    lea rdi, [rel numerator]
    lea rsi, [rel height_root]
    lea rdx, [rel height]
    call __al_big_multiply
    mov rax, [rsp + 96]
    sub rax, 256
    mov [rel metadata + 16], rax
    jmp .round_height
.tiny_height:
    ; asinh(W) lies below W. At |x|=1, its expansion around
    ; sqrt(|y|) lies above that leading term, even for tiny |y|.
    lea rdi, [rel numerator]
    lea rsi, [rel height_root]
    call __al_big_copy
    lea rdi, [rel numerator]
    mov esi, 248
    call __al_big_left
    lea rdi, [rel numerator]
    lea rsi, [rel height_root]
    cmp dword [rsp + 104], 0
    jne .height_below
    call __al_big_add
    jmp .tiny_height_scale
.height_below:
    call __al_big_sub
.tiny_height_scale:
    mov rax, [rsp + 96]
    sub rax, 248
    mov [rel metadata + 16], rax
.round_height:
    mov qword [rel metadata + 24], 2
    mov eax, [rsp + 48]
    mov [rel metadata + 8], rax
    lea rdi, [rel numerator]
    lea rsi, [rel denominator]
    lea rdx, [rel comparison]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_round_irrational
    mov [rsp + 60], ecx
    jmp .store_height
.zero_height:
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    mov ecx, [rsp + 48]
    call __al_fp_pack_exact
.store_height:
    mov r14, rax
    mov r15d, edx

    test dword [rsp + 44], 1
    jz .ordinary_angle
    cmp dword [rsp + 16], 0
    jne .ordinary_angle
    cmp dword [rsp + 36], 0
    je .ordinary_angle
    mov eax, [rsp + 108]
    cmp eax, 80
    jl .ordinary_angle
    sub eax, [rsp + 112]
    cmp eax, 80
    jg .large_real_angle
.ordinary_angle:
    lea rdi, [rel horizontal]
    lea rsi, [rel angle_root]
    mov rdx, [rsp + 64]
    mov rcx, [rsp + 88]
    call __al_complex_align
    mov edi, ebx
    mov ecx, [rsp + 52]
    xor r8d, r8d
    mov r9d, 2
    lea rsi, [rel horizontal]
    lea rdx, [rel angle_root]
    test dword [rsp + 44], 1
    jz .round_angle
    lea rsi, [rel angle_root]
    lea rdx, [rel horizontal]
    mov eax, [rsp + 16]
    shl eax, 1
    or ecx, eax
.round_angle:
    call __al_math_atan
    jmp .save_angle

.large_real_angle:
    ; For large positive x and small y/x, acos(x+iy)'s angle
    ; is y/x plus a correction whose sign is that of 3-2y².
    lea rdi, [rel temporary]
    lea rsi, [rel vertical_squared]
    call __al_big_copy
    lea rdi, [rel height]
    mov esi, 3
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel height]
    lea rsi, [rel temporary]
    xor edx, edx
    mov rcx, [rsp + 72]
    inc rcx
    call __al_complex_align
    lea rdi, [rel height]
    lea rsi, [rel temporary]
    call __al_big_cmp
    mov [rsp + 120], eax
    lea rdi, [rel temporary]
    mov rsi, [rsp + 24]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel numerator]
    lea rsi, [rel temporary]
    call __al_big_copy
    lea rdi, [rel numerator]
    mov esi, 248
    call __al_big_left
    lea rdi, [rel numerator]
    lea rsi, [rel temporary]
    cmp dword [rsp + 120], 0
    jl .angle_below
    call __al_big_add
    jmp .angle_denominator
.angle_below:
    call __al_big_sub
.angle_denominator:
    lea rdi, [rel denominator]
    mov rsi, [rsp]
    xor edx, edx
    call __al_big_init128
    movsxd rax, dword [rsp + 32]
    movsxd rdx, dword [rsp + 8]
    sub rax, rdx
    sub rax, 248
    mov [rel metadata + 16], rax
    mov qword [rel metadata + 24], 0
    mov eax, [rsp + 52]
    mov [rel metadata + 8], rax
    lea rdi, [rel numerator]
    lea rsi, [rel denominator]
    lea rdx, [rel comparison]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_round_irrational
.save_angle:
    mov r12, rax
    mov r13d, edx
    or [rsp + 60], ecx
    lea rdi, [rel __al_fork_scratch_locks + 76]
    call __al_unlock
    mov edi, [rsp + 60]
    xor esi, esi
    test edi, 16
    jz .publish
    mov esi, 34
.publish:
    call __al_math_effects
    jmp .results

.nonfinite:
    cmp dword [rsp + 12], 5
    je .invalid
    cmp dword [rsp + 36], 5
    jne .special_height
.invalid:
    mov edi, 1
    xor esi, esi
    call __al_math_effects
.special_height:
    mov edi, ebx
    mov esi, 2
    mov edx, [rsp + 48]
    cmp dword [rsp + 12], 3
    je .infinite_height
    cmp dword [rsp + 36], 3
    jne .pack_height
.infinite_height:
    xor esi, esi
.pack_height:
    call __al_fp_special
    mov r14, rax
    mov r15d, edx
    cmp dword [rsp + 12], 0
    je .center_angle
    cmp dword [rsp + 12], 3
    ja .nan_angle
    cmp dword [rsp + 36], 3
    ja .nan_angle
    cmp dword [rsp + 12], 3
    jne .center_angle
    mov esi, 2
    cmp dword [rsp + 36], 3
    jne .infinite_horizontal
    mov esi, 1
    test dword [rsp + 44], 1
    jz .constant_angle
    mov eax, [rsp + 16]
    lea esi, [rax*2 + 1]
    jmp .constant_angle
.infinite_horizontal:
    test dword [rsp + 44], 1
    jz .constant_angle
    mov esi, [rsp + 16]
    shl esi, 2
    jmp .constant_angle
.center_angle:
    xor esi, esi
    test dword [rsp + 44], 1
    jz .constant_angle
    mov esi, 2
.constant_angle:
    mov edi, ebx
    mov edx, [rsp + 52]
    call __al_complex_constant_angle
    jmp .store_angle
.nan_angle:
    mov edi, ebx
    mov esi, 2
    xor edx, edx
    call __al_fp_special
.store_angle:
    mov r12, rax
    mov r13d, edx
.results:
    cmp dword [rsp + 44], 2
    jae .swapped
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
    add rsp, 160
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata alloc noexec nowrite progbits
align 8
zero:
    dq 0

section .data alloc noexec write progbits
align 8
metadata:
    dq 0, 0, 0, 2, 0

section .bss alloc noexec write nobits
alignb 16
    resd 1                    ; preserve scratch record offsets
alignb 16
horizontal: resb 10248
unit: resb 10248
plus: resb 10248
gap: resb 10248
vertical_squared: resb 10248
delta: resb 10248
temporary: resb 10248
angle_root: resb 10248
height_root: resb 10248
height: resb 10248
numerator: resb 10248
denominator: resb 10248
comparison: resb 10248

section .note.GNU-stack noalloc noexec nowrite progbits
