; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: sqrtl
; header: math.h
; prototype: long double sqrtl(long double x)
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

global sqrtl:function
extern __errno_location:function

section .text.sqrtl alloc exec nowrite progbits
sqrtl:
    movzx eax, word [rsp + 16]
    test eax, 0x8000
    jz .compute
    mov rdx, [rsp + 8]
    cmp eax, 0x8000
    jne .negative_nonzero
    test rdx, rdx
    jz .compute
.negative_nonzero:
    cmp eax, 0xffff
    jne .domain
    mov rcx, 0x8000000000000000
    cmp rdx, rcx
    jne .compute
.domain:
    sub rsp, 8
    call __errno_location
    mov dword [rax], 33
    add rsp, 8
.compute:
    fld tword [rsp + 8]
    fsqrt
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
