; Compute the Q256 Gaussian continued fraction with b=rdx, scale 2^rcx and four bignums at rsi.
bits 64
default rel

global __al_erfc_fraction:function
extern __al_big_init128:function
extern __al_big_copy:function
extern __al_big_muladd:function
extern __al_big_left:function
extern __al_big_mul_u64:function
extern __al_big_add:function
extern __al_fixed_big_ratio256:function

section .text.__al_erfc_fraction alloc exec nowrite progbits
__al_erfc_fraction:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32
    mov rbx, rdi
    mov r12, rsi
    lea r13, [rsi + 10248]
    lea r14, [rsi + 20496]
    lea r15, [rsi + 30744]
    mov [rsp], rdx               ; integer denominator b
    mov [rsp + 8], rcx           ; scaling exponent
    lea rax, [rcx + rcx - 1]
    mov [rsp + 16], rax          ; coefficient n * 2^(2s-1)
    mov qword [rsp + 24], 384
    mov qword [r12], 0
    mov rdi, r13
    mov esi, 1
    xor edx, edx
    call __al_big_init128

    ; Continuants remain exact integers. Each step replaces A/B by
    ; (n * 2^(2s-1) * B) / (b * B + A).
.term:
    mov rdi, r14
    mov rsi, r13
    call __al_big_copy
    mov rdi, r14
    mov rsi, [rsp + 24]
    xor edx, edx
    call __al_big_muladd
    mov rdi, r14
    mov rsi, [rsp + 16]
    call __al_big_left
    mov rdi, r15
    mov rsi, r13
    mov rdx, [rsp]
    call __al_big_mul_u64
    mov rdi, r15
    mov rsi, r12
    call __al_big_add

    mov rax, r12
    mov r12, r14
    mov r14, rax
    mov rax, r13
    mov r13, r15
    mov r15, rax
    dec qword [rsp + 24]
    jnz .term

    mov rdi, r15
    mov rsi, r13
    mov rdx, [rsp]
    call __al_big_mul_u64
    mov rdi, r15
    mov rsi, r12
    call __al_big_add
    mov rdi, r13
    mov rsi, [rsp + 8]
    call __al_big_left
    mov rdi, rbx
    mov rsi, r13
    mov rdx, r15
    call __al_fixed_big_ratio256
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
