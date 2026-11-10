; For a binary32 lgamma input in edi, return bits in eax and accepted in edx.
; Retain the shared Q256 path for poles, special values, and ambiguous rounding.
bits 64
default rel

global __al_lgammaf_fast:function
extern __al_log_f64_bounded:function
extern __al_lgamma_f64_stirling:function
extern __al_math_effects:function

section .text.__al_lgammaf_fast alloc exec nowrite progbits
__al_lgammaf_fast:
    sub rsp, 40
    mov eax, edi
    and eax, 0x7fffffff
    jz .decline
    cmp eax, 0x7f800000
    jae .decline
    cmp eax, 0x3d800000           ; |x| <= 1/16
    jbe .small
    test edi, edi
    js .negative
    cmp eax, 0x41000000           ; x >= 8
    jae .stirling
    cmp eax, 0x3f600000           ; x >= 7/8
    jb .recurrence
    cmp eax, 0x3f900000           ; x <= 9/8
    jbe .root_one
    cmp eax, 0x3ff00000           ; x >= 15/8
    jb .recurrence
    cmp eax, 0x40080000           ; x <= 17/8
    ja .recurrence

    stmxcsr [rsp]
    ldmxcsr [rel masked_nearest]
    movd xmm0, edi
    cvtss2sd xmm0, xmm0
    subsd xmm0, qword [rel two]
    lea rdx, [rel series_two]
    jmp .root_series
.root_one:
    stmxcsr [rsp]
    ldmxcsr [rel masked_nearest]
    movd xmm0, edi
    cvtss2sd xmm0, xmm0
    subsd xmm0, qword [rel one]
    lea rdx, [rel series_one]
.root_series:
    mov ecx, 17
    mov r8d, 1
    jmp .gamma_series

.small:
    stmxcsr [rsp]
    ldmxcsr [rel masked_nearest]
    movd xmm0, edi
    cvtss2sd xmm0, xmm0
    movsd [rsp + 16], xmm0
    movd xmm0, eax
    cvtss2sd xmm0, xmm0
    call __al_log_f64_bounded
    movsd [rsp + 24], xmm0
    movsd xmm0, qword [rsp + 16]
    lea rdx, [rel series_one]
    mov ecx, 11
    xor r8d, r8d
.gamma_series:
    ; Factor the exact displacement before evaluating the polynomial.
    movsd xmm1, qword [rdx + rcx*8]
.gamma_term:
    dec ecx
    mulsd xmm1, xmm0
    addsd xmm1, qword [rdx + rcx*8]
    test ecx, ecx
    jnz .gamma_term
    mulsd xmm0, xmm1
    test r8d, r8d
    jnz .enclose
    subsd xmm0, qword [rsp + 24]   ; log Gamma(1+x) - log |x|
    jmp .enclose

.stirling:
    stmxcsr [rsp]
    ldmxcsr [rel masked_nearest]
    movd xmm0, edi
    cvtss2sd xmm0, xmm0
    call __al_lgamma_f64_stirling
    jmp .enclose

.negative:
    cmp eax, 0x4b000000           ; all binary32 magnitudes >= 2^23 are integral
    jae .decline
    cmp eax, 0x42000000           ; reflect when |x| > 32
    ja .reflect
.recurrence:
    stmxcsr [rsp]
    ldmxcsr [rel masked_nearest]
    movd xmm0, edi
    cvtss2sd xmm0, xmm0
    test edi, edi
    jns .start_product
    cvttsd2si eax, xmm0
    cvtsi2sd xmm1, eax
    ucomisd xmm0, xmm1
    je .ambiguous
.start_product:
    movsd xmm1, qword [rel one]
.product:
    mulsd xmm1, xmm0
    addsd xmm0, qword [rel one]
    ucomisd xmm0, qword [rel eight]
    jb .product

    ; log |Gamma(x)| = log Gamma(y) - log |product|, with 8 <= y < 9.
    movq rax, xmm1
    mov rdx, 0x7fffffffffffffff
    and rax, rdx
    mov [rsp + 24], rax
    call __al_lgamma_f64_stirling
    movsd [rsp + 16], xmm0
    movsd xmm0, qword [rsp + 24]
    call __al_log_f64_bounded
    movsd xmm1, qword [rsp + 16]
    subsd xmm1, xmm0
    movapd xmm0, xmm1
    movsd xmm1, qword [rel recurrence_error]
    jmp .bounds

.reflect:
    stmxcsr [rsp]
    ldmxcsr [rel masked_nearest]
    movd xmm0, eax
    cvtss2sd xmm0, xmm0
    movapd xmm1, xmm0
    addsd xmm1, qword [rel one]
    movsd [rsp + 16], xmm1       ; 1 + |x|

    cvttsd2si ecx, xmm0
    cvtsi2sd xmm1, ecx
    subsd xmm0, xmm1
    pxor xmm1, xmm1
    ucomisd xmm0, xmm1
    je .ambiguous                ; exact negative integer
    ucomisd xmm0, qword [rel half]
    jbe .distance
    movsd xmm1, qword [rel one]
    subsd xmm1, xmm0
    movapd xmm0, xmm1
.distance:
    movsd [rsp + 24], xmm0       ; d = distance to the nearest integer
    call __al_log_f64_bounded
    movsd [rsp + 32], xmm0
    movsd xmm0, qword [rsp + 24]
    mulsd xmm0, xmm0
    lea rdx, [rel sinc_series]
    movsd xmm1, qword [rdx + 10*8]
    mov ecx, 10
