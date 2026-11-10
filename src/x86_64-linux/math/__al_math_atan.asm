; Compute atan/atan2 for r9 0/1, or a scaled angle of exact bignums for r9=2.
bits 64
default rel

global __al_math_atan:function
extern __al_fork_scratch_locks:data
extern __al_fp_decode:function
extern __al_fp_pack_exact:function
extern __al_fp_quiet:function
extern __al_math_effects:function
extern __al_lock:function
extern __al_unlock:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_big_cmp:function
extern __al_big_bits:function
extern __al_big_multiply:function
extern __al_fixed_big_ratio256:function
extern __al_fixed_mul256:function
extern __al_big_copy:function
extern __al_big_sub:function
extern __al_big_add:function
extern __al_big_divsmall:function
extern __al_pi_q256:function
extern __al_pi_complement:function
extern __al_round_irrational:function

section .text.__al_math_atan alloc exec nowrite progbits
__al_math_atan:
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
    mov r15d, r8d
    mov [rsp + 64], r9d
    mov qword [rsp + 72], 0
    cmp r9d, 2
    je .raw_ratio
    call __al_fp_decode
    mov [rsp], rax
    mov [rsp + 16], edx
    mov [rsp + 24], r8d
    mov [rsp + 32], ecx
    cmp r8d, 5
    je .signaling
    cmp dword [rsp + 64], 0
    jne .decode_x
    mov qword [rsp + 8], 1
    mov dword [rsp + 20], 0
    mov dword [rsp + 28], 2
    mov dword [rsp + 36], 0
    jmp .classify
.decode_x:
    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    call __al_fp_decode
    mov [rsp + 8], rax
    mov [rsp + 20], edx
    mov [rsp + 28], r8d
    mov [rsp + 36], ecx
    cmp r8d, 5
    je .signaling_x
.classify:
    cmp dword [rsp + 24], 4
    je .original
    cmp dword [rsp + 28], 4
    je .return_x
    cmp dword [rsp + 24], 0
    je .zero_y
    cmp dword [rsp + 28], 0
    je .half_pi
    cmp dword [rsp + 24], 3
    je .infinite_y
    cmp dword [rsp + 28], 3
    je .infinite_x

    mov dword [rsp + 40], 0      ; use the half-pi complement when |y| exceeds |x|
    mov rax, [rsp]
    mov rdx, [rsp + 8]
    bsr r9, rax
    bsr r10, rdx
    mov r11d, [rsp + 16]
    add r11d, r9d
    sub r11d, [rsp + 20]
    sub r11d, r10d
    js .ratio_exponent
    jnz .invert_ratio
    mov ecx, 63
    sub ecx, r9d
    shl rax, cl
    mov ecx, 63
    sub ecx, r10d
    shl rdx, cl
    cmp rax, rdx
    jb .ratio_exponent
    je .equal_magnitudes
.invert_ratio:
    mov dword [rsp + 40], 1
    neg r11d
    mov rax, [rsp]
    mov rdx, [rsp + 8]
    mov [rsp], rdx
    mov [rsp + 8], rax
    mov eax, [rsp + 16]
    mov edx, [rsp + 20]
    mov [rsp + 16], edx
    mov [rsp + 20], eax
.ratio_exponent:
    cmp r11d, -81
    jl .tiny_ratio
    mov dword [rsp + 48], 0      ; use the quarter-pi complement for the transformed ratio
    lea rdi, [rel __al_fork_scratch_locks + 16]
    call __al_lock
    lea rdi, [rel term]
    mov rsi, [rsp]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel auxiliary]
    mov rsi, [rsp + 8]
    xor edx, edx
    call __al_big_init128
    mov esi, [rsp + 16]
    sub esi, [rsp + 20]
    js .align_denominator
    lea rdi, [rel term]
    call __al_big_left
    jmp .divide_ratio
.align_denominator:
    neg esi
    lea rdi, [rel auxiliary]
    call __al_big_left
.divide_ratio:
    lea rdi, [rel argument]
    lea rsi, [rel term]
    lea rdx, [rel auxiliary]
    call __al_fixed_big_ratio256
    cmp qword [rel argument], 8
    jb .series
    test dword [rel argument + 36], 0x80000000
    jz .series

    ; For r >= 1/2, atan(r) = pi/4 - atan((1-r)/(1+r)).
    mov dword [rsp + 48], 1
    lea rdi, [rel term]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel term]
    mov esi, 256
    call __al_big_left
    lea rdi, [rel auxiliary]
    lea rsi, [rel term]
    call __al_big_copy
    lea rdi, [rel term]
    lea rsi, [rel argument]
    call __al_big_sub
    lea rdi, [rel auxiliary]
    lea rsi, [rel argument]
    call __al_big_add
    lea rdi, [rel argument]
    lea rsi, [rel term]
    lea rdx, [rel auxiliary]
    call __al_fixed_big_ratio256

