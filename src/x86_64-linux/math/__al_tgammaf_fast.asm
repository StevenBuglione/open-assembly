; For an ordinary binary32 gamma input in edi, return bits in eax and accepted in edx.
; The caller has handled range extremes and retains the Q256 fallback.
bits 64
default rel

global __al_tgammaf_fast:function
extern __al_math_effects:function

section .text.__al_tgammaf_fast alloc exec nowrite progbits
__al_tgammaf_fast:
    sub rsp, 24
    stmxcsr [rsp]
    ldmxcsr [rel masked_nearest]
    movd xmm0, edi
    cvtss2sd xmm0, xmm0
    and edi, 0x7fffffff
    cmp edi, 0x36800000           ; |x| < 2^-18
    jae .central

    movsd xmm1, qword [rel tiny_c3]
    mulsd xmm1, xmm0
    addsd xmm1, qword [rel tiny_c2]
    mulsd xmm1, xmm0
    addsd xmm1, qword [rel negative_euler]
    movsd xmm2, qword [rel one]
    divsd xmm2, xmm0
    addsd xmm2, xmm1
    movapd xmm0, xmm2
    movsd xmm3, qword [rel tiny_error]
    jmp .enclose

.central:
    cvttsd2si eax, xmm0
    cvtsi2sd xmm1, eax
    ucomisd xmm0, xmm1
    je .miss                     ; exact factorials and negative poles

    ; k = floor(x - 2.5), so x-k lies in [2.5, 3.5).
    movapd xmm1, xmm0
    subsd xmm1, qword [rel two_and_half]
    cvttsd2si r8d, xmm1
    cvtsi2sd xmm2, r8d
    ucomisd xmm1, xmm2
    jae .reduced
    dec r8d
    cvtsi2sd xmm2, r8d
.reduced:
    movapd xmm1, xmm0
    subsd xmm1, xmm2
    subsd xmm1, qword [rel three]

    lea rdx, [rel coefficients]
    movsd xmm2, qword [rdx + 24*8]
    mov ecx, 24
.polynomial:
    dec ecx
    mulsd xmm2, xmm1
    addsd xmm2, qword [rdx + rcx*8]
    test ecx, ecx
    jnz .polynomial

    movsd xmm1, qword [rel one]
    test r8d, r8d
    jz .central_enclosure
    js .multiply_forward
.multiply_backward:
    subsd xmm0, qword [rel one]
    mulsd xmm1, xmm0
    dec r8d
    jnz .multiply_backward
    mulsd xmm2, xmm1
    jmp .central_enclosure
.multiply_forward:
    mulsd xmm1, xmm0
    inc r8d
    jz .divide
    addsd xmm0, qword [rel one]
    jmp .multiply_forward
.divide:
    divsd xmm2, xmm1
.central_enclosure:
    movapd xmm0, xmm2
    movsd xmm3, qword [rel central_error]

.enclose:
    ; A relative radius with guard margin for the two endpoint operations.
    movq rax, xmm0
    mov rdx, 0x7fffffffffffffff
    and rax, rdx
    movq xmm1, rax
    mulsd xmm3, xmm1
    movapd xmm4, xmm0
    subsd xmm4, xmm3             ; lower endpoint
    addsd xmm0, xmm3             ; upper endpoint

    ; Convert in the caller's rounding direction, with clean masked flags
    ; for each endpoint and without flush-to-zero or denormals-are-zero.
    mov eax, [rsp]
    and eax, 0x6000
    or eax, 0x1f80
    mov [rsp + 4], eax
    ldmxcsr [rsp + 4]
    cvtsd2ss xmm5, xmm4
    stmxcsr [rsp + 8]
    ldmxcsr [rsp + 4]
    cvtsd2ss xmm6, xmm0
    stmxcsr [rsp + 12]
    movd eax, xmm5
    movd edx, xmm6
    cmp eax, edx
    jne .miss
    mov ecx, [rsp + 8]
    and ecx, 8
    mov edx, [rsp + 12]
    and edx, 8
    cmp ecx, edx
    jne .miss

    ; Exclude a possible exact result even when both endpoints round alike.
    cvtss2sd xmm5, xmm5
    ucomisd xmm5, xmm4
    jb .inexact
    ucomisd xmm5, xmm0
    jbe .miss
.inexact:
    ldmxcsr [rsp]
    mov edi, 32                  ; FE_INEXACT
    xor esi, esi
    test ecx, ecx
    jnz .range
    mov edx, eax
    and edx, 0x7fffffff
    cmp edx, 0x00800000
    jae .publish
    mov ecx, 16                  ; FE_UNDERFLOW for a tiny inexact result
.range:
    or edi, ecx
    mov esi, 34                  ; ERANGE
.publish:
    mov [rsp + 16], eax
    call __al_math_effects
    mov eax, [rsp + 16]
    mov edx, 1
    jmp .done
.miss:
    ldmxcsr [rsp]
    xor edx, edx
.done:
    add rsp, 24
    ret

section .rodata.__al_tgammaf_fast alloc noexec nowrite progbits align=8
masked_nearest:
    dq 0x1f80
one:
    dq 0x3ff0000000000000
two_and_half:
    dq 0x4004000000000000
three:
    dq 0x4008000000000000
tiny_error:
    dq 0x3ce0000000000000        ; 2^-49
central_error:
    dq 0x3d80000000000000        ; 2^-39
negative_euler:
    dq 0xbfe2788cfc6fb619
tiny_c2:
    dq 0x3fefa658c23b1578
tiny_c3:
    dq 0xbfed0a118f324b63
coefficients:
    ; Binary64 Taylor coefficients of Gamma(3+d) in increasing degree.
    dq 0x4000000000000000, 0x3ffd8773039049e7, 0x3ff3f18547938453
    dq 0x3fe2665a2bdcf38b, 0x3fcd73187d1582e8, 0x3fb2defd42705e3d
    dq 0x3f9691f1cf9aab71, 0x3f76516ec8f419d1, 0x3f56343551826c2c
    dq 0x3f315a5dc3630bf5, 0x3f100b449ce69f12, 0x3ee1d665e68521c0
    dq 0x3ec42f39ed5058bd, 0x3e77a0f4ffdac1f1, 0x3e7ea9541fcb2448
    dq 0xbe5184909ded7ea8, 0x3e4284d15d0e9da1, 0xbe24f80b65b5a42c
    dq 0x3e0dfe3dfa6ab1f9, 0xbdf3827939c8e474, 0x3dda47e0ca5fb7ed
    dq 0xbdc1790473ab0c4e, 0x3da7556cd96e6880, 0xbd8f1c43118ef423
    dq 0x3d74bf76be4d5ad8

section .note.GNU-stack noalloc noexec nowrite progbits
