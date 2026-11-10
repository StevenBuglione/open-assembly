; Compute asin (rcx=0) or acos (rcx=1) from encoded kind and raw words.
bits 64
default rel

global __al_math_asin:function
extern __al_fork_scratch_locks:data
extern __al_fp_decode:function
extern __al_fp_quiet:function
extern __al_fp_special:function
extern __al_math_effects:function
extern __al_lock:function
extern __al_unlock:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_big_sub:function
extern __al_big_add:function
extern __al_big_copy:function
extern __al_big_muladd:function
extern __al_big_divsmall:function
extern __al_big_isqrt:function
extern __al_fixed_mul256:function
extern __al_pi_q256:function
extern __al_pi_complement:function
extern __al_round_irrational:function
extern __al_math_tiny_adjust:function

section .text.__al_math_asin alloc exec nowrite progbits
__al_math_asin:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32
    mov ebx, edi
    mov r12, rsi
    mov r13d, edx
    mov r14, rcx
    call __al_fp_decode
    mov r15d, ecx
    cmp r8d, 5
    je .signaling
    cmp r8d, 4
    je .original
    cmp r8d, 3
    je .domain
    test r8d, r8d
    jz .zero
    bsr r9, rax
    lea r10d, [rdx + r9]
    test r10d, r10d
    jg .domain
    jl .finite
    mov ecx, r9d
    mov r11d, 1
    shl r11, cl
    cmp rax, r11
    jne .domain
    test r14d, r14d
    jz .half_pi
    test r15d, r15d
    jnz .full_pi
    xor eax, eax
    xor edx, edx
    jmp .done

.finite:
    cmp r10d, -80
    jl .tiny
    mov [rsp], rax
    mov [rsp + 8], edx
    mov [rsp + 16], r10d
    mov dword [rsp + 20], 0
    lea rdi, [rel __al_fork_scratch_locks + 12]
    call __al_lock
    lea rdi, [rel argument]
    mov rsi, [rsp]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel argument]
    mov esi, [rsp + 8]
    add esi, 256
    call __al_big_left
    cmp dword [rsp + 16], -1
    jl .series

    ; For |x| >= 1/2, the half-angle argument sqrt((1-|x|)/2)
    ; is at most 1/2. Construct its Q256 floor with integer sqrt.
    mov dword [rsp + 20], 1
    lea rdi, [rel term]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel term]
    mov esi, 256
    call __al_big_left
    lea rdi, [rel term]
    lea rsi, [rel argument]
    call __al_big_sub
    lea rdi, [rel term]
    mov esi, 255
    call __al_big_left
    lea rdi, [rel argument]
    lea rsi, [rel term]
    lea rdx, [rel auxiliary]
    lea rcx, [rel comparison]
    call __al_big_isqrt

.series:
    lea rdi, [rel squared]
    lea rsi, [rel argument]
    mov rdx, rsi
    lea rcx, [rel product_words]
    call __al_fixed_mul256
    lea rdi, [rel term]
    lea rsi, [rel argument]
    call __al_big_copy
    lea rdi, [rel series]
    lea rsi, [rel argument]
    call __al_big_copy
    mov dword [rsp + 24], 2
.next_term:
    lea rdi, [rel term]
    mov rsi, rdi
    lea rdx, [rel squared]
    lea rcx, [rel product_words]
    call __al_fixed_mul256
    mov esi, [rsp + 24]
    dec esi
    imul esi, esi
    lea rdi, [rel term]
    xor edx, edx
    call __al_big_muladd
    mov esi, [rsp + 24]
    lea eax, [rsi + 1]
    imul esi, eax
    lea rdi, [rel term]
    call __al_big_divsmall
    cmp qword [rel term], 0
    je .compose
    lea rdi, [rel series]
    lea rsi, [rel term]
    call __al_big_add
    add dword [rsp + 24], 2
    cmp dword [rsp + 24], 264
    jbe .next_term

.compose:
    cmp dword [rsp + 20], 0
    je .direct
    lea rdi, [rel series]
    mov esi, 1
    call __al_big_left
    test r14d, r14d
    jz .half_pi_complement
    test r15d, r15d
    jz .round
    lea rdi, [rel series]
    lea rsi, [rel auxiliary]
    mov edx, 4
    call __al_pi_complement
    jmp .round
.direct:
    test r14d, r14d
    jz .round
    test r15d, r15d
    jz .half_pi_complement
    lea rdi, [rel auxiliary]
    mov esi, 2
    call __al_pi_q256
    lea rdi, [rel series]
    lea rsi, [rel auxiliary]
    call __al_big_add
    jmp .round
.half_pi_complement:
    lea rdi, [rel series]
    lea rsi, [rel auxiliary]
    mov edx, 2
    call __al_pi_complement
    jmp .round

.tiny:
    test r14d, r14d
    jnz .half_pi
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    mov ecx, r15d
    add ecx, ecx
    neg ecx
    inc ecx
    call __al_math_tiny_adjust
    jmp .done
.zero:
    test r14d, r14d
    jz .original
.half_pi:
    mov eax, 2
    jmp .constant
.full_pi:
    mov eax, 4
.constant:
    mov [rsp + 24], eax
    lea rdi, [rel __al_fork_scratch_locks + 12]
    call __al_lock
    lea rdi, [rel series]
    mov esi, [rsp + 24]
    call __al_pi_q256
.round:
    test r14d, r14d
    jz .result_sign
    xor r15d, r15d
.result_sign:
    mov [rel metadata + 8], r15
    mov qword [rel metadata + 16], -256
    mov qword [rel metadata + 24], 2
    mov qword [rel metadata + 32], 0
    lea rdi, [rel series]
    lea rsi, [rel denominator]
    lea rdx, [rel comparison]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_round_irrational
    mov r12, rax
    mov r13d, edx
    mov [rsp + 28], ecx
    lea rdi, [rel __al_fork_scratch_locks + 12]
    call __al_unlock
    mov edi, [rsp + 28]
    xor esi, esi
    test edi, 16
    jz .effects
    mov esi, 34
.effects:
    call __al_math_effects
    jmp .original
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
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .bss.__al_math_asin alloc noexec write nobits align=8
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
