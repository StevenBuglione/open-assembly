; Compute asinh/acosh/atanh for rcx 0/1/2 from encoded kind and raw words.
bits 64
default rel

global __al_math_inverse_hyperbolic:function
extern __al_fp_decode:function
extern __al_fp_quiet:function
extern __al_fp_special:function
extern __al_math_effects:function
extern __al_math_tiny_adjust:function
extern __al_math_log:function
extern __al_round_irrational:function
extern __al_lock:function
extern __al_unlock:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_big_sub:function
extern __al_big_add:function
extern __al_big_copy:function
extern __al_big_isqrt:function

section .text.__al_math_inverse_hyperbolic alloc exec nowrite progbits
__al_math_inverse_hyperbolic:
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
    cmp r14d, 1
    je .acosh_classify
    test r8d, r8d
    jz .original
    cmp r8d, 3
    jne .exponent
    cmp r14d, 2
    je .domain
    jmp .original
.acosh_classify:
    test r15d, r15d
    jnz .domain
    test r8d, r8d
    jz .domain
    cmp r8d, 3
    je .original
.exponent:
    bsr r9, rax
    lea r10d, [rdx + r9]
    cmp r14d, 2
    je .atanh_range
    cmp r14d, 1
    jne .valid
    test r10d, r10d
    js .domain
    jnz .valid
    mov ecx, r9d
    mov r11d, 1
    shl r11, cl
    cmp rax, r11
    jne .valid
    xor eax, eax
    xor edx, edx
    jmp .done
.atanh_range:
    test r10d, r10d
    jg .domain
    jl .valid
    mov ecx, r9d
    mov r11d, 1
    shl r11, cl
    cmp rax, r11
    jne .domain
    jmp .pole

.valid:
    cmp r10d, -80
    jl .tiny
    mov [rsp], rax
    mov [rsp + 8], edx
    mov [rsp + 16], r10d
    lea rdi, [rel inverse_hyper_lock]
    call __al_lock
    cmp dword [rsp + 16], 96
    jge .asymptote
    cmp r14d, 2
    je .tangent
    ; Form x squared plus or minus one on the exact common dyadic
    ; scale, then convert its square root to Q256.
    mov rax, [rsp]
    mul rax
    lea rdi, [rel term]
    mov rsi, rax
    call __al_big_init128
    lea rdi, [rel auxiliary]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    movsxd rsi, dword [rsp + 8]
    add rsi, rsi
    mov [rsp + 24], rsi
    test rsi, rsi
    js .align_one
    lea rdi, [rel term]
    call __al_big_left
    mov qword [rsp + 24], 0
    jmp .form_radicand
.align_one:
    neg rsi
    lea rdi, [rel auxiliary]
    call __al_big_left
.form_radicand:
    lea rdi, [rel term]
    lea rsi, [rel auxiliary]
    cmp r14d, 1
    je .cosine_radicand
    call __al_big_add
    jmp .root_quantum
.cosine_radicand:
    call __al_big_sub
.root_quantum:
    lea rdi, [rel term]
    mov rsi, [rsp + 24]
    add rsi, 512
    call __al_big_left
    lea rdi, [rel radical]
    lea rsi, [rel term]
    lea rdx, [rel auxiliary]
    lea rcx, [rel comparison]
    call __al_big_isqrt
    lea rdi, [rel argument]
    mov rsi, [rsp]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel argument]
    mov esi, [rsp + 8]
    add esi, 256
    call __al_big_left
    lea rdi, [rel argument]
    lea rsi, [rel radical]
    call __al_big_add
    lea rsi, [rel argument]
    mov edx, -256
    jmp .log_magnitude
.asymptote:
    lea rdi, [rel argument]
    mov rsi, [rsp]
    xor edx, edx
    call __al_big_init128
    lea rsi, [rel argument]
    mov edx, [rsp + 8]
    inc edx
.log_magnitude:
    mov edi, ebx
    mov ecx, 5
    lea r8, [rel series]
    call __al_math_log
    mov qword [rel metadata + 16], -256
    jmp .round

.tangent:
    ; atanh(x) = (log(1+x) - log(1-x))/2. Each dyadic input to
    ; the logarithm is exact on the grid in this range.
    lea rdi, [rel argument]
    mov rsi, [rsp]
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel argument]
    mov esi, [rsp + 8]
    add esi, 256
    call __al_big_left
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
    lea rdi, [rel auxiliary]
    lea rsi, [rel argument]
    call __al_big_add
    lea rdi, [rel term]
    lea rsi, [rel argument]
    call __al_big_sub
    lea rsi, [rel auxiliary]
    mov edx, -256
    mov edi, ebx
    mov ecx, 5
    lea r8, [rel series]
    call __al_math_log
    lea rsi, [rel term]
    mov edx, -256
    mov edi, ebx
    mov ecx, 5
    lea r8, [rel radical]
    call __al_math_log
    lea rdi, [rel series]
    lea rsi, [rel radical]
    call __al_big_add
    mov qword [rel metadata + 16], -257

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
    mov [rsp + 28], ecx
    lea rdi, [rel inverse_hyper_lock]
    call __al_unlock
    mov edi, [rsp + 28]
    xor esi, esi
    test edi, 16
    jz .effects
    mov esi, 34
.effects:
    call __al_math_effects
    jmp .original
.tiny:
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    lea ecx, [r15*2 - 1]
    cmp r14d, 2
    jne .tiny_adjust
    neg ecx
.tiny_adjust:
    call __al_math_tiny_adjust
    jmp .done
.pole:
    mov edi, 4
    mov esi, 34
    call __al_math_effects
    mov edi, ebx
    xor esi, esi
    mov edx, r15d
    call __al_fp_special
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
    add rsp, 48
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .bss.__al_math_inverse_hyperbolic alloc noexec write nobits align=8
inverse_hyper_lock:
    resq 1
metadata:
    resq 6
argument:
    resq 1281
term:
    resq 1281
auxiliary:
    resq 1281
radical:
    resq 1281
series:
    resq 1281
denominator:
    resq 1281
comparison:
    resq 1281

section .note.GNU-stack noalloc noexec nowrite progbits
