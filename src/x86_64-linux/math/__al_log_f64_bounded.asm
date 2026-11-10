; Approximate log(x) in xmm0 for positive normal binary64 inputs.
; The caller establishes nearest rounding with masked exceptions.
bits 64
default rel

global __al_log_f64_bounded:function

section .text.__al_log_f64_bounded alloc exec nowrite progbits
__al_log_f64_bounded:
    movq rax, xmm0
    mov rdx, rax
    shr rdx, 52
    sub edx, 1023
    mov rcx, 0x000fffffffffffff
    and rax, rcx
    mov rcx, 0x3ff0000000000000
    or rax, rcx
    movq xmm0, rax

    ; x = 2^e m, z = (m-1)/(m+1). Use 16 odd terms in log(m).
    movapd xmm1, xmm0
    subsd xmm0, qword [rel one]
    addsd xmm1, qword [rel one]
    divsd xmm0, xmm1
    movapd xmm1, xmm0
    mulsd xmm1, xmm1
    lea rax, [rel reciprocal_odd]
    movsd xmm2, qword [rax + 15*8]
    mov ecx, 15
.series:
    dec ecx
    mulsd xmm2, xmm1
    addsd xmm2, qword [rax + rcx*8]
    test ecx, ecx
    jnz .series
    mulsd xmm0, xmm2
    addsd xmm0, xmm0
    cvtsi2sd xmm1, edx
    mulsd xmm1, qword [rel ln2]
    addsd xmm0, xmm1
    ret

section .rodata.__al_log_f64_bounded alloc noexec nowrite progbits align=8
one:
    dq 0x3ff0000000000000
ln2:
    dq 0x3fe62e42fefa39ef
reciprocal_odd:
    dq 0x3ff0000000000000, 0x3fd5555555555555, 0x3fc999999999999a, 0x3fc2492492492492
    dq 0x3fbc71c71c71c71c, 0x3fb745d1745d1746, 0x3fb3b13b13b13b14, 0x3fb1111111111111
    dq 0x3fae1e1e1e1e1e1e, 0x3faaf286bca1af28, 0x3fa8618618618618, 0x3fa642c8590b2164
    dq 0x3fa47ae147ae147b, 0x3fa2f684bda12f68, 0x3fa1a7b9611a7b96, 0x3fa0842108421084

section .note.GNU-stack noalloc noexec nowrite progbits
