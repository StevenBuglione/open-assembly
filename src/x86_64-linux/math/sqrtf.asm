; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: sqrtf
; header: math.h
; prototype: float sqrtf(float x)
; standard: C17 7.12.7.5
; deps: feraiseexcept, __errno_location
; errno: EDOM
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the square root rounded in the active mode. Preserve signed zero.
; semantics: Negative nonzero x gives a quiet NaN, raises FE_INVALID and sets EDOM. A signaling NaN is quieted and raises invalid.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global sqrtf:function
extern __errno_location:function

section .text.sqrtf alloc exec nowrite progbits
sqrtf:
    movd eax, xmm0
    test eax, eax
    jns .compute
    cmp eax, 0x80000000
    je .compute
    cmp eax, 0xff800000
    ja .compute
    sub rsp, 8
    mov [rsp], eax
    call __errno_location
    mov dword [rax], 33
    movd xmm0, dword [rsp]
    add rsp, 8
.compute:
    sqrtss xmm0, xmm0
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
