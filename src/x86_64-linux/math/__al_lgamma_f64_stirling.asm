; Approximate log Gamma(x) for binary64 x >= 8 in xmm0.
; The caller establishes nearest rounding with masked exceptions.
bits 64
default rel

global __al_lgamma_f64_stirling:function
extern __al_log_f64_bounded:function

section .text.__al_lgamma_f64_stirling alloc exec nowrite progbits
__al_lgamma_f64_stirling:
    sub rsp, 8
    movsd [rsp], xmm0
    call __al_log_f64_bounded
    movsd xmm1, qword [rsp]
    movapd xmm2, xmm1
    subsd xmm2, qword [rel half]
    mulsd xmm2, xmm0
    subsd xmm2, xmm1
    addsd xmm2, qword [rel half_log_two_pi]

    movsd xmm0, qword [rel one]
    divsd xmm0, xmm1
    movapd xmm1, xmm0
    mulsd xmm1, xmm1
    lea rdx, [rel bernoulli]
    movsd xmm3, qword [rdx + 7*8]
    mov ecx, 7
.term:
    dec ecx
    mulsd xmm3, xmm1
    addsd xmm3, qword [rdx + rcx*8]
    test ecx, ecx
    jnz .term
    mulsd xmm0, xmm3
    addsd xmm0, xmm2
    add rsp, 8
    ret

section .rodata.__al_lgamma_f64_stirling alloc noexec nowrite progbits align=8
half:
    dq 0x3fe0000000000000
one:
    dq 0x3ff0000000000000
half_log_two_pi:
    dq 0x3fed67f1c864beb5
bernoulli:
    dq 0x3fb5555555555555, 0xbf66c16c16c16c17, 0x3f4a01a01a01a01a, 0xbf43813813813814
    dq 0x3f4b951e2b18ff23, 0xbf5f6ab0d9993c7d, 0x3f7a41a41a41a41a, 0xbf9e4286cb0f5398

section .note.GNU-stack noalloc noexec nowrite progbits
