; Compute erf (rcx=0) or erfc (rcx=1) from kind and raw words.
bits 64
default rel

global __al_math_erf:function
extern __al_fork_scratch_locks:data
extern __al_fp_decode:function
extern __al_fp_quiet:function
extern __al_fp_pack_exact:function
extern __al_math_effects:function
extern __al_math_tiny_adjust:function
extern __al_math_scale:function
extern __al_math_exp:function
extern __al_round_irrational:function
extern __al_lock:function
extern __al_unlock:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_big_right_sticky:function
extern __al_big_copy:function
extern __al_big_add:function
extern __al_big_sub:function
extern __al_big_muladd:function
extern __al_big_divsmall:function
extern __al_big_mul_u64:function
extern __al_fixed_mul256:function
extern __al_erfc_fraction:function

section .text.__al_math_erf alloc exec nowrite progbits
__al_math_erf:
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
    call __al_fp_decode
    mov r15d, ecx
    cmp r8d, 5
    je .signaling
    cmp r8d, 4
    je .original
    cmp r8d, 3
    je .infinity
    test r8d, r8d
    jz .zero
    mov [rsp], rax
    mov [rsp + 8], rdx
    bsr r9, rax
    add r9d, edx
    cmp r9d, -80
    jl .tiny
    cmp r9d, 3
    jl .prepare
    test r14d, r14d
    jz .erf_limit
    test r15d, r15d
    jnz .erfc_limit
    cmp r9d, 7
    jge .erfc_underflow
.prepare:
    mov [rsp + 16], r9d
    lea rdi, [rel __al_fork_scratch_locks + 20]
    call __al_lock
    lea rdi, [rel argument]
    mov rsi, [rsp]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel argument]
    mov rsi, [rsp + 8]
    add rsi, 256
    call __al_big_left
    lea rdi, [rel squared]
    lea rsi, [rel argument]
    mov rdx, rsi
    lea rcx, [rel product_words]
    call __al_fixed_mul256
    cmp dword [rsp + 16], 1
    jge .tail

    lea rdi, [rel term]
    lea rsi, [rel argument]
    call __al_big_copy
    lea rdi, [rel series]
    lea rsi, [rel argument]
    call __al_big_copy
    mov qword [rel negative_terms], 0
    mov dword [rsp + 20], 1
.next_term:
    lea rdi, [rel term]
    mov rsi, rdi
    lea rdx, [rel squared]
    lea rcx, [rel product_words]
    call __al_fixed_mul256
    mov eax, [rsp + 20]
    lea esi, [rax + rax - 1]
    xor edx, edx
    lea rdi, [rel term]
    call __al_big_muladd
    mov eax, [rsp + 20]
    lea esi, [rax + rax + 1]
    imul esi, eax
    lea rdi, [rel term]
    call __al_big_divsmall
    cmp qword [rel term], 0
    je .finish_series
    lea rdi, [rel series]
    test dword [rsp + 20], 1
    jz .add_term
    lea rdi, [rel negative_terms]
.add_term:
    lea rsi, [rel term]
    call __al_big_add
    inc dword [rsp + 20]
    cmp dword [rsp + 20], 100
    jbe .next_term
.finish_series:
    lea rdi, [rel series]
    lea rsi, [rel negative_terms]
    call __al_big_sub
    lea rdi, [rel series]
    mov rsi, rdi
    lea rdx, [rel twice_inverse_sqrt_pi]
    lea rcx, [rel product_words]
    call __al_fixed_mul256
    test r14d, r14d
    jz .round_fixed

    lea rdi, [rel term]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel term]
    mov esi, 256
    call __al_big_left
    lea rdi, [rel term]
    lea rsi, [rel series]
    test r15d, r15d
    jnz .negative_erfc
    call __al_big_sub
    jmp .complement_ready
.negative_erfc:
    call __al_big_add
.complement_ready:
    xor r15d, r15d
    jmp .use_term

.tail:
    mov rdx, [rsp]
    mov rax, [rsp + 8]
    cmp rax, -1
    jl .fraction_scale
    lea ecx, [rax + 1]
    shl rdx, cl
    mov ecx, 1
    jmp .fraction
.fraction_scale:
    mov rcx, rax
    neg rcx