.series:
    lea rdi, [rel squared]
    lea rsi, [rel argument]
    mov rdx, rsi
    lea rcx, [rel product_words]
    call __al_fixed_mul256
    lea rdi, [rel series]
    lea rsi, [rel argument]
    call __al_big_copy
    lea rdi, [rel term]
    lea rsi, [rel argument]
    call __al_big_copy
    mov dword [rsp + 60], 3
    mov dword [rsp + 68], 1
.next_term:
    lea rdi, [rel term]
    mov rsi, rdi
    lea rdx, [rel squared]
    lea rcx, [rel product_words]
    call __al_fixed_mul256
    lea rdi, [rel auxiliary]
    lea rsi, [rel term]
    call __al_big_copy
    lea rdi, [rel auxiliary]
    mov esi, [rsp + 60]
    call __al_big_divsmall
    cmp qword [rel auxiliary], 0
    je .compose
    lea rdi, [rel series]
    lea rsi, [rel auxiliary]
    cmp dword [rsp + 68], 0
    je .positive_term
    call __al_big_sub
    jmp .next_order
.positive_term:
    call __al_big_add
.next_order:
    xor dword [rsp + 68], 1
    add dword [rsp + 60], 2
    cmp dword [rsp + 60], 263
    jbe .next_term
.compose:
    cmp dword [rsp + 48], 0
    je .compose_vertical
    lea rdi, [rel series]
    lea rsi, [rel auxiliary]
    mov edx, 1
    call __al_pi_complement
.compose_vertical:
    cmp dword [rsp + 40], 0
    je .compose_left
    lea rdi, [rel series]
    lea rsi, [rel auxiliary]
    mov edx, 2
    call __al_pi_complement
.compose_left:
    cmp dword [rsp + 36], 0
    je .round_fixed
    lea rdi, [rel series]
    lea rsi, [rel auxiliary]
    mov edx, 4
    call __al_pi_complement
    jmp .round_fixed

.raw_ratio:
    ; Mode 2 receives nonnegative y and x magnitudes at rsi/rdx
    ; on a common dyadic scale, their sign bits in rcx (y first),
    ; and a signed binary output scale in r8. Flags return in ecx.
    mov r13, rdx
    mov eax, ecx
    and eax, 1
    mov [rsp + 32], eax
    shr ecx, 1
    and ecx, 1
    mov [rsp + 36], ecx
    mov [rsp + 72], r8
    mov dword [rsp + 40], 0
    mov dword [rsp + 48], 0
    lea rdi, [rel __al_fork_scratch_locks + 16]
    call __al_lock
    cmp qword [r12], 0
    je .raw_zero_y
    cmp qword [r13], 0
    je .raw_half_pi
    mov rdi, r12
    mov rsi, r13
    call __al_big_cmp
    test eax, eax
    jz .raw_equal
    js .raw_length
    mov rax, r12
    mov r12, r13
    mov r13, rax
    mov dword [rsp + 40], 1
.raw_length:
    mov rdi, r13
    call __al_big_bits
    mov r14, rax
    mov rdi, r12
    call __al_big_bits
    sub r14, rax
    cmp r14, 81
    ja .raw_tiny
    lea rdi, [rel term]
    mov rsi, r12
    call __al_big_copy
    lea rdi, [rel auxiliary]
    mov rsi, r13
    call __al_big_copy
    jmp .divide_ratio
.raw_tiny:
    cmp dword [rsp + 40], 0
    jne .raw_half_pi
    cmp dword [rsp + 36], 0
    jne .raw_full_pi
    cmp r14, 125
    jbe .raw_tiny_polynomial
    lea rdi, [rel series]
    mov rsi, r12
    call __al_big_copy
    lea rdi, [rel series]
    mov esi, 248
    call __al_big_left
    lea rdi, [rel series]
    mov rsi, r12
    call __al_big_sub
    mov rax, [rsp + 72]
    sub rax, 248
    jmp .raw_tiny_round
