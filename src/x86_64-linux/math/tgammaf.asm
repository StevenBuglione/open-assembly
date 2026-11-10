; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: tgammaf
; header: math.h
; prototype: float tgammaf(float x)
; standard: C17 7.12.8.4
; deps: fegetround, feraiseexcept, __errno_location
; errno: EDOM, ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the gamma value, including its sign on the negative real intervals. Use the active rounding mode.
; semantics: Signed zero gives signed infinity with ERANGE and FE_DIVBYZERO. Negative integers and negative infinity report EDOM and FE_INVALID with a quiet NaN.
; semantics: Quiet signaling NaNs with FE_INVALID. Overflow or a tiny inexact result reports ERANGE with the corresponding flags.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global tgammaf:function
extern __al_math_gamma:function
extern __al_math_scale:function
extern __al_tgammaf_fast:function

section .text.tgammaf alloc exec nowrite progbits
tgammaf:
    movd esi, xmm0
    sub rsp, 8
    mov eax, esi
    and eax, 0x7fffffff
    cmp eax, 0x7f800000
    jae .general
    test eax, eax
    jz .general
    cmp eax, 0x00200000           ; 2^-128
    jb .overflow
    test esi, esi
    js .negative
    cmp eax, 0x420c2910           ; first positive normal argument with gamma > 2^128
    jb .general
.overflow:
    and esi, 0x80000000
    mov ecx, 65536
    jmp .scale

.negative:
    cmp eax, 0x00200000           ; gamma(-2^-128) < -2^128
    je .overflow
    cmp eax, 0x42280000           ; |x| > 42
    jbe .general
    cmp eax, 0x4b000000           ; every float at or above 2^23 is integral
    jae .general
    mov r8d, eax
    shr r8d, 23
    mov ecx, 150
    sub ecx, r8d                  ; fractional significand bits, from 1 through 18
    mov edx, 1
    shl edx, cl
    dec edx
    test eax, edx
    jz .general                   ; a negative integer is a pole
    shr eax, cl
    and eax, 1
    xor eax, 1                    ; negative gamma when floor(|x|) is even
    shl eax, 31
    mov esi, eax
    mov rcx, -65536
.scale:
    or esi, 0x3f800000            ; signed one, scaled well beyond the output range
    xor edi, edi
    xor edx, edx
    call __al_math_scale
    jmp .done

.general:
    cmp eax, 0x00200000           ; keep the exact positive overflow boundary in Q256
    jbe .shared
    cmp eax, 0x42280000           ; exclude the large negative integers and nonfinite inputs
    jae .shared
    mov [rsp], esi
    mov edi, esi
    call __al_tgammaf_fast
    test edx, edx
    jnz .done
    mov esi, [rsp]
.shared:
    mov ecx, 1
    xor edx, edx
    xor edi, edi
    call __al_math_gamma
.done:
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