.fraction:
    lea rdi, [rel tail_factor]
    lea rsi, [rel fraction_scratch]
    call __al_erfc_fraction
    lea rdi, [rel tail_factor]
    mov rsi, rdi
    lea rdx, [rel inverse_sqrt_pi]
    lea rcx, [rel product_words]
    call __al_fixed_mul256
    lea rdi, [rel squared]
    mov rsi, rdi
    lea rdx, [rel log2e_lower]
    lea rcx, [rel product_words]
    call __al_fixed_mul256
    mov edi, ebx
    lea rsi, [rel squared]
    mov edx, 1
    mov ecx, 5
    lea r8, [rel exponential]
    call __al_math_exp
    mov [rsp + 24], rax
    lea rdi, [rel series]
    lea rsi, [rel exponential]
    lea rdx, [rel tail_factor]
    lea rcx, [rel product_words]
    call __al_fixed_mul256

    test r14d, r14d
    jz .tail_complement
    test r15d, r15d
    jnz .tail_complement
    mov rax, [rsp + 24]
    sub rax, 256
    mov [rel metadata + 16], rax
    jmp .round
.tail_complement:
    lea rdi, [rel series]
    mov rsi, [rsp + 24]
    neg rsi
    call __al_big_right_sticky
    lea rdi, [rel term]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel term]
    mov esi, 256
    call __al_big_left
    test r14d, r14d
    jz .subtract_tail
    xor r15d, r15d
    lea rdi, [rel term]
    mov esi, 1
    call __al_big_left
.subtract_tail:
    lea rdi, [rel term]
    lea rsi, [rel series]
    call __al_big_sub
.use_term:
    lea rdi, [rel series]
    lea rsi, [rel term]
    call __al_big_copy
.round_fixed:
    mov qword [rel metadata + 16], -256
.round:
    mov [rel metadata + 8], r15
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
    mov [rsp + 32], ecx
    lea rdi, [rel __al_fork_scratch_locks + 20]
    call __al_unlock
    mov edi, [rsp + 32]
    xor esi, esi
    test edi, 16
    jz .effects
    mov esi, 34
.effects:
    call __al_math_effects
    jmp .original

.tiny:
    test r14d, r14d
    jnz .tiny_erfc
    lea rdi, [rel __al_fork_scratch_locks + 20]
    call __al_lock
    lea rdi, [rel series]
    lea rsi, [rel twice_inverse_sqrt_pi]
    mov rdx, [rsp]
    call __al_big_mul_u64
    mov rax, [rsp + 8]
    sub rax, 256
    mov [rel metadata + 16], rax
    jmp .round
.tiny_erfc:
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    xor ecx, ecx
    call __al_fp_pack_exact
    mov rsi, rax
    lea ecx, [r15*2 - 1]
    jmp .adjust
.erf_limit:
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    mov ecx, r15d
    call __al_fp_pack_exact
    mov rsi, rax
    lea ecx, [r15*2 - 1]
    jmp .adjust
.erfc_limit:
    mov edi, ebx
    mov esi, 2
    xor edx, edx
    xor ecx, ecx
    call __al_fp_pack_exact
    mov rsi, rax
    mov ecx, -1
.adjust:
    mov edi, ebx
    call __al_math_tiny_adjust
    jmp .done
.erfc_underflow:
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    xor ecx, ecx
    call __al_fp_pack_exact
    mov edi, ebx
    mov rsi, rax
    mov rcx, -65536
    call __al_math_scale
    jmp .done

.infinity:
    test r14d, r14d
    jz .signed_one
    mov esi, r15d
    add esi, esi
    xor ecx, ecx
    jmp .pack_exact
.zero:
    test r14d, r14d
    jz .original
    xor r15d, r15d
.signed_one:
    mov esi, 1
    mov ecx, r15d
.pack_exact:
    mov edi, ebx
    xor edx, edx
    call __al_fp_pack_exact
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

section .rodata.__al_math_erf alloc noexec nowrite progbits align=8
; Directed MPFR bounds agree on these floors at the Q256 scale.
inverse_sqrt_pi:
    dq 8
    dd 0xcce620b0, 0x39a15830, 0xac3e7517, 0x1409a0eb, 0x6bfec344, 0x71d48a7f, 0x14db688d, 0x906eba82
twice_inverse_sqrt_pi:
    dq 9
    dd 0x99cc4161, 0x7342b061, 0x587cea2e, 0x281341d7, 0xd7fd8688, 0xe3a914fe, 0x29b6d11a, 0x20dd7504, 0x00000001
log2e_lower:
    dq 9
    dd 0xa342648f, 0x164a2cd9, 0xbad2b4b1, 0xd6aef551
    dd 0xd23a7d11, 0x7d0ffda0, 0xb82fe177, 0x71547652, 0x00000001

section .bss.__al_math_erf alloc noexec write nobits align=8
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
negative_terms:
    resq 1281
tail_factor:
    resq 1281
exponential:
    resq 1281
denominator:
    resq 1281
comparison:
    resq 1281
fraction_scratch:
    resq 5124
product_words:
    resd 18

section .note.GNU-stack noalloc noexec nowrite progbits