.raw_tiny_polynomial:
    ; atan(r)/r = 1-r²/3+O(r⁴). Preserve the first correction
    ; when it fits the Q256 grid, and preserve the full raw ratio.
    lea rdi, [rel term]
    mov rsi, r12
    call __al_big_copy
    lea rdi, [rel argument]
    lea rsi, [rel term]
    mov rdx, r13
    call __al_fixed_big_ratio256
    lea rdi, [rel squared]
    lea rsi, [rel argument]
    mov rdx, rsi
    lea rcx, [rel product_words]
    call __al_fixed_mul256
    lea rdi, [rel squared]
    mov esi, 3
    call __al_big_divsmall
    lea rdi, [rel term]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel term]
    mov esi, 256
    call __al_big_left
    lea rdi, [rel term]
    lea rsi, [rel squared]
    call __al_big_sub
    lea rdi, [rel series]
    mov rsi, r12
    lea rdx, [rel term]
    call __al_big_multiply
    mov rax, [rsp + 72]
    sub rax, 256
.raw_tiny_round:
    mov [rel metadata + 16], rax
    lea rdi, [rel denominator]
    mov rsi, r13
    call __al_big_copy
    mov qword [rel metadata + 24], 0
    jmp .round
.raw_zero_y:
    cmp dword [rsp + 36], 0
    jne .raw_full_pi
    lea rdi, [rel __al_fork_scratch_locks + 16]
    call __al_unlock
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    mov ecx, [rsp + 32]
    call __al_fp_pack_exact
    xor ecx, ecx
    jmp .done
.raw_equal:
    mov eax, [rsp + 36]
    lea eax, [rax*2 + 1]
    jmp .constant_locked
.raw_full_pi:
    mov eax, 4
    jmp .constant_locked
.raw_half_pi:
    mov eax, 2
    jmp .constant_locked

.tiny_ratio:
    cmp dword [rsp + 40], 0
    jne .half_pi
    cmp dword [rsp + 36], 0
    jne .full_pi
    lea rdi, [rel __al_fork_scratch_locks + 16]
    call __al_lock
    lea rdi, [rel series]
    mov rsi, [rsp]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel series]
    mov esi, 192
    call __al_big_left
    lea rdi, [rel term]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel series]
    lea rsi, [rel term]
    call __al_big_sub
    lea rdi, [rel denominator]
    mov rsi, [rsp + 8]
    xor edx, edx
    call __al_big_init128
    movsxd rax, dword [rsp + 16]
    movsxd rdx, dword [rsp + 20]
    sub rax, rdx
    sub rax, 192
    mov [rel metadata + 16], rax
    mov qword [rel metadata + 24], 0
    jmp .round

.zero_y:
    cmp dword [rsp + 36], 0
    jne .full_pi
    jmp .original
.infinite_y:
    cmp dword [rsp + 28], 3
    je .equal_magnitudes
.half_pi:
    mov eax, 2
    jmp .constant
.infinite_x:
    cmp dword [rsp + 36], 0
    jne .full_pi
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    mov ecx, [rsp + 32]
    call __al_fp_pack_exact
    jmp .done
.equal_magnitudes:
    mov eax, [rsp + 36]
    lea eax, [rax*2 + 1]
    jmp .constant
.full_pi:
    mov eax, 4
.constant:
    mov [rsp + 56], eax
    lea rdi, [rel __al_fork_scratch_locks + 16]
    call __al_lock
    lea rdi, [rel series]
    mov eax, [rsp + 56]
.constant_locked:
    lea rdi, [rel series]
    mov esi, eax
    call __al_pi_q256
.round_fixed:
    mov rax, [rsp + 72]
    sub rax, 256
    mov [rel metadata + 16], rax
    mov qword [rel metadata + 24], 2
.round:
    mov eax, [rsp + 32]
    mov [rel metadata + 8], rax
    mov qword [rel metadata + 32], 0
    lea rdi, [rel series]
    lea rsi, [rel denominator]
    lea rdx, [rel comparison]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_round_irrational
    mov r12, rax
    mov r13d, edx
    mov [rsp + 52], ecx
    lea rdi, [rel __al_fork_scratch_locks + 16]
    call __al_unlock
    mov ecx, [rsp + 52]
    cmp dword [rsp + 64], 2
    je .original
    mov edi, ecx
    xor esi, esi
    test edi, 16
    jz .raise
    mov esi, 34
.raise:
    call __al_math_effects
    jmp .original

.signaling_x:
    mov r12, r14
    mov r13d, r15d
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
    jmp .original
.return_x:
    mov r12, r14
    mov r13d, r15d
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

section .bss.__al_math_atan alloc noexec write nobits align=8
    resq 1                    ; preserve scratch record offsets
metadata:
    resq 6
argument:
    resq 1281
squared:
    resq 1281
term:
    resq 1281
series:
    resq 1281
auxiliary:
    resq 1281
denominator:
    resq 1281
comparison:
    resq 1281
product_words:
    resd 18

section .note.GNU-stack noalloc noexec nowrite progbits