.sinc_term:
    dec ecx
    mulsd xmm1, xmm0
    addsd xmm1, qword [rdx + rcx*8]
    test ecx, ecx
    jnz .sinc_term
    movapd xmm0, xmm1
    call __al_log_f64_bounded
    addsd xmm0, qword [rsp + 32]
    movsd [rsp + 24], xmm0       ; log(d) + log(sinc(pi*d))
    movsd xmm0, qword [rsp + 16]
    call __al_lgamma_f64_stirling
    addsd xmm0, qword [rsp + 24]
    pxor xmm1, xmm1
    subsd xmm1, xmm0
    movapd xmm0, xmm1

.enclose:
    movq rax, xmm0
    mov rdx, 0x7fffffffffffffff
    and rax, rdx
    movq xmm1, rax
    mulsd xmm1, qword [rel relative_error]
.bounds:
    movapd xmm2, xmm0
    subsd xmm2, xmm1
    addsd xmm0, xmm1

    mov eax, [rsp]
    and eax, 0x6000
    or eax, 0x1f80
    mov [rsp + 4], eax
    ldmxcsr [rsp + 4]
    cvtsd2ss xmm3, xmm2
    stmxcsr [rsp + 8]
    ldmxcsr [rsp + 4]
    cvtsd2ss xmm4, xmm0
    stmxcsr [rsp + 12]
    movd eax, xmm3
    movd edx, xmm4
    cmp eax, edx
    jne .ambiguous
    mov ecx, [rsp + 8]
    and ecx, 8
    mov edx, [rsp + 12]
    and edx, 8
    cmp ecx, edx
    jne .ambiguous

    cvtss2sd xmm3, xmm3
    ucomisd xmm3, xmm2
    jb .inexact
    ucomisd xmm3, xmm0
    jbe .ambiguous
.inexact:
    ; Leave any tiny result to the shared engine.
    mov edx, eax
    and edx, 0x7fffffff
    cmp edx, 0x00800000
    jb .ambiguous
    ldmxcsr [rsp]
    mov edi, 32
    xor esi, esi
    test ecx, ecx
    jz .publish
    or edi, ecx
    mov esi, 34
.publish:
    mov [rsp + 16], eax
    call __al_math_effects
    mov eax, [rsp + 16]
    mov edx, 1
    jmp .done
.ambiguous:
    ldmxcsr [rsp]
.decline:
    xor edx, edx
.done:
    add rsp, 40
    ret

section .rodata.__al_lgammaf_fast alloc noexec nowrite progbits align=8
masked_nearest:
    dq 0x1f80
half:
    dq 0x3fe0000000000000
one:
    dq 0x3ff0000000000000
two:
    dq 0x4000000000000000
eight:
    dq 0x4020000000000000
relative_error:
    dq 0x3d90000000000000        ; 2^-38
recurrence_error:
    dq 0x3db0000000000000        ; 2^-36 absolute, including cancellation
series_one:
    ; Coefficients of log Gamma(1+d) for powers 1 through 18.
    dq 0xbfe2788cfc6fb619, 0x3fea51a6625307d3, 0xbfd9a4d55beab2d7
    dq 0x3fd151322ac7d848, 0xbfca8b9c17aa6149, 0x3fc5b40cb100c306
    dq 0xbfc2703a1dcea3ae, 0x3fc010b36af86397, 0xbfbc806706d57db4
    dq 0x3fb9a01e385d5f8f, 0xbfb748c33114c6d6, 0x3fb556ad63243bc4
    dq 0xbfb3b1d971fc5985, 0x3fb2496df8320c5f, 0xbfb11133476e7fe0
    dq 0x3fb00010064cdeb2, 0xbfae1e2d311e8abd, 0x3fac71ce3a20b419
series_two:
    ; Coefficients of log Gamma(2+d) for powers 1 through 18.
    dq 0x3fdb0ee6072093ce, 0x3fd4a34cc4a60fa6, 0xbfb13e001a557607
    dq 0x3f951322ac7d8483, 0xbf7e404fc218f5f2, 0x3f67add6eadb6c30
    dq 0xbf538ac5c2bf8e08, 0x3f40b36af86396e9, 0xbf2d3fd4c76d2fc8
    dq 0x3f1a127b0f17d65a, 0xbf078de5bd7c81ef, 0x3ef580dcee66eb02
    dq 0xbee3cbc963ce2243, 0x3ed2597a39f34aac, 0xbec11b2eb7679541
    dq 0x3eb0064cdeb22f0f, 0xbe9e2600d93cfd2f, 0x3e8c76bbb3f07a4d
sinc_series:
    ; Coefficients of sin(pi*d)/(pi*d), in powers of d^2.
    dq 0x3ff0000000000000, 0xbffa51a6625307d3, 0x3fe9f9cb402bc46c
    dq 0xbfc86a8e4720db67, 0x3f9ac6805cf350a6, 0xbf633816aa4607ab
    dq 0x3f2374719fab3915, 0xbedd42498d1ce099, 0x3e90fc992ff39e13
    dq 0xbe3f5f9d970ca6df, 0x3de79788684225ea

section .note.GNU-stack noalloc noexec nowrite progbits
