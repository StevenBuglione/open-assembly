; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: sqrt
; header: math.h
; prototype: double sqrt(double x)
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

global sqrt:function
extern __errno_location:function

section .text.sqrt alloc exec nowrite progbits
sqrt:
    movq rax, xmm0
    test rax, rax
    jns .compute
    mov rdx, 0x8000000000000000
    cmp rax, rdx
    je .compute
    mov rdx, 0xfff0000000000000
    cmp rax, rdx
    ja .compute
    sub rsp, 8
    mov [rsp], rax
    call __errno_location
    mov dword [rax], 33
    movq xmm0, qword [rsp]
    add rsp, 8
.compute:
    sqrtsd xmm0, xmm0
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
